/// 앱 언어. 기본은 영어.
enum AppLanguage {
  en('English'),
  ko('한국어');

  const AppLanguage(this.nativeName);

  /// 그 언어로 쓴 이름 (설정에서 보여줌)
  final String nativeName;

  static AppLanguage fromCode(String? code) => AppLanguage.values.firstWhere(
    (l) => l.name == code,
    orElse: () => AppLanguage.en,
  );
}

/// 화면 글자 번역. 쓰는 곳에서 한국어와 영어를 나란히 적습니다:
///
/// ```dart
/// Text(tr('저장', 'Save'))
/// ```
///
/// 언어를 바꾸면 앱 전체가 새로 그려집니다 (main.dart).
class Tr {
  AppLanguage language = AppLanguage.en;

  bool get ko => language == AppLanguage.ko;

  String call(String ko, String en) => this.ko ? ko : en;

  /// 병 수 (예: 3병 / 3 bottles)
  String bottles(int n) => ko ? '$n병' : (n == 1 ? '1 bottle' : '$n bottles');

  /// 날짜 (예: 2026.11.20 / Nov 20, 2026)
  String date(DateTime d) {
    if (ko) {
      return '${d.year}.${d.month.toString().padLeft(2, '0')}.'
          '${d.day.toString().padLeft(2, '0')}';
    }
    return '${_months[d.month - 1]} ${d.day}, ${d.year}';
  }

  /// 요일이 붙은 날짜 (예: 2026.11.20 (금) / Fri, Nov 20, 2026)
  String dateWithDay(DateTime d) {
    if (ko) {
      const days = ['월', '화', '수', '목', '금', '토', '일'];
      return '${date(d)} (${days[d.weekday - 1]})';
    }
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[d.weekday - 1]}, ${date(d)}';
  }

  /// 숙성 연수 (예: 12년 / 12 yrs)
  String age(int years) => ko ? '$years년' : '$years yrs';

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
}

/// 앱 전체에서 쓰는 번역기
final tr = Tr();
