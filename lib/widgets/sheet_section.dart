import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// 둥근 카드 한 칸. 위에 한국어 제목과 작은 영문 부제가 붙습니다.
class SheetSection extends StatelessWidget {
  const SheetSection({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 16),
    required this.child,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: NoteColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: NoteColors.line.withValues(alpha: 0.6)),
      ),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: NoteColors.text,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(width: 8),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontFamily: serif,
                    fontStyle: FontStyle.italic,
                    fontSize: 13,
                    color: NoteColors.hint,
                  ),
                ),
              ],
              const Spacer(),
              ?trailing,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// 작은 둥근 꼬리표 (종류, 지역 등).
class InfoPill extends StatelessWidget {
  const InfoPill(this.text, {super.key, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: NoteColors.surfaceHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: NoteColors.gold),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: const TextStyle(fontSize: 12, color: NoteColors.text),
          ),
        ],
      ),
    );
  }
}

/// 점수를 둥근 링으로 보여줍니다 (0~100).
class ScoreRing extends StatelessWidget {
  const ScoreRing({super.key, required this.score, this.size = 52});

  final double? score;
  final double size;

  @override
  Widget build(BuildContext context) {
    final s = score;
    final label = s == null
        ? '–'
        : (s == s.roundToDouble() ? '${s.toInt()}' : s.toStringAsFixed(1));
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter((s ?? 0) / 100),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: serif,
              fontWeight: FontWeight.w700,
              fontSize: size * 0.34,
              color: s == null ? NoteColors.faint : NoteColors.text,
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.fraction);
  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.08;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    canvas.drawArc(
      rect,
      0,
      6.2832,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = NoteColors.line,
    );
    if (fraction <= 0) return;
    canvas.drawArc(
      rect,
      -1.5708,
      6.2832 * fraction.clamp(0, 1),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = const SweepGradient(
          startAngle: -1.5708,
          endAngle: 4.7124,
          colors: [Color(0xFFC9772F), Color(0xFFEBC07A)],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.fraction != fraction;
}

/// 고를 수 있는 둥근 버튼 (종류, 산지, 필터).
class SelectPill extends StatelessWidget {
  const SelectPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.small = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// 세부 지역처럼 한 단계 아래 선택지는 작고 테두리만 있는 모양.
  final bool small;

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? (small ? NoteColors.amber.withValues(alpha: 0.18) : NoteColors.amber)
        : (small ? Colors.transparent : NoteColors.surfaceHigh);
    final fg = selected
        ? (small ? NoteColors.gold : NoteColors.ink)
        : (small ? NoteColors.hint : NoteColors.text);
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: small ? 32 : 36,
          padding: EdgeInsets.symmetric(horizontal: small ? 12 : 16),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            border: small
                ? Border.all(
                    color: selected ? NoteColors.amber : NoteColors.line,
                  )
                : null,
          ),
          // 글자 너비만큼만 차지하고 세로로는 가운데 정렬.
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              style: TextStyle(
                fontSize: small ? 12.5 : 13,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
