/// 위스키 테이스팅 노트 데이터 모델.
///
/// 항목 구성은 손으로 쓰던 "Whiskey Tasting Note" PDF 양식을 그대로 따릅니다.
library;

enum WhiskyType {
  singleMalt('Single Malt'),
  blended('Blended'),
  bourbon('Bourbon'),
  japanese('Japanese'),
  world('World');

  const WhiskyType(this.label);
  final String label;

  static WhiskyType? fromName(String? name) {
    for (final t in values) {
      if (t.name == name) return t;
    }
    return null;
  }
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
  FlavorAxis('질감', ['꿀', '초콜릿', '오일', '푸풋함', '버터']),
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

/// 색상 스케일 범위 (PDF 기준 0.0 ~ 2.0).
const colorMin = 0.0;
const colorMax = 2.0;

class TastingNote {
  TastingNote({
    required this.id,
    this.name = '',
    this.type,
    this.region = '',
    this.ageCask = '',
    this.abv,
    this.price = '',
    this.score,
    this.color,
    this.photo,
    List<int>? nose,
    List<int>? palate,
    List<int>? retronasal,
    Map<String, int>? characters,
    this.finish = scaleDefault,
    this.overall = '',
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : nose = _fit(nose, aromaAxes.length),
       palate = _fit(palate, palateAxes.length),
       retronasal = _fit(retronasal, aromaAxes.length),
       characters = {
         for (final s in characterScales)
           s.key: characters?[s.key] ?? scaleDefault,
       },
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? createdAt ?? DateTime.now();

  factory TastingNote.create() =>
      TastingNote(id: DateTime.now().microsecondsSinceEpoch.toString());

  final String id;
  String name;
  WhiskyType? type;

  /// 국가 / 지역
  String region;

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

  final DateTime createdAt;
  DateTime updatedAt;

  TastingNote copy() => TastingNote.fromJson(toJson());

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type?.name,
    'region': region,
    'ageCask': ageCask,
    'abv': abv,
    'price': price,
    'score': score,
    'color': color,
    'photo': photo,
    'nose': nose,
    'palate': palate,
    'retronasal': retronasal,
    'characters': characters,
    'finish': finish,
    'overall': overall,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory TastingNote.fromJson(Map<String, dynamic> j) => TastingNote(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    type: WhiskyType.fromName(j['type'] as String?),
    region: j['region'] as String? ?? '',
    ageCask: j['ageCask'] as String? ?? '',
    abv: (j['abv'] as num?)?.toDouble(),
    price: j['price'] as String? ?? '',
    score: (j['score'] as num?)?.toDouble(),
    color: (j['color'] as num?)?.toDouble(),
    photo: j['photo'] as String?,
    nose: _intList(j['nose']),
    palate: _intList(j['palate']),
    retronasal: _intList(j['retronasal']),
    characters: (j['characters'] as Map?)?.map(
      (k, v) => MapEntry(k as String, (v as num).toInt()),
    ),
    finish: (j['finish'] as num?)?.toInt() ?? scaleDefault,
    overall: j['overall'] as String? ?? '',
    createdAt: DateTime.tryParse(j['createdAt'] as String? ?? ''),
    updatedAt: DateTime.tryParse(j['updatedAt'] as String? ?? ''),
  );

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
