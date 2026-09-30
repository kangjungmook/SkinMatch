import 'package:flutter/material.dart';

/// CSS `border: dashed`와 비슷한 점선 둥근 테두리
class DashedBorder extends StatelessWidget {
  const DashedBorder({
    super.key,
    required this.child,
    required this.color,
    this.radius = 16,
    this.width = 1.5,
    this.dash = 4.5,
    this.gap = 3.5,
  });

  final Widget child;
  final Color color;
  final double radius;
  final double width;
  final double dash;
  final double gap;

  @override
  Widget build(BuildContext context) => CustomPaint(foregroundPainter: _DashPainter(color, radius, width, dash, gap), child: child);
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.color, this.radius, this.width, this.dash, this.gap);
  final Color color;
  final double radius;
  final double width;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius((Offset.zero & size).deflate(width / 2), Radius.circular(radius - width / 2));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    for (final m in (Path()..addRRect(r)).computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + dash), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashPainter o) => o.color != color || o.radius != radius || o.width != width;
}
