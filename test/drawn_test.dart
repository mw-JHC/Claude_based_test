import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:whisky_note/data/note_store.dart';
import 'package:whisky_note/models/tasting_note.dart';
import 'package:whisky_note/screens/note_edit_screen.dart';
import 'package:whisky_note/services/bottle_scanner.dart';
import 'package:whisky_note/services/label_parser.dart';
import 'package:whisky_note/widgets/whisky_bottle.dart';

/// 배경 제거가 되는 척하는 스캐너 (라벨은 못 읽음).
/// [failFirst]만큼은 실패합니다 (폰에서 모듈을 내려받는 중인 상황).
class _CutoutScanner implements BottleScanner {
  _CutoutScanner({this.failFirst = 0});
  int failFirst;

  @override
  Future<Uint8List?> cutout(String imagePath) async =>
      failFirst-- > 0 ? null : Uint8List.fromList([1]);

  @override
  Future<List<OcrLine>> readText(String imagePath) async => const [];
}

void main() {
  test('그린 병 선택은 저장했다가 다시 읽어도 남는다', () {
    final n = TastingNote(id: 'a', photo: 'p.jpg', drawn: true);
    expect(TastingNote.fromJson(n.toJson()).drawn, isTrue);
    expect(TastingNote.fromJson(TastingNote(id: 'b').toJson()).drawn, isFalse);
  });

  testWidgets('그린 병을 고르면 사진이 있어도 그린 병을 보여준다', (tester) async {
    final image = MemoryImage(Uint8List.fromList([1]));
    Future<void> show(bool drawn) => tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: BottleFigure(
          note: TastingNote(id: 'a', name: 'Test', drawn: drawn),
          cutout: image,
          photo: image,
          height: 150,
        ),
      ),
    );
    await show(true);
    expect(find.byType(WhiskyBottle), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    await show(false);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('사진을 찍은 뒤 병만/원본/그린 병 중에서 고른다', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: NoteEditScreen(
          store: NoteStore(MemoryNoteStorage()),
          scanner: _CutoutScanner(),
        ),
      ),
    );
    final state = tester.state(find.byType(NoteEditScreen)) as dynamic;
    await tester.runAsync(() => state.usePhotoForTest('/tmp/x.jpg') as Future);
    await tester.pump();

    expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    final drawn = find.byIcon(Icons.brush_outlined);
    await tester.ensureVisible(drawn);
    await tester.tap(drawn);
    await tester.pump();
    expect(find.byType(WhiskyBottle), findsOneWidget);
  });

  testWidgets('배경 제거가 처음에 실패해도 병만 버튼으로 다시 할 수 있다', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: NoteEditScreen(
          store: NoteStore(MemoryNoteStorage()),
          scanner: _CutoutScanner(failFirst: 1),
        ),
      ),
    );
    final state = tester.state(find.byType(NoteEditScreen)) as dynamic;
    await tester.runAsync(() => state.usePhotoForTest('/tmp/x.jpg') as Future);
    await tester.pump();

    // 실패했어도 세 가지가 모두 보인다
    final cutout = find.byIcon(Icons.auto_awesome);
    expect(cutout, findsOneWidget);
    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    expect(find.byIcon(Icons.brush_outlined), findsOneWidget);
    expect(
      find.textContaining(RegExp('배경을 지운 실제 병|background removed')),
      findsNothing,
    );

    await tester.ensureVisible(cutout);
    await tester.runAsync(() async {
      await tester.tap(cutout);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    expect(
      find.textContaining(RegExp('배경을 지운 실제 병|background removed')),
      findsOneWidget,
    );
  });
}
