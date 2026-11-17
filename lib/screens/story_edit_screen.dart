import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../data/note_store.dart';
import '../models/tasting_note.dart';
import '../theme.dart';
import '../widgets/sheet_section.dart';
import '../l10n/tr.dart';

/// 병 하나에 이야기 한 편을 쓰거나 고칩니다.
/// 그날의 맛, 함께한 사람, 사진을 날짜와 함께 남깁니다.
class StoryEditScreen extends StatefulWidget {
  const StoryEditScreen({
    super.key,
    required this.store,
    required this.note,
    this.story,
  });

  final NoteStore store;
  final TastingNote note;

  /// 고칠 이야기. null이면 새 이야기.
  final StoryEntry? story;

  @override
  State<StoryEditScreen> createState() => _StoryEditScreenState();
}

/// 화면에 보여줄 사진: 이미 저장된 것(name) 또는 새로 고른 것(path).
class _Photo {
  const _Photo.saved(this.name) : path = null;
  const _Photo.picked(this.path) : name = null;
  final String? name;
  final String? path;
}

class _StoryEditScreenState extends State<StoryEditScreen> {
  late final StoryEntry _story = widget.story?.copy() ?? StoryEntry.create();
  late final _text = TextEditingController(text: _story.text);
  late final _with = TextEditingController(text: _story.companions);
  late final List<_Photo> _photos = [
    for (final p in _story.photos) _Photo.saved(p),
  ];
  bool _saving = false;

  bool get _isNew => widget.story == null;

  @override
  void dispose() {
    _text.dispose();
    _with.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _story.date,
      firstDate: DateTime(1990),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (d != null) setState(() => _story.date = d);
  }

  Future<void> _addPhotos(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = source == ImageSource.gallery
          ? await picker.pickMultiImage(maxWidth: 2000, imageQuality: 88)
          : [
              ?await picker.pickImage(
                source: source,
                maxWidth: 2000,
                imageQuality: 88,
              ),
            ];
      setState(() => _photos.addAll(picked.map((x) => _Photo.picked(x.path))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('사진을 가져오지 못했습니다: $e', 'Could not load the photo: $e'),
          ),
        ),
      );
    }
  }

  Future<void> _save() async {
    if (_text.text.trim().isEmpty && _photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              '이야기나 사진을 하나 이상 남겨 주세요.',
              'Add some text or at least one photo.',
            ),
          ),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    final storage = widget.store.storage;
    final note = widget.note.copy();
    _story
      ..text = _text.text.trim()
      ..companions = _with.text.trim();
    _story.photos
      ..clear()
      ..addAll([
        for (final p in _photos)
          p.name ?? await storage.importPhoto(p.path!, note.id),
      ]);
    final i = note.stories.indexWhere((s) => s.id == _story.id);
    if (i >= 0) {
      note.stories[i] = _story;
    } else {
      note.stories.add(_story);
    }
    await widget.store.upsert(note);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('이야기 삭제', 'Delete story')),
        content: Text(
          tr('이 이야기와 사진을 지울까요?', 'Delete this story and its photos?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(tr('취소', 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(
              tr('삭제', 'Delete'),
              style: TextStyle(color: Color(0xFFE0605E)),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final note = widget.note.copy();
    note.stories.removeWhere((s) => s.id == _story.id);
    await widget.store.upsert(note);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Add Story' : 'Edit Story'),
        actions: [
          if (!_isNew)
            IconButton(
              tooltip: tr('이야기 삭제', 'Delete story'),
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.check),
            label: Text(tr('이야기 저장', 'Save story')),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Text(
            widget.note.name,
            style: const TextStyle(
              fontFamily: serif,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: NoteColors.text,
            ),
          ),
          const SizedBox(height: 14),
          SheetSection(
            title: tr('그날', 'Day'),
            subtitle: 'Day',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.event, size: 18),
                  label: Text(storyDate(_story.date)),
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _with,
                  decoration: InputDecoration(
                    label: inputLabel('함께한 사람', 'With'),
                    prefixIcon: const Icon(Icons.people_outline, size: 20),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _text,
                  minLines: 5,
                  maxLines: null,
                  decoration: InputDecoration(
                    hintText: tr(
                      '그날의 맛, 분위기, 기억하고 싶은 이야기 …',
                      'How it tasted, the mood, what you want to remember …',
                    ),
                  ),
                ),
              ],
            ),
          ),
          SheetSection(
            title: tr('사진', 'Photos'),
            subtitle: 'Photos',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_photos.isNotEmpty) ...[
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    children: [
                      for (var i = 0; i < _photos.length; i++) _tile(i),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _addPhotos(ImageSource.camera),
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: Text(tr('촬영', 'Camera')),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _addPhotos(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text(tr('갤러리', 'Gallery')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(int i) {
    final p = _photos[i];
    final image = p.path != null
        ? FileImage(File(p.path!))
        : widget.store.storage.image(p.name);
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: image == null
              ? Container(color: NoteColors.surfaceHigh)
              : Image(image: image, fit: BoxFit.cover),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: IconButton(
            tooltip: tr('사진 빼기', 'Remove photo'),
            visualDensity: VisualDensity.compact,
            onPressed: () => setState(() => _photos.removeAt(i)),
            icon: const Icon(Icons.close, size: 16),
            style: IconButton.styleFrom(
              backgroundColor: NoteColors.bg.withValues(alpha: 0.7),
              foregroundColor: NoteColors.text,
            ),
          ),
        ),
      ],
    );
  }
}

/// 이야기 날짜 (예: 2026.11.20 (금) / Fri, Nov 20, 2026)
String storyDate(DateTime d) => tr.dateWithDay(d);
