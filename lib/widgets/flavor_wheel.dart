import 'package:material_ui/material_ui.dart';

import '../models/tasting_note.dart';
import '../theme.dart';
import 'radar_chart.dart';
import '../l10n/tr.dart';

/// 향 / 맛 / 비후방 후각 칸에 들어가는 원형 차트.
///
/// 값은 축 이름 옆에 표시되고, 예시는 이름 옆 (?) 버튼으로 봅니다.
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
    final hasHelp = axes.any((a) => a.examples.isNotEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (editable)
          Text(
            hasHelp
                ? tr(
                    '차트를 누르거나 끌어서 강도를 정하세요 (중심 0 ~ 바깥 10)\n(?)를 누르면 예시가 나옵니다',
                    'Tap or drag the chart to set the intensity (centre 0 – edge 10)\nTap (?) for examples',
                  )
                : tr(
                    '차트를 누르거나 끌어서 강도를 정하세요 (중심 0 ~ 바깥 10)',
                    'Tap or drag the chart to set the intensity (centre 0 – edge 10)',
                  ),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: NoteColors.hint),
          ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: RadarChart(
              axes: axes,
              values: values,
              max: radarMax,
              color: color,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
