/// 위스키 테이스팅 노트 데이터 모델.
///
/// 항목 구성은 손으로 쓰던 "Whiskey Tasting Note" PDF 양식을 그대로 따릅니다.
library;

/// 위스키 종류 (만드는 방식).
enum WhiskyType {
  singleMalt('Single Malt'),
  singleGrain('Single Grain'),
  blended('Blended'),
  blendedMalt('Blended Malt'),
  blendedGrain('Blended Grain');

  const WhiskyType(this.label);
  final String label;

  static WhiskyType? fromName(String? name) {
    for (final t in values) {
      if (t.name == name) return t;
    }
    return null;
  }
}

/// 산지 (나라). 세부 지역이 정해진 나라는 [subRegions]에서 고르고,
/// World는 나라 이름을 직접 적습니다.
enum WhiskyOrigin {
  scotland('Scotland', [
    'Speyside',
    'Highland',
    'Lowland',
    'Islay',
    'Campbeltown',
    'Islands',
  ]),
  american('American', [
    'Bourbon',
    'Rye',
    'Tennessee',
    'Wheat',
    'Corn',
    'American Single Malt',
  ]),
  irish('Irish'),
  japanese('Japanese'),
  taiwanese('Taiwanese'),
  world('World');

  const WhiskyOrigin(this.label, [this.subRegions = const []]);
  final String label;
  final List<String> subRegions;

  /// World는 세부 지역 대신 나라 이름을 직접 적습니다.
  bool get freeText => this == world;

  static WhiskyOrigin? fromName(String? name) {
    for (final o in values) {
      if (o.name == name) return o;
    }
    return null;
  }
}

/// 글자(라벨, 예전 지역 입력값)에서 산지와 세부 지역을 찾습니다.
/// 대문자로 바꾼 글자를 넣어 주세요. 못 찾으면 null.
(WhiskyOrigin, String)? originFromText(String upper) {
  bool has(String pattern) => RegExp(pattern).hasMatch(upper);
  const s = WhiskyOrigin.scotland, a = WhiskyOrigin.american;
  const w = WhiskyOrigin.world;
  final rules = <(String, WhiskyOrigin, String)>[
    (r'ISLAY', s, 'Islay'),
    (r'SPEYSIDE', s, 'Speyside'),
    (r'CAMPBELTOWN', s, 'Campbeltown'),
    (r'LOWLAND', s, 'Lowland'),
    (r'HIGHLAND', s, 'Highland'),
    (r'\bISLANDS?\b|ISLE OF', s, 'Islands'),
    (r'SCOTCH|SCOTLAND', s, ''),
    (r'TENNESSEE', a, 'Tennessee'),
    (r'BOURBON', a, 'Bourbon'),
    (r'\bRYE\b', a, 'Rye'),
    (r'KENTUCKY|AMERICAN|\bUSA\b|AMERICA', a, ''),
    (r'IRISH|IRELAND', WhiskyOrigin.irish, ''),
    (r'JAPAN', WhiskyOrigin.japanese, ''),
    (r'TAIWAN|KAVALAN', WhiskyOrigin.taiwanese, ''),
    (r'BAVARIA|GERMAN', w, 'Germany'),
    (r'INDIA', w, 'India'),
    (r'AUSTRALIA', w, 'Australia'),
    (r'CANADA|CANADIAN', w, 'Canada'),
    (r'WALES|WELSH', w, 'Wales'),
    (r'FRANCE|FRENCH', w, 'France'),
    (r'SWEDEN|SWEDISH', w, 'Sweden'),
  ];
  for (final (pattern, origin, sub) in rules) {
    if (has(pattern)) return (origin, sub);
  }
  return null;
}

/// 레이더 차트의 축 하나 (예: 곡물). [examples]는 (?) 버튼을 누르면 보이는 예시입니다.
class FlavorAxis {
  const FlavorAxis(this.label, [this.examples = const []]);
  final String label;
  final List<String> examples;
}

/// 향(Nose)과 비후방 후각(Retronasal)에 쓰는 8개 축. 위에서부터 시계방향.
const aromaAxes = <FlavorAxis>[
  FlavorAxis('곡물', ['밀가루', '호밀빵', '쌀', '끓인 곡물']),
  FlavorAxis('과일', ['말린 과일', '익힌 과일', '신선한 과일', '시트러스', '포도', '사과', '레몬', '배']),
  FlavorAxis('꽃', ['꽃향', '식물', '건초', '풀']),
  FlavorAxis('나무', ['오래된', '마른', '젖은', '쪼개진', '새 가구']),
  FlavorAxis('이탄', ['병원', '훈제', '이끼', '요오드', '타지 않은 숯향', '타고 남은 숯향']),
  FlavorAxis('아로마', ['바닐라', '너트', '아세톤']),
  FlavorAxis('질감', ['꿀', '초콜릿', '오일', '풋풋함', '버터']),
  FlavorAxis('기타', ['황', '플라스틱', '가죽', '담배', '고무', '흙']),
];

/// 맛(Palate)에 쓰는 6개 축. 위에서부터 시계방향.
const palateAxes = <FlavorAxis>[
  FlavorAxis('단맛'),
  FlavorAxis('신맛'),
  FlavorAxis('짠맛'),
  FlavorAxis('감칠맛'),
  FlavorAxis('지방맛'),
  FlavorAxis('쓴맛'),
];

/// 레이더 차트 값의 최대치 (PDF의 동심원 개수).
const radarMax = 10;

/// 개성(Characters) 막대 하나: 왼쪽 ↔ 오른쪽.
class CharacterScale {
  const CharacterScale(this.key, this.left, this.right);
  final String key;
  final String left;
  final String right;
}

const characterScales = <CharacterScale>[
  CharacterScale('dryOily', '드라이', '오일리'),
  CharacterScale('lightHeavy', '가벼운', '무거운'),
  CharacterScale('mildSpicy', '순한', '매운'),
  CharacterScale('smoothIntense', '부드러운', '강렬한'),
];

/// 여운(피니시) 막대: 짧다 ↔ 길다.
const finishScale = CharacterScale('finish', '짧다', '길다');

/// 개성 막대의 칸 수 (PDF 기준 9칸, 값은 1~9).
const scaleSteps = 9;
const scaleDefault = 5;

/// 색상 스케일 범위 (0.0 연한 짚색 ~ 1.0 짙은 마호가니).
const colorMin = 0.0;
const colorMax = 1.0;

/// 한 병에 남기는 이야기 한 편: 그날의 맛, 함께한 사람, 사진.
class StoryEntry {
  StoryEntry({
    required this.id,
    required this.date,
    this.text = '',
    this.companions = '',
    List<String>? photos,
  }) : photos = photos ?? [];

  factory StoryEntry.create() => StoryEntry(
    id: DateTime.now().microsecondsSinceEpoch.toString(),
    date: DateTime.now(),
  );

  final String id;
  DateTime date;

  /// 그날의 맛과 이야기
  String text;

  /// 함께 마신 사람
  String companions;

  /// 앱 저장소 안의 사진 파일 이름들
  final List<String> photos;

  StoryEntry copy() => StoryEntry.fromJson(toJson());

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'text': text,
    'companions': companions,
    'photos': photos,
  };

  factory StoryEntry.fromJson(Map<String, dynamic> j) => StoryEntry(
    id: j['id'] as String,
    date: DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime.now(),
    text: j['text'] as String? ?? '',
    companions: j['companions'] as String? ?? '',
    photos: (j['photos'] as List?)?.cast<String>().toList(),
  );
}

class TastingNote {
  TastingNote({
    required this.id,
    this.name = '',
    this.type,
    this.origin,
    this.subRegion = '',
    this.ageCask = '',
    this.abv,
    this.price = '',
    this.score,
    this.color,
    this.photo,
    this.cutout,
    List<int>? nose,
    List<int>? palate,
    List<int>? retronasal,
    Map<String, int>? characters,
    this.finish = scaleDefault,
    this.overall = '',
    this.emptiedAt,
    List<StoryEntry>? stories,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : nose = _fit(nose, aromaAxes.length),
       palate = _fit(palate, palateAxes.length),
       retronasal = _fit(retronasal, aromaAxes.length),
       characters = {
         for (final s in characterScales)
           s.key: characters?[s.key] ?? scaleDefault,
       },
       stories = stories ?? [],
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? createdAt ?? DateTime.now();

  factory TastingNote.create() =>
      TastingNote(id: DateTime.now().microsecondsSinceEpoch.toString());

  final String id;
  String name;
  WhiskyType? type;

  /// 산지 (나라)
  WhiskyOrigin? origin;

  /// 세부 지역 (예: Islay, Bourbon) 또는 World일 때 나라 이름
  String subRegion;

  /// 화면에 보여줄 산지 (예: "Scotland · Islay")
  String get regionLabel => [
    if (origin != null) origin!.label,
    if (subRegion.isNotEmpty) subRegion,
  ].join(' · ');

  /// 숙성연도 / 캐스크
  String ageCask;

  /// 도수 ABV(%)
  double? abv;

  /// 가격 (통화와 용량을 자유롭게 적을 수 있도록 문자열)
  String price;

  /// 점수 (0 ~ 100)
  double? score;

  /// 색상 스케일 값 (0.0 ~ 2.0)
  double? color;

  /// 앱 저장소 안의 사진 파일 이름 (전체 경로가 아님)
  String? photo;

  /// 배경을 지우고 병만 오려낸 PNG 파일 이름. 진열장에 이걸 세웁니다.
  String? cutout;

  /// 향 / Nose (aromaAxes 순서, 각 0 ~ radarMax)
  final List<int> nose;

  /// 맛 / Palate (palateAxes 순서, 각 0 ~ radarMax)
  final List<int> palate;

  /// 비후방 후각 / Retronasal aroma (aromaAxes 순서)
  final List<int> retronasal;

  /// 개성 / Characters (characterScales의 key → 1 ~ scaleSteps)
  final Map<String, int> characters;

  /// 여운 길이 (1 ~ scaleSteps)
  int finish;

  /// 총평 / Overall
  String overall;

  /// 병을 비운 날. 값이 있으면 진열장 대신 Memory Library에 놓입니다.
  DateTime? emptiedAt;
  bool get isEmpty => emptiedAt != null;

  /// 이 병과 함께한 이야기들 (날짜별 기록)
  final List<StoryEntry> stories;

  /// 날짜가 최근인 이야기부터
  List<StoryEntry> get storiesByDate =>
      [...stories]..sort((a, b) => b.date.compareTo(a.date));

  /// 이 노트가 쓰는 모든 사진 파일 (병 사진, 오려낸 병, 이야기 사진)
  Set<String> get files => {
    ?photo,
    ?cutout,
    for (final s in stories) ...s.photos,
  };

  final DateTime createdAt;
  DateTime updatedAt;

  TastingNote copy() => TastingNote.fromJson(toJson());

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type?.name,
    'origin': origin?.name,
    'subRegion': subRegion,
    'ageCask': ageCask,
    'abv': abv,
    'price': price,
    'score': score,
    'color': color,
    'photo': photo,
    'cutout': cutout,
    'nose': nose,
    'palate': palate,
    'retronasal': retronasal,
    'characters': characters,
    'finish': finish,
    'overall': overall,
    'emptiedAt': emptiedAt?.toIso8601String(),
    'stories': [for (final s in stories) s.toJson()],
    // 색상 값의 범위 버전 (1: 예전 0~2, 2: 지금 0~1)
    'colorScale': 2,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory TastingNote.fromJson(Map<String, dynamic> j) {
    // 예전 형식 바꾸기: 종류에 있던 Bourbon/Japanese/World와
    // 자유 입력 지역("Scotland / Islay")을 산지 + 세부 지역으로 옮깁니다.
    final rawType = j['type'] as String?;
    var origin = WhiskyOrigin.fromName(j['origin'] as String?);
    var sub = j['subRegion'] as String? ?? '';
    final legacyRegion = (j['region'] as String? ?? '').trim();
    if (origin == null && !j.containsKey('origin')) {
      final fromType = switch (rawType) {
        'bourbon' => (WhiskyOrigin.american, 'Bourbon'),
        'japanese' => (WhiskyOrigin.japanese, ''),
        'world' => (WhiskyOrigin.world, ''),
        _ => null,
      };
      final fromRegion = legacyRegion.isEmpty
          ? null
          : originFromText(legacyRegion.toUpperCase()) ??
                (WhiskyOrigin.world, legacyRegion);
      final picked = fromRegion ?? fromType;
      if (picked != null) {
        origin = picked.$1;
        sub = picked.$2.isNotEmpty ? picked.$2 : (fromType?.$2 ?? '');
      }
    }
    return TastingNote(
      id: j['id'] as String,
      name: j['name'] as String? ?? '',
      type: WhiskyType.fromName(rawType),
      origin: origin,
      subRegion: sub,
      ageCask: j['ageCask'] as String? ?? '',
      abv: (j['abv'] as num?)?.toDouble(),
      price: j['price'] as String? ?? '',
      score: (j['score'] as num?)?.toDouble(),
      // 예전 노트(0~2 범위)는 0~1 범위로 줄입니다.
      color: switch ((j['color'] as num?)?.toDouble()) {
        null => null,
        final c when j['colorScale'] == 2 => c,
        final c => (c / 2).clamp(colorMin, colorMax),
      },
      photo: j['photo'] as String?,
      cutout: j['cutout'] as String?,
      nose: _intList(j['nose']),
      palate: _intList(j['palate']),
      retronasal: _intList(j['retronasal']),
      characters: (j['characters'] as Map?)?.map(
        (k, v) => MapEntry(k as String, (v as num).toInt()),
      ),
      finish: (j['finish'] as num?)?.toInt() ?? scaleDefault,
      overall: j['overall'] as String? ?? '',
      emptiedAt: DateTime.tryParse(j['emptiedAt'] as String? ?? ''),
      stories: [
        for (final e in (j['stories'] as List? ?? const []))
          StoryEntry.fromJson(Map<String, dynamic>.from(e as Map)),
      ],
      createdAt: DateTime.tryParse(j['createdAt'] as String? ?? ''),
      updatedAt: DateTime.tryParse(j['updatedAt'] as String? ?? ''),
    );
  }

  static List<int>? _intList(Object? v) =>
      (v as List?)?.map((e) => (e as num).toInt()).toList();

  /// 저장된 값의 개수가 축 개수와 다르면 0으로 채우거나 잘라서 맞춥니다.
  static List<int> _fit(List<int>? values, int length) => List<int>.generate(
    length,
    (i) => (values != null && i < values.length)
        ? values[i].clamp(0, radarMax)
        : 0,
  );
}
