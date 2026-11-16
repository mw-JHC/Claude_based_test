import 'package:material_ui/material_ui.dart';

import '../models/tasting_note.dart';
import '../theme.dart';

/// 개성 막대 색 (드라이↔오일리는 금색, 가벼운↔무거운은 초록 …).
const scaleColors = <String, Color>{
  'dryOily': Color(0xFFD9A84E),
  'lightHeavy': Color(0xFF8DB580),
  'mildSpicy': Color(0xFFEF7A55),
  'smoothIntense': Color(0xFFE0605E),
  'finish': Color(0xFFEBC07A),
};

/// 맛 / 비후방 후각 차트 색 (어두운 바탕에서 잘 보이도록 밝게).
const palateColor = Color(0xFFE0806A);
const retronasalColor = Color(0xFF8DB580);

/// 왼쪽 라벨 ── 1~9 막대 ── 오른쪽 라벨.
class CharacterSlider extends StatelessWidget {
  const CharacterSlider({
    super.key,
    required this.scale,
    required this.value,
    this.onChanged,
  });

  final CharacterScale scale;
  final int value;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    final color = scaleColors[scale.key] ?? NoteColors.amber;
    const labelStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: NoteColors.hint,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 62, child: Text(scale.left, style: labelStyle)),
          Expanded(
            child: onChanged == null
                ? _Bar(value: value, color: color)
                : Slider(
                    value: value.toDouble(),
                    min: 1,
                    max: scaleSteps.toDouble(),
                    divisions: scaleSteps - 1,
                    label: '$value',
                    activeColor: color,
                    inactiveColor: color.withValues(alpha: 0.18),
                    onChanged: (v) => onChanged!(v.round()),
                  ),
          ),
          SizedBox(
            width: 54,
            child: Text(
              scale.right,
              style: labelStyle,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

/// 읽기 전용: 가는 트랙 위에 현재 위치를 점으로 표시.
class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.color});

  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = (value - 1) / (scaleSteps - 1);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          return SizedBox(
            height: 14,
            child: Stack(
              alignment: Alignment.centerLeft,
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Container(
                  width: w * t,
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: LinearGradient(
                      colors: [color.withValues(alpha: 0.3), color],
                    ),
                  ),
                ),
                Positioned(
                  left: w * t - 7,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: NoteColors.surface, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.5),
                          blurRadius: 8,
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
