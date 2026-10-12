import 'package:flutter/material.dart';

/// Pixel-perfect Google 'G' official logo using vector paths and official brand colors.
class GoogleLogoPainter extends CustomPainter {
  const GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()..style = PaintingStyle.fill;

    // Blue: horizontal bar and lower right
    paint.color = const Color(0xFF4285F4);
    final bluePath = Path()
      ..moveTo(w * 0.98, h * 0.51)
      ..cubicTo(w * 0.98, h * 0.47, w * 0.97, h * 0.44, w * 0.96, h * 0.41)
      ..lineTo(w * 0.5, h * 0.41)
      ..lineTo(w * 0.5, h * 0.60)
      ..lineTo(w * 0.77, h * 0.60)
      ..cubicTo(w * 0.76, h * 0.68, w * 0.71, h * 0.75, w * 0.64, h * 0.80)
      ..lineTo(w * 0.64, h * 0.95)
      ..lineTo(w * 0.84, h * 0.95)
      ..cubicTo(w * 0.94, h * 0.85, w * 0.98, h * 0.69, w * 0.98, h * 0.51);
    canvas.drawPath(bluePath, paint);

    // Green: bottom
    paint.color = const Color(0xFF34A853);
    final greenPath = Path()
      ..moveTo(w * 0.5, h * 1.0)
      ..cubicTo(w * 0.63, h * 1.0, w * 0.75, h * 0.95, w * 0.84, h * 0.86)
      ..lineTo(w * 0.64, h * 0.71)
      ..cubicTo(w * 0.60, h * 0.74, w * 0.55, h * 0.76, w * 0.5, h * 0.76)
      ..cubicTo(w * 0.38, h * 0.76, w * 0.28, h * 0.68, w * 0.24, h * 0.58)
      ..lineTo(w * 0.04, h * 0.58)
      ..lineTo(w * 0.04, h * 0.73)
      ..cubicTo(w * 0.14, h * 0.90, w * 0.30, h * 1.0, w * 0.5, h * 1.0);
    canvas.drawPath(greenPath, paint);

    // Yellow: bottom left
    paint.color = const Color(0xFFFBBC05);
    final yellowPath = Path()
      ..moveTo(w * 0.24, h * 0.58)
      ..cubicTo(w * 0.23, h * 0.55, w * 0.22, h * 0.52, w * 0.22, h * 0.5)
      ..cubicTo(w * 0.22, h * 0.47, w * 0.23, h * 0.44, w * 0.24, h * 0.41)
      ..lineTo(w * 0.04, h * 0.41)
      ..cubicTo(w * 0.02, h * 0.47, w * 0.0, h * 0.53, w * 0.0, h * 0.6)
      ..lineTo(w * 0.24, h * 0.58);
    canvas.drawPath(yellowPath, paint);

    // Red: top
    paint.color = const Color(0xFFEA4335);
    final redPath = Path()
      ..moveTo(w * 0.5, h * 0.20)
      ..cubicTo(w * 0.58, h * 0.20, w * 0.65, h * 0.23, w * 0.70, h * 0.28)
      ..lineTo(w * 0.85, h * 0.13)
      ..cubicTo(w * 0.75, h * 0.05, w * 0.63, 0.0, w * 0.5, 0.0)
      ..cubicTo(w * 0.30, 0.0, w * 0.14, h * 0.11, w * 0.04, h * 0.27)
      ..lineTo(w * 0.24, h * 0.42)
      ..cubicTo(w * 0.28, h * 0.32, w * 0.38, h * 0.20, w * 0.5, h * 0.20);
    canvas.drawPath(redPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Standalone Google G logo icon.
class GoogleLogoIcon extends StatelessWidget {
  final double size;
  const GoogleLogoIcon({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const CustomPaint(
        painter: GoogleLogoPainter(),
      ),
    );
  }
}

/// Standard, accessible Google Sign-In Button compliant with Google brand specifications.
class GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final String label;

  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.label = 'Continue with Google',
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1F2937),
          side: const BorderSide(color: Color(0xFFE5E7EB), width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Color(0xFF4285F4), strokeWidth: 2),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const GoogleLogoIcon(size: 20),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2937),
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Helper divider with "OR" text between primary login and alternative social methods.
class OrDivider extends StatelessWidget {
  final String label;

  const OrDivider({super.key, this.label = 'OR'});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0xFFE5E7EB), thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF9CA3AF),
              letterSpacing: 0.8,
            ),
          ),
        ),
        const Expanded(child: Divider(color: Color(0xFFE5E7EB), thickness: 1)),
      ],
    );
  }
}
