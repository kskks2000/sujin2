import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.markSize = 58,
    this.showWordmark = true,
    this.onDark = false,
    this.subtitle,
  });

  final double markSize;
  final bool showWordmark;
  final bool onDark;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final textColor = onDark ? Colors.white : AppTheme.ink;
    final secondaryColor = onDark ? Colors.white70 : AppTheme.muted;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _BrandMark(size: markSize),
        if (showWordmark) ...[
          SizedBox(width: markSize * 0.24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'SUJIN',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: secondaryColor,
                      letterSpacing: 2.4,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Text(
                '수진 TMS',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
              ),
              Text(
                subtitle ?? '운송 운영 컨트롤 타워',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: secondaryColor),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.34),
        gradient: const LinearGradient(
          colors: [Color(0xFF123A60), Color(0xFF11767A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF123A60).withOpacity(0.24),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: EdgeInsets.all(size * 0.16),
      child: CustomPaint(painter: _BrandMarkPainter()),
    );
  }
}

class _BrandMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final routePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.12
      ..color = Colors.white.withOpacity(0.94)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final route = Path()
      ..moveTo(size.width * 0.2, size.height * 0.28)
      ..cubicTo(
        size.width * 0.5,
        size.height * 0.03,
        size.width * 0.86,
        size.height * 0.26,
        size.width * 0.54,
        size.height * 0.46,
      )
      ..cubicTo(
        size.width * 0.24,
        size.height * 0.62,
        size.width * 0.2,
        size.height * 0.92,
        size.width * 0.8,
        size.height * 0.74,
      );

    canvas.drawPath(route, routePaint);

    final startDot = Paint()..color = const Color(0xFFFFC857);
    final endDot = Paint()..color = const Color(0xFF13B9A8);
    final innerDot = Paint()..color = const Color(0xFF123A60);
    final whiteDot = Paint()..color = Colors.white;

    final start = Offset(size.width * 0.22, size.height * 0.28);
    final mid = Offset(size.width * 0.58, size.height * 0.46);
    final end = Offset(size.width * 0.8, size.height * 0.74);

    canvas.drawCircle(start, size.width * 0.11, startDot);
    canvas.drawCircle(start, size.width * 0.05, innerDot);
    canvas.drawCircle(mid, size.width * 0.08, whiteDot);
    canvas.drawCircle(end, size.width * 0.11, endDot);
    canvas.drawCircle(end, size.width * 0.05, innerDot);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
