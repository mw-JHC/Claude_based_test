import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'data/app_settings.dart';
import 'data/note_store.dart';
import 'screens/note_list_screen.dart';
import 'screens/welcome_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 앱에 넣은 글꼴(Playfair Display)의 라이선스를 "오픈소스 라이선스" 화면에 표시
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Playfair Display',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
  final store = NoteStore(await FileNoteStorage.open());
  final settings = await AppSettings.load();
  // 시작 화면(스플래시)이 떠 있는 동안 기록을 먼저 읽습니다.
  // (기록이 있는 사용자에게 환영 화면이 뜨지 않도록)
  await store.load();
  runApp(WhiskyNoteApp(store: store, settings: settings));
}

class WhiskyNoteApp extends StatelessWidget {
  const WhiskyNoteApp({super.key, required this.store, required this.settings});

  final NoteStore store;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Whisky Library',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      // 처음 실행이면 환영 화면부터 (기록이 이미 있는 예전 사용자는 건너뜀)
      home: settings.onboarded || store.notes.isNotEmpty
          ? NoteListScreen(store: store, settings: settings)
          : WelcomeScreen(store: store, settings: settings),
    );
  }
}
