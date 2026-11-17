import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:whisky_note/data/app_settings.dart';
import 'package:whisky_note/data/backup.dart';
import 'package:whisky_note/data/note_store.dart';
import 'package:whisky_note/main.dart';
import 'package:whisky_note/models/tasting_note.dart';
import 'package:whisky_note/screens/note_list_screen.dart';

void main() {
  group('백업', () {
    test('노트와 사진을 zip으로 묶었다가 다른 폰(빈 저장소)에 그대로 복원한다', () async {
      final from = MemoryNoteStorage();
      final store = NoteStore(from);
      await from.writePhoto('h.png', [1, 2, 3]);
      await from.writePhoto('story.jpg', [4, 5]);
      await store.upsert(
        TastingNote(
          id: 'h',
          name: 'Hibiki',
          photo: 'h.png',
          score: 90,
          stories: [
            StoryEntry(
              id: 's',
              date: DateTime(2026, 11, 1),
              text: '첫날',
              photos: ['story.jpg'],
            ),
          ],
        ),
      );
      await store.upsert(
        TastingNote(id: 'e', name: 'Empty', emptiedAt: DateTime(2026)),
      );
      final zip = await BackupService(store).build(appVersion: '1.0.0');

      final to = MemoryNoteStorage();
      final other = NoteStore(to);
      await other.upsert(TastingNote(id: 'old', name: '사라질 병'));
      final summary = BackupService(other).inspect(zip);
      expect(summary.notes, 2);
      expect(summary.photos, 2);

      expect(await BackupService(other).restore(zip), 2);
      expect(other.byId('old'), isNull);
      expect(other.byId('h')!.score, 90);
      expect(other.byId('h')!.stories.single.text, '첫날');
      expect(other.memories.single.name, 'Empty');
      expect(to.photos['h.png'], [1, 2, 3]);
      expect(to.photos['story.jpg'], [4, 5]);
    });

    test('백업 파일이 아니면 알기 쉬운 오류', () {
      final store = NoteStore(MemoryNoteStorage());
      expect(
        () => BackupService(store).inspect(Uint8List.fromList([1, 2, 3])),
        throwsA(isA<BackupException>()),
      );
    });
  });

  testWidgets('처음 실행: 환영 화면 → 샘플로 둘러보기 → 진열장', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final settings = await AppSettings.load();
    final store = NoteStore(MemoryNoteStorage());
    await store.load(); // 앱도 시작 전에 기록을 읽습니다
    await tester.pumpWidget(WhiskyNoteApp(store: store, settings: settings));
    expect(find.text('첫 병 진열하기'), findsOneWidget);

    final samples = find.text('샘플 위스키로 둘러보기');
    await tester.ensureVisible(samples);
    await tester.pumpAndSettle();
    await tester.tap(samples);
    // 샘플을 넣는 동안 로딩 표시가 계속 돌아서 조금씩 시간을 진행시킵니다.
    for (
      var i = 0;
      i < 50 && find.byType(NoteListScreen).evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();

    expect(find.byType(NoteListScreen), findsOneWidget);
    expect(store.notes.length, 40);
    expect(settings.onboarded, isTrue);
  });

  testWidgets('기록이 이미 있으면 환영 화면을 건너뛴다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await AppSettings.load();
    final store = NoteStore(MemoryNoteStorage());
    await store.upsert(TastingNote(id: 'a', name: 'A'));
    await store.load();
    await tester.pumpWidget(WhiskyNoteApp(store: store, settings: settings));
    expect(find.byType(NoteListScreen), findsOneWidget);
  });
}
