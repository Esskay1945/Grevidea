import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A bounded, painter-driven tree. Only this exposed scene receives taps;
/// score cards and task controls remain outside its hit-test area.
class AutumnTree extends StatefulWidget {
  const AutumnTree({super.key});
  @override
  State<AutumnTree> createState() => _AutumnTreeState();
}

class _AutumnTreeState extends State<AutumnTree>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _sway = AnimationController(
      vsync: this, duration: const Duration(seconds: 8));
  late final AnimationController _fall = AnimationController(
      vsync: this, duration: const Duration(seconds: 3));
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
    _sync();
  }

  void _sync() {
    if (_active && _enabled && !_reduced) {
      if (!_sway.isAnimating) _sway.repeat(reverse: true);
    } else {
      _sway.stop();
      _fall.stop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    _sync();
  }

  void _releaseLeaves() {
    if (!_reduced && _active && _enabled) _fall.forward(from: 0);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sway.dispose();
    _fall.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Autumn tree. Tap to release falling leaves.',
        button: true,
        onTap: _releaseLeaves,
        child: GestureDetector(
          excludeFromSemantics: true,
          behavior: HitTestBehavior.opaque,
          onTap: _releaseLeaves,
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _TreePainter(
                sway: _sway,
                fall: _fall,
                dark: Theme.of(context).brightness == Brightness.dark,
                reduced: _reduced,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
}

class _TreePainter extends CustomPainter {
  final Animation<double> sway;
  final Animation<double> fall;
  final bool dark;
  final bool reduced;
  _TreePainter({required this.sway, required this.fall, required this.dark,
    required this.reduced}) : super(repaint: Listenable.merge([sway, fall]));

  static const _colors = [Color(0xFFC56332), Color(0xFFE4A34F),
    Color(0xFFA6472C), Color(0xFFD88A36)];

  @override
  void paint(Canvas canvas, Size size) {
    final root = Offset(size.width * 0.72, size.height);
    final drift = reduced ? 0.0 : (sway.value - 0.5) * 5;
    final wood = Paint()
      ..color = dark ? const Color(0xFF99704C) : const Color(0xFF785137)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final trunk = Path()..moveTo(root.dx, root.dy)
      ..cubicTo(root.dx - 10, size.height * 0.7, root.dx + 6,
          size.height * 0.4, root.dx - 28 + drift, 12);
    canvas.drawPath(trunk, wood..strokeWidth = 12);
    for (var i = 0; i < 7; i++) {
      final y = 30.0 + i * 17;
      final end = Offset(root.dx + (i.isEven ? -1 : 1) * (65 + i * 8) + drift, y - 24);
      canvas.drawLine(Offset(root.dx - 12, y + 20), end, wood..strokeWidth = 3);
    }
    for (var i = 0; i < 85; i++) {
      final angle = i * 2.39996;
      final radius = math.sqrt(i / 85);
      final center = Offset(root.dx - 15 + math.cos(angle) * radius * size.width * 0.32 + drift,
          66 + math.sin(angle) * radius * 57);
      _leaf(canvas, center, angle, _colors[i % 4], 7);
    }
    if (!reduced && fall.value > 0 && fall.value < 1) {
      for (var i = 0; i < 12; i++) {
        final t = fall.value;
        final x = root.dx - 90 + i * 14 + math.sin(t * 7 + i) * 20;
        final y = 30 + (i % 4) * 17 + t * size.height;
        _leaf(canvas, Offset(x, y), t * 5 + i,
            _colors[i % 4].withValues(alpha: 1 - t), 8);
      }
    }
  }

  void _leaf(Canvas canvas, Offset center, double angle, Color color, double r) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    final leaf = Path()..moveTo(-r, 0)
      ..quadraticBezierTo(0, -r, r, 0)
      ..quadraticBezierTo(0, r, -r, 0);
    canvas.drawPath(leaf, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TreePainter old) =>
      old.dark != dark || old.reduced != reduced || old.sway != sway || old.fall != fall;
}
