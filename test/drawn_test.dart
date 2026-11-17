import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:whisky_note/data/note_store.dart';
import 'package:whisky_note/models/tasting_note.dart';
import 'package:whisky_note/screens/note_edit_screen.dart';
import 'package:whisky_note/services/bottle_scanner.dart';
import 'package:whisky_note/services/label_parser.dart';
import 'package:whisky_note/widgets/whisky_bottle.dart';

/// 배경 제거가 되는 척하는 스캐너 (라벨은 못 읽음)
class _CutoutScanner implements BottleScanner {
  @override
  Future<Uint8List?> cutout(String imagePath) async => Uint8List.fromList([1]);

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
}
