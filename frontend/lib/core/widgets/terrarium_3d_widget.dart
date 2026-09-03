import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Terrarium3DWidget renders the living botanical terrarium hero orb
/// nestled inside an illuminated Champagne Gold radial progress arch.
class Terrarium3DWidget extends StatefulWidget {
  final int score;
  final double size;

  const Terrarium3DWidget({
    super.key,
    this.score = 82,
    this.size = 140.0,
  });

  @override
  State<Terrarium3DWidget> createState() => _Terrarium3DWidgetState();
}

class _Terrarium3DWidgetState extends State<Terrarium3DWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _dragX = 0.0;
  double _dragY = 0.0;

  @override
  void initState() {
    super.initState();
    // Continuous subtle organic breathing animation
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) {
        setState(() {
          _dragX += details.delta.dx * 0.01;
          _dragY += details.delta.dy * 0.01;
          _dragX = _dragX.clamp(-0.4, 0.4);
          _dragY = _dragY.clamp(-0.4, 0.4);
        });
      },
      onPanEnd: (_) {
        setState(() {
          _dragX = 0.0;
          _dragY = 0.0;
        });
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final breath = math.sin(_controller.value * 2 * math.pi) * 0.03;
          final tiltX = _dragX + (breath * 0.5);
          final tiltY = _dragY;

          return SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // ── 1. Golden Radial Score Arch ─────────────────────────────
                CustomPaint(
                  size: Size(widget.size, widget.size),
                  painter: _GoldenScoreArchPainter(
                    score: widget.score,
                    pulse: _controller.value,
                  ),
                ),

                // ── 2. Pseudo-3D Glass Sphere with Gyroscopic Transform ──────
                Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.002) // 3D perspective depth
                    ..rotateY(tiltX)
                    ..rotateX(-tiltY),
                  child: Container(
                    width: widget.size * 0.72,
                    height: widget.size * 0.72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        center: Alignment(-0.25, -0.25),
                        radius: 0.9,
                        colors: [
                          Color(0x66FFFFFF),
                          Color(0x1A0D3B2E),
                          Color(0xCC041C13),
                        ],
                        stops: [0.0, 0.5, 1.0],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.champagneGold.withOpacity(0.2),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                        const BoxShadow(
                          color: Color(0x80000000),
                          blurRadius: 12,
                          offset: Offset(0, 6),
                        ),
                      ],
                      border: Border.all(
                        color: AppColors.champagneGold.withOpacity(0.5),
                        width: 1.5,
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Subtle Terrarium Moss & Micro-flora inside
                        Icon(
                          Icons.eco_rounded,
                          size: widget.size * 0.36,
                          color: AppColors.emerald.withOpacity(0.9),
                        ),
                        Positioned(
                          top: widget.size * 0.16,
                          left: widget.size * 0.22,
                          child: Container(
                            width: 12,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _GoldenScoreArchPainter extends CustomPainter {
  final int score;
  final double pulse;

  _GoldenScoreArchPainter({required this.score, required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 6;

    // Background track arc
    final trackPaint = Paint()
      ..color = AppColors.champagneGold.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 0.75,
      math.pi * 1.5,
      false,
      trackPaint,
    );

    // Active progress arc
    final progressAngle = (score / 100.0) * (math.pi * 1.5);
    final progressPaint = Paint()
      ..shader = const SweepGradient(
        colors: [
          AppColors.polishedBrass,
          AppColors.champagneGold,
          AppColors.goldLight,
        ],
        stops: [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7.0
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 0.75,
      progressAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GoldenScoreArchPainter oldDelegate) => true;
}
