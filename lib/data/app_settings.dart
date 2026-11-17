import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/tr.dart';

/// 진열장 분위기.
enum CabinetStyle {
  woodShop,
  backBar,
  museum;

  String get label => switch (this) {
    woodShop => tr('고급 위스키숍 원목장', 'Whisky shop cabinet'),
    backBar => tr('바 뒤편 진열장', 'Back bar shelves'),
    museum => tr('박물관 유리 케이스', 'Museum glass cases'),
  };

  String get description => switch (this) {
    woodShop => tr(
      '짙은 원목 선반과 황동 이름표, 따뜻한 조명',
      'Dark wood shelves, brass name plates, warm light',
    ),
    backBar => tr(
      '거울 뒤판과 유리 선반, 선반마다 LED 조명',
      'Mirrored back, glass shelves and LED strips',
    ),
    museum => tr(
      '어두운 전시실, 받침대 위 유리 케이스와 스포트라이트',
      'A dark gallery, plinths, glass cases and spotlights',
    ),
  };

  static CabinetStyle fromName(String? name) => CabinetStyle.values.firstWhere(
    (s) => s.name == name,
    orElse: () => CabinetStyle.woodShop,
  );
}

/// 앱 설정. 폰에 저장되어 앱을 다시 켜도 유지됩니다.
class AppSettings extends ChangeNotifier {
  AppSettings._(this._prefs, this._style, this._onboarded, this._language) {
    tr.language = _language;
  }

  static const _styleKey = 'cabinetStyle';
  static const _onboardedKey = 'onboarded';
  static const _languageKey = 'language';

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings._(
      prefs,
      CabinetStyle.fromName(prefs.getString(_styleKey)),
      prefs.getBool(_onboardedKey) ?? false,
      // 기본은 영어
      AppLanguage.fromCode(prefs.getString(_languageKey)),
    );
  }

  final SharedPreferences _prefs;
  CabinetStyle _style;

  CabinetStyle get cabinetStyle => _style;

  /// 처음 실행 때 보여주는 환영 화면을 봤는지
  bool _onboarded;
  bool get onboarded => _onboarded;

  /// 화면 언어
  AppLanguage _language;
  AppLanguage get language => _language;

  Future<void> setLanguage(AppLanguage language) async {
    if (language == _language) return;
    _language = language;
    tr.language = language;
    notifyListeners();
    await _prefs.setString(_languageKey, language.name);
  }

  Future<void> setOnboarded() async {
    _onboarded = true;
    notifyListeners();
    await _prefs.setBool(_onboardedKey, true);
  }

  Future<void> setCabinetStyle(CabinetStyle style) async {
    if (style == _style) return;
    _style = style;
    notifyListeners();
    await _prefs.setString(_styleKey, style.name);
  }
}
