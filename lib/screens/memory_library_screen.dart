import 'package:material_ui/material_ui.dart';

import '../data/app_settings.dart';
import '../data/note_store.dart';
import '../theme.dart';
import '../widgets/cabinet_view.dart';
import 'note_detail_screen.dart';

/// 다 마신 병을 전시하는 곳. 노트와 이야기는 그대로 남아 있습니다.
class MemoryLibraryScreen extends StatelessWidget {
  const MemoryLibraryScreen({
    super.key,
    required this.store,
    required this.settings,
  });

  final NoteStore store;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([store, settings]),
          builder: (context, _) {
            final memories = store.memories;
            final stories = memories.fold<int>(
              0,
              (sum, n) => sum + n.stories.length,
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 10, 16, 14),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: '뒤로',
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Memory Library',
                              style: TextStyle(
                                fontFamily: serif,
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                height: 1.1,
                                color: NoteColors.text,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '비운 병 ${memories.length}  ·  이야기 $stories',
                              style: const TextStyle(
                                fontSize: 13,
                                color: NoteColors.hint,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    child: CabinetView(
                      store: store,
                      notes: memories,
                      style: settings.cabinetStyle,
                      onOpen: (n) => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              NoteDetailScreen(store: store, noteId: n.id),
                        ),
                      ),
                      emptyMessage: const _NoMemories(),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NoMemories extends StatelessWidget {
  const _NoMemories();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: NoteColors.bg.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: NoteColors.line),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_stories_outlined, size: 36, color: NoteColors.gold),
            SizedBox(height: 14),
            Text(
              '아직 비운 병이 없어요',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: NoteColors.text,
              ),
            ),
            SizedBox(height: 6),
            Text(
              '다 마신 병은 노트에서 "병 비우기"를 누르면\n이야기와 함께 이곳에 전시됩니다.',
              textAlign: TextAlign.center,
              style: TextStyle(color: NoteColors.hint, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
