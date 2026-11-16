import '../models/tasting_note.dart';

/// 라벨에서 읽은 글자 한 줄. [height]는 글자 크기 (클수록 중요한 글자).
class OcrLine {
  const OcrLine(this.text, this.height);
  final String text;
  final double height;
}

/// 라벨 글자로 추측한 정보.
class LabelGuess {
  const LabelGuess({
    this.brand,
    this.age,
    this.type,
    this.origin,
    this.subRegion = '',
    this.words = const [],
  });

  /// 가장 크게 쓰인 이름 (예: Glenfiddich)
  final String? brand;

  /// 숙성 연수 (예: 16)
  final int? age;
  final WhiskyType? type;

  /// 산지와 세부 지역 (예: Scotland, Highland)
  final WhiskyOrigin? origin;
  final String subRegion;

  /// 라벨에서 읽은 글자들 (큰 글자부터). 이름에 덧붙일 후보로 보여줍니다.
  final List<String> words;

  /// 이름 칸에 넣을 값 (예: "Glenfiddich 16")
  String? get name {
    if (brand == null) return null;
    return age == null ? brand : '$brand $age';
  }

  bool get isEmpty => brand == null && age == null && words.isEmpty;
}

/// 이름이 될 수 없는 흔한 라벨 문구.
const _stopWords = {
  'SINGLE',
  'MALT',
  'WHISKY',
  'WHISKEY',
  'SCOTCH',
  'BLENDED',
  'BOURBON',
  'STRAIGHT',
  'KENTUCKY',
  'IRISH',
  'JAPANESE',
  'RYE',
  'GRAIN',
  'POT',
  'STILL',
  'AGED',
  'AGE',
  'YEARS',
  'YEAR',
  'YRS',
  'OLD',
  'JAHRE',
  'DISTILLERY',
  'DISTILLED',
  'DISTILLERS',
  'PRODUCT',
  'OF',
  'THE',
  'AND',
  'IN',
  'CASK',
  'CASKS',
  'STRENGTH',
  'NON',
  'CHILL',
  'FILTERED',
  'NATURAL',
  'COLOUR',
  'MATURED',
  'FINISH',
  'FINISHED',
  'OAK',
  'SHERRY',
  'EST',
  'ESTD',
  'SINCE',
  'ML',
  'CL',
  'VOL',
  'ALC',
  'PREMIUM',
  'RESERVE',
  'EDITION',
  'LIMITED',
  'BAVARIAN',
  'BAVARIA',
  'HIGHLAND',
  'HIGHLANDS',
  'LOWLAND',
  'SPEYSIDE',
  'ISLAY',
  'CAMPBELTOWN',
  'WEST',
  'EAST',
  'NORTH',
  'SOUTH',
  'SCOTLAND',
  'JAPAN',
  'GERMANY',
  'USA',
  'TEAM',
  'FORMULA',
  'ONE',
  'BOTTLED',
  'BY',
};

/// 글자 크기, 키워드를 보고 이름 / 숙성 연수 / 종류 / 지역을 추측합니다.
LabelGuess parseLabel(List<OcrLine> raw) {
  final lines = [
    for (final l in raw)
      if (l.text.trim().isNotEmpty)
        OcrLine(l.text.trim().replaceAll(RegExp(r'\s+'), ' '), l.height),
  ]..sort((a, b) => b.height.compareTo(a.height));
  if (lines.isEmpty) return const LabelGuess();
  final all = lines.map((l) => l.text.toUpperCase()).join(' ');
  final origin = originFromText(all);

  return LabelGuess(
    brand: _brand(lines),
    age: _age(lines),
    type: _type(all),
    origin: origin?.$1,
    subRegion: origin?.$2 ?? '',
    words: _words(lines),
  );
}

WhiskyType? _type(String all) {
  // 더 구체적인 이름부터 확인합니다 (BLENDED MALT가 BLENDED보다 먼저).
  if (all.contains('SINGLE GRAIN')) return WhiskyType.singleGrain;
  if (all.contains('BLENDED MALT') ||
      all.contains('PURE MALT') ||
      all.contains('VATTED')) {
    return WhiskyType.blendedMalt;
  }
  if (all.contains('BLENDED GRAIN')) return WhiskyType.blendedGrain;
  if (all.contains('SINGLE MALT')) return WhiskyType.singleMalt;
  if (all.contains('BLENDED')) return WhiskyType.blended;
  return null;
}

final _ageWithUnit = RegExp(
  r'\b(\d{1,2})\s*(?:YEARS?|YRS?|Y\.?\s?O\.?|JAHRE|ANS|AÑOS)\b',
  caseSensitive: false,
);
final _agedNumber = RegExp(r'\bAGED\s*(\d{1,2})\b', caseSensitive: false);
final _onlyNumber = RegExp(r'^\d{1,2}$');

int? _age(List<OcrLine> lines) {
  bool ok(int a) => a >= 3 && a <= 60;
  for (final l in lines) {
    final m = _ageWithUnit.firstMatch(l.text) ?? _agedNumber.firstMatch(l.text);
    if (m != null) {
      final a = int.parse(m.group(1)!);
      if (ok(a)) return a;
    }
  }
  // "14"처럼 숫자만 크게 쓰인 라벨 (큰 글자 순으로 이미 정렬됨)
  final biggest = lines.first.height;
  for (final l in lines) {
    if (_onlyNumber.hasMatch(l.text) && l.height >= biggest * 0.4) {
      final a = int.parse(l.text);
      if (ok(a)) return a;
    }
  }
  return null;
}

List<String> _letters(String s) =>
    RegExp(r"[A-Za-zÀ-ÿ'’]+")
        .allMatches(s)
        .map((m) => m.group(0)!.toUpperCase())
        .toList();

/// 로트 번호(L A11089) 같은 글자와 숫자가 섞인 잡음인지.
bool _isNoise(String s) {
  final letters = s.replaceAll(RegExp(r'[^A-Za-z]'), '').length;
  final digits = s.replaceAll(RegExp(r'[^0-9]'), '').length;
  return letters < 2 || digits > letters;
}

String? _brand(List<OcrLine> lines) {
  for (final l in lines) {
    if (_isNoise(l.text) || l.text.length > 30) continue;
    final words = _letters(l.text);
    if (words.isEmpty || words.every(_stopWords.contains)) continue;
    // "Glenfiddich." 처럼 끝에 붙은 점은 뗍니다.
    return l.text.replaceAll(RegExp(r'[.,;:·]+$'), '');
  }
  return null;
}

List<String> _words(List<OcrLine> lines) {
  final seen = <String>{};
  final out = <String>[];
  for (final l in lines) {
    if (_isNoise(l.text) || l.text.length > 30) continue;
    if (seen.add(l.text.toUpperCase())) out.add(l.text);
    if (out.length == 8) break;
  }
  return out;
}
