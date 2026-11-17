import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:whisky_note/data/app_settings.dart';
import 'package:whisky_note/data/note_store.dart';
import 'package:whisky_note/main.dart';
import 'package:whisky_note/models/tasting_note.dart';
import 'package:whisky_note/screens/note_detail_screen.dart';
import 'package:whisky_note/widgets/cabinet_view.dart';
import 'package:whisky_note/widgets/flavor_wheel.dart';
import 'package:whisky_note/widgets/whisky_bottle.dart';

void main() {
  test('노트를 JSON으로 저장했다가 그대로 다시 읽을 수 있다', () {
    final note = TastingNote(
      id: '1',
      name: 'Lagavulin 16',
      type: WhiskyType.singleMalt,
      origin: WhiskyOrigin.scotland,
      subRegion: 'Islay',
      abv: 43,
      score: 92,
      color: 1.3,
      nose: [1, 2, 3, 4, 9, 5, 6, 7],
      palate: [5, 2, 6, 3, 4, 2],
      characters: {'dryOily': 7},
      finish: 9,
    );
    final back = TastingNote.fromJson(note.toJson());
    expect(back.toJson(), note.toJson());
    expect(back.characters['dryOily'], 7);
    expect(back.characters['lightHeavy'], scaleDefault);
  });

  test('축 개수가 맞지 않거나 범위를 벗어난 값은 보정된다', () {
    final n = TastingNote(id: 'x', nose: [20, -3]);
    expect(n.nose.length, aromaAxes.length);
    expect(n.nose.take(3), [radarMax, 0, 0]);
  });

  testWidgets('새 노트를 작성하면 목록에 나타난다', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    // 환영 화면은 이미 본 것으로
    SharedPreferences.setMockInitialValues({'onboarded': true});
    final settings = await AppSettings.load();
    final store = NoteStore(MemoryNoteStorage());
    await tester.pumpWidget(WhiskyNoteApp(store: store, settings: settings));
    await store.load();
    await tester.pump();
    expect(find.text('아직 기록한 위스키가 없습니다'), findsOneWidget);

    await tester.tap(find.byTooltip('Add Whisky'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Lagavulin 16');
    await tester.tap(find.text('Single Malt'));
    await tester.tap(find.byTooltip('저장'));
    await tester.pumpAndSettle();

    expect(store.notes.single.type, WhiskyType.singleMalt);

    // 진열장: 병 라벨과 이름표에 이름이 보이고, 병을 누르면 노트가 열린다.
    expect(find.text('Lagavulin 16'), findsWidgets);
    await tester.tap(find.byType(WhiskyBottle));
    await tester.pumpAndSettle();
    expect(find.byType(NoteDetailScreen), findsOneWidget);
    await tester.tap(find.byTooltip('뒤로'));
    await tester.pumpAndSettle();

    // 목록 보기로 바꿀 수 있다.
    await tester.tap(find.byTooltip('목록으로 보기'));
    await tester.pumpAndSettle();
    expect(find.text('SINGLE MALT'), findsOneWidget);
    await tester.tap(find.byTooltip('진열장으로 보기'));
    await tester.pumpAndSettle();

    // 설정에서 진열장 분위기를 바꾸면 저장되고 바로 반영된다.
    await tester.tap(find.byTooltip('설정'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('박물관 유리 케이스'));
    await tester.pumpAndSettle();
    expect(settings.cabinetStyle, CabinetStyle.museum);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('cabinetStyle'), 'museum');
    await tester.pageBack();
    await tester.pumpAndSettle();
    // 박물관 케이스는 받침대에 비친 반사까지 그려서 병이 두 번 나온다 (첫 번째가 실제 병).
    await tester.tap(find.byType(WhiskyBottle).first);
    await tester.pumpAndSettle();
    expect(find.byType(NoteDetailScreen), findsOneWidget);
  });

  testWidgets('(?)를 누르면 예시가 나오고 값은 바뀌지 않는다', (tester) async {
    final values = List<int>.filled(aromaAxes.length, 0);
    var changed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 380,
            child: FlavorWheel(
              axes: aromaAxes,
              values: values,
              onChanged: (_, _) => changed = true,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.help_outline).at(4)); // 4번 축 = 이탄
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('요오드'), findsOneWidget);
    expect(changed, isFalse);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('맛 차트에는 (?) 버튼 없이 숫자만 나온다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 380,
            child: FlavorWheel(axes: palateAxes, values: [3, 0, 0, 0, 0, 7]),
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.help_outline), findsNothing);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
  });

  test('예전 형식(종류 Bourbon, 자유 입력 지역)을 산지로 옮긴다', () {
    TastingNote old(Map<String, dynamic> extra) =>
        TastingNote.fromJson({'id': 'x', 'name': 'n', ...extra});

    final bourbon = old({'type': 'bourbon', 'region': 'USA / Kentucky'});
    expect(bourbon.type, isNull);
    expect(bourbon.origin, WhiskyOrigin.american);
    expect(bourbon.subRegion, 'Bourbon');

    final islay = old({'type': 'singleMalt', 'region': 'Scotland / Islay'});
    expect(islay.type, WhiskyType.singleMalt);
    expect(islay.regionLabel, 'Scotland · Islay');

    final japan = old({'type': 'japanese', 'region': ''});
    expect(japan.origin, WhiskyOrigin.japanese);

    final other = old({'type': 'world', 'region': 'Germany / Bavaria'});
    expect(other.origin, WhiskyOrigin.world);
    expect(other.subRegion, 'Germany');

    final free = old({'region': '스웨덴 어딘가'});
    expect(free.origin, WhiskyOrigin.world);
    expect(free.subRegion, '스웨덴 어딘가');

    // 새 형식으로 저장한 것은 그대로 읽는다.
    final again = TastingNote.fromJson(islay.toJson());
    expect(again.regionLabel, 'Scotland · Islay');
  });

  testWidgets('병이 많으면 진열장이 여러 칸으로 나뉘고 옆으로 넘긴다', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final store = NoteStore(MemoryNoteStorage());
    final notes = [
      for (var i = 0; i < 30; i++) TastingNote(id: '$i', name: 'Bottle $i'),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CabinetView(store: store, notes: notes, onOpen: (_) {}),
        ),
      ),
    );
    expect(find.textContaining('1/'), findsOneWidget);
    expect(find.text('Bottle 0'), findsWidgets);
    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1500);
    await tester.pumpAndSettle();
    expect(find.textContaining('2/'), findsOneWidget);
  });

  for (final style in CabinetStyle.values) {
    testWidgets('진열장(${style.label})에서 병을 길게 눌러 끌면 자리가 바뀐다', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      final store = NoteStore(MemoryNoteStorage());
      final notes = [
        for (final n in ['A', 'B', 'C']) TastingNote(id: n, name: n),
      ];
      List<String>? order;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CabinetView(
              store: store,
              notes: notes,
              style: style,
              onOpen: (_) {},
              onReorder: (ids) => order = ids,
            ),
          ),
        ),
      );
      // 끌 수 있는 병 (거울/유리 반사는 제외됨)
      final bottles = find.byType(LongPressDraggable<String>);
      expect(bottles, findsNWidgets(3));
      final a = tester.getCenter(bottles.at(0));
      final c = tester.getCenter(bottles.at(2));
      final gesture = await tester.startGesture(a);
      await tester.pump(const Duration(milliseconds: 600)); // 길게 누르기
      for (var t = 1; t <= 10; t++) {
        await gesture.moveTo(Offset.lerp(a, c, t / 10)!);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(order, ['B', 'C', 'A']);
    });
  }
}
