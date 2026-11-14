import 'package:material_ui/material_ui.dart';

import '../models/tasting_note.dart';
import '../theme.dart';

/// PDF 상단의 색상 막대 (0.0 연한 짚색 → 2.0 짙은 마호가니).
const _stops = <(double, Color)>[
  (0.0, Color(0xFFF7E7A6)),
  (0.3, Color(0xFFE8C547)),
  (0.6, Color(0xFFD49A1E)),
  (0.9, Color(0xFFB86B0C)),
  (1.2, Color(0xFF8E3B08)),
  (1.5, Color(0xFF6A1E05)),
  (1.8, Color(0xFF4A0D04)),
  (2.0, Color(0xFF2A0603)),
];

Color whiskyColor(double v) {
  final x = v.clamp(colorMin, colorMax);
  for (var i = 0; i < _stops.length - 1; i++) {
    final (a, ca) = _stops[i];
    final (b, cb) = _stops[i + 1];
    if (x <= b) return Color.lerp(ca, cb, (x - a) / (b - a))!;
  }
  return _stops.last.$2;
}

/// 0.1 단위로 21칸. 칸을 누르면 선택, 같은 칸을 다시 누르면 해제.
class ColorScalePicker extends StatelessWidget {
  const ColorScalePicker({super.key, required this.value, this.onChanged});

  final double? value;
  final ValueChanged<double?>? onChanged;

  static const _count = 21;

  @override
  Widget build(BuildContext context) {
    final selected = value == null ? null : (value! * 10).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 36,
          child: Row(
            children: [
              for (var i = 0; i < _count; i++)
                Expanded(
                  child: GestureDetector(
                    onTap: onChanged == null
                        ? null
                        : () => onChanged!(selected == i ? null : i / 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: whiskyColor(i / 10),
                        border: selected == i
                            ? Border.all(color: Colors.black, width: 3)
                            : null,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final t in ['0.0', '0.5', '1.0', '1.5', '2.0'])
              Text(t, style: const TextStyle(fontSize: 11)),
          ],
        ),
        if (value != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '선택: ${value!.toStringAsFixed(1)}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: NoteColors.leather,
              ),
            ),
          ),
      ],
    );
  }
}
