import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:whisky_note/data/note_store.dart';
import 'package:whisky_note/main.dart';
import 'package:whisky_note/models/tasting_note.dart';
import 'package:whisky_note/widgets/whisky_bottle.dart';

void main() {
  test('노트를 JSON으로 저장했다가 그대로 다시 읽을 수 있다', () {
    final note = TastingNote(
      id: '1',
      name: 'Lagavulin 16',
      type: WhiskyType.singleMalt,
      region: 'Scotland / Islay',
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

    final store = NoteStore(MemoryNoteStorage());
    await tester.pumpWidget(WhiskyNoteApp(store: store));
    await store.load();
    await tester.pump();
    expect(find.text('아직 기록한 위스키가 없습니다'), findsOneWidget);

    await tester.tap(find.text('Add Whisky'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, '이름 / Name *'),
      'Lagavulin 16',
    );
    await tester.tap(find.text('Single Malt'));
    await tester.tap(find.byTooltip('저장'));
    await tester.pumpAndSettle();

    expect(store.notes.single.type, WhiskyType.singleMalt);

    // 진열장: 병 라벨과 이름표에 이름이 보이고, 병을 누르면 노트가 열린다.
    expect(find.text('Lagavulin 16'), findsWidgets);
    await tester.tap(find.byType(WhiskyBottle));
    await tester.pumpAndSettle();
    expect(find.text('Whiskey Tasting Note'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // 목록 보기로 바꿀 수 있다.
    await tester.tap(find.byTooltip('목록으로 보기'));
    await tester.pumpAndSettle();
    expect(find.text('Single Malt'), findsOneWidget);
  });
}
