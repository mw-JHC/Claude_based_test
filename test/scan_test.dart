import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_subject_segmentation/google_mlkit_subject_segmentation.dart';
import 'package:material_ui/material_ui.dart';

import 'package:whisky_note/data/note_store.dart';
import 'package:whisky_note/models/tasting_note.dart';
import 'package:whisky_note/screens/note_edit_screen.dart';
import 'package:whisky_note/services/bottle_scanner.dart';
import 'package:whisky_note/services/label_parser.dart';

/// 실제 병 사진 3장에서 나올 법한 라벨 글자 (글자, 글자 높이).
const slyrs = [
  OcrLine('SLYRS', 30),
  OcrLine('Bavarian Whisky Distillery', 6),
  OcrLine('L A11089', 8),
  OcrLine('SLYRS', 90),
  OcrLine('BAVARIAN', 40),
  OcrLine('SINGLE MALT', 22),
  OcrLine('WHISKY', 22),
];
const glenfiddich = [
  OcrLine('PRODUCT OF THE GLEN', 14),
  OcrLine('Glenfiddich.', 48),
  OcrLine('SINGLE MALT SCOTCH WHISKY', 14),
  OcrLine('AGED 16 YEARS', 16),
  OcrLine('FORMULA ONE TEAM', 8),
];
const oban = [
  OcrLine('OBAN', 18),
  OcrLine('1794', 16),
  OcrLine('OBAN', 40),
  OcrLine('14', 70),
  OcrLine('WEST HIGHLAND', 10),
  OcrLine('SINGLE MALT', 12),
  OcrLine('SCOTCH WHISKY', 12),
];

class FakeScanner implements BottleScanner {
  FakeScanner(this.lines, {this.cutoutBytes});
  final List<OcrLine> lines;
  final Uint8List? cutoutBytes;

  @override
  Future<Uint8List?> cutout(String imagePath) async => cutoutBytes;

  @override
  Future<List<OcrLine>> readText(String imagePath) async => lines;
}

void main() {
  group('라벨 읽기', () {
    test('SLYRS: 가장 큰 글자가 이름, 로트 번호는 무시', () {
      final g = parseLabel(slyrs);
      expect(g.name, 'SLYRS');
      expect(g.age, isNull);
      expect(g.type, WhiskyType.singleMalt);
      expect(g.origin, WhiskyOrigin.world);
      expect(g.subRegion, 'Germany');
      expect(g.words, isNot(contains('L A11089')));
      expect(g.words.where((w) => w == 'SLYRS').length, 1);
    });

    test('Glenfiddich: "AGED 16 YEARS"에서 숙성 연수, 끝의 점은 뗌', () {
      final g = parseLabel(glenfiddich);
      expect(g.name, 'Glenfiddich 16');
      expect(g.age, 16);
      expect(g.origin, WhiskyOrigin.scotland);
      expect(g.subRegion, '');
    });

    test('Oban: 크게 쓰인 숫자 14는 숙성 연수, 1794는 아님', () {
      final g = parseLabel(oban);
      expect(g.name, 'OBAN 14');
      expect(g.origin, WhiskyOrigin.scotland);
      expect(g.subRegion, 'Highland');
    });

    test('글자가 없으면 빈 추측', () {
      expect(parseLabel(const []).isEmpty, isTrue);
    });
  });

  test('여러 물체 중 세로로 긴 큰 물체(병)를 고른다', () {
    final cup = Subject(
      startX: 0,
      startY: 0,
      width: 300,
      height: 320,
      bitmap: Uint8List(1),
    );
    final bottle = Subject(
      startX: 0,
      startY: 0,
      width: 200,
      height: 700,
      bitmap: Uint8List(2),
    );
    expect(MlKitBottleScanner.pickBottle([cup, bottle]), same(bottle));
    expect(MlKitBottleScanner.pickBottle(const []), isNull);
  });

  testWidgets('사진을 고르면 빈 칸만 라벨 정보로 채운다', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    final store = NoteStore(MemoryNoteStorage());
    final original = TastingNote(
      id: 'g',
      origin: WhiskyOrigin.world,
      subRegion: 'Germany',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: NoteEditScreen(
          store: store,
          original: original,
          scanner: FakeScanner(glenfiddich),
        ),
      ),
    );
    final state = tester.state(find.byType(NoteEditScreen)) as dynamic;
    await tester.runAsync(() => state.usePhotoForTest('/tmp/x.jpg') as Future);
    await tester.pump();

    expect(find.widgetWithText(TextField, 'Glenfiddich 16'), findsOneWidget);
    expect(find.widgetWithText(TextField, '16년'), findsOneWidget);
    // 이미 고른 산지는 덮어쓰지 않는다 (라벨은 Scotland라고 해도).
    expect(find.widgetWithText(TextField, 'Germany'), findsOneWidget);
    // 배경 제거가 안 되는 기기면 원본 사진을 쓴다고 알려준다.
    expect(find.textContaining('원본 사진'), findsWidgets);
    // 라벨 글자 칩을 누르면 이름에 덧붙는다.
    final chip = find.widgetWithText(ActionChip, 'FORMULA ONE TEAM');
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pump();
    expect(
      find.widgetWithText(TextField, 'Glenfiddich 16 FORMULA ONE TEAM'),
      findsOneWidget,
    );
  });

  test('종류: 구체적인 이름(Blended Malt)을 먼저 알아본다', () {
    WhiskyType? t(String text) =>
        parseLabel([OcrLine(text, 10), const OcrLine('NAME', 30)]).type;
    expect(t('BLENDED MALT SCOTCH WHISKY'), WhiskyType.blendedMalt);
    expect(t('SINGLE GRAIN'), WhiskyType.singleGrain);
    expect(t('BLENDED GRAIN'), WhiskyType.blendedGrain);
    expect(t('BLENDED SCOTCH WHISKY'), WhiskyType.blended);
  });

  test('산지: 버번은 American / Bourbon', () {
    final g = parseLabel(const [
      OcrLine('WILD TURKEY', 40),
      OcrLine('KENTUCKY STRAIGHT BOURBON WHISKEY', 12),
    ]);
    expect(g.origin, WhiskyOrigin.american);
    expect(g.subRegion, 'Bourbon');
  });
}
