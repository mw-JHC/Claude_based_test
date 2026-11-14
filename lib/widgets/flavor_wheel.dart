import 'package:material_ui/material_ui.dart';

import '../models/tasting_note.dart';
import '../theme.dart';
import 'radar_chart.dart';

/// 레이더 차트 + PDF 오른쪽에 있던 항목 설명(곡물: 밀가루 쌀 호밀빵 …).
class FlavorWheel extends StatelessWidget {
  const FlavorWheel({
    super.key,
    required this.axes,
    required this.values,
    this.onChanged,
    this.color = NoteColors.amber,
  });

  final List<FlavorAxis> axes;
  final List<int> values;
  final void Function(int axis, int value)? onChanged;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final editable = onChanged != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (editable)
          const Text(
            '차트를 누르거나 끌어서 강도를 정하세요 (중심 0 ~ 바깥 10)',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: NoteColors.hint),
          ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: RadarChart(
              labels: [for (final a in axes) a.label],
              values: values,
              max: radarMax,
              color: color,
              onChanged: onChanged,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var i = 0; i < axes.length; i++)
              _AxisChip(
                axis: axes[i],
                value: values[i],
                color: color,
                onReset: editable && values[i] > 0
                    ? () => onChanged!(i, 0)
                    : null,
              ),
          ],
        ),
      ],
    );
  }
}

class _AxisChip extends StatelessWidget {
  const _AxisChip({
    required this.axis,
    required this.value,
    required this.color,
    this.onReset,
  });

  final FlavorAxis axis;
  final int value;
  final Color color;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final active = value > 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.18) : Colors.white54,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: active ? color : Colors.black12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${axis.label}  $value',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: NoteColors.amber,
                  fontSize: 13,
                ),
              ),
              if (axis.hint.isNotEmpty)
                Text(
                  axis.hint,
                  style: const TextStyle(fontSize: 11, color: NoteColors.hint),
                ),
            ],
          ),
          if (onReset != null)
            InkWell(
              onTap: onReset,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close, size: 14),
              ),
            )
          else
            const SizedBox(width: 4),
        ],
      ),
    );
  }
}
