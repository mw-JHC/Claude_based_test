import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 진열장 분위기.
enum CabinetStyle {
  woodShop('고급 위스키숍 원목장', '원목장', '짙은 원목 선반과 황동 이름표, 따뜻한 조명'),
  backBar('바 뒤편 진열장', '바 진열장', '거울 뒤판과 유리 선반, 선반마다 LED 조명'),
  museum('박물관 유리 케이스', '박물관', '어두운 전시실, 받침대 위 유리 케이스와 스포트라이트');

  const CabinetStyle(this.label, this.shortLabel, this.description);
  final String label;

  /// 진열장 아래에 짧게 보여줄 이름
  final String shortLabel;
  final String description;

  static CabinetStyle fromName(String? name) => CabinetStyle.values.firstWhere(
    (s) => s.name == name,
    orElse: () => CabinetStyle.woodShop,
  );
}

/// 앱 설정. 폰에 저장되어 앱을 다시 켜도 유지됩니다.
class AppSettings extends ChangeNotifier {
  AppSettings._(this._prefs, this._style);

  static const _styleKey = 'cabinetStyle';

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings._(
      prefs,
      CabinetStyle.fromName(prefs.getString(_styleKey)),
    );
  }

  final SharedPreferences _prefs;
  CabinetStyle _style;

  CabinetStyle get cabinetStyle => _style;

  Future<void> setCabinetStyle(CabinetStyle style) async {
    if (style == _style) return;
    _style = style;
    notifyListeners();
    await _prefs.setString(_styleKey, style.name);
  }
}
