import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class GoogleSignInButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const GoogleSignInButton({
    super.key,
    this.text = 'Continue with Google',
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Branded Google 'G' Icon
            _GoogleGIcon(),
            const SizedBox(width: 12),
            Text(
              text,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkTextPrimary : AppColors.royalForest,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleGIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Draw Google's 4-color 'G' icon
    final redPaint = Paint()..color = const Color(0xFFEA4335)..style = PaintingStyle.fill;
    final yellowPaint = Paint()..color = const Color(0xFFFBBC05)..style = PaintingStyle.fill;
    final greenPaint = Paint()..color = const Color(0xFF34A853)..style = PaintingStyle.fill;
    final bluePaint = Paint()..color = const Color(0xFF4285F4)..style = PaintingStyle.fill;

    final center = Offset(w / 2, h / 2);
    final radius = w / 2;

    // Blue Bar
    final barRect = Rect.fromLTRB(w * 0.45, h * 0.38, w, h * 0.62);
    canvas.drawRect(barRect, bluePaint);

    // Blue Arc (Top right to bottom right)
    final blueArc = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(Rect.fromCircle(center: center, radius: radius), -0.78, 1.2, false)
      ..close();
    canvas.drawPath(blueArc, bluePaint);

    // Green Arc (Bottom)
    final greenArc = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(Rect.fromCircle(center: center, radius: radius), 0.42, 1.6, false)
      ..close();
    canvas.drawPath(greenArc, greenPaint);

    // Yellow Arc (Bottom-left to Top-left)
    final yellowArc = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(Rect.fromCircle(center: center, radius: radius), 2.02, 1.6, false)
      ..close();
    canvas.drawPath(yellowArc, yellowPaint);

    // Red Arc (Top)
    final redArc = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(Rect.fromCircle(center: center, radius: radius), 3.62, 1.5, false)
      ..close();
    canvas.drawPath(redArc, redPaint);

    // Cut out the inner circle hole
    final innerClearPaint = Paint()
      ..color = Colors.transparent
      ..blendMode = BlendMode.clear;
    canvas.drawCircle(center, radius * 0.6, innerClearPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
