import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/purchase.dart';
import '../services/budget_service.dart';
import '../services/theme_service.dart';
import '../widgets/animations.dart';

const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

const _green = ThemeService.primaryColor;
const _walletHeroTag = 'spending-wallet';

String _money(double v) => formatMoney(v);
String _shortDate(DateTime d) => '${_monthNames[d.month - 1].substring(0, 3)} ${d.day}, ${d.year}';
bool _inMonth(Purchase p, DateTime m) => p.date.year == m.year && p.date.month == m.month;

/// Picks a King Soopers PDF, records every trip for spending and adds recent food to the pantry.
/// Used from the Pantry "+" menu and the spending screens.
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
        content: Row(
          children: [
            Breathing(
              child: CircleAvatar(
                radius: 24,
                backgroundColor: Color(0x2627AE60),
                child: Icon(Icons.receipt_long_rounded, color: _green),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reading your receipt…', style: TextStyle(fontWeight: FontWeight.w600)),
                  SizedBox(height: 4),
                  Text('This can take up to a minute.', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
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
        : repeat > 0
            ? 'Its food was already in your pantry.'
            : 'No pantry items added (only trips from the last 2 weeks go into the pantry).';
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
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    duration: const Duration(seconds: 6),
    backgroundColor: error ? Colors.red.shade700 : null,
  ));
}

/// Palette shared by the spending screens, following the app's light/dark setting.
class _Palette {
  final bool dark;
  _Palette(this.dark);
  Color get bg => dark ? ThemeService.darkBackground : ThemeService.lightBackground;
  Color get card => dark ? ThemeService.darkCard : ThemeService.lightCard;
  Color get text => dark ? ThemeService.darkTextPrimary : ThemeService.lightTextPrimary;
  Color get subtext => dark ? ThemeService.darkTextSecondary : ThemeService.lightTextSecondary;
  Color get track => (dark ? ThemeService.darkBorder : ThemeService.lightBorder).withValues(alpha: dark ? 0.6 : 0.8);

  BoxDecoration cardDecoration({double radius = 20}) => BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.25 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      );
}

// =============================================================================
// Pantry home card
// =============================================================================

/// Compact "spent this month" card shown on the Pantry home. Tap for the full breakdown.
class PantrySpendingCard extends StatelessWidget {
  const PantrySpendingCard({super.key});

  @override
  Widget build(BuildContext context) {
    final service = BudgetService();
    final c = _Palette(ThemeService().isDarkMode);
    final now = DateTime.now();

    return StreamBuilder<double?>(
      stream: service.watchMonthlyBudget(),
      builder: (context, budgetSnap) => StreamBuilder<List<Purchase>>(
        stream: service.watchPurchases(),
        builder: (context, snap) {
          if (snap.hasError || !snap.hasData) return const SizedBox.shrink();
          final budget = budgetSnap.data;
          final empty = snap.data!.isEmpty;
          final thisMonth = snap.data!.where((p) => _inMonth(p, now));
          final spent = thisMonth.fold<double>(0, (a, p) => a + p.total);
          final saved = thisMonth.fold<double>(0, (a, p) => a + p.savings);
          final ratio = budget != null && budget > 0 ? spent / budget : null;
          final barColor = _budgetColor(ratio);

          return Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              decoration: c.cardDecoration(radius: 16),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: empty
                      ? () => importKingSoopersPdf(context)
                      : () => Navigator.push(context, _fadeRoute(const SpendingScreen())),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Hero(
                          tag: _walletHeroTag,
                          child: iconChip(Icons.account_balance_wallet_rounded, barColor, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: empty
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Track grocery spending',
                                        style: TextStyle(color: c.text, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 2),
                                    Text('Import a King Soopers PDF to stock your pantry and see where your money goes',
                                        style: TextStyle(color: c.subtext, fontSize: 12)),
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text('${_monthNames[now.month - 1]} groceries',
                                            style: TextStyle(color: c.subtext, fontSize: 12)),
                                        const Spacer(),
                                        CountUp(spent, style: TextStyle(color: c.text, fontWeight: FontWeight.bold)),
                                        if (budget != null)
                                          Text(' / ${_money(budget)}', style: TextStyle(color: c.subtext, fontSize: 12)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    GrowBar(fraction: ratio ?? 0, color: barColor, track: c.track, height: 6),
                                    const SizedBox(height: 6),
                                    Text(
                                      [
                                        if (saved > 0) 'Saved ${_money(saved)} with deals & coupons',
                                        if (budget == null) 'Tap to set a budget',
                                      ].join(' · '),
                                      style: TextStyle(color: c.subtext, fontSize: 11),
                                    ),
                                  ],
                                ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right_rounded, color: c.subtext),
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

Color _budgetColor(double? ratio) => ratio == null || ratio <= 0.85
    ? _green
    : ratio > 1
        ? Colors.red.shade600
        : Colors.orange.shade600;

Route<T> _fadeRoute<T>(Widget page) => PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 450),
      reverseTransitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(curved),
            child: child,
          ),
        );
      },
    );

// =============================================================================
// Spending screen
// =============================================================================

/// Monthly spending against a budget, opened from the Pantry spending card.
class SpendingScreen extends StatefulWidget {
  const SpendingScreen({super.key});
  @override
  State<SpendingScreen> createState() => _SpendingScreenState();
}

class _SpendingScreenState extends State<SpendingScreen> {
  final _service = BudgetService();
  late final _c = _Palette(ThemeService().isDarkMode);

  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  final Set<SpendCategory> _expanded = {};
  bool _loadingAdvice = false;
  String? _advice;

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  bool _isFuture(DateTime m) {
    final now = DateTime.now();
    return m.year > now.year || (m.year == now.year && m.month > now.month);
  }

  void _setMonth(DateTime m) {
    if (_isFuture(m) || m == _month) return;
    setState(() {
      _month = m;
      _expanded.clear();
    });
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _editBudget(double? current) async {
    final controller = TextEditingController(text: current?.toStringAsFixed(0) ?? '');
    final value = await showDialog<double?>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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

  void _openTrip(Purchase p) => Navigator.push(context, _fadeRoute(PurchaseDetailScreen(purchase: p)));

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
          backgroundColor: _c.bg,
          appBar: AppBar(
            backgroundColor: _c.bg,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: _c.text),
            title: Text('Grocery Spending', style: TextStyle(fontWeight: FontWeight.bold, color: _c.text)),
            actions: [
              IconButton(
                tooltip: 'Import King Soopers PDF',
                icon: Icon(Icons.upload_file_rounded, color: _c.text),
                onPressed: () => importKingSoopersPdf(context),
              ),
              IconButton(
                tooltip: 'Set monthly budget',
                icon: Icon(Icons.savings_rounded, color: _c.text),
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
              final trips = all.where((p) => _inMonth(p, _month)).toList();
              final sections = <Widget>[
                _summaryCard(trips, budget),
                _savingsCard(all, trips),
                if (trips.isNotEmpty) _categoryCard(trips),
                _adviceCard(all, budget),
                if (trips.isNotEmpty) _tripsSection(trips) else _emptyMonth(),
              ];
              return Column(
                children: [
                  _monthSelector(),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: ListView(
                        key: ValueKey(_month),
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                        children: [
                          for (var i = 0; i < sections.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Entrance(index: i, child: sections[i]),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _monthSelector() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Container(
          decoration: _c.cardDecoration(radius: 30),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.chevron_left_rounded, color: _c.text),
                onPressed: () => _setMonth(DateTime(_month.year, _month.month - 1)),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, a) => FadeTransition(
                    opacity: a,
                    child: ScaleTransition(scale: Tween(begin: 0.9, end: 1.0).animate(a), child: child),
                  ),
                  child: Text(
                    '${_monthNames[_month.month - 1]} ${_month.year}',
                    key: ValueKey(_month),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _c.text),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right_rounded, color: _isCurrentMonth ? _c.track : _c.text),
                onPressed: _isCurrentMonth ? null : () => _setMonth(DateTime(_month.year, _month.month + 1)),
              ),
            ],
          ),
        ),
      );

  Widget _cardHeader(IconData icon, Color color, String title, {Widget? trailing}) => Row(
        children: [
          iconChip(icon, color),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _c.text))),
          if (trailing != null) trailing,
        ],
      );

  Widget _stat(String label, String value, {Color? color, Color? labelColor}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: labelColor ?? _c.subtext, fontSize: 12)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(color: color ?? _c.text, fontWeight: FontWeight.w700, fontSize: 16)),
        ],
      );

  /// Green header card: what was spent this month, with a budget ring.
  Widget _summaryCard(List<Purchase> trips, double? budget) {
    final spent = trips.fold<double>(0, (a, p) => a + p.total);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final projected = _isCurrentMonth && spent > 0 ? spent / DateTime.now().day * daysInMonth : null;
    final ratio = budget != null && budget > 0 ? spent / budget : null;
    final ringColor = ratio == null || ratio <= 0.85
        ? Colors.white
        : ratio > 1
            ? const Color(0xFFFF8A80)
            : const Color(0xFFFFD180);
    const white70 = Color(0xB3FFFFFF);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: _c.dark
              ? const [Color(0xFF1E6B41), Color(0xFF134D2E)]
              : const [Color(0xFF2ECC71), Color(0xFF1E8449)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: _green.withValues(alpha: 0.3), blurRadius: 18, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Hero(
                          tag: _walletHeroTag,
                          child: iconChip(Icons.account_balance_wallet_rounded, Colors.white, size: 16, pad: 6),
                        ),
                        const SizedBox(width: 8),
                        const Text('Spent this month', style: TextStyle(color: white70)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: CountUp(spent,
                          style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      budget == null
                          ? 'No budget set'
                          : ratio! > 1
                              ? '${_money(spent - budget)} over your ${_money(budget)} budget'
                              : '${_money(budget - spent)} left of ${_money(budget)}',
                      style: const TextStyle(color: white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (ratio != null)
                SizedBox(
                  width: 84,
                  height: 84,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: ratio.clamp(0, 1).toDouble()),
                    duration: const Duration(milliseconds: 1100),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, __) => Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: v,
                          strokeWidth: 8,
                          strokeCap: StrokeCap.round,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          valueColor: AlwaysStoppedAnimation(ringColor),
                        ),
                        Center(
                          child: Text('${(ratio * 100).round()}%',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ],
                    ),
                  ),
                )
              else
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  onPressed: () => _editBudget(null),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Budget'),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _stat('Trips', '${trips.length}', color: Colors.white, labelColor: white70),
              const SizedBox(width: 28),
              if (projected != null)
                _stat('On pace for', _money(projected),
                    color: budget != null && projected > budget ? const Color(0xFFFF8A80) : Colors.white,
                    labelColor: white70),
            ],
          ),
        ],
      ),
    );
  }

  /// Savings for the selected month, how they break down, and a 6-month chart (tap a bar to jump).
  Widget _savingsCard(List<Purchase> all, List<Purchase> trips) {
    final saved = trips.fold<double>(0, (a, p) => a + p.savings);
    final itemDeals = trips.fold<double>(0, (a, p) => a + p.itemDiscounts);
    final coupons = trips.fold<double>(0, (a, p) => a + p.couponSavings);
    final otherSavings = saved - itemDeals - coupons;
    final paid = trips.fold<double>(0, (a, p) => a + p.total);
    final shelf = paid + saved;
    final rate = shelf > 0 ? saved / shelf : 0.0;

    final months = [for (var i = 5; i >= 0; i--) DateTime(_month.year, _month.month - i)];
    final history = [
      for (final m in months) (month: m, saved: all.where((p) => _inMonth(p, m)).fold<double>(0, (a, p) => a + p.savings)),
    ];
    final maxSaved = history.fold<double>(0, (a, h) => h.saved > a ? h.saved : a);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _c.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(Icons.local_offer_rounded, _green, 'Savings',
              trailing: saved > 0
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('${(rate * 100).round()}% off',
                          style: const TextStyle(color: _green, fontWeight: FontWeight.bold, fontSize: 12)),
                    )
                  : null),
          const SizedBox(height: 14),
          CountUp(saved, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: _green)),
          const SizedBox(height: 2),
          Text(
            saved > 0 ? 'You paid ${_money(paid)} instead of ${_money(shelf)}' : 'No savings recorded this month',
            style: TextStyle(color: _c.subtext, fontSize: 13),
          ),
          if (itemDeals > 0 || coupons > 0) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (itemDeals > 0) _savingsChip('Item coupons & sales', itemDeals),
                if (coupons > 0) _savingsChip('Order coupons', coupons),
                if (otherSavings >= 0.01) _savingsChip('Other', otherSavings),
              ],
            ),
          ],
          if (maxSaved > 0) ...[
            const SizedBox(height: 18),
            SizedBox(
              height: 110,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final h in history)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _setMonth(h.month),
                        child: _savingsColumn(h.month, h.saved, maxSaved),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _savingsChip(String label, double amount) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _green.withValues(alpha: _c.dark ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: _c.subtext, fontSize: 11)),
            Text(_money(amount), style: const TextStyle(color: _green, fontWeight: FontWeight.bold)),
          ],
        ),
      );

  Widget _savingsColumn(DateTime month, double saved, double maxSaved) {
    final selected = month == _month;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        AnimatedOpacity(
          opacity: selected && saved > 0 ? 1 : 0,
          duration: const Duration(milliseconds: 250),
          child: Text('\$${saved.round()}', style: const TextStyle(color: _green, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 4),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: maxSaved > 0 ? saved / maxSaved : 0),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutBack,
          builder: (_, f, __) => AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 22,
            height: 4 + 64 * f.clamp(0, 1.1),
            decoration: BoxDecoration(
              color: selected ? _green : _green.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _monthNames[month.month - 1].substring(0, 3),
          style: TextStyle(
            color: selected ? _c.text : _c.subtext,
            fontSize: 11,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _adviceCard(List<Purchase> all, double? budget) => Container(
        padding: const EdgeInsets.all(18),
        decoration: _c.cardDecoration(),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _cardHeader(
                Icons.auto_awesome_rounded,
                const Color(0xFF8E44AD),
                'Budget coach',
                trailing: FilledButton.tonal(
                  onPressed: _loadingAdvice ? null : () => _getAdvice(all, budget),
                  child: _loadingAdvice
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_advice == null ? 'Get tips' : 'Refresh'),
                ),
              ),
              const SizedBox(height: 10),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _advice != null
                    ? SelectableText(_advice!, key: ValueKey(_advice), style: TextStyle(color: _c.text, height: 1.5))
                    : Text('Uses your last 3 months of trips to suggest where to cut back.',
                        style: TextStyle(color: _c.subtext, fontSize: 13)),
              ),
            ],
          ),
        ),
      );

  // ---------------------------------------------------------------------------
  // Where it went: tap a category to see exactly what it was spent on
  // ---------------------------------------------------------------------------

  Widget _categoryCard(List<Purchase> trips) {
    final totals = <SpendCategory, double>{};
    for (final p in trips) {
      p.categoryTotals().forEach((c, v) => totals[c] = (totals[c] ?? 0) + v);
    }
    // Only what was bought; tax, fees and order coupons aren't spending categories.
    totals
      ..remove(SpendCategory.tax)
      ..remove(SpendCategory.orderCoupons);
    final entries = totals.entries.where((e) => e.value > 0.005).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final max = entries.isEmpty ? 1.0 : entries.first.value;
    final sum = entries.fold<double>(0, (a, e) => a + e.value);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _c.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(Icons.donut_small_rounded, const Color(0xFF3498DB), 'Where it went',
              trailing: Text('Tap to see items', style: TextStyle(color: _c.subtext, fontSize: 11))),
          const SizedBox(height: 14),
          _stackedBar(entries, sum),
          const SizedBox(height: 10),
          for (final e in entries) _categoryRow(e.key, e.value, e.value / max, e.value / sum, trips),
        ],
      ),
    );
  }

  /// One bar split into every category's share of the month.
  Widget _stackedBar(List<MapEntry<SpendCategory, double>> entries, double sum) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 14,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeOutCubic,
            builder: (_, t, __) => Row(
              children: [
                for (final e in entries)
                  Expanded(
                    flex: (e.value / sum * 1000 * t).round().clamp(1, 1000),
                    child: Container(
                      margin: const EdgeInsets.only(right: 1.5),
                      color: e.key.color,
                    ),
                  ),
                if (((1 - t) * 1000).round() > 0)
                  Expanded(flex: ((1 - t) * 1000).round(), child: Container(color: _c.track)),
              ],
            ),
          ),
        ),
      );

  Widget _categoryRow(SpendCategory cat, double amount, double barFraction, double? share, List<Purchase> trips) {
    final open = _expanded.contains(cat);
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => open ? _expanded.remove(cat) : _expanded.add(cat)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                children: [
                  iconChip(cat.icon, cat.color, size: 16, pad: 6),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(cat.label,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: _c.text, fontSize: 14, fontWeight: FontWeight.w500)),
                            ),
                            Text(_money(amount),
                                style: TextStyle(
                                  color: amount < 0 ? cat.color : _c.text,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                )),
                            if (share != null)
                              SizedBox(
                                width: 42,
                                child: Text('${(share * 100).round()}%',
                                    textAlign: TextAlign.right, style: TextStyle(color: _c.subtext, fontSize: 12)),
                              ),
                          ],
                        ),
                        if (amount > 0) ...[
                          const SizedBox(height: 6),
                          GrowBar(fraction: barFraction, color: cat.color, track: _c.track, height: 6),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(Icons.expand_more_rounded, color: _c.subtext, size: 20),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: open ? _categoryDetails(cat, trips) : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  /// The purchases behind one category this month, biggest first. Tap one to open its trip.
  Widget _categoryDetails(SpendCategory cat, List<Purchase> trips) {
    final rows = <({Purchase trip, String title, String subtitle, double amount})>[];
    for (final p in trips) {
      for (final i in p.items.where((i) => i.category == cat)) {
        rows.add((
          trip: p,
          title: i.name,
          subtitle: [
            _shortDate(p.date),
            if (i.quantity != 1) '× ${_qty(i.quantity)}',
            if (i.savings > 0) 'saved ${_money(i.savings)}',
          ].join(' · '),
          amount: i.price,
        ));
      }
      if (cat == SpendCategory.other && p.unaccounted.abs() >= 0.01) {
        rows.add((
          trip: p,
          title: 'Not matched to an item',
          subtitle: "${_shortDate(p.date)} · receipt items didn't add up",
          amount: p.unaccounted,
        ));
      }
    }
    rows.sort((a, b) => b.amount.abs().compareTo(a.amount.abs()));

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: cat.color.withValues(alpha: _c.dark ? 0.08 : 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: cat.color, width: 3)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            Entrance(
              index: i.clamp(0, 8),
              child: InkWell(
                onTap: () => _openTrip(rows[i].trip),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(rows[i].title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: _c.text, fontSize: 13)),
                            const SizedBox(height: 2),
                            Text(rows[i].subtitle, style: TextStyle(color: _c.subtext, fontSize: 11)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(_money(rows[i].amount),
                          style: TextStyle(
                            color: rows[i].amount < 0 ? _green : _c.text,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          )),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Trips
  // ---------------------------------------------------------------------------

  Widget _emptyMonth() => Container(
        padding: const EdgeInsets.all(24),
        decoration: _c.cardDecoration(),
        child: Column(
          children: [
            iconChip(Icons.receipt_long_rounded, _green, size: 28, pad: 12),
            const SizedBox(height: 12),
            Text('No trips in ${_monthNames[_month.month - 1]}',
                style: TextStyle(color: _c.text, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Import a King Soopers PDF to see where your money goes.',
                textAlign: TextAlign.center, style: TextStyle(color: _c.subtext, fontSize: 13)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => importKingSoopersPdf(context),
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Import PDF'),
            ),
          ],
        ),
      );

  Widget _tripsSection(List<Purchase> trips) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text('Trips', style: TextStyle(fontWeight: FontWeight.bold, color: _c.text, fontSize: 16)),
          ),
          for (final p in trips) _tripTile(p),
        ],
      );

  Widget _tripTile(Purchase p) => Dismissible(
        key: ValueKey(p.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(color: Colors.red.shade600, borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.delete_rounded, color: Colors.white),
        ),
        confirmDismiss: (_) => showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
          margin: const EdgeInsets.only(bottom: 10),
          decoration: _c.cardDecoration(radius: 16),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _openTrip(p),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: _green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(_monthNames[p.date.month - 1].substring(0, 3).toUpperCase(),
                              style: const TextStyle(color: _green, fontSize: 10, fontWeight: FontWeight.bold)),
                          Text('${p.date.day}',
                              style: const TextStyle(color: _green, fontSize: 18, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.store,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: _c.text, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          p.addsUp
                              ? Text(
                                  '${p.items.length} items${p.savings > 0 ? ' · saved ${_money(p.savings)}' : ''}',
                                  style: TextStyle(color: _c.subtext, fontSize: 12),
                                )
                              : Text(
                                  "Doesn't add up (${_money(p.unaccounted)} unmatched)",
                                  style: TextStyle(color: Colors.orange.shade600, fontSize: 12),
                                ),
                        ],
                      ),
                    ),
                    Text(_money(p.total), style: TextStyle(color: _c.text, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

String _qty(double q) => q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(2);

// =============================================================================
// Trip detail
// =============================================================================

/// Line items for one trip. Tap an item to fix its category.
class PurchaseDetailScreen extends StatefulWidget {
  final Purchase purchase;
  const PurchaseDetailScreen({super.key, required this.purchase});
  @override
  State<PurchaseDetailScreen> createState() => _PurchaseDetailScreenState();
}

class _PurchaseDetailScreenState extends State<PurchaseDetailScreen> {
  late Purchase _purchase = widget.purchase;
  late final _c = _Palette(ThemeService().isDarkMode);

  Future<void> _changeCategory(int index) async {
    final item = _purchase.items[index];
    final picked = await showModalBottomSheet<SpendCategory>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            for (final c in SpendCategory.itemCategories)
              ListTile(
                leading: iconChip(c.icon, c.color, size: 18, pad: 6),
                title: Text(c.label),
                trailing: c == item.category ? const Icon(Icons.check_rounded, color: _green) : null,
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
    final p = _purchase;
    return Scaffold(
      backgroundColor: _c.bg,
      appBar: AppBar(
        backgroundColor: _c.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(_shortDate(p.date), style: TextStyle(color: _c.text, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: _c.text),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Entrance(
            index: 0,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: _c.cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.store, style: TextStyle(color: _c.subtext)),
                  const SizedBox(height: 6),
                  CountUp(p.total, style: TextStyle(color: _c.text, fontSize: 32, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 20,
                    runSpacing: 8,
                    children: [
                      _miniStat('Tax', _money(p.tax)),
                      if (p.fees > 0) _miniStat('Fees', _money(p.fees)),
                      if (p.couponSavings > 0) _miniStat('Order coupons', '-${_money(p.couponSavings)}', color: _green),
                      if (p.savings > 0) _miniStat('Saved', _money(p.savings), color: _green),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (!p.addsUp) ...[
            const SizedBox(height: 12),
            Entrance(
              index: 1,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange.shade600),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Items (${_money(p.itemsTotal)}) + tax & fees (${_money(p.tax + p.fees)}) - order coupons '
                        '(${_money(p.couponSavings)}) don\'t match the receipt total (${_money(p.total)}). '
                        'The ${_money(p.unaccounted)} difference is counted as Other. Re-importing the PDF may fix it.',
                        style: TextStyle(color: _c.text, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text('${p.items.length} items · tap to change category',
                style: TextStyle(color: _c.subtext, fontSize: 12)),
          ),
          Container(
            decoration: _c.cardDecoration(),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < p.items.length; i++)
                  Entrance(
                    index: (i + 1).clamp(0, 10),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _changeCategory(i),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
                                child: KeyedSubtree(
                                  key: ValueKey(p.items[i].category),
                                  child: iconChip(p.items[i].category.icon, p.items[i].category.color,
                                      size: 16, pad: 7),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p.items[i].name, style: TextStyle(color: _c.text, fontSize: 14)),
                                    const SizedBox(height: 2),
                                    Text(
                                      [
                                        p.items[i].category.label,
                                        if (p.items[i].quantity != 1) '× ${_qty(p.items[i].quantity)}',
                                        if (p.items[i].savings > 0)
                                          'reg ${_money(p.items[i].listPrice)}, saved ${_money(p.items[i].savings)}',
                                      ].join(' · '),
                                      style: TextStyle(color: _c.subtext, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(_money(p.items[i].price),
                                  style: TextStyle(color: _c.text, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, {Color? color}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: _c.subtext, fontSize: 11)),
          Text(value, style: TextStyle(color: color ?? _c.text, fontWeight: FontWeight.w600)),
        ],
      );
}
