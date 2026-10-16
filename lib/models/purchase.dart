import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'grocery_type.dart';

/// Spending categories used to group King Soopers line items.
enum SpendCategory {
  produce('Produce', Icons.eco_rounded, Color(0xFF27AE60)),
  meatSeafood('Meat & Protein', Icons.set_meal_rounded, Color(0xFFE74C3C)),
  dairyEggs('Dairy & Eggs', Icons.egg_rounded, Color(0xFF3498DB)),
  bakery('Bakery', Icons.bakery_dining_rounded, Color(0xFFD68910)),
  pantry('Pantry', Icons.kitchen_rounded, Color(0xFF8E44AD)),
  frozen('Frozen', Icons.ac_unit_rounded, Color(0xFF00BCD4)),
  snacks('Snacks & Sweets', Icons.cookie_rounded, Color(0xFFE67E22)),
  beverages('Beverages', Icons.local_drink_rounded, Color(0xFF16A085)),
  alcohol('Alcohol', Icons.wine_bar_rounded, Color(0xFF922B21)),
  household('Household', Icons.cleaning_services_rounded, Color(0xFF5D6D7E)),
  personalCare('Personal Care', Icons.spa_rounded, Color(0xFFEC407A)),
  fuel('Fuel', Icons.local_gas_station_rounded, Color(0xFF34495E)),
  other('Other', Icons.category_rounded, Color(0xFF95A5A6)),
  // Receipt-level only: never assigned to an item.
  tax('Tax & fees', Icons.receipt_rounded, Color(0xFF7F8C8D)),
  orderCoupons('Order coupons', Icons.local_offer_rounded, Color(0xFF27AE60));

  const SpendCategory(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;

  /// Categories a line item can belong to.
  static List<SpendCategory> get itemCategories => values.where((c) => c != tax && c != orderCoupons).toList();

  static SpendCategory fromName(String? name) {
    if (name == null) return SpendCategory.other;
    final n = name.trim().toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    for (final c in itemCategories) {
      if (c.name.toLowerCase() == n || c.label.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '') == n) {
        return c;
      }
    }
    // Older imports stored the label "Meat & Seafood".
    if (n == 'meatseafood') return SpendCategory.meatSeafood;
    return SpendCategory.other;
  }

  /// Comma-separated list of category keys for prompts.
  static String get promptKeys => itemCategories.map((c) => c.name).join(', ');
}

class LineItem {
  final String name;
  final double quantity;
  final double price; // what was paid for the line, as printed on the receipt (after its own discounts)
  final double listPrice; // regular price: price + savings
  final double savings; // item-level discounts printed under the line
  final SpendCategory category;
  // Set only for food that belongs in the pantry; null for household items, fuel, etc.
  final GroceryType? pantryType;
  final int? expiryDays;

  const LineItem({
    required this.name,
    required this.quantity,
    required this.price,
    required this.listPrice,
    required this.savings,
    required this.category,
    this.pantryType,
    this.expiryDays,
  });

  bool get isPantryFood => pantryType != null && price > 0;

  LineItem copyWith({SpendCategory? category, double? price}) => LineItem(
        name: name,
        quantity: quantity,
        price: price ?? this.price,
        listPrice: listPrice,
        savings: price == null ? savings : listPrice - price,
        category: category ?? this.category,
        pantryType: pantryType,
        expiryDays: expiryDays,
      );

  /// Reads a stored item.
  factory LineItem.fromMap(Map<String, dynamic> m) {
    final price = _toDouble(m['price']) ?? 0;
    final savings = (_toDouble(m['savings']) ?? 0).abs();
    return LineItem(
      name: (m['name'] ?? 'Item').toString(),
      quantity: _toDouble(m['quantity'] ?? m['qty']) ?? 1,
      price: price,
      listPrice: _toDouble(m['listPrice']) ?? price + savings,
      savings: savings,
      category: SpendCategory.fromName(m['category']?.toString()),
      pantryType: m['pantryType'] == null ? null : GroceryType.fromString(m['pantryType'].toString()),
      expiryDays: _toDouble(m['expiryDays'])?.round(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'quantity': quantity,
        'price': price,
        'listPrice': listPrice,
        'savings': savings,
        'category': category.name,
        if (pantryType != null) 'pantryType': pantryType!.name,
        if (expiryDays != null) 'expiryDays': expiryDays,
      };
}

/// One shopping trip / receipt.
class Purchase {
  final String id;
  final DateTime date;
  final String store;
  final double total; // amount charged
  final double tax;
  final double fees; // delivery, bag, service fees
  final double savings; // all savings the receipt reports
  final double itemDiscounts; // "Item Coupons & Sales": discounts attached to specific items
  final double couponSavings; // "Coupons": order-level coupons not tied to an item, applied after items
  final List<LineItem> items;

  /// Problems found when checking the AI's extraction against the receipt's own summary.
  /// Only set right after parsing; not stored.
  final List<String> problems;

  const Purchase({
    required this.id,
    required this.date,
    required this.store,
    required this.total,
    required this.tax,
    this.fees = 0,
    required this.savings,
    this.itemDiscounts = 0,
    this.couponSavings = 0,
    required this.items,
    this.problems = const [],
  });

  /// Deterministic id so importing the same receipt twice overwrites rather than duplicates.
  static String makeId(DateTime date, double total) {
    final d = '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
    return '${d}_${(total * 100).round()}';
  }

  /// How far apart the numbers may be before we treat the extraction as wrong (rounding).
  static const tolerance = 0.10;

  double get itemsTotal => items.fold<double>(0, (a, i) => a + i.price);

  /// Receipt total not explained by items + tax + fees - order coupons. Non-zero means the extraction is off.
  double get unaccounted => total - tax - fees + couponSavings - itemsTotal;

  bool get addsUp => unaccounted.abs() <= tolerance;

  Purchase copyWith({List<LineItem>? items}) => Purchase(
        id: id,
        date: date,
        store: store,
        total: total,
        tax: tax,
        fees: fees,
        savings: savings,
        itemDiscounts: itemDiscounts,
        couponSavings: couponSavings,
        items: items ?? this.items,
      );

  /// Spend per category, plus tax & fees and order coupons (negative). Anything the items don't explain
  /// goes under "Other" so the entries always add up to the receipt total.
  Map<SpendCategory, double> categoryTotals() {
    final totals = <SpendCategory, double>{};
    for (final item in items) {
      totals[item.category] = (totals[item.category] ?? 0) + item.price;
    }
    if ((tax + fees).abs() >= 0.01) totals[SpendCategory.tax] = tax + fees;
    if (couponSavings >= 0.01) totals[SpendCategory.orderCoupons] = -couponSavings;
    if (unaccounted.abs() >= 0.01) {
      totals[SpendCategory.other] = (totals[SpendCategory.other] ?? 0) + unaccounted;
    }
    return totals;
  }

  /// Builds a trip from the AI's raw extraction of a receipt, and checks it against the receipt's own summary.
  ///
  /// King Soopers prints each line at the price actually paid, with that item's discounts listed underneath;
  /// the subtotal is the regular-price total (paid + item discounts). Order-level coupons, fees and tax come after.
  factory Purchase.fromReceipt(Map<String, dynamic> m) {
    final date = _toDate(m['date']) ?? DateTime.now();
    final total = _toDouble(m['total']) ?? 0;
    final tax = _toDouble(m['tax']) ?? 0;
    final fees = _toDouble(m['fees']) ?? 0;
    final subtotal = _toDouble(m['subtotal']) ?? 0;
    final itemDiscounts = (_toDouble(m['itemDiscounts']) ?? 0).abs();
    final coupons = (_toDouble(m['coupons']) ?? 0).abs();

    // Merge repeated lines for the same product (King Soopers sometimes prints a $0.00 line carrying the coupon).
    final byName = <String, Map<String, dynamic>>{};
    for (final e in (m['items'] as List? ?? const []).whereType<Map>()) {
      final item = Map<String, dynamic>.from(e);
      final name = (item['name'] ?? 'Item').toString();
      final prev = byName[name];
      if (prev == null) {
        byName[name] = item;
        continue;
      }
      final price = _toDouble(item['price']) ?? 0;
      prev['price'] = (_toDouble(prev['price']) ?? 0) + price;
      prev['discount'] = (_toDouble(prev['discount']) ?? 0).abs() + (_toDouble(item['discount']) ?? 0).abs();
      if (price != 0) prev['quantity'] = (_toDouble(prev['quantity']) ?? 1) + (_toDouble(item['quantity']) ?? 1);
    }

    final items = [
      for (final r in byName.values)
        LineItem(
          name: (r['name'] ?? 'Item').toString(),
          quantity: _toDouble(r['quantity']) ?? 1,
          price: _toDouble(r['price']) ?? 0,
          listPrice: (_toDouble(r['price']) ?? 0) + (_toDouble(r['discount']) ?? 0).abs(),
          savings: (_toDouble(r['discount']) ?? 0).abs(),
          category: SpendCategory.fromName(r['category']?.toString()),
          pantryType: r['pantryType'] == null ? null : GroceryType.fromString(r['pantryType'].toString()),
          expiryDays: _toDouble(r['expiryDays'])?.round(),
        ),
    ];

    final paidSum = items.fold<double>(0, (a, i) => a + i.price);
    final discountSum = items.fold<double>(0, (a, i) => a + i.savings);
    final problems = <String>[];
    if (subtotal > 0 && (paidSum + discountSum - subtotal).abs() > tolerance) {
      problems.add('item prices (${_c(paidSum)}) + item discounts (${_c(discountSum)}) should equal the subtotal '
          '${_c(subtotal)} but come to ${_c(paidSum + discountSum)}');
    }
    if (itemDiscounts > 0 && (discountSum - itemDiscounts).abs() > tolerance) {
      problems.add('item discounts sum to ${_c(discountSum)} but "Item Coupons & Sales" is ${_c(itemDiscounts)}');
    }
    final expected = paidSum - coupons + fees + tax;
    if ((expected - total).abs() > tolerance) {
      problems.add('item prices - coupons + fees + tax = ${_c(expected)} but the total is ${_c(total)}');
    }

    final reportedSavings = (_toDouble(m['savings']) ?? 0).abs();
    return Purchase(
      id: makeId(date, total),
      date: date,
      store: (m['store'] ?? 'King Soopers').toString(),
      total: total,
      tax: tax,
      fees: fees,
      savings: reportedSavings > 0 ? reportedSavings : discountSum + coupons,
      itemDiscounts: itemDiscounts > 0 ? itemDiscounts : discountSum,
      couponSavings: coupons,
      items: items,
      problems: problems,
    );
  }

  /// Reads a stored trip.
  factory Purchase.fromMap(Map<String, dynamic> m, {String? id}) {
    final date = _toDate(m['date']) ?? DateTime.now();
    final total = _toDouble(m['total']) ?? 0;
    return Purchase(
      id: id ?? makeId(date, total),
      date: date,
      store: (m['store'] ?? 'King Soopers').toString(),
      total: total,
      tax: _toDouble(m['tax']) ?? 0,
      fees: _toDouble(m['fees']) ?? 0,
      savings: (_toDouble(m['savings']) ?? 0).abs(),
      itemDiscounts: (_toDouble(m['itemDiscounts']) ?? 0).abs(),
      couponSavings: (_toDouble(m['couponSavings']) ?? 0).abs(),
      items: (m['items'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => LineItem.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  factory Purchase.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Purchase.fromMap(doc.data() ?? const {}, id: doc.id);

  Map<String, dynamic> toMap() => {
        'date': Timestamp.fromDate(date),
        'store': store,
        'total': total,
        'tax': tax,
        'fees': fees,
        'savings': savings,
        'itemDiscounts': itemDiscounts,
        'couponSavings': couponSavings,
        'items': items.map((e) => e.toMap()).toList(),
        'importedAt': FieldValue.serverTimestamp(),
      };
}

String _c(double v) => '\$${v.toStringAsFixed(2)}';

double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString().replaceAll(RegExp(r'[^0-9.\-]'), ''));
}

DateTime? _toDate(dynamic v) {
  if (v == null) return null;
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  return DateTime.tryParse(v.toString());
}
