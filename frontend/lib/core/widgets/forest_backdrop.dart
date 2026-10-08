import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Decorative only: never changes the navigator's constraints or hit testing.
class ForestBackdrop extends StatefulWidget {
  final Widget child;
  const ForestBackdrop({super.key, required this.child});

  @override
  State<ForestBackdrop> createState() => _ForestBackdropState();
}

class _ForestBackdropState extends State<ForestBackdrop>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _motion;
  bool _active = true;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    );
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  void _syncMotion() {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_active && !reduceMotion && TickerMode.valuesOf(context).enabled) {
      if (!_motion.isAnimating) _motion.repeat();
    } else {
      _motion.stop();
    }
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
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
                    const ColoredBox(color: Color(0xFF071B18)),
                    AnimatedSwitcher(
                      duration: reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 700),
                      child: SizedBox.expand(
                        key: ValueKey(dark),
                        child: Image.asset(
                          dark
                              ? 'assets/forest/forest_night.webp'
                              : 'assets/forest/forest_day.webp',
                          fit: BoxFit.cover,
                          alignment: const Alignment(0.25, 0),
                          excludeFromSemantics: true,
                          errorBuilder: (_, __, ___) =>
                              const ColoredBox(color: Color(0xFF071B18)),
                        ),
                      ),
                    ),
                    // Contrast scrim keeps text legible over both skies.
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: dark
                              ? const [
                                  Color(0xE6031118),
                                  Color(0xB8031118),
                                  Color(0xE6031118),
                                ]
                              : const [
                                  Color(0xD9072117),
                                  Color(0xA6072117),
                                  Color(0xD9072117),
                                ],
                          stops: const [0, 0.42, 1],
                        ),
                      ),
                    ),
                    RepaintBoundary(
                      child: CustomPaint(
                        painter: _ForestAtmosphere(
                          clock: _motion,
                          dark: dark,
                          still: reduceMotion,
                        ),
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

/// Bounded particle count, painter-only ticks; no app/widget rebuild per frame.
class _ForestAtmosphere extends CustomPainter {
  final Animation<double> clock;
  final bool dark;
  final bool still;

  _ForestAtmosphere({
    required this.clock,
    required this.dark,
    required this.still,
  }) : super(repaint: clock);

  @override
  void paint(Canvas canvas, Size size) {
    final phase = (still ? 0.0 : clock.value) * math.pi * 2;
    final count = dark ? 24 : 8;
    for (var i = 0; i < count; i++) {
      // Cluster at the perimeter, away from the main reading area.
      final side = i.isEven ? 0.055 : 0.94;
      final x = size.width * (side + math.sin(phase + i * 1.7) * 0.035);
      final y = size.height *
          (((i * 0.137) % 0.9) + 0.05 + math.cos(phase + i * 0.9) * 0.014);
      final center = Offset(x, y);
      final pulse = still ? 0.65 : 0.45 + 0.25 * math.sin(phase * 2 + i);
      final color = dark ? const Color(0xFFFFE994) : const Color(0xFFE0F5A8);
      final radius = dark ? 11.0 : 5.0;
      final glow = Paint()
        ..shader = ui.Gradient.radial(center, radius, [
          color.withValues(alpha: pulse * (dark ? 0.45 : 0.15)),
          color.withValues(alpha: 0),
        ]);
      canvas.drawCircle(center, radius, glow);
      canvas.drawCircle(
        center,
        dark ? 1.5 : 0.8,
        Paint()..color = color.withValues(alpha: pulse),
      );
    }
    final center = Offset(
      size.width * (0.7 + math.sin(phase) * 0.12),
      size.height * 0.79,
    );
    final radius = size.width * 0.7;
    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: radius * 2,
        height: size.height * 0.2,
      ),
      Paint()
        ..shader = ui.Gradient.radial(center, radius, [
          const Color(0xFFB7DCD0).withValues(alpha: dark ? 0.025 : 0.045),
          Colors.transparent,
        ]),
    );
  }

  @override
  bool shouldRepaint(covariant _ForestAtmosphere oldDelegate) =>
      oldDelegate.dark != dark ||
      oldDelegate.still != still ||
      oldDelegate.clock != clock;
}
