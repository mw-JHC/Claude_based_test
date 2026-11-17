import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../models/tasting_note.dart';
import '../l10n/tr.dart';
import 'note_store.dart';

/// 백업 파일 안의 노트 목록 이름
const _notesEntry = 'whisky_notes.json';
const _photoDir = 'photos/';

/// 백업 파일이 잘못됐을 때
class BackupException implements Exception {
  const BackupException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 백업 내용 요약 (복원 전에 보여줌)
class BackupSummary {
  const BackupSummary({
    required this.notes,
    required this.photos,
    this.createdAt,
  });
  final int notes;
  final int photos;
  final DateTime? createdAt;
}

/// 모든 노트와 사진을 zip 파일 하나로 묶고, 다시 풀어 되돌립니다.
///
/// zip 안: whisky_notes.json (앱이 저장하는 것과 같은 형식) + photos/사진들
class BackupService {
  const BackupService(this.store);

  final NoteStore store;

  /// 백업 파일 내용을 만듭니다.
  Future<Uint8List> build({String appVersion = ''}) async {
    final archive = Archive();
    final notes = store.notes;
    final json = const JsonEncoder.withIndent('  ').convert({
      'app': 'Whisky Library',
      'appVersion': appVersion,
      'version': 1,
      'createdAt': DateTime.now().toIso8601String(),
      'notes': [for (final n in notes) n.toJson()],
    });
    archive.addFile(ArchiveFile.bytes(_notesEntry, utf8.encode(json)));
    for (final name in {for (final n in notes) ...n.files}) {
      final bytes = await store.storage.readPhoto(name);
      if (bytes != null) {
        archive.addFile(ArchiveFile.bytes('$_photoDir$name', bytes));
      }
    }
    return ZipEncoder().encodeBytes(archive);
  }

  /// 백업 파일을 읽어 요약만 보여줍니다 (아직 바꾸지 않음).
  BackupSummary inspect(Uint8List zip) {
    final (archive, data) = _open(zip);
    final photos = archive.files
        .where((f) => f.isFile && f.name.startsWith(_photoDir))
        .length;
    return BackupSummary(
      notes: (data['notes'] as List).length,
      photos: photos,
      createdAt: DateTime.tryParse(data['createdAt'] as String? ?? ''),
    );
  }

  /// 백업 파일로 지금 기록을 모두 바꿉니다. 복원한 노트 수를 돌려줍니다.
  Future<int> restore(Uint8List zip) async {
    final (archive, data) = _open(zip);
    final notes = [
      for (final e in data['notes'] as List)
        TastingNote.fromJson(Map<String, dynamic>.from(e as Map)),
    ];
    for (final f in archive.files) {
      if (!f.isFile || !f.name.startsWith(_photoDir)) continue;
      final name = f.name.substring(_photoDir.length);
      // 폴더를 벗어나는 이름은 무시 (../ 등)
      if (name.isEmpty || name.contains('/') || name.contains('..')) continue;
      await store.storage.writePhoto(name, f.content);
    }
    await store.replaceAll(notes);
    return notes.length;
  }

  (Archive, Map<String, dynamic>) _open(Uint8List zip) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(zip);
    } catch (_) {
      throw BackupException(
        tr(
          'Whisky Library 백업 파일(.zip)이 아니에요.',
          'This is not a Whisky Library backup (.zip).',
        ),
      );
    }
    final entry = archive.findFile(_notesEntry);
    if (entry == null) {
      throw BackupException(
        tr(
          '백업 파일 안에 위스키 기록이 없어요.',
          'The backup file contains no whisky notes.',
        ),
      );
    }
    try {
      final data =
          jsonDecode(utf8.decode(entry.content)) as Map<String, dynamic>;
      if (data['notes'] is! List) throw const FormatException();
      return (archive, data);
    } catch (_) {
      throw BackupException(tr('백업 파일이 손상됐어요.', 'The backup file is damaged.'));
    }
  }
}
