import 'package:material_ui/material_ui.dart';

/// PDF 양식의 색감 (짙은 갈색 + 금색 + 크림색).
class NoteColors {
  static const ink = Color(0xFF1E120A); // 섹션 제목 배경
  static const gold = Color(0xFFE2B04A); // 제목 글자
  static const leather = Color(0xFF6B3A1F); // 상단 입력칸
  static const cream = Color(0xFFF7F0E1); // 바탕
  static const paper = Color(0xFFE6DAC4); // 섹션 안쪽
  static const amber = Color(0xFFC8781E); // 테두리, 강조
  static const hint = Color(0xFF8A6A4A);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: NoteColors.amber,
    primary: NoteColors.leather,
    secondary: NoteColors.amber,
    surface: NoteColors.cream,
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: NoteColors.cream,
    appBarTheme: const AppBarTheme(
      backgroundColor: NoteColors.ink,
      foregroundColor: NoteColors.gold,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: NoteColors.gold,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        fontStyle: FontStyle.italic,
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: NoteColors.amber,
      foregroundColor: Colors.white,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(),
      isDense: true,
    ),
  );
}
