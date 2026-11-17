import 'dart:convert';
import 'dart:math' as math;
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

  /// 진열장 순서대로 정렬된 목록 (끌어서 바꾼 순서).
  List<TastingNote> get notes =>
      List<TastingNote>.unmodifiable(<TastingNote>[..._notes]..sort(_byOrder));

  static int _byOrder(TastingNote a, TastingNote b) {
    final c = a.order.compareTo(b.order);
    return c != 0 ? c : b.updatedAt.compareTo(a.updatedAt);
  }

  /// 진열장에 있는 (아직 비우지 않은) 병들
  List<TastingNote> get library => notes.where((n) => !n.isEmpty).toList();

  /// Memory Library의 빈 병들. 최근에 비운 병부터.
  List<TastingNote> get memories =>
      _notes.where((n) => n.isEmpty).toList()
        ..sort((a, b) => b.emptiedAt!.compareTo(a.emptiedAt!));

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
    // 순서가 없던 예전 노트는 최근 수정 순으로 자리를 매깁니다.
    final sorted = [..._notes]..sort(_byOrder);
    for (var i = 0; i < sorted.length; i++) {
      sorted[i].order = i;
    }
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
      // 새 병은 진열장 맨 앞에 놓습니다.
      note.order = _notes.isEmpty
          ? 0
          : _notes.map((n) => n.order).reduce(math.min) - 1;
      _notes.add(note);
    }
    await storage.saveAll(_notes);
    // 더 이상 쓰지 않는 사진(바꾸거나 지운 사진)은 지웁니다.
    if (old != null) {
      for (final name in old.files.difference(note.files)) {
        await storage.deletePhoto(name);
      }
    }
    notifyListeners();
  }

  /// 끌어서 놓은 새 순서. [ids]는 화면에 보이던 병들(필터가 걸렸으면 그 일부)이고,
  /// 그 병들이 차지하던 자리 번호를 새 순서대로 다시 나눠 줍니다.
  Future<void> reorder(List<String> ids) async {
    final picked = [for (final id in ids) ?byId(id)];
    final slots = picked.map((n) => n.order).toList()..sort();
    for (var i = 0; i < picked.length; i++) {
      picked[i].order = slots[i];
    }
    await storage.saveAll(_notes);
    notifyListeners();
  }

  Future<void> delete(String id) async {
    final note = byId(id);
    if (note == null) return;
    _notes.remove(note);
    await storage.saveAll(_notes);
    for (final name in note.files) {
      await storage.deletePhoto(name);
    }
    notifyListeners();
  }
}
