import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart' show FileImage, ImageProvider;
import 'package:path_provider/path_provider.dart';

import '../models/tasting_note.dart';

/// 노트와 사진을 실제로 저장하는 곳.
abstract class NoteStorage {
  Future<List<TastingNote>> loadAll();
  Future<void> saveAll(List<TastingNote> notes);

  /// 고른 사진을 앱 저장소로 복사하고, 저장된 파일 이름을 돌려줍니다.
  Future<String> importPhoto(String sourcePath, String noteId);

  /// 병만 오려낸 PNG 같은 메모리 속 이미지를 저장하고, 파일 이름을 돌려줍니다.
  Future<String> importBytes(Uint8List bytes, String noteId, String ext);
  Future<void> deletePhoto(String name);

  /// 저장된 사진을 화면에 그릴 수 있는 형태로 돌려줍니다.
  ImageProvider? image(String? name);
}

/// 폰의 앱 전용 폴더에 JSON 파일과 사진을 저장합니다.
/// 앱을 삭제하면 같이 지워집니다.
class FileNoteStorage implements NoteStorage {
  FileNoteStorage._(this._root);

  static Future<FileNoteStorage> open() async =>
      FileNoteStorage._(await getApplicationDocumentsDirectory());

  final Directory _root;

  File get _notesFile => File('${_root.path}/whisky_notes.json');
  Directory get _photoDir => Directory('${_root.path}/photos');

  @override
  Future<List<TastingNote>> loadAll() async {
    if (!await _notesFile.exists()) return [];
    final raw = jsonDecode(await _notesFile.readAsString()) as Map;
    return (raw['notes'] as List)
        .map((e) => TastingNote.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  @override
  Future<void> saveAll(List<TastingNote> notes) async {
    // 임시 파일에 먼저 쓰고 바꿔치기해서, 저장 중에 앱이 꺼져도 파일이 깨지지 않게 합니다.
    final tmp = File('${_notesFile.path}.tmp');
    await tmp.writeAsString(
      const JsonEncoder.withIndent(
        '  ',
      ).convert({'version': 1, 'notes': notes.map((n) => n.toJson()).toList()}),
      flush: true,
    );
    await tmp.rename(_notesFile.path);
  }

  @override
  Future<String> importPhoto(String sourcePath, String noteId) async {
    await _photoDir.create(recursive: true);
    final dot = sourcePath.lastIndexOf('.');
    final ext = dot >= 0 ? sourcePath.substring(dot) : '.jpg';
    final name = '${noteId}_${DateTime.now().millisecondsSinceEpoch}$ext';
    await File(sourcePath).copy('${_photoDir.path}/$name');
    return name;
  }

  @override
  Future<String> importBytes(Uint8List bytes, String noteId, String ext) async {
    await _photoDir.create(recursive: true);
    final name = '${noteId}_${DateTime.now().millisecondsSinceEpoch}$ext';
    await File('${_photoDir.path}/$name').writeAsBytes(bytes, flush: true);
    return name;
  }

  @override
  Future<void> deletePhoto(String name) async {
    final f = File('${_photoDir.path}/$name');
    if (await f.exists()) await f.delete();
  }

  @override
  ImageProvider? image(String? name) =>
      name == null ? null : FileImage(File('${_photoDir.path}/$name'));
}

/// 테스트용: 메모리에만 저장합니다.
class MemoryNoteStorage implements NoteStorage {
  final List<Map<String, dynamic>> _saved = [];

  @override
  Future<List<TastingNote>> loadAll() async =>
      _saved.map(TastingNote.fromJson).toList();

  @override
  Future<void> saveAll(List<TastingNote> notes) async {
    _saved
      ..clear()
      ..addAll(notes.map((n) => n.toJson()));
  }

  @override
  Future<String> importPhoto(String sourcePath, String noteId) async =>
      sourcePath;

  @override
  Future<String> importBytes(
    Uint8List bytes,
    String noteId,
    String ext,
  ) async => '$noteId$ext';

  @override
  Future<void> deletePhoto(String name) async {}

  @override
  ImageProvider? image(String? name) => null;
}

/// 앱 전체에서 공유하는 노트 목록.
class NoteStore extends ChangeNotifier {
  NoteStore(this.storage);

  final NoteStorage storage;
  final List<TastingNote> _notes = [];
  bool loaded = false;

  /// 최근에 수정한 노트가 위로 오도록 정렬된 목록.
  List<TastingNote> get notes => List.unmodifiable(
    [..._notes]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
  );

  TastingNote? byId(String id) {
    for (final n in _notes) {
      if (n.id == id) return n;
    }
    return null;
  }

  Future<void> load() async {
    _notes
      ..clear()
      ..addAll(await storage.loadAll());
    loaded = true;
    notifyListeners();
  }

  /// 새 노트는 추가하고, 같은 id가 있으면 덮어씁니다.
  Future<void> upsert(TastingNote note) async {
    note.updatedAt = DateTime.now();
    final i = _notes.indexWhere((n) => n.id == note.id);
    final old = i >= 0 ? _notes[i] : null;
    if (i >= 0) {
      _notes[i] = note;
    } else {
      _notes.add(note);
    }
    await storage.saveAll(_notes);
    // 바뀐 사진은 지웁니다.
    for (final (before, after) in [
      (old?.photo, note.photo),
      (old?.cutout, note.cutout),
    ]) {
      if (before != null && before != after) await storage.deletePhoto(before);
    }
    notifyListeners();
  }

  Future<void> delete(String id) async {
    final note = byId(id);
    if (note == null) return;
    _notes.remove(note);
    await storage.saveAll(_notes);
    for (final name in [note.photo, note.cutout]) {
      if (name != null) await storage.deletePhoto(name);
    }
    notifyListeners();
  }
}
