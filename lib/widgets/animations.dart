import 'package:flutter/material.dart';

/// Shared motion pieces used by the Pantry and spending screens.

String formatMoney(double v) => '${v < 0 ? '-' : ''}\$${v.abs().toStringAsFixed(2)}';

/// Number that counts up to its value, and animates between values when it changes.
class CountUp extends StatelessWidget {
  final double value;
  final TextStyle style;
  final String Function(double) format;
  const CountUp(this.value, {super.key, required this.style, this.format = formatMoney});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => Text(format(v), style: style),
      );
}

/// Rounded bar that grows to [fraction] of the available width.
class GrowBar extends StatelessWidget {
  final double fraction;
  final Color color;
  final Color track;
  final double height;
  const GrowBar({super.key, required this.fraction, required this.color, required this.track, this.height = 8});

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        decoration: BoxDecoration(color: track, borderRadius: BorderRadius.circular(height)),
        alignment: Alignment.centerLeft,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: fraction.clamp(0, 1).toDouble()),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutCubic,
          builder: (_, f, __) => FractionallySizedBox(
            widthFactor: f,
            child: Container(
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(height)),
            ),
          ),
        ),
      );
}

/// Fades and slides its child up into place, [index] steps after its siblings.
class Entrance extends StatelessWidget {
  final int index;
  final Widget child;
  const Entrance({super.key, required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    const step = 70, length = 420;
    final total = length + index * step;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(index * step / total, 1, curve: Curves.easeOutCubic),
      child: child,
      builder: (_, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 24 * (1 - t)), child: child),
      ),
    );
  }
}

/// Repeats a gentle animation on its child: [pulse] scales it, otherwise it floats up and down.
class Breathing extends StatefulWidget {
  final Widget child;
  final bool pulse;
  final Duration period;
  const Breathing({
    super.key,
    required this.child,
    this.pulse = true,
    this.period = const Duration(milliseconds: 900),
  });

  @override
  State<Breathing> createState() => _BreathingState();
}

class _BreathingState extends State<Breathing> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: widget.period)..repeat(reverse: true);
  late final _curve = CurvedAnimation(parent: _c, curve: Curves.easeInOut);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.pulse
      ? ScaleTransition(scale: Tween(begin: 0.88, end: 1.08).animate(_curve), child: widget.child)
      : AnimatedBuilder(
          animation: _curve,
          child: widget.child,
          builder: (_, child) => Transform.translate(offset: Offset(0, -8 * _curve.value), child: child),
        );
}

/// Small rounded square holding a tinted icon.
Widget iconChip(IconData icon, Color color, {double size = 18, double pad = 8}) => Container(
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: color, size: size),
    );
