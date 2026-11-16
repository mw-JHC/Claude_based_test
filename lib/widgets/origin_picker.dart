import 'package:material_ui/material_ui.dart';

import '../models/tasting_note.dart';
import '../theme.dart';
import 'sheet_section.dart';

/// 산지 고르기: 먼저 나라, 그 아래에 그 나라의 세부 지역이 나옵니다.
/// World는 나라 이름을 직접 적습니다.
class OriginPicker extends StatefulWidget {
  const OriginPicker({
    super.key,
    required this.origin,
    required this.subRegion,
    required this.onChanged,
  });

  final WhiskyOrigin? origin;
  final String subRegion;
  final void Function(WhiskyOrigin? origin, String subRegion) onChanged;

  @override
  State<OriginPicker> createState() => _OriginPickerState();
}

class _OriginPickerState extends State<OriginPicker> {
  late final _country = TextEditingController(
    text: widget.origin?.freeText == true ? widget.subRegion : '',
  );

  @override
  void didUpdateWidget(OriginPicker old) {
    super.didUpdateWidget(old);
    // 라벨 읽기로 바깥에서 World 나라가 채워지면 입력칸도 맞춥니다.
    if (widget.origin?.freeText == true && widget.subRegion != _country.text) {
      _country.text = widget.subRegion;
    }
  }

  @override
  void dispose() {
    _country.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final origin = widget.origin;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '산지',
          style: TextStyle(fontSize: 12, color: NoteColors.hint),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final o in WhiskyOrigin.values)
              SelectPill(
                label: o.label,
                selected: origin == o,
                // 다시 누르면 선택 해제. 나라를 바꾸면 세부 지역은 비웁니다.
                onTap: () => widget.onChanged(origin == o ? null : o, ''),
              ),
          ],
        ),
        if (origin != null && origin.subRegions.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            origin == WhiskyOrigin.american ? '스타일' : '세부 지역',
            style: const TextStyle(fontSize: 12, color: NoteColors.hint),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final r in origin.subRegions)
                SelectPill(
                  label: r,
                  small: true,
                  selected: widget.subRegion == r,
                  onTap: () =>
                      widget.onChanged(origin, widget.subRegion == r ? '' : r),
                ),
            ],
          ),
        ],
        if (origin != null && origin.freeText) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _country,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: '나라 (예: Germany, India)',
            ),
            onChanged: (v) => widget.onChanged(origin, v.trim()),
          ),
        ],
      ],
    );
  }
}
