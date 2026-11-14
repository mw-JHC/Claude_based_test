import 'package:material_ui/material_ui.dart';

import '../data/note_store.dart';
import '../models/tasting_note.dart';
import '../theme.dart';
import '../widgets/color_scale.dart';
import '../widgets/note_photo.dart';
import 'note_detail_screen.dart';
import 'note_edit_screen.dart';

/// 첫 화면: 마셔본 위스키 목록.
class NoteListScreen extends StatefulWidget {
  const NoteListScreen({super.key, required this.store});

  final NoteStore store;

  @override
  State<NoteListScreen> createState() => _NoteListScreenState();
}

class _NoteListScreenState extends State<NoteListScreen> {
  String _query = '';

  bool _matches(TastingNote n) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return [
      n.name,
      n.region,
      n.ageCask,
      n.type?.label ?? '',
      n.overall,
    ].any((s) => s.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return Scaffold(
      appBar: AppBar(title: const Text('Whisky Note')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => NoteEditScreen(store: store))),
        icon: const Icon(Icons.add),
        label: const Text('새 노트'),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          if (!store.loaded) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = store.notes;
          if (all.isEmpty) return const _EmptyState();
          final notes = all.where(_matches).toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v.trim()),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: '이름, 지역, 종류로 검색',
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${notes.length}병',
                    style: const TextStyle(color: NoteColors.hint),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
                  itemCount: notes.length,
                  itemBuilder: (context, i) =>
                      _NoteCard(store: store, note: notes[i]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.store, required this.note});

  final NoteStore store;
  final TastingNote note;

  @override
  Widget build(BuildContext context) {
    final sub = [
      note.type?.label,
      note.region,
      note.ageCask,
      if (note.abv != null) '${note.abv}%',
    ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
    return Card(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: const BorderSide(color: NoteColors.paper),
      ),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => NoteDetailScreen(store: store, noteId: note.id),
          ),
        ),
        child: SizedBox(
          height: 88,
          child: Row(
            children: [
              SizedBox(
                width: 88,
                child: NotePhoto(
                  file: store.storage.photoFile(note.photo),
                  icon: 32,
                ),
              ),
              // 위스키 색을 세로 띠로 표시.
              Container(
                width: 6,
                color: note.color == null
                    ? Colors.transparent
                    : whiskyColor(note.color!),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (sub.isNotEmpty)
                        Text(
                          sub,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: NoteColors.hint,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (note.score != null)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Text(
                    note.score! == note.score!.roundToDouble()
                        ? '${note.score!.toInt()}'
                        : '${note.score}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: NoteColors.amber,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_bar, size: 64, color: NoteColors.amber),
            SizedBox(height: 16),
            Text(
              '아직 기록한 위스키가 없습니다',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              '아래 "새 노트" 버튼으로 첫 테이스팅 노트를 남겨보세요.',
              textAlign: TextAlign.center,
              style: TextStyle(color: NoteColors.hint),
            ),
          ],
        ),
      ),
    );
  }
}
