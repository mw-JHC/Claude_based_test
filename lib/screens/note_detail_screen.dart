import 'package:material_ui/material_ui.dart';

import '../data/note_store.dart';
import '../models/tasting_note.dart';
import '../theme.dart';
import '../widgets/character_slider.dart';
import '../widgets/color_scale.dart';
import '../widgets/flavor_wheel.dart';
import '../widgets/note_photo.dart';
import '../widgets/sheet_section.dart';
import 'note_edit_screen.dart';

/// 저장된 노트를 PDF 양식처럼 보여주는 화면.
class NoteDetailScreen extends StatelessWidget {
  const NoteDetailScreen({
    super.key,
    required this.store,
    required this.noteId,
  });

  final NoteStore store;
  final String noteId;

  Future<void> _delete(BuildContext context, TastingNote note) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('노트 삭제'),
        content: Text('"${note.name}" 노트를 삭제할까요?\n삭제하면 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await store.delete(note.id);
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final note = store.byId(noteId);
        if (note == null) return const Scaffold();
        return Scaffold(
          appBar: AppBar(
            title: Text(note.name),
            actions: [
              IconButton(
                tooltip: '수정',
                icon: const Icon(Icons.edit),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        NoteEditScreen(store: store, original: note),
                  ),
                ),
              ),
              IconButton(
                tooltip: '삭제',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _delete(context, note),
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _header(note),
                if (note.color != null)
                  SheetSection(
                    title: '색상',
                    subtitle: 'Color',
                    child: ColorScalePicker(value: note.color),
                  ),
                SheetSection(
                  title: '향',
                  subtitle: 'Nose',
                  child: FlavorWheel(axes: aromaAxes, values: note.nose),
                ),
                SheetSection(
                  title: '맛',
                  subtitle: 'Palate',
                  child: FlavorWheel(
                    axes: palateAxes,
                    values: note.palate,
                    color: const Color(0xFFB0202A),
                  ),
                ),
                SheetSection(
                  title: '비후방 후각',
                  subtitle: 'Retronasal',
                  child: FlavorWheel(
                    axes: aromaAxes,
                    values: note.retronasal,
                    color: const Color(0xFF3F5E2E),
                  ),
                ),
                SheetSection(
                  title: '개성',
                  subtitle: 'Characters',
                  child: Column(
                    children: [
                      for (final s in characterScales)
                        CharacterSlider(
                          scale: s,
                          value: note.characters[s.key]!,
                        ),
                      const Divider(),
                      CharacterSlider(scale: finishScale, value: note.finish),
                    ],
                  ),
                ),
                if (note.overall.isNotEmpty)
                  SheetSection(
                    title: '총평',
                    subtitle: 'Overall',
                    child: Text(
                      note.overall,
                      style: const TextStyle(fontSize: 15, height: 1.4),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _header(TastingNote note) {
    final photo = store.storage.photoFile(note.photo);
    String? num(double? v, String unit) =>
        v == null ? null : '${v == v.roundToDouble() ? v.toInt() : v}$unit';
    final rows = <(String, String?)>[
      ('종류', note.type?.label),
      ('국가 / 지역', note.region),
      ('숙성 / 캐스크', note.ageCask),
      ('도수', num(note.abv, '%')),
      ('가격', note.price),
      ('작성일', _date(note.createdAt)),
    ];
    return SheetSection(
      title: 'Whiskey Tasting Note',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (photo != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(height: 260, child: NotePhoto(file: photo)),
            ),
          if (note.score != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                '${num(note.score, '')} / 100',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: NoteColors.leather,
                ),
              ),
            ),
          for (final (label, value) in rows)
            if (value != null && value.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 100,
                      child: Text(
                        label,
                        style: const TextStyle(color: NoteColors.hint),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        value,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
          if (note.color != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  const SizedBox(
                    width: 100,
                    child: Text('색상', style: TextStyle(color: NoteColors.hint)),
                  ),
                  Container(
                    width: 40,
                    height: 16,
                    color: whiskyColor(note.color!),
                  ),
                  const SizedBox(width: 8),
                  Text(note.color!.toStringAsFixed(1)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _date(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
}
