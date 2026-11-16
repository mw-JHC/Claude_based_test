import 'package:material_ui/material_ui.dart';

import '../data/app_settings.dart';
import '../data/note_store.dart';
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
      appBar: AppBar(title: const Text('설정')),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(12),
          children: [
            SheetSection(
              title: '진열장',
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
          ],
        ),
      ),
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
    final sample = store.notes.take(4).toList();
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? NoteColors.amber : Colors.black12,
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
                      color: selected ? NoteColors.amber : Colors.black26,
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
