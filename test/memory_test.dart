import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:whisky_note/data/note_store.dart';
import 'package:whisky_note/data/sample_data.dart';
import 'package:whisky_note/models/tasting_note.dart';
import 'package:whisky_note/screens/note_detail_screen.dart';
import 'package:whisky_note/screens/stats_screen.dart';

/// 지운 사진을 기억하는 저장소.
class TrackingStorage extends MemoryNoteStorage {
  final deleted = <String>[];

  @override
  Future<void> deletePhoto(String name) async => deleted.add(name);
}

void main() {
  test('예전 색상 값(0~2)은 0~1로 바뀌고, 새 값은 그대로', () {
    final old = TastingNote.fromJson({'id': 'a', 'color': 1.2});
    expect(old.color, closeTo(0.6, 1e-9));
    final again = TastingNote.fromJson(old.toJson());
    expect(again.color, closeTo(0.6, 1e-9));
  });

  test('이야기와 빈 병 날짜를 저장했다가 다시 읽는다', () {
    final n = TastingNote(
      id: 'h',
      name: 'Hibiki',
      emptiedAt: DateTime(2026, 11, 20),
      stories: [
        StoryEntry(
          id: 's1',
          date: DateTime(2026, 11, 1),
          text: '첫날',
          companions: '아내',
          photos: ['p1.jpg'],
        ),
        StoryEntry(id: 's2', date: DateTime(2026, 11, 10), text: '둘째 날'),
      ],
    );
    final back = TastingNote.fromJson(n.toJson());
    expect(back.isEmpty, isTrue);
    expect(back.storiesByDate.map((s) => s.text), ['둘째 날', '첫날']);
    expect(back.stories.first.companions, '아내');
    expect(back.files, {'p1.jpg'});
  });

  test('이야기를 지우면 그 사진 파일도 지운다', () async {
    final storage = TrackingStorage();
    final store = NoteStore(storage);
    final n = TastingNote(
      id: 'h',
      name: 'Hibiki',
      stories: [
        StoryEntry(id: 's1', date: DateTime(2026), photos: ['a.jpg', 'b.jpg']),
      ],
    );
    await store.upsert(n);
    final edited = n.copy()..stories.clear();
    await store.upsert(edited);
    expect(storage.deleted, unorderedEquals(['a.jpg', 'b.jpg']));
  });

  testWidgets('병 비우기: 진열장에서 Memory Library로 옮기고, 되돌릴 수 있다', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final store = NoteStore(MemoryNoteStorage());
    await store.upsert(TastingNote(id: 'h', name: 'Hibiki'));
    await tester.pumpWidget(
      MaterialApp(
        home: NoteDetailScreen(store: store, noteId: 'h'),
      ),
    );

    final empty = find.text('병 비우기 (Empty)');
    await tester.scrollUntilVisible(empty, 300);
    await tester.ensureVisible(empty);
    await tester.pumpAndSettle();
    await tester.tap(empty);
    await tester.pumpAndSettle();
    await tester.tap(find.text('비우기'));
    await tester.pumpAndSettle();

    expect(store.library, isEmpty);
    expect(store.memories.single.name, 'Hibiki');
    // 노트는 그대로 남아 있다.
    expect(store.byId('h'), isNotNull);

    final restore = find.text('다시 진열장에 놓기');
    await tester.ensureVisible(restore);
    await tester.pumpAndSettle();
    await tester.tap(restore);
    await tester.pumpAndSettle();
    expect(store.library.single.name, 'Hibiki');
    expect(store.memories, isEmpty);
  });

  testWidgets('이야기가 날짜와 함께 보인다', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final store = NoteStore(MemoryNoteStorage());
    await store.upsert(
      TastingNote(
        id: 'h',
        name: 'Hibiki',
        stories: [
          StoryEntry(
            id: 's',
            date: DateTime(2026, 11, 20),
            text: '눈 오는 날 한 잔',
            companions: '친구들',
          ),
        ],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: NoteDetailScreen(store: store, noteId: 'h'),
      ),
    );
    final text = find.text('눈 오는 날 한 잔');
    await tester.scrollUntilVisible(text, 300);
    expect(text, findsOneWidget);
    expect(find.text('2026.11.20 (금)'), findsOneWidget);
    expect(find.text('친구들'), findsOneWidget);
    expect(find.text('Add Story'), findsOneWidget);
  });

  testWidgets('통계: 진열 중 / 비운 병 수와 산지별 막대', (tester) async {
    final store = NoteStore(MemoryNoteStorage());
    await store.upsert(
      TastingNote(id: 'a', name: 'A', origin: WhiskyOrigin.scotland),
    );
    await store.upsert(
      TastingNote(id: 'b', name: 'B', origin: WhiskyOrigin.scotland),
    );
    await store.upsert(
      TastingNote(
        id: 'c',
        name: 'C',
        origin: WhiskyOrigin.japanese,
        emptiedAt: DateTime(2026),
      ),
    );
    await tester.pumpWidget(MaterialApp(home: StatsScreen(store: store)));
    expect(find.text('진열 중'), findsOneWidget);
    expect(find.text('2'), findsOneWidget); // 진열 중 2병
    expect(find.text('Scotland'), findsOneWidget);
    expect(find.text('2병  100%'), findsWidgets); // 산지와 종류(미입력) 막대
    expect(find.text('Japanese'), findsNothing); // 진열장에는 없음
    await tester.tap(find.text('Memory'));
    await tester.pumpAndSettle();
    expect(find.text('Japanese'), findsOneWidget); // 비운 병 산지
    await tester.tap(find.text('Total'));
    await tester.pumpAndSettle();
    expect(find.text('Scotland'), findsOneWidget);
    expect(find.text('Japanese'), findsOneWidget);
  });

  testWidgets('순위: 같은 점수는 공동 순위, 1위 → 10위 → 전체로 펼친다', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final store = NoteStore(MemoryNoteStorage());
    // 점수: 95, 90, 90, 85, 80 … (12병)
    final scores = <double>[95, 90, 90, 85, 80, 79, 78, 77, 76, 75, 74, 73];
    for (final (i, sc) in scores.indexed) {
      await store.upsert(TastingNote(id: '$i', name: 'W$i', score: sc));
    }
    await store.upsert(TastingNote(id: 'x', name: 'NoScore'));
    await tester.pumpWidget(MaterialApp(home: StatsScreen(store: store)));

    // 처음에는 1위만
    expect(find.text('W0'), findsOneWidget);
    expect(find.text('W1'), findsNothing);

    await tester.tap(find.byTooltip('10위까지 보기'));
    await tester.pumpAndSettle();
    expect(find.text('W1'), findsOneWidget);
    expect(find.text('W2'), findsOneWidget);
    expect(find.text('공동'), findsNWidgets(2)); // 90점 두 병은 공동 2위
    expect(find.text('4'), findsOneWidget); // 다음은 3위가 아니라 4위
    expect(find.text('W10'), findsNothing); // 11위는 아직 안 보임

    await tester.tap(find.textContaining('전체 12병'));
    await tester.pumpAndSettle();
    expect(find.text('W11'), findsOneWidget);
    expect(find.text('NoScore'), findsNothing); // 점수 없는 병은 순위에서 빠짐
  });

  test('순서 바꾸기: 필터로 일부만 보일 때도 그 병들끼리 자리를 바꾼다', () async {
    final store = NoteStore(MemoryNoteStorage());
    for (final id in ['d', 'c', 'b', 'a']) {
      await store.upsert(TastingNote(id: id, name: id));
    }
    // 새 병은 맨 앞이라 a, b, c, d 순서
    expect(store.notes.map((n) => n.id), ['a', 'b', 'c', 'd']);
    // b와 d만 보이는 상태에서 d를 b 앞으로
    await store.reorder(['d', 'b']);
    expect(store.notes.map((n) => n.id), ['a', 'd', 'c', 'b']);
  });

  test('샘플 40병을 넣고, 샘플만 지운다', () async {
    final store = NoteStore(MemoryNoteStorage());
    await store.upsert(TastingNote(id: 'mine', name: '내 위스키'));
    expect(await addSampleWhiskies(store), 40);
    expect(store.notes.length, 41);
    expect(store.memories.length, 8);
    expect(store.notes.where((n) => n.stories.isNotEmpty), isNotEmpty);
    // 진열장 순서가 샘플 목록 순서
    expect(store.library.first.name, 'Glenfiddich 18');
    expect(await removeSampleWhiskies(store), 40);
    expect(store.notes.single.id, 'mine');
  });
}
