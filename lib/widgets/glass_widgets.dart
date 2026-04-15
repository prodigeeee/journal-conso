import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:math';

class NeonBottomShadowPainter extends CustomPainter {
  final bool isDarkMode;
  NeonBottomShadowPainter({required this.isDarkMode});

  @override
  void paint(Canvas canvas, Size size) {
    final Color accentColor = isDarkMode
        ? const Color(0xFFFF6D00)
        : const Color(0xFF2365FF);
    Rect rect = Offset.zero & size;
    const double rad = 24.0;
    RRect rrect = RRect.fromRectAndRadius(rect, const Radius.circular(rad));
    Path rectPath = Path()..addRRect(rrect);

    void drawInnerShadow(Color color, double blur, double dy) {
      Path holePath = Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            rect.translate(0, -dy),
            const Radius.circular(rad),
          ),
        );
      Path shadowPath = Path.combine(
        PathOperation.difference,
        rectPath,
        holePath,
      );
      canvas.drawPath(
        shadowPath,
        Paint()
          ..color = color
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
      );
    }

    drawInnerShadow(accentColor.withValues(alpha: isDarkMode ? 0.8 : 0.4), 24, 8);
    drawInnerShadow(accentColor.withValues(alpha: isDarkMode ? 1.0 : 0.7), 12, 4);
    drawInnerShadow(Colors.white.withValues(alpha: isDarkMode ? 0.8 : 0.9), 4, 1.5);
    drawInnerShadow(Colors.white.withValues(alpha: 1.0), 1, 0.5);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Widget glassModule({
  required Widget child,
  Color? borderColor,
  required bool isDarkMode,
  EdgeInsets? padding,
  bool showHalo = true,
}) {
  return Container(
    margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        if (isDarkMode)
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 15,
            offset: const Offset(0, 6),
          )
        else
          BoxShadow(
            color: const Color(0xFF90A4AE).withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: -2,
          ),
      ],
    ),
    child: RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              gradient: isDarkMode
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF1E272E).withValues(alpha: 0.3),
                        const Color(0xFF000000).withValues(alpha: 0.15),
                      ],
                    )
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.6),
                        Colors.white.withValues(alpha: 0.25),
                      ],
                    ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: borderColor ??
                    (isDarkMode
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.white.withValues(alpha: 0.7)),
                width: 0.8,
              ),
            ),
            child: Stack(
              children: [
                if (showHalo)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: CustomPaint(
                        painter: NeonBottomShadowPainter(isDarkMode: isDarkMode),
                      ),
                    ),
                  ),
                Positioned(
                  top: -50,
                  left: -50,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withValues(alpha: isDarkMode ? 0.05 : 0.2),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: padding ?? const EdgeInsets.all(12),
                  child: child,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class WavePainter extends CustomPainter {
  final Color color;
  final double progress;
  WavePainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    double y = size.height * (0.6 + sin(progress * 2 * pi) * 0.05);
    path.moveTo(0, y);
    for (double x = 0; x <= size.width; x++) {
      double sine = sin((progress * 2 * pi) + (x * 0.15));
      path.lineTo(x, y + (sine * 3));
    }
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(WavePainter oldDelegate) => true;
}

class LiquidGlassFAB extends StatefulWidget {
  final Color accentColor;
  final VoidCallback onPressed;
  const LiquidGlassFAB({super.key, required this.accentColor, required this.onPressed});
  @override
  State<LiquidGlassFAB> createState() => _LiquidGlassFABState();
}

class _LiquidGlassFABState extends State<LiquidGlassFAB>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onPressed,
      child: Container(
        width: 65,
        height: 65,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.accentColor.withValues(alpha: 0.4),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipOval(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(color: widget.accentColor.withValues(alpha: 0.2)),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return CustomPaint(
                    size: const Size(65, 65),
                    painter: WavePainter(
                      color: widget.accentColor,
                      progress: _controller.value,
                    ),
                  );
                },
              ),
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.4),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.1),
                    ],
                  ),
                ),
              ),
              const Icon(Icons.add, color: Colors.white, size: 35),
            ],
          ),
        ),
      ),
    );
  }
}
