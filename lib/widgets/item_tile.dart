import 'package:flutter/material.dart';

import 'animations.dart';
import '../models/grocery_type.dart';

class ItemTile extends StatelessWidget {
  const ItemTile({
    super.key,
    required this.name,
    required this.expiry,
    required this.quantity,
    required this.groceryType,
    required this.onEdit,
    required this.onUsedHalf,
    required this.onFinish,
    required this.onRemove,
    this.onSelectMultiple,
    this.onPrioritize,
    this.onUnprioritize,
    this.onFreeze,
    this.onUnfreeze,
    this.isDarkMode = false,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.isPrioritized = false,
    this.isFrozen = false,
    this.isCompactView = false,
    this.onSelectionChanged,
    this.usagePercentage = 100.0,
  });

  final String name;
  final DateTime? expiry;
  final num quantity;
  final GroceryType groceryType;
  final double usagePercentage;
  final VoidCallback onEdit;
  final Future<void> Function() onUsedHalf;
  final Future<void> Function() onFinish;
  final Future<void> Function() onRemove;
  final VoidCallback? onSelectMultiple;
  final VoidCallback? onPrioritize;
  final VoidCallback? onUnprioritize;
  final VoidCallback? onFreeze;
  final VoidCallback? onUnfreeze;
  final bool isDarkMode;
  final bool isSelectionMode;
  final bool isSelected;
  final bool isPrioritized;
  final bool isFrozen;
  final bool isCompactView;
  final ValueChanged<bool>? onSelectionChanged;

  IconData _getGroceryIcon(GroceryType type) {
    switch (type) {
      case GroceryType.meat:
        return Icons.restaurant_rounded;
      case GroceryType.poultry:
        return Icons.egg_rounded;
      case GroceryType.seafood:
        return Icons.set_meal_rounded;
      case GroceryType.vegetable:
        return Icons.eco_rounded;
      case GroceryType.fruit:
        return Icons.apple_rounded;
      case GroceryType.dairy:
        return Icons.local_drink_rounded;
      case GroceryType.grain:
        return Icons.grain_rounded;
      case GroceryType.beverage:
        return Icons.local_cafe_rounded;
      case GroceryType.snack:
        return Icons.cookie_rounded;
      case GroceryType.condiment:
        return Icons.local_fire_department_rounded;
      case GroceryType.frozen:
        return Icons.ac_unit_rounded;
      case GroceryType.other:
        return Icons.inventory_rounded;
    }
  }

  Color _getGroceryColor(GroceryType type) {
    switch (type) {
      case GroceryType.meat:
        return const Color(0xFFE74C3C);
      case GroceryType.poultry:
        return const Color(0xFFF39C12);
      case GroceryType.seafood:
        return const Color(0xFF3498DB);
      case GroceryType.vegetable:
        return const Color(0xFF27AE60);
      case GroceryType.fruit:
        return const Color(0xFFE91E63);
      case GroceryType.dairy:
        return const Color(0xFF9B59B6);
      case GroceryType.grain:
        return const Color(0xFF8E44AD);
      case GroceryType.beverage:
        return const Color(0xFF1ABC9C);
      case GroceryType.snack:
        return const Color(0xFFF1C40F);
      case GroceryType.condiment:
        return const Color(0xFFFF5722);
      case GroceryType.frozen:
        return const Color(0xFF00BCD4);
      case GroceryType.other:
        return const Color(0xFF95A5A6);
    }
  }

  Color _getUsageColor(double percentage) {
    // Smooth gradient: Green (100%) -> Yellow (50%) -> Red (0%)
    if (percentage > 50) {
      // Interpolate between yellow and green
      final t = ((percentage - 50) / 50).clamp(0.0, 1.0);
      return Color.lerp(
        const Color(0xFFF39C12), // Yellow
        const Color(0xFF27AE60), // Green
        t,
      )!;
    } else {
      // Interpolate between red and yellow
      final t = (percentage / 50).clamp(0.0, 1.0);
      return Color.lerp(
        const Color(0xFFE74C3C), // Red
        const Color(0xFFF39C12), // Yellow
        t,
      )!;
    }
  }

  /// Days until expiry (negative once expired), or null when there's no date.
  int? get _daysLeft {
    if (expiry == null) return null;
    final now = DateTime.now();
    return DateTime(expiry!.year, expiry!.month, expiry!.day).difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  static String expiryLabel(int? daysLeft) => daysLeft == null
      ? 'no date'
      : daysLeft < -1
          ? 'expired ${-daysLeft}d ago'
          : daysLeft == -1
              ? 'expired yesterday'
              : daysLeft == 0
                  ? 'today'
                  : daysLeft == 1
                      ? 'tomorrow'
                      : daysLeft <= 13
                          ? 'in $daysLeft days'
                          : 'in ${(daysLeft / 7).round()} wks';

  static Color expiryColor(int? daysLeft) => daysLeft == null
      ? const Color(0xFF95A5A6)
      : daysLeft <= 1
          ? const Color(0xFFE74C3C)
          : daysLeft <= 3
              ? const Color(0xFFF39C12)
              : const Color(0xFF27AE60);

  @override
  Widget build(BuildContext context) {
    final days = _daysLeft;
    final chipColor = expiryColor(days);
    final groceryColor = _getGroceryColor(groceryType);
    final usageColor = _getUsageColor(usagePercentage);
    final text = isDarkMode ? const Color(0xFFE8E8E8) : const Color(0xFF2C3E50);
    final subtext = isDarkMode ? const Color(0xFF9E9E9E) : const Color(0xFF7F8C8D);
    final compact = isCompactView;
    final iconSize = compact ? 34.0 : 42.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isSelectionMode ? () => onSelectionChanged?.call(!isSelected) : () => _showActions(context),
        onLongPress: onSelectMultiple,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: compact ? 8 : 12),
          child: Row(
            children: [
              // Type icon inside a ring showing how much is left
              SizedBox(
                width: iconSize + 8,
                height: iconSize + 8,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (usagePercentage < 100)
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: (usagePercentage / 100).clamp(0.0, 1.0)),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, __) => SizedBox.expand(
                          child: CircularProgressIndicator(
                            value: v,
                            strokeWidth: 2.5,
                            strokeCap: StrokeCap.round,
                            backgroundColor: usageColor.withValues(alpha: 0.15),
                            valueColor: AlwaysStoppedAnimation(usageColor),
                          ),
                        ),
                      ),
                    Container(
                      width: iconSize,
                      height: iconSize,
                      decoration: BoxDecoration(color: groceryColor.withValues(alpha: 0.14), shape: BoxShape.circle),
                      child: Icon(_getGroceryIcon(groceryType), color: groceryColor, size: compact ? 16 : 20),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: compact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: compact ? 14 : 15, fontWeight: FontWeight.w600, color: text, height: 1.25),
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          if (isPrioritized) ...[
                            const Icon(Icons.flag_rounded, size: 13, color: Color(0xFFE74C3C)),
                            const SizedBox(width: 3),
                          ],
                          if (isFrozen) ...[
                            const Icon(Icons.ac_unit_rounded, size: 13, color: Color(0xFF00BCD4)),
                            const SizedBox(width: 3),
                          ],
                          Flexible(
                            child: Text(
                              [
                                groceryType.displayName,
                                if (quantity > 1) '×$quantity',
                                if (usagePercentage < 100) '${usagePercentage.round()}% left',
                              ].join(' · '),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: subtext),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (isSelectionMode)
                Checkbox(
                  value: isSelected,
                  onChanged: (value) => onSelectionChanged?.call(value ?? false),
                  activeColor: const Color(0xFF27AE60),
                  visualDensity: VisualDensity.compact,
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: chipColor.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    expiryLabel(days),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: chipColor),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Everything you can do with an item, in one sheet instead of a crowded popup.
  Future<void> _showActions(BuildContext context) async {
    final days = _daysLeft;
    final groceryColor = _getGroceryColor(groceryType);
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    Widget action(IconData icon, Color color, String label, VoidCallback? run) => ListTile(
          leading: iconChip(icon, color, size: 18, pad: 7),
          title: Text(label),
          onTap: run == null
              ? null
              : () {
                  Navigator.pop(context);
                  run();
                },
        );

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(
                  children: [
                    iconChip(_getGroceryIcon(groceryType), groceryColor, size: 22, pad: 10),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(
                            [
                              groceryType.displayName,
                              if (expiry != null) 'expires ${months[expiry!.month - 1]} ${expiry!.day} (${expiryLabel(days)})',
                              '${usagePercentage.round()}% left',
                            ].join(' · '),
                            style: TextStyle(fontSize: 12, color: Theme.of(ctx).hintColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          onUsedHalf();
                        },
                        icon: const Icon(Icons.contrast_rounded),
                        label: const Text('Used ½'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF27AE60)),
                        onPressed: () {
                          Navigator.pop(ctx);
                          onFinish();
                        },
                        icon: const Icon(Icons.check_circle_rounded),
                        label: const Text('Finished'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              action(Icons.edit_rounded, const Color(0xFF4A90E2), 'Edit', onEdit),
              if (onPrioritize != null && !isPrioritized)
                action(Icons.flag_rounded, const Color(0xFFE74C3C), 'Prioritize', onPrioritize),
              if (onUnprioritize != null && isPrioritized)
                action(Icons.outlined_flag_rounded, const Color(0xFF95A5A6), 'Remove priority', onUnprioritize),
              if (onFreeze != null && !isFrozen)
                action(Icons.ac_unit_rounded, const Color(0xFF00BCD4), 'Freeze', onFreeze),
              if (onUnfreeze != null && isFrozen)
                action(Icons.whatshot_rounded, const Color(0xFFF39C12), 'Unfreeze', onUnfreeze),
              if (onSelectMultiple != null)
                action(Icons.checklist_rounded, const Color(0xFF27AE60), 'Select multiple', onSelectMultiple),
              action(Icons.delete_rounded, const Color(0xFFE74C3C), 'Remove', onRemove),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
