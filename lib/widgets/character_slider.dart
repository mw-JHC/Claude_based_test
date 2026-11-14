import 'package:material_ui/material_ui.dart';

import '../models/tasting_note.dart';

/// PDF의 개성 막대 색 (드라이↔오일리는 금색, 가벼운↔무거운은 초록 …).
const scaleColors = <String, Color>{
  'dryOily': Color(0xFFC1902A),
  'lightHeavy': Color(0xFF3F5E2E),
  'mildSpicy': Color(0xFFE8262A),
  'smoothIntense': Color(0xFFB0202A),
  'finish': Color(0xFFE8B84A),
};

/// 왼쪽 라벨 ── 1~9칸 막대 ── 오른쪽 라벨.
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
    final color = scaleColors[scale.key] ?? Colors.brown;
    const labelStyle = TextStyle(fontSize: 13, fontWeight: FontWeight.bold);
    return Row(
      children: [
        SizedBox(width: 60, child: Text(scale.left, style: labelStyle)),
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
                  inactiveColor: color.withValues(alpha: 0.2),
                  onChanged: (v) => onChanged!(v.round()),
                ),
        ),
        SizedBox(
          width: 52,
          child: Text(
            scale.right,
            style: labelStyle,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

/// 읽기 전용: PDF처럼 9칸 중 선택한 칸까지 색칠.
class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.color});

  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: [
          for (var i = 1; i <= scaleSteps; i++)
            Expanded(
              child: Container(
                height: 18,
                decoration: BoxDecoration(
                  color: i == value
                      ? color
                      : color.withValues(alpha: i < value ? 0.35 : 0.06),
                  border: Border.all(color: Colors.black26, width: 0.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
