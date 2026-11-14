import 'package:material_ui/material_ui.dart';

import 'data/note_store.dart';
import 'screens/note_list_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = NoteStore(await FileNoteStorage.open());
  runApp(WhiskyNoteApp(store: store));
  await store.load();
}

class WhiskyNoteApp extends StatelessWidget {
  const WhiskyNoteApp({super.key, required this.store});

  final NoteStore store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Whisky Library',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: NoteListScreen(store: store),
    );
  }
}
