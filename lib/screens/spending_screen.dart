import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/purchase.dart';
import '../services/budget_service.dart';
import '../services/theme_service.dart';

const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

String _money(double v) => '${v < 0 ? '-' : ''}\$${v.abs().toStringAsFixed(2)}';
String _shortDate(DateTime d) => '${_monthNames[d.month - 1].substring(0, 3)} ${d.day}, ${d.year}';

/// Picks a King Soopers PDF, records every trip for spending and adds recent food to the pantry.
/// Used from the Pantry "+" menu and the spending card.
Future<void> importKingSoopersPdf(BuildContext context) async {
  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['pdf'],
    withData: true,
  );
  final file = result?.files.singleOrNull;
  if (file == null || file.bytes == null || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(child: Text('Reading your King Soopers PDF…')),
          ],
        ),
      ),
    ),
  );

  String message;
  var error = false;
  try {
    final r = await BudgetService().importPdf(file.bytes!, filename: file.name);
    final repeat = r.trips.length - r.newTrips;
    final pantry = r.pantryItems > 0
        ? 'Added ${r.pantryItems} food items to your pantry.'
        : 'No new pantry items (only trips from the last 2 weeks are added).';
    message = 'Imported ${r.trips.length} trip${r.trips.length == 1 ? '' : 's'} (${_money(r.total)})'
        '${repeat > 0 ? ', $repeat already imported' : ''}. $pantry';
  } on BudgetImportException catch (e) {
    message = e.message;
    error = true;
  } catch (e) {
    message = 'Import failed: $e';
    error = true;
  }
  navigator.pop();
  messenger.showSnackBar(SnackBar(
    content: Text(message),
    duration: const Duration(seconds: 6),
    backgroundColor: error ? Colors.red.shade700 : null,
  ));
}

/// Compact "spent this month" card shown on the Pantry home. Tap for the full breakdown.
class PantrySpendingCard extends StatelessWidget {
  const PantrySpendingCard({super.key});

  @override
  Widget build(BuildContext context) {
    final service = BudgetService();
    final dark = ThemeService().isDarkMode;
    final text = dark ? ThemeService.darkTextPrimary : ThemeService.lightTextPrimary;
    final subtext = dark ? ThemeService.darkTextSecondary : ThemeService.lightTextSecondary;
    final now = DateTime.now();

    return StreamBuilder<double?>(
      stream: service.watchMonthlyBudget(),
      builder: (context, budgetSnap) => StreamBuilder<List<Purchase>>(
        stream: service.watchPurchases(),
        builder: (context, snap) {
          if (snap.hasError || !snap.hasData) return const SizedBox.shrink();
          final budget = budgetSnap.data;
          final empty = snap.data!.isEmpty;
          final thisMonth = snap.data!.where((p) => p.date.year == now.year && p.date.month == now.month);
          final spent = thisMonth.fold<double>(0, (a, p) => a + p.total);
          final saved = thisMonth.fold<double>(0, (a, p) => a + p.savings);
          final ratio = budget != null && budget > 0 ? spent / budget : null;
          final barColor = ratio == null || ratio <= 0.85
              ? ThemeService.primaryColor
              : ratio > 1
                  ? Colors.red.shade600
                  : Colors.orange.shade600;

          return Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            decoration: BoxDecoration(
              color: dark ? ThemeService.darkCardBackground : ThemeService.lightCardBackground,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? 0.2 : 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: empty
                    ? () => importKingSoopersPdf(context)
                    : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SpendingScreen())),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: barColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.account_balance_wallet_rounded, color: barColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: empty
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Track grocery spending',
                                      style: TextStyle(color: text, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text('Import a King Soopers PDF to stock your pantry and see where your money goes',
                                      style: TextStyle(color: subtext, fontSize: 12)),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text('${_monthNames[now.month - 1]} groceries',
                                          style: TextStyle(color: subtext, fontSize: 12)),
                                      const Spacer(),
                                      Text(
                                        budget == null ? _money(spent) : '${_money(spent)} / ${_money(budget)}',
                                        style: TextStyle(color: text, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(
                                      value: (ratio ?? 0).clamp(0, 1).toDouble(),
                                      minHeight: 6,
                                      backgroundColor: dark ? ThemeService.darkBorder : ThemeService.lightBorder,
                                      valueColor: AlwaysStoppedAnimation(barColor),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    [
                                      if (saved > 0) 'Saved ${_money(saved)} with deals & coupons',
                                      if (budget == null) 'Tap to set a budget',
                                    ].join(' · '),
                                    style: TextStyle(color: subtext, fontSize: 11),
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right_rounded, color: subtext),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Monthly spending against a budget, opened from the Pantry spending card.
class SpendingScreen extends StatefulWidget {
  const SpendingScreen({super.key});
  @override
  State<SpendingScreen> createState() => _SpendingScreenState();
}

class _SpendingScreenState extends State<SpendingScreen> {
  final _service = BudgetService();
  final _theme = ThemeService();

  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  bool _loadingAdvice = false;
  String? _advice;

  bool get _dark => _theme.isDarkMode;
  Color get _bg => _dark ? ThemeService.darkBackground : ThemeService.lightBackground;
  Color get _card => _dark ? ThemeService.darkCard : ThemeService.lightCard;
  Color get _text => _dark ? ThemeService.darkTextPrimary : ThemeService.lightTextPrimary;
  Color get _subtext => _dark ? ThemeService.darkTextSecondary : ThemeService.lightTextSecondary;
  Color get _border => _dark ? ThemeService.darkBorder : ThemeService.lightBorder;

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  void _shiftMonth(int delta) => setState(() => _month = DateTime(_month.year, _month.month + delta));

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _editBudget(double? current) async {
    final controller = TextEditingController(text: current?.toStringAsFixed(0) ?? '');
    final value = await showDialog<double?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Monthly grocery budget'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          decoration: const InputDecoration(prefixText: '\$ ', hintText: 'e.g. 400'),
        ),
        actions: [
          if (current != null)
            TextButton(onPressed: () => Navigator.pop(ctx, -1.0), child: const Text('Remove')),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, double.tryParse(controller.text)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (value == null) return;
    await _service.setMonthlyBudget(value < 0 ? null : value);
  }

  Future<void> _getAdvice(List<Purchase> purchases, double? budget) async {
    setState(() => _loadingAdvice = true);
    try {
      final advice = await _service.getBudgetAdvice(purchases: purchases, monthlyBudget: budget);
      if (mounted) setState(() => _advice = advice);
    } on BudgetImportException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red.shade700),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingAdvice = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<double?>(
      stream: _service.watchMonthlyBudget(),
      builder: (context, budgetSnap) {
        final budget = budgetSnap.data;
        return Scaffold(
          backgroundColor: _bg,
          appBar: AppBar(
            backgroundColor: _bg,
            elevation: 0,
            iconTheme: IconThemeData(color: _text),
            title: Text('Grocery Spending', style: TextStyle(fontWeight: FontWeight.bold, color: _text)),
            actions: [
              IconButton(
                tooltip: 'Import King Soopers PDF',
                icon: Icon(Icons.picture_as_pdf_rounded, color: _text),
                onPressed: () => importKingSoopersPdf(context),
              ),
              IconButton(
                tooltip: 'Set monthly budget',
                icon: Icon(Icons.savings_rounded, color: _text),
                onPressed: () => _editBudget(budget),
              ),
            ],
          ),
          body: StreamBuilder<List<Purchase>>(
            stream: _service.watchPurchases(),
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(child: Text('Could not load purchases:\n${snap.error}', textAlign: TextAlign.center));
              }
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final all = snap.data!;
              final monthTrips = all
                  .where((p) => p.date.year == _month.year && p.date.month == _month.month)
                  .toList();
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                children: [
                  _monthSelector(),
                  const SizedBox(height: 12),
                  _summaryCard(monthTrips, budget),
                  const SizedBox(height: 16),
                  _savingsCard(all),
                  const SizedBox(height: 16),
                  _adviceCard(all, budget),
                  if (monthTrips.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _categoryCard(monthTrips),
                    const SizedBox(height: 16),
                    _sectionTitle('Trips'),
                    ...monthTrips.map(_tripTile),
                  ],
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _monthSelector() => Row(
        children: [
          IconButton(icon: Icon(Icons.chevron_left_rounded, color: _text), onPressed: () => _shiftMonth(-1)),
          Expanded(
            child: Text(
              '${_monthNames[_month.month - 1]} ${_month.year}',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _text),
            ),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right_rounded, color: _isCurrentMonth ? _border : _text),
            onPressed: _isCurrentMonth ? null : () => _shiftMonth(1),
          ),
        ],
      );

  BoxDecoration get _cardDecoration => BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      );

  Widget _summaryCard(List<Purchase> trips, double? budget) {
    final spent = trips.fold<double>(0, (a, p) => a + p.total);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final projected = _isCurrentMonth && spent > 0 ? spent / DateTime.now().day * daysInMonth : null;
    final ratio = budget != null && budget > 0 ? spent / budget : null;
    final overBudget = ratio != null && ratio > 1;
    final barColor = ratio == null
        ? ThemeService.primaryColor
        : ratio > 1
            ? Colors.red.shade600
            : ratio > 0.85
                ? Colors.orange.shade600
                : ThemeService.primaryColor;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Spent', style: TextStyle(color: _subtext)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_money(spent), style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: _text)),
              if (budget != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 6),
                  child: Text('of ${_money(budget)}', style: TextStyle(color: _subtext, fontSize: 16)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (ratio != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: ratio.clamp(0, 1).toDouble(),
                minHeight: 10,
                backgroundColor: _border,
                valueColor: AlwaysStoppedAnimation(barColor),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              overBudget ? '${_money(spent - budget!)} over budget' : '${_money(budget! - spent)} left',
              style: TextStyle(color: barColor, fontWeight: FontWeight.w600),
            ),
          ] else
            TextButton.icon(
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              onPressed: () => _editBudget(null),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Set a monthly budget'),
            ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              _stat('Trips', '${trips.length}'),
              if (projected != null)
                _stat('On pace for', _money(projected),
                    color: budget != null && projected > budget ? Colors.red.shade600 : null),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, {Color? color}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: _subtext, fontSize: 12)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(color: color ?? _text, fontWeight: FontWeight.w600, fontSize: 16)),
        ],
      );

  /// Savings for the selected month, how they break down, and the last 6 months for comparison.
  Widget _savingsCard(List<Purchase> all) {
    double savedIn(DateTime m) => all
        .where((p) => p.date.year == m.year && p.date.month == m.month)
        .fold<double>(0, (a, p) => a + p.savings);

    final trips = all.where((p) => p.date.year == _month.year && p.date.month == _month.month).toList();
    final saved = trips.fold<double>(0, (a, p) => a + p.savings);
    final itemDeals = trips.fold<double>(0, (a, p) => a + p.itemDiscounts);
    final coupons = trips.fold<double>(0, (a, p) => a + p.couponSavings);
    final otherSavings = saved - itemDeals - coupons;
    final paid = trips.fold<double>(0, (a, p) => a + p.total);
    final shelf = paid + saved;
    final rate = shelf > 0 ? saved / shelf : 0.0;

    final months = [for (var i = 5; i >= 0; i--) DateTime(_month.year, _month.month - i)];
    final history = [for (final m in months) (month: m, saved: savedIn(m))];
    final maxSaved = history.fold<double>(0, (a, h) => h.saved > a ? h.saved : a);
    const green = Color(0xFF27AE60);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_offer_rounded, color: green, size: 20),
              const SizedBox(width: 8),
              Text('Savings', style: TextStyle(fontWeight: FontWeight.bold, color: _text)),
            ],
          ),
          const SizedBox(height: 12),
          Text(_money(saved), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: green)),
          const SizedBox(height: 2),
          Text(
            saved > 0
                ? 'You paid ${_money(paid)} instead of ${_money(shelf)}, ${(rate * 100).round()}% off shelf price'
                : 'No savings recorded this month',
            style: TextStyle(color: _subtext, fontSize: 13),
          ),
          if (itemDeals > 0 || coupons > 0) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                if (itemDeals > 0) _stat('Item coupons & sales', _money(itemDeals), color: green),
                if (coupons > 0) _stat('Order coupons', _money(coupons), color: green),
                if (otherSavings >= 0.01) _stat('Other savings', _money(otherSavings), color: green),
              ],
            ),
          ],
          if (maxSaved > 0) ...[
            const SizedBox(height: 16),
            Text('Last 6 months', style: TextStyle(color: _subtext, fontSize: 12)),
            const SizedBox(height: 8),
            for (final h in history)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 36,
                      child: Text(
                        _monthNames[h.month.month - 1].substring(0, 3),
                        style: TextStyle(
                          color: h.month == _month ? _text : _subtext,
                          fontSize: 12,
                          fontWeight: h.month == _month ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: h.saved / maxSaved,
                          minHeight: 8,
                          backgroundColor: _border.withValues(alpha: 0.4),
                          valueColor: AlwaysStoppedAnimation(green.withValues(alpha: h.month == _month ? 1 : 0.55)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 64,
                      child: Text(_money(h.saved),
                          textAlign: TextAlign.right, style: TextStyle(color: _subtext, fontSize: 12)),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _adviceCard(List<Purchase> all, double? budget) => Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: ThemeService.primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Budget coach', style: TextStyle(fontWeight: FontWeight.bold, color: _text)),
                ),
                TextButton(
                  onPressed: _loadingAdvice ? null : () => _getAdvice(all, budget),
                  child: _loadingAdvice
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_advice == null ? 'Get tips' : 'Refresh'),
                ),
              ],
            ),
            if (_advice != null) ...[
              const SizedBox(height: 8),
              SelectableText(_advice!, style: TextStyle(color: _text, height: 1.45)),
            ] else
              Text('Uses your last 3 months of trips to suggest where to cut back.',
                  style: TextStyle(color: _subtext, fontSize: 13)),
          ],
        ),
      );

  Widget _categoryCard(List<Purchase> trips) {
    final totals = <SpendCategory, double>{};
    for (final p in trips) {
      p.categoryTotals().forEach((c, v) => totals[c] = (totals[c] ?? 0) + v);
    }
    final deductions = totals.entries.where((e) => e.value < -0.005).toList();
    final entries = totals.entries.where((e) => e.value > 0.005).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final max = entries.isEmpty ? 1.0 : entries.first.value;
    final sum = entries.fold<double>(0, (a, e) => a + e.value);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Where it went', style: TextStyle(fontWeight: FontWeight.bold, color: _text)),
          const SizedBox(height: 12),
          for (final e in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(e.key.icon, size: 18, color: e.key.color),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 110,
                    child: Text(e.key.label,
                        overflow: TextOverflow.ellipsis, style: TextStyle(color: _text, fontSize: 13)),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: e.value / max,
                        minHeight: 8,
                        backgroundColor: _border.withValues(alpha: 0.4),
                        valueColor: AlwaysStoppedAnimation(e.key.color),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 92,
                    child: Text(
                      '${_money(e.value)} · ${(e.value / sum * 100).round()}%',
                      textAlign: TextAlign.right,
                      style: TextStyle(color: _subtext, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          for (final e in deductions)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(e.key.icon, size: 18, color: e.key.color),
                  const SizedBox(width: 8),
                  Expanded(child: Text(e.key.label, style: TextStyle(color: _text, fontSize: 13))),
                  Text(_money(e.value), style: TextStyle(color: e.key.color, fontSize: 12)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Text(t, style: TextStyle(fontWeight: FontWeight.bold, color: _text, fontSize: 16)),
      );

  Widget _tripTile(Purchase p) => Dismissible(
        key: ValueKey(p.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(color: Colors.red.shade600, borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.delete_rounded, color: Colors.white),
        ),
        confirmDismiss: (_) => showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete trip?'),
            content: Text('${_shortDate(p.date)} · ${_money(p.total)}\n\nPantry items from this trip are kept.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
            ],
          ),
        ),
        onDismissed: (_) => _service.deletePurchase(p.id),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: _cardDecoration.copyWith(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PurchaseDetailScreen(purchase: p)),
            ),
            leading: CircleAvatar(
              backgroundColor: ThemeService.primaryColor.withValues(alpha: 0.15),
              child: Icon(Icons.shopping_basket_rounded, color: ThemeService.primaryColor),
            ),
            title: Text(_shortDate(p.date), style: TextStyle(color: _text, fontWeight: FontWeight.w600)),
            subtitle: p.addsUp
                ? Text(
                    '${p.items.length} items${p.savings > 0 ? ' · saved ${_money(p.savings)}' : ''}',
                    style: TextStyle(color: _subtext),
                  )
                : Text(
                    "Items don't add up (${_money(p.unaccounted)} unmatched)",
                    style: TextStyle(color: Colors.orange.shade600),
                  ),
            trailing: Text(_money(p.total),
                style: TextStyle(color: _text, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
      );
}

/// Line items for one trip. Tap an item to fix its category.
class PurchaseDetailScreen extends StatefulWidget {
  final Purchase purchase;
  const PurchaseDetailScreen({super.key, required this.purchase});
  @override
  State<PurchaseDetailScreen> createState() => _PurchaseDetailScreenState();
}

class _PurchaseDetailScreenState extends State<PurchaseDetailScreen> {
  late Purchase _purchase = widget.purchase;
  final _theme = ThemeService();

  Future<void> _changeCategory(int index) async {
    final item = _purchase.items[index];
    final picked = await showModalBottomSheet<SpendCategory>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            for (final c in SpendCategory.itemCategories)
              ListTile(
                leading: Icon(c.icon, color: c.color),
                title: Text(c.label),
                trailing: c == item.category ? const Icon(Icons.check_rounded) : null,
                onTap: () => Navigator.pop(ctx, c),
              ),
          ],
        ),
      ),
    );
    if (picked == null || picked == item.category) return;
    final items = [..._purchase.items];
    items[index] = item.copyWith(category: picked);
    setState(() => _purchase = _purchase.copyWith(items: items));
    await BudgetService().updateItems(_purchase);
  }

  @override
  Widget build(BuildContext context) {
    final dark = _theme.isDarkMode;
    final text = dark ? ThemeService.darkTextPrimary : ThemeService.lightTextPrimary;
    final subtext = dark ? ThemeService.darkTextSecondary : ThemeService.lightTextSecondary;
    final p = _purchase;

    return Scaffold(
      backgroundColor: dark ? ThemeService.darkBackground : ThemeService.lightBackground,
      appBar: AppBar(
        backgroundColor: dark ? ThemeService.darkBackground : ThemeService.lightBackground,
        title: Text(_shortDate(p.date), style: TextStyle(color: text, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: text),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ListTile(
            title: Text(p.store, style: TextStyle(color: text, fontWeight: FontWeight.w600)),
            subtitle: Text(
              [
                'Tax ${_money(p.tax)}',
                if (p.fees > 0) 'Fees ${_money(p.fees)}',
                if (p.couponSavings > 0) 'Order coupons -${_money(p.couponSavings)}',
                if (p.savings > 0) 'Saved ${_money(p.savings)}',
              ].join(' · '),
              style: TextStyle(color: subtext),
            ),
            trailing: Text(_money(p.total),
                style: TextStyle(color: text, fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          if (!p.addsUp)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange.shade600),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Items (${_money(p.itemsTotal)}) + tax & fees (${_money(p.tax + p.fees)}) - order coupons '
                      '(${_money(p.couponSavings)}) don\'t match the receipt total '
                      '(${_money(p.total)}). The ${_money(p.unaccounted)} difference is counted as Other. '
                      'Re-importing the PDF may fix it.',
                      style: TextStyle(color: text, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          const Divider(),
          for (var i = 0; i < p.items.length; i++)
            ListTile(
              onTap: () => _changeCategory(i),
              leading: Icon(p.items[i].category.icon, color: p.items[i].category.color),
              title: Text(p.items[i].name, style: TextStyle(color: text)),
              subtitle: Text(
                [
                  p.items[i].category.label,
                  if (p.items[i].quantity != 1) '× ${_qty(p.items[i].quantity)}',
                  if (p.items[i].savings > 0)
                    'reg ${_money(p.items[i].listPrice)}, saved ${_money(p.items[i].savings)}',
                ].join(' · '),
                style: TextStyle(color: subtext, fontSize: 12),
              ),
              trailing: Text(_money(p.items[i].price), style: TextStyle(color: text)),
            ),
        ],
      ),
    );
  }

  static String _qty(double q) => q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(2);
}
