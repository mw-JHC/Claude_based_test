import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../models/tasting_note.dart';
import '../theme.dart';

/// PDF의 원형 차트(향, 맛, 비후방 후각).
///
/// 각 축 이름 옆에 현재 값이 붙고, 예시가 있는 축에는 (?) 버튼이 붙어서
/// 누르면 예시가 나옵니다.
///
/// [onChanged]가 있으면 차트를 누르거나 끌어서 값을 바꿀 수 있습니다.
/// 축 방향으로 바깥쪽을 누를수록 값이 커지고, 중심을 누르면 0이 됩니다.
class RadarChart extends StatefulWidget {
  const RadarChart({
    super.key,
    required this.axes,
    required this.values,
    required this.max,
    this.onChanged,
    this.color = NoteColors.amber,
  });

  final List<FlavorAxis> axes;
  final List<int> values;
  final int max;
  final void Function(int axis, int value)? onChanged;
  final Color color;

  @override
  State<RadarChart> createState() => _RadarChartState();
}

class _RadarChartState extends State<RadarChart> {
  /// 차트 바깥에 이름표가 들어갈 여백 (좌우는 넓게, 위아래는 좁게).
  static const _sideSpace = 62.0;
  static const _topSpace = 56.0;

  /// 끄는 동안에는 처음 잡은 축만 바뀌도록 고정합니다.
  int? _dragAxis;

  static double _radius(Size s) =>
      math.min(s.width / 2 - _sideSpace, s.height / 2 - _topSpace);

  int get _n => widget.axes.length;

  /// i번 축의 방향 (위쪽 12시가 0번, 시계방향).
  double _angle(int i) => -math.pi / 2 + 2 * math.pi * i / _n;

  int _axisAt(Offset d) {
    var a = math.atan2(d.dy, d.dx) + math.pi / 2;
    if (a < 0) a += 2 * math.pi;
    return (a / (2 * math.pi / _n)).round() % _n;
  }

  void _handle(Offset pos, Size size, {bool start = false}) {
    final onChanged = widget.onChanged;
    if (onChanged == null) return;
    final d = pos - size.center(Offset.zero);
    final r = _radius(size);
    if (start) {
      if (d.distance > r + 16) return;
      _dragAxis = _axisAt(d);
    }
    final axis = _dragAxis;
    if (axis == null) return;
    // 고정된 축 방향으로 투영한 길이로 값을 정합니다.
    final a = _angle(axis);
    final along = d.dx * math.cos(a) + d.dy * math.sin(a);
    final value = (along / r * widget.max).round().clamp(0, widget.max);
    if (value != widget.values[axis]) onChanged(axis, value);
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.1,
      child: LayoutBuilder(
        builder: (context, c) {
          final size = Size(c.maxWidth, c.maxHeight);
          final center = size.center(Offset.zero);
          final r = _radius(size);

          Widget chart = CustomPaint(
            size: size,
            painter: _RadarPainter(
              count: _n,
              // 편집 화면에서 리스트를 직접 바꾸므로 복사본을 넘겨야 다시 그려집니다.
              values: List.of(widget.values),
              max: widget.max,
              color: widget.color,
              radius: r,
            ),
          );
          if (widget.onChanged != null) {
            chart = GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (e) {
                _handle(e.localPosition, size, start: true);
                _dragAxis = null;
              },
              onPanStart: (e) => _handle(e.localPosition, size, start: true),
              onPanUpdate: (e) => _handle(e.localPosition, size),
              onPanEnd: (_) => _dragAxis = null,
              child: chart,
            );
          }

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(child: chart),
              // 이름표는 차트와 형제로 둬서, (?)를 눌러도 값이 바뀌지 않게 합니다.
              for (var i = 0; i < _n; i++)
                _placeLabel(
                  center: center,
                  radius: r + 8,
                  angle: _angle(i),
                  child: _AxisLabel(
                    axis: widget.axes[i],
                    value: widget.values[i],
                    color: widget.color,
                    // 아래쪽 이름표는 숫자를 차트 쪽(위)에 둡니다.
                    valueFirst: math.sin(_angle(i)) > 0.3,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// 이름표의 "차트에 가장 가까운 쪽"이 축 끝에 오도록 배치합니다.
  /// 오른쪽 축은 오른쪽으로, 위쪽 축은 위로 뻗어 나갑니다.
  Widget _placeLabel({
    required Offset center,
    required double radius,
    required double angle,
    required Widget child,
  }) {
    final cos = math.cos(angle), sin = math.sin(angle);
    final anchor = center + Offset(cos, sin) * radius;
    // 축 방향 기준 정렬: cos=1(오른쪽) → 이름표 왼쪽 끝이 기준점.
    final ax = cos.abs() < 0.2 ? 0.0 : -cos.sign;
    final ay = sin.abs() < 0.2 ? 0.0 : -sin.sign;
    return Positioned(
      left: anchor.dx,
      top: anchor.dy,
      child: FractionalTranslation(
        translation: Offset(-(ax + 1) / 2, -(ay + 1) / 2),
        child: child,
      ),
    );
  }
}

/// 축 이름 + 값 + (?) 버튼.
class _AxisLabel extends StatelessWidget {
  const _AxisLabel({
    required this.axis,
    required this.value,
    required this.color,
    required this.valueFirst,
  });

  final FlavorAxis axis;
  final int value;
  final Color color;
  final bool valueFirst;

  @override
  Widget build(BuildContext context) {
    final name = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          axis.label,
          style: const TextStyle(
            color: NoteColors.text,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (axis.examples.isNotEmpty) _HelpButton(axis: axis),
      ],
    );
    final active = value > 0;
    final badge = Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: active ? color : NoteColors.surfaceHigh,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: active ? color : NoteColors.line),
      ),
      child: Text(
        '$value',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: active ? NoteColors.ink : NoteColors.faint,
        ),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: valueFirst ? [badge, name] : [name, badge],
    );
  }
}

/// 누르면 그 축의 예시(곡물 → 밀가루, 호밀빵 …)를 보여주는 작은 버튼.
class _HelpButton extends StatelessWidget {
  const _HelpButton({required this.axis});

  final FlavorAxis axis;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 4),
      preferBelow: false,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: NoteColors.ink,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: NoteColors.gold.withValues(alpha: 0.7)),
      ),
      richMessage: TextSpan(
        children: [
          TextSpan(
            text: '${axis.label}\n',
            style: const TextStyle(
              color: NoteColors.gold,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          TextSpan(
            text: axis.examples.join(', '),
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ],
      ),
      child: Semantics(
        button: true,
        label: '${axis.label} 예시 보기',
        child: const Padding(
          // 손가락으로 누르기 쉽게 주변 여백을 둡니다.
          padding: EdgeInsets.fromLTRB(3, 4, 4, 4),
          child: Icon(Icons.help_outline, size: 16, color: NoteColors.hint),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.count,
    required this.values,
    required this.max,
    required this.color,
    required this.radius,
  });

  final int count;
  final List<int> values;
  final int max;
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final n = count;
    final c = size.center(Offset.zero);
    final r = radius;
    Offset at(int i, double frac) {
      final a = -math.pi / 2 + 2 * math.pi * i / n;
      return c + Offset(math.cos(a), math.sin(a)) * r * frac;
    }

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0.10),
            color.withValues(alpha: 0.02),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..color = NoteColors.line
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
  }

  @override
  bool shouldRepaint(_RadarPainter old) =>
      old.values != values ||
      old.max != max ||
      old.color != color ||
      old.radius != radius;
}
