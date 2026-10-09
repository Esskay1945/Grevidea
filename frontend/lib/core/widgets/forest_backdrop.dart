import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Full-screen reference artwork shared across the entire app. The legacy
/// class name remains so existing routes and integrations keep their geometry.
class ForestBackdrop extends StatefulWidget {
  final Widget child;
  const ForestBackdrop({super.key, required this.child});

  static void releaseLeaves(BuildContext context, Offset globalPosition) {
    context.findAncestorStateOfType<_ForestBackdropState>()?._releaseLeaves(
      globalPosition,
    );
  }

  @override
  State<ForestBackdrop> createState() => _ForestBackdropState();
}

class _ForestBackdropState extends State<ForestBackdrop>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  );
  late final AnimationController _leaves = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  );
  Offset _origin = Offset.zero;
  bool _active = true;
  bool _reduced = false;
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    _enabled = TickerMode.of(context);
    _syncMotion();
  }

  void _syncMotion() {
    if (_active && !_reduced && _enabled) {
      if (!_motion.isAnimating) _motion.repeat();
    } else {
      _motion.stop();
      _leaves.stop();
    }
  }

  void _releaseLeaves(Offset globalPosition) {
    if (!_active || _reduced || !_enabled) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    setState(() => _origin = box.globalToLocal(globalPosition));
    _leaves.forward(from: 0);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    _syncMotion();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _motion.dispose();
    _leaves.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: RepaintBoundary(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: dark
                          ? AppColors.midnightObsidian
                          : const Color(0xFFF6E9D8),
                    ),
                    AnimatedSwitcher(
                      duration: _reduced
                          ? Duration.zero
                          : const Duration(milliseconds: 500),
                      child: SizedBox.expand(
                        key: ValueKey(dark),
                        child: Image.asset(
                          dark
                              ? 'assets/autumn/autumn_night.webp'
                              : 'assets/autumn/autumn_day.webp',
                          fit: BoxFit.cover,
                          alignment: Alignment.centerRight,
                          excludeFromSemantics: true,
                          errorBuilder: (_, __, ___) => ColoredBox(
                            color: dark
                                ? AppColors.midnightObsidian
                                : const Color(0xFFF6E9D8),
                          ),
                        ),
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: dark
                              ? const [
                                  Color(0x3821150F),
                                  Color(0x1021150F),
                                  Color(0x2521150F),
                                ]
                              : const [
                                  Color(0x66FFF4E5),
                                  Color(0x08FFF4E5),
                                  Color(0x33FFF4E5),
                                ],
                          stops: const [0, 0.55, 1],
                        ),
                      ),
                    ),
                    CustomPaint(
                      painter: _AutumnAtmosphere(
                        motion: _motion,
                        leaves: _leaves,
                        origin: _origin,
                        dark: dark,
                        still: _reduced,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

/// Painter-only frames with a fixed twelve-leaf burst. This draws foliage,
/// never the tree itself; the tree is the full-resolution reference artwork.
class _AutumnAtmosphere extends CustomPainter {
  final Animation<double> motion;
  final Animation<double> leaves;
  final Offset origin;
  final bool dark;
  final bool still;
  _AutumnAtmosphere({
    required this.motion,
    required this.leaves,
    required this.origin,
    required this.dark,
    required this.still,
  }) : super(repaint: Listenable.merge([motion, leaves]));

  @override
  void paint(Canvas canvas, Size size) {
    if (still) return;
    final phase = motion.value * math.pi * 2;
    for (var i = 0; i < 6; i++) {
      final x = size.width * (0.96 + math.sin(phase + i) * 0.02);
      final y = size.height * ((motion.value + i / 6) % 1);
      _leaf(
        canvas,
        Offset(x, y),
        phase + i,
        const Color(0xFFB96932).withValues(alpha: dark ? 0.30 : 0.22),
      );
    }
    if (leaves.value <= 0 || leaves.value >= 1) return;
    final t = leaves.value;
    for (var i = 0; i < 12; i++) {
      final x = origin.dx + (i - 6) * 5 + math.sin(t * 8 + i) * 22;
      final y = origin.dy - (i % 3) * 12 + t * size.height * 0.55;
      final color = [
        const Color(0xFFC56432),
        const Color(0xFFE2A34F),
        const Color(0xFFB54C2C),
      ][i % 3].withValues(alpha: (1 - t) * 0.8);
      _leaf(canvas, Offset(x, y), t * 6 + i, color);
    }
  }

  void _leaf(Canvas canvas, Offset center, double angle, Color color) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    final path = Path()
      ..moveTo(0, -9)
      ..lineTo(3, -4)
      ..lineTo(7, -6)
      ..lineTo(6, -1)
      ..lineTo(10, 0)
      ..lineTo(5, 4)
      ..lineTo(1, 5)
      ..lineTo(0, 10)
      ..lineTo(-1, 5)
      ..lineTo(-5, 4)
      ..lineTo(-10, 0)
      ..lineTo(-6, -1)
      ..lineTo(-7, -6)
      ..lineTo(-3, -4)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawLine(
      const Offset(0, -7),
      const Offset(0, 7),
      Paint()
        ..color = const Color(0xFF6A391F).withValues(alpha: color.a)
        ..strokeWidth = 0.7,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AutumnAtmosphere old) =>
      old.dark != dark ||
      old.still != still ||
      old.origin != origin ||
      old.motion != motion ||
      old.leaves != leaves;
}
