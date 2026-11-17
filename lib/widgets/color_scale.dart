import 'package:material_ui/material_ui.dart';

import '../models/tasting_note.dart';
import '../theme.dart';
import '../l10n/tr.dart';

/// 색상 막대 (0.0 연한 짚색 → 1.0 짙은 마호가니).
const _stops = <(double, Color)>[
  (0.0, Color(0xFFF7E7A6)),
  (0.15, Color(0xFFE8C547)),
  (0.3, Color(0xFFD49A1E)),
  (0.45, Color(0xFFB86B0C)),
  (0.6, Color(0xFF8E3B08)),
  (0.75, Color(0xFF6A1E05)),
  (0.9, Color(0xFF4A0D04)),
  (1.0, Color(0xFF2A0603)),
];

/// 색상 값 글자 (0.4, 0.25, 1.0 …)
String formatColor(double v) {
  final s = v.toStringAsFixed(2);
  return s.endsWith('0') ? v.toStringAsFixed(1) : s;
}

Color whiskyColor(double v) {
  final x = v.clamp(colorMin, colorMax);
  for (var i = 0; i < _stops.length - 1; i++) {
    final (a, ca) = _stops[i];
    final (b, cb) = _stops[i + 1];
    if (x <= b) return Color.lerp(ca, cb, (x - a) / (b - a))!;
  }
  return _stops.last.$2;
}

/// 0.05 단위로 21칸 (0.0 ~ 1.0). 칸을 누르면 선택, 같은 칸을 다시 누르면 해제.
class ColorScalePicker extends StatelessWidget {
  const ColorScalePicker({super.key, required this.value, this.onChanged});

  final double? value;
  final ValueChanged<double?>? onChanged;

  static const _count = 21;

  @override
  Widget build(BuildContext context) {
    final selected = value == null ? null : (value! * 20).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 둥근 막대 (선택 테두리가 잘리지 않게 바깥은 둥글게만 자릅니다)
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 40,
            child: Row(
              children: [
                for (var i = 0; i < _count; i++)
                  Expanded(
                    child: GestureDetector(
                      onTap: onChanged == null
                          ? null
                          : () => onChanged!(selected == i ? null : i / 20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: whiskyColor(i / 20),
                          border: selected == i
                              ? Border.all(color: NoteColors.text, width: 2.5)
                              : null,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final t in ['0.0', '0.25', '0.5', '0.75', '1.0'])
              Text(
                t,
                style: const TextStyle(fontSize: 11, color: NoteColors.hint),
              ),
          ],
        ),
        if (value != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${tr('선택', 'Selected')}: ${formatColor(value!)}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: NoteColors.gold,
              ),
            ),
          ),
      ],
    );
  }
}
