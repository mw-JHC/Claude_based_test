import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:whisky_note/data/app_settings.dart';
import 'package:whisky_note/data/note_store.dart';
import 'package:whisky_note/data/sample_data.dart';
import 'package:whisky_note/l10n/tr.dart';
import 'package:whisky_note/main.dart';
import 'package:whisky_note/models/tasting_note.dart';
import 'package:whisky_note/widgets/sheet_section.dart';

void main() {
  testWidgets('기본 언어는 영어: 환영 화면이 영어로 나온다', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final settings = await AppSettings.load();
    expect(settings.language, AppLanguage.en);
    final store = NoteStore(MemoryNoteStorage());
    await store.load();
    await tester.pumpWidget(WhiskyNoteApp(store: store, settings: settings));
    expect(find.text('Add your first bottle'), findsOneWidget);
    expect(find.text('첫 병 진열하기'), findsNothing);
  });

  testWidgets('설정에서 언어를 바꾸면 앱 전체가 바뀌고 저장된다', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'onboarded': true});
    final settings = await AppSettings.load();
    final store = NoteStore(MemoryNoteStorage());
    await store.load();
    await tester.pumpWidget(WhiskyNoteApp(store: store, settings: settings));
    expect(find.text('No whiskies yet'), findsOneWidget);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Language'), findsOneWidget);
    await tester.tap(find.text('한국어'));
    await tester.pumpAndSettle();

    expect(settings.language, AppLanguage.ko);
    expect((await SharedPreferences.getInstance()).getString('language'), 'ko');
    // 새 언어로 첫 화면부터 다시
    expect(find.text('아직 기록한 위스키가 없습니다'), findsOneWidget);
  });

  testWidgets('영어 화면의 한글-영어 이름표는 영어만 보인다', (tester) async {
    tr.language = AppLanguage.en;
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: BiLabel('도수', 'ABV'))),
    );
    expect(find.text('ABV'), findsOneWidget);
    expect(find.text('도수'), findsNothing);
  });

  test('번역된 데이터: 차트 축, 개성, 날짜, 병 수', () {
    tr.language = AppLanguage.en;
    expect(aromaAxes.first.label, 'Grain');
    expect(aromaAxes[4].examples, contains('Iodine'));
    expect(characterScales.first.left, 'Dry');
    expect(tr.bottles(1), '1 bottle');
    expect(tr.bottles(3), '3 bottles');
    expect(tr.dateWithDay(DateTime(2026, 11, 20)), 'Fri, Nov 20, 2026');
    tr.language = AppLanguage.ko;
    expect(aromaAxes.first.label, '곡물');
    expect(tr.bottles(3), '3병');
    expect(tr.dateWithDay(DateTime(2026, 11, 20)), '2026.11.20 (금)');
  });

  test('영어 화면에서 샘플을 넣으면 이야기와 숙성 연수도 영어', () async {
    tr.language = AppLanguage.en;
    final store = NoteStore(MemoryNoteStorage());
    await addSampleWhiskies(store);
    final talisker = store.notes.firstWhere((n) => n.name == 'Talisker 10');
    expect(talisker.stories.first.text, startsWith('Peppery'));
    final glen = store.notes.firstWhere((n) => n.name == 'Glenfiddich 18');
    expect(glen.ageCask, '18 yrs / Oloroso');
  });
}
