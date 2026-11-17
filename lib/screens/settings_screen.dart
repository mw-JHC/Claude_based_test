import 'package:material_ui/material_ui.dart';

import '../data/app_settings.dart';
import '../data/note_store.dart';
import '../data/sample_data.dart';
import '../theme.dart';
import '../widgets/cabinet_view.dart';
import '../widgets/sheet_section.dart';

/// 설정 화면. 진열장 분위기를 고릅니다.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.settings,
    required this.store,
  });

  final AppSettings settings;
  final NoteStore store;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            SheetSection(
              title: '진열장 분위기',
              subtitle: 'Cabinet',
              child: Column(
                children: [
                  for (final style in CabinetStyle.values)
                    _StyleOption(
                      style: style,
                      selected: settings.cabinetStyle == style,
                      store: store,
                      onTap: () => settings.setCabinetStyle(style),
                    ),
                ],
              ),
            ),
            SheetSection(
              title: '테스트 데이터',
              subtitle: 'Samples',
              child: _SampleButtons(store: store),
            ),
          ],
        ),
      ),
    );
  }
}

/// 샘플 위스키 40병 넣기 / 지우기 (직접 넣은 병은 건드리지 않음).
class _SampleButtons extends StatefulWidget {
  const _SampleButtons({required this.store});

  final NoteStore store;

  @override
  State<_SampleButtons> createState() => _SampleButtonsState();
}

class _SampleButtonsState extends State<_SampleButtons> {
  bool _busy = false;

  Future<void> _run(Future<int> Function(NoteStore) job, String done) async {
    setState(() => _busy = true);
    final count = await job(widget.store);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(done.replaceAll('{n}', '$count'))));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '여러 산지·종류의 위스키 40병(빈 병 8병, 이야기 포함)을 넣어 기능을 시험해 볼 수 있어요. '
          '지우기는 샘플만 지우고 직접 넣은 병은 그대로 둡니다.',
          style: TextStyle(color: NoteColors.hint, fontSize: 12.5, height: 1.5),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () => _run(addSampleWhiskies, '샘플 {n}병을 넣었어요.'),
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.playlist_add),
                label: const Text('샘플 40병 넣기'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => _run(removeSampleWhiskies, '샘플 {n}병을 지웠어요.'),
                icon: const Icon(Icons.delete_sweep_outlined),
                label: const Text('샘플 지우기'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 진열장 스타일 하나: 이름, 설명, 내 위스키로 그린 작은 미리보기.
class _StyleOption extends StatelessWidget {
  const _StyleOption({
    required this.style,
    required this.selected,
    required this.store,
    required this.onTap,
  });

  final CabinetStyle style;
  final bool selected;
  final NoteStore store;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 미리보기는 실제 진열장의 첫 줄만 잘라서 보여줍니다.
    final sample = store.library.take(4).toList();
    return Semantics(
      button: true,
      selected: selected,
      label: style.label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: NoteColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? NoteColors.amber : NoteColors.line,
              width: selected ? 3 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 170,
                child: IgnorePointer(
                  child: ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.topCenter,
                      maxHeight: 420,
                      child: SizedBox(
                        height: 420,
                        child: CabinetView(
                          store: store,
                          notes: sample,
                          style: style,
                          onOpen: (_) {},
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            style.label,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            style.description,
                            style: const TextStyle(
                              fontSize: 12,
                              color: NoteColors.hint,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      selected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: selected ? NoteColors.amber : NoteColors.faint,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
