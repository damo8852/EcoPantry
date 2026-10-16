import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../models/grocery_type.dart';
import '../models/purchase.dart';
import 'config_service.dart';

/// Imports King Soopers purchase PDFs and stores trips + the monthly budget in Firestore.
///
/// Data layout:
///   users/{uid}                   -> field `monthlyGroceryBudget` (number)
///   users/{uid}/purchases/{id}    -> one [Purchase] per receipt
///   users/{uid}/items/{id}        -> food from recent trips is also added to the pantry
class BudgetService {
  static final BudgetService _instance = BudgetService._internal();
  factory BudgetService() => _instance;
  BudgetService._internal();

  static const String _baseUrl = 'https://api.openai.com/v1';

  final _db = FirebaseFirestore.instance;
  final _configService = ConfigService();

  String get _uid => FirebaseAuth.instance.currentUser!.uid;
  DocumentReference<Map<String, dynamic>> get _userDoc => _db.collection('users').doc(_uid);
  CollectionReference<Map<String, dynamic>> get _purchases => _userDoc.collection('purchases');

  // ---------------------------------------------------------------------------
  // Firestore
  // ---------------------------------------------------------------------------

  Stream<List<Purchase>> watchPurchases() => _purchases
      .orderBy('date', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Purchase.fromDoc).toList());

  Stream<double?> watchMonthlyBudget() => _userDoc.snapshots().map((d) {
        final v = d.data()?['monthlyGroceryBudget'];
        return v is num ? v.toDouble() : null;
      });

  Future<void> setMonthlyBudget(double? amount) =>
      _userDoc.set({'monthlyGroceryBudget': amount ?? FieldValue.delete()}, SetOptions(merge: true));

  /// Only trips this recent have their food added to the pantry; older ones only count toward spending.
  static const pantryWindow = Duration(days: 14);

  /// Parses a PDF, saves every trip for spending, and adds food from recent trips to the pantry.
  /// Each trip's food is added at most once, even if the same PDF is imported again.
  Future<PdfImportResult> importPdf(Uint8List bytes, {String filename = 'receipt.pdf'}) async {
    final trips = await parseReceiptPdf(bytes, filename: filename);
    final cutoff = DateTime.now().subtract(pantryWindow);

    var newTrips = 0;
    var pantryItems = 0;
    final batch = _db.batch();
    final items = _userDoc.collection('items');
    for (final p in trips) {
      final ref = _purchases.doc(p.id);
      final existing = await ref.get();
      if (!existing.exists) newTrips++;
      final alreadyInPantry = existing.data()?['addedToPantry'] == true;
      final food = p.items.where((i) => i.price > 0 && _pantryType(i) != null).toList();
      // Only mark the trip once its food is actually in the pantry, so a bad import can be redone.
      final addToPantry = !alreadyInPantry && p.date.isAfter(cutoff) && food.isNotEmpty;

      batch.set(ref, {...p.toMap(), 'addedToPantry': alreadyInPantry || addToPantry});

      if (alreadyInPantry) {
        // Re-import: correct prices on pantry items that came from this trip, without re-adding them.
        final byName = {for (final i in food) i.name: i};
        final existingItems = await items.where('purchaseId', isEqualTo: p.id).get();
        for (final doc in existingItems.docs) {
          final match = byName[doc.data()['name']];
          if (match != null) {
            batch.update(doc.reference, {'price': match.price / _pantryQty(match), 'updatedAt': FieldValue.serverTimestamp()});
          }
        }
      }
      if (!addToPantry) continue;

      for (final item in food) {
        final qty = _pantryQty(item);
        batch.set(items.doc(), {
          'name': item.name,
          'quantity': qty,
          'price': item.price / qty,
          'currency': '\$',
          'groceryType': _pantryType(item)!.name,
          'expiryDate': Timestamp.fromDate(p.date.add(Duration(days: item.expiryDays ?? 7))),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'source': 'kingsoopers_pdf',
          'purchaseId': p.id,
        });
        pantryItems++;
      }
    }
    await batch.commit();
    return PdfImportResult(trips: trips, newTrips: newTrips, pantryItems: pantryItems);
  }

  /// Pantry type from the AI, or inferred from the spending category; null for non-food.
  static GroceryType? _pantryType(LineItem item) =>
      item.pantryType ??
      switch (item.category) {
        SpendCategory.produce => GroceryType.vegetable,
        SpendCategory.meatSeafood => GroceryType.meat,
        SpendCategory.plantProtein => GroceryType.other,
        SpendCategory.dairyEggs => GroceryType.dairy,
        SpendCategory.bakery => GroceryType.grain,
        SpendCategory.pantry => GroceryType.condiment,
        SpendCategory.frozen => GroceryType.frozen,
        SpendCategory.snacks => GroceryType.snack,
        SpendCategory.beverages => GroceryType.beverage,
        _ => null,
      };

  /// Weighed produce (2.13 lb) is one pantry item; counted items keep their count.
  static int _pantryQty(LineItem item) {
    final isWhole = item.quantity >= 1 && item.quantity == item.quantity.roundToDouble();
    return isWhole ? item.quantity.toInt() : 1;
  }

  Future<void> updateItems(Purchase purchase) =>
      _purchases.doc(purchase.id).update({'items': purchase.items.map((e) => e.toMap()).toList()});

  Future<void> deletePurchase(String id) => _purchases.doc(id).delete();

  // ---------------------------------------------------------------------------
  // PDF import
  // ---------------------------------------------------------------------------

  /// Sends the PDF to OpenAI and returns every trip found in it.
  /// If a trip's items + tax don't match its total, the model is asked once to correct it.
  /// Throws a [BudgetImportException] with a user-facing message on failure.
  Future<List<Purchase>> parseReceiptPdf(Uint8List bytes, {String filename = 'receipt.pdf'}) async {
    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': _parsePrompt},
      {
        'role': 'user',
        'content': [
          {
            'type': 'file',
            'file': {
              'filename': filename,
              'file_data': 'data:application/pdf;base64,${base64Encode(bytes)}',
            },
          },
          {'type': 'text', 'text': 'Extract every purchase in this PDF as JSON.'},
        ],
      },
    ];

    var content = await _extract(messages);
    var trips = _decodeTrips(content);

    final off = trips.where((t) => t.problems.isNotEmpty).toList();
    if (off.isNotEmpty) {
      final problems = [
        for (final t in off)
          for (final p in t.problems) '- ${t.date.toIso8601String().substring(0, 10)} (total ${t.total}): $p',
      ];
      messages
        ..add({'role': 'assistant', 'content': content})
        ..add({
          'role': 'user',
          'content': 'Your numbers do not match the receipt summary:\n${problems.join('\n')}\n'
              'Re-read those receipts. Common causes: a missed item or discount line, subtracting a discount from a '
              'price that already includes it, or using the unit price instead of the line amount. '
              'Return the full corrected JSON for ALL trips.',
        });
      try {
        content = await _extract(messages);
        final retried = _decodeTrips(content);
        int errors(List<Purchase> ts) => ts.fold<int>(0, (a, t) => a + t.problems.length);
        if (errors(retried) < errors(trips)) trips = retried;
      } on BudgetImportException {
        // First result is still usable; trips that don't add up are flagged in the UI.
      }
    }
    return trips;
  }

  Future<String> _extract(List<Map<String, dynamic>> messages) => _chat(
        messages: messages,
        maxTokens: 16000,
        json: true,
        timeout: const Duration(minutes: 3),
      );

  List<Purchase> _decodeTrips(String content) {
    final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      throw BudgetImportException('Could not read the AI response. Try again.');
    }
    final trips = (decoded['trips'] as List? ?? const [])
        .whereType<Map>()
        .map((t) => Purchase.fromReceipt(Map<String, dynamic>.from(t)))
        .where((p) => p.total != 0 || p.items.isNotEmpty)
        .toList();
    if (trips.isEmpty) {
      throw BudgetImportException('No King Soopers purchases were found in that PDF.');
    }
    return trips;
  }

  static final String _parsePrompt = '''
You extract grocery purchases from King Soopers (Kroger) receipts, invoices and purchase-history PDFs.
The PDF may contain one receipt or many trips. Return ONLY JSON shaped like:
{"trips":[{"date":"YYYY-MM-DD","store":"King Soopers <location if shown>",
  "subtotal":0.00,"itemDiscounts":0.00,"coupons":0.00,"fees":0.00,"tax":0.00,"total":0.00,"savings":0.00,
  "items":[{"name":"","quantity":1,"price":0.00,"discount":0.00,"category":"","pantryType":null,"expiryDays":null}]}]}

Copy numbers exactly as printed. Do not do any discount math yourself.

Items:
- One entry per purchased line. Never output discount/savings lines as items.
- "price": the amount printed at the right of the line (all units / the full weight). On King Soopers receipts this
  is already what was paid after that item's sales and coupons, e.g. "5 x \$0.99  \$4.95" -> price 4.95, quantity 5.
- "discount": the sum of every discount line printed under that item ("Item Coupon/Sale: -\$0.50", "SC 1.00-",
  "KS SAVINGS", "CARD SAVINGS", "COUPON"), as a positive number. 0 if none. Do not subtract it from price.
- If the same product is printed on two lines (e.g. one with a price and one at \$0.00 carrying a coupon),
  output both lines with the same name.
- Weighed items: quantity is the weight in lb if shown, otherwise 1.
- Returned items get a negative price.

Trip summary (from the order summary / totals section; 0 if not shown):
- "subtotal": the subtotal before discounts. "itemDiscounts": "Item Coupons & Sales" or the total of item-level savings.
- "coupons": order-level coupons not printed under a specific item ("Coupons").
- "fees": all fees added together (delivery, service, bag, "Other Fees"). "tax": tax.
- "total": the amount charged. "savings": the headline total savings figure, positive.
- "subtotal" on King Soopers receipts is the regular-price total, i.e. sum(price) + sum(discount).
- Check: sum(price) + sum(discount) = subtotal, sum(discount) = itemDiscounts, and
  sum(price) - coupons + fees + tax = total. Re-read the receipt if these don't hold.

Other:
- Expand abbreviated product names into readable ones (e.g. "KRO 2% MLK GAL" -> "Kroger 2% Milk, Gallon").
- Ignore payment lines, fuel points, balances, barcodes and ads.
- "category" must be one of: ${SpendCategory.promptKeys}. Tofu, tempeh, seitan and other plant-based proteins are plantProtein.
- "pantryType": for food or drink that gets stored at home, one of: ${GroceryType.values.map((t) => t.name).join(', ')}.
  Use null for anything that is not food (household, personal care, fuel, bags, deposits).
- "expiryDays": for food, typical days until it should be used if stored normally (milk 7, bananas 5,
  canned goods 365, frozen 90). null for non-food.
- Use numbers, not strings, for money.
''';

  // ---------------------------------------------------------------------------
  // Budget coaching
  // ---------------------------------------------------------------------------

  /// Asks the model for concrete budgeting advice based on recent trips.
  Future<String> getBudgetAdvice({required List<Purchase> purchases, double? monthlyBudget}) async {
    final cutoff = DateTime.now().subtract(const Duration(days: 92));
    final recent = purchases.where((p) => p.date.isAfter(cutoff)).toList();
    if (recent.isEmpty) {
      throw BudgetImportException('Import some recent receipts first.');
    }

    final byMonth = <String, double>{};
    final savedByMonth = <String, double>{};
    final byCategory = <String, double>{};
    final byItem = <String, ({int count, double spent})>{};
    for (final p in recent) {
      final key = '${p.date.year}-${p.date.month.toString().padLeft(2, '0')}';
      byMonth[key] = (byMonth[key] ?? 0) + p.total;
      savedByMonth[key] = (savedByMonth[key] ?? 0) + p.savings;
      p.categoryTotals().forEach((c, v) => byCategory[c.label] = (byCategory[c.label] ?? 0) + v);
      for (final i in p.items) {
        final prev = byItem[i.name];
        byItem[i.name] = (count: (prev?.count ?? 0) + 1, spent: (prev?.spent ?? 0) + i.price);
      }
    }
    final topItems = byItem.entries.toList()..sort((a, b) => b.value.spent.compareTo(a.value.spent));
    final summary = {
      'monthlyBudget': monthlyBudget,
      'trips': recent.length,
      'spendByMonth': byMonth.map((k, v) => MapEntry(k, _r(v))),
      'spendByCategoryLast3Months': byCategory.map((k, v) => MapEntry(k, _r(v))),
      'savingsByMonth': savedByMonth.map((k, v) => MapEntry(k, _r(v))),
      'couponSavingsLast3Months': _r(recent.fold<double>(0, (a, p) => a + p.couponSavings)),
      'topItemsBySpend': topItems
          .take(25)
          .map((e) => {'item': e.key, 'timesBought': e.value.count, 'spent': _r(e.value.spent)})
          .toList(),
    };

    return _chat(
      messages: [
        {
          'role': 'system',
          'content': 'You are a practical grocery budgeting coach for someone who shops at King Soopers. '
              'Be specific to their data, quote dollar amounts, and keep it short. '
              'Reply in plain text: one sentence on how they are doing against their budget (or a suggested '
              'monthly budget if none is set), then 4-6 bullet points starting with "• " with concrete actions '
              '(swaps to Kroger brand, items to buy less often, categories to cap, trip frequency, digital coupons). '
              'No markdown headings or bold.',
        },
        {'role': 'user', 'content': jsonEncode(summary)},
      ],
      maxTokens: 700,
      temperature: 0.4,
    );
  }

  static double _r(double v) => (v * 100).roundToDouble() / 100;

  // ---------------------------------------------------------------------------

  Future<String> _chat({
    required List<Map<String, dynamic>> messages,
    int maxTokens = 1000,
    double temperature = 0.1,
    bool json = false,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final apiKey = await _configService.getOpenAiApiKey();
    if (apiKey == null) throw BudgetImportException('OpenAI API key is not configured.');

    final body = <String, dynamic>{
      'model': _configService.openAiModel,
      'messages': messages,
      ...ConfigService().openAiSampling(temperature: temperature, maxTokens: maxTokens),
      if (json) 'response_format': {'type': 'json_object'},
    };

    final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$_baseUrl/chat/completions'),
            headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $apiKey'},
            body: jsonEncode(body),
          )
          .timeout(timeout);
    } catch (e) {
      throw BudgetImportException('Network error: $e');
    }

    if (response.statusCode != 200) {
      print('OpenAI API error: ${response.statusCode} - ${response.body}');
      String? detail;
      try {
        detail = (jsonDecode(response.body) as Map)['error']?['message']?.toString();
      } catch (_) {}
      throw BudgetImportException('AI request failed (${response.statusCode})${detail != null ? ': $detail' : '.'}');
    }
    final data = jsonDecode(response.body);
    final choice = data['choices']?[0];
    if (choice?['finish_reason'] == 'length') {
      throw BudgetImportException('That PDF is too long to read at once. Try splitting it into smaller date ranges.');
    }
    final content = choice?['message']?['content']?.toString().trim();
    if (content == null || content.isEmpty) throw BudgetImportException('The AI returned an empty response.');
    return content;
  }
}

class PdfImportResult {
  final List<Purchase> trips;
  final int newTrips;
  final int pantryItems;
  const PdfImportResult({required this.trips, required this.newTrips, required this.pantryItems});

  double get total => trips.fold<double>(0, (a, p) => a + p.total);
  DateTime get latestDate => trips.map((t) => t.date).reduce((a, b) => a.isAfter(b) ? a : b);
}

class BudgetImportException implements Exception {
  final String message;
  BudgetImportException(this.message);
  @override
  String toString() => message;
}
