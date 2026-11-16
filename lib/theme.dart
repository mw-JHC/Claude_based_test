import 'package:material_ui/material_ui.dart';

/// 어두운 위스키 라운지 분위기의 색.
///
/// 거의 검은 웜톤 배경 위에 호박색/구리색 포인트와 크림색 글자를 씁니다.
class NoteColors {
  // 바탕과 면
  static const bg = Color(0xFF110D0B); // 화면 바탕
  static const surface = Color(0xFF1C1714); // 카드
  static const surfaceHigh = Color(0xFF28211C); // 입력칸, 칩
  static const line = Color(0xFF3A302A); // 얇은 테두리

  // 글자
  static const text = Color(0xFFF4EBDD);
  static const hint = Color(0xFFA6978A); // 보조 글자
  static const faint = Color(0xFF6F6359);

  // 포인트
  static const amber = Color(0xFFD99A4E); // 주 포인트 (호박색)
  static const gold = Color(0xFFEBC07A); // 밝은 포인트
  static const leather = Color(0xFFB0662E); // 진한 포인트 (구리색)
  static const ink = Color(0xFF0B0807); // 가장 어두운 색

  // 예전 이름 (진열장/병 그림에서 사용)
  static const cream = text;
  static const paper = surface;

  /// 주요 버튼, 강조에 쓰는 호박색 그라데이션.
  static const accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEBB46A), Color(0xFFC9772F)],
  );
}

/// 제목과 위스키 이름에 쓰는 세리프 폰트.
const serif = 'Playfair';

ThemeData buildTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: NoteColors.amber,
        brightness: Brightness.dark,
      ).copyWith(
        primary: NoteColors.amber,
        onPrimary: NoteColors.ink,
        secondary: NoteColors.gold,
        onSecondary: NoteColors.ink,
        surface: NoteColors.surface,
        onSurface: NoteColors.text,
        onSurfaceVariant: NoteColors.hint,
        surfaceContainerHighest: NoteColors.surfaceHigh,
        outline: NoteColors.line,
        outlineVariant: NoteColors.line,
      );
  final rounded = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(14),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: NoteColors.bg,
    splashFactory: InkSparkle.splashFactory,
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontFamily: serif, fontWeight: FontWeight.w700),
      headlineMedium: TextStyle(fontFamily: serif, fontWeight: FontWeight.w700),
      headlineSmall: TextStyle(fontFamily: serif, fontWeight: FontWeight.w700),
      titleLarge: TextStyle(fontFamily: serif, fontWeight: FontWeight.w700),
    ).apply(bodyColor: NoteColors.text, displayColor: NoteColors.text),
    appBarTheme: const AppBarTheme(
      backgroundColor: NoteColors.bg,
      surfaceTintColor: Colors.transparent,
      foregroundColor: NoteColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: serif,
        color: NoteColors.text,
        fontSize: 22,
        fontWeight: FontWeight.w700,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: NoteColors.amber,
      foregroundColor: NoteColors.ink,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      extendedTextStyle: const TextStyle(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: NoteColors.surfaceHigh,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: const TextStyle(color: NoteColors.hint),
      floatingLabelStyle: const TextStyle(color: NoteColors.gold),
      hintStyle: const TextStyle(color: NoteColors.faint),
      suffixStyle: const TextStyle(color: NoteColors.hint),
      prefixIconColor: NoteColors.hint,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: NoteColors.amber, width: 1.4),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: NoteColors.surfaceHigh,
      selectedColor: NoteColors.amber,
      disabledColor: NoteColors.surfaceHigh,
      side: BorderSide.none,
      shape: const StadiumBorder(),
      labelStyle: const TextStyle(color: NoteColors.text, fontSize: 13),
      // 선택/비선택 글자 굵기가 같아야 칩 너비가 바뀌며 글자가 잘리지 않습니다.
      secondaryLabelStyle: const TextStyle(color: NoteColors.ink, fontSize: 13),
      checkmarkColor: NoteColors.ink,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: NoteColors.amber,
        foregroundColor: NoteColors.ink,
        shape: rounded,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: NoteColors.text,
        side: const BorderSide(color: NoteColors.line),
        shape: rounded,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: NoteColors.surfaceHigh,
        foregroundColor: NoteColors.hint,
        selectedBackgroundColor: NoteColors.amber,
        selectedForegroundColor: NoteColors.ink,
        side: BorderSide.none,
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    ),
    sliderTheme: const SliderThemeData(
      trackHeight: 4,
      thumbColor: NoteColors.text,
      overlayColor: Color(0x22D99A4E),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: NoteColors.surfaceHigh,
      contentTextStyle: const TextStyle(color: NoteColors.text),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: NoteColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: NoteColors.surfaceHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(color: NoteColors.text, fontSize: 12),
    ),
    dividerTheme: const DividerThemeData(color: NoteColors.line, space: 1),
  );
}
