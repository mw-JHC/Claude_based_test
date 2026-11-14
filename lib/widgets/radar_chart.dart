import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// PDF의 원형 차트(향, 맛, 비후방 후각).
///
/// [onChanged]가 있으면 차트를 누르거나 끌어서 값을 바꿀 수 있습니다.
/// 축 방향으로 바깥쪽을 누를수록 값이 커지고, 중심을 누르면 0이 됩니다.
class RadarChart extends StatefulWidget {
  const RadarChart({
    super.key,
    required this.labels,
    required this.values,
    required this.max,
    this.onChanged,
    this.color = NoteColors.amber,
  });

  final List<String> labels;
  final List<int> values;
  final int max;
  final void Function(int axis, int value)? onChanged;
  final Color color;

  @override
  State<RadarChart> createState() => _RadarChartState();
}

class _RadarChartState extends State<RadarChart> {
  static const _labelSpace = 30.0;

  /// 끄는 동안에는 처음 잡은 축만 바뀌도록 고정합니다.
  int? _dragAxis;

  double _radius(Size size) => size.shortestSide / 2 - _labelSpace;

  int _axisAt(Offset d) {
    final n = widget.labels.length;
    // 위쪽(12시)이 0번 축, 시계방향으로 증가.
    var a = math.atan2(d.dy, d.dx) + math.pi / 2;
    if (a < 0) a += 2 * math.pi;
    return (a / (2 * math.pi / n)).round() % n;
  }

  void _handle(Offset pos, Size size, {bool start = false}) {
    final onChanged = widget.onChanged;
    if (onChanged == null) return;
    final d = pos - size.center(Offset.zero);
    final r = _radius(size);
    if (start) {
      if (d.distance > r + _labelSpace) return;
      _dragAxis = _axisAt(d);
    }
    final axis = _dragAxis;
    if (axis == null) return;
    // 고정된 축 방향으로 투영한 길이로 값을 정합니다.
    final angle = -math.pi / 2 + 2 * math.pi * axis / widget.labels.length;
    final along = d.dx * math.cos(angle) + d.dy * math.sin(angle);
    final value = (along / r * widget.max).round().clamp(0, widget.max);
    if (value != widget.values[axis]) onChanged(axis, value);
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, c) {
          final size = Size(c.maxWidth, c.maxHeight);
          final paint = CustomPaint(
            size: size,
            painter: _RadarPainter(
              labels: widget.labels,
              // 편집 화면에서 리스트를 직접 바꾸므로 복사본을 넘겨야 다시 그려집니다.
              values: List.of(widget.values),
              max: widget.max,
              color: widget.color,
              labelSpace: _labelSpace,
            ),
          );
          if (widget.onChanged == null) return paint;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (e) {
              _handle(e.localPosition, size, start: true);
              _dragAxis = null;
            },
            onPanStart: (e) => _handle(e.localPosition, size, start: true),
            onPanUpdate: (e) => _handle(e.localPosition, size),
            onPanEnd: (_) => _dragAxis = null,
            child: paint,
          );
        },
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.labels,
    required this.values,
    required this.max,
    required this.color,
    required this.labelSpace,
  });

  final List<String> labels;
  final List<int> values;
  final int max;
  final Color color;
  final double labelSpace;

  @override
  void paint(Canvas canvas, Size size) {
    final n = labels.length;
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - labelSpace;
    Offset at(int i, double frac) {
      final a = -math.pi / 2 + 2 * math.pi * i / n;
      return c + Offset(math.cos(a), math.sin(a)) * r * frac;
    }

    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.black54
      ..strokeWidth = 0.6;
    for (var k = 1; k <= max; k++) {
      canvas.drawCircle(c, r * k / max, grid);
    }
    for (var i = 0; i < n; i++) {
      canvas.drawLine(c, at(i, 1), grid);
    }

    final shape = Path();
    for (var i = 0; i < n; i++) {
      final p = at(i, values[i] / max);
      i == 0 ? shape.moveTo(p.dx, p.dy) : shape.lineTo(p.dx, p.dy);
    }
    shape.close();
    canvas.drawPath(shape, Paint()..color = color.withValues(alpha: 0.35));
    canvas.drawPath(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color,
    );
    final dot = Paint()..color = color;
    for (var i = 0; i < n; i++) {
      if (values[i] > 0) canvas.drawCircle(at(i, values[i] / max), 3.5, dot);
    }

    for (var i = 0; i < n; i++) {
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final p = at(i, 1 + (labelSpace * 0.55) / r);
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) =>
      old.values != values || old.max != max || old.color != color;
}
