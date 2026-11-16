import 'package:material_ui/material_ui.dart';

import 'data/app_settings.dart';
import 'data/note_store.dart';
import 'screens/note_list_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = NoteStore(await FileNoteStorage.open());
  final settings = await AppSettings.load();
  runApp(WhiskyNoteApp(store: store, settings: settings));
  await store.load();
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
      home: NoteListScreen(store: store, settings: settings),
    );
  }
}
