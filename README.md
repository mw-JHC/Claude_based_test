# Whisky Library

손으로 쓰던 위스키 테이스팅 노트 PDF 양식을 그대로 옮긴 Flutter 앱입니다. 안드로이드에서 먼저 쓰고, 나중에 iOS에서도 같은 코드로 빌드할 수 있습니다.

## 디자인

어두운 위스키 라운지 분위기의 다크 테마입니다. 호박색/구리색 포인트, 둥근 카드, 제목과 위스키 이름에는 세리프 폰트(Playfair Display, SIL OFL)를 씁니다. 색과 공통 스타일은 `lib/theme.dart`에 모여 있습니다.

## 기능

- **진열장 보기**: 마셔본 위스키를 진열장에 세워서 보여줍니다.
  - **병 사진을 찍으면 배경을 지우고 병만 오려서** 진열장에 세웁니다 (구글 ML Kit, 폰 안에서 처리). 사진이 없는 병은 그린 병으로 보입니다.
  - 진열장 분위기는 **설정(⚙)** 에서 고릅니다: 고급 위스키숍 원목장 / 바 뒤편 진열장(거울, 유리 선반, LED) / 박물관 유리 케이스(받침대, 스포트라이트).
  - 진열장을 좌우로 끌면 입체적으로 살짝 돌아갔다가 제자리로 돌아옵니다. 병을 누르면 노트가 열립니다.
- **병 촬영**: 카메라 화면에 병 모양 가이드 틀이 떠서 정면으로 찍도록 도와줍니다.
  찍고 나면 라벨 글자를 읽어 **이름, 숙성 연수, 종류, 지역**의 빈 칸을 채웁니다 (예: "Glenfiddich 16"). 라벨에서 읽은 다른 글자는 눌러서 이름에 덧붙일 수 있습니다.
- **목록 보기**: 오른쪽 위 버튼으로 진열장과 목록을 바꿀 수 있습니다. 이름, 지역, 종류로 검색합니다.
- **노트 작성/수정**: PDF 양식의 모든 항목을 입력합니다.
  - 종류 (Single Malt / Blended / Bourbon / Japanese / World)
  - 이름, 국가/지역, 숙성연도/캐스크, 도수, 가격, 점수(0~100)
  - 색상 0.0 ~ 2.0 (0.1 단위, 색 막대에서 선택)
  - 사진 (카메라 촬영 또는 갤러리)
  - 향 / Nose, 비후방 후각 / Retronasal: 8개 축 (곡물, 과일, 꽃, 나무, 이탄, 아로마, 질감, 기타)
  - 맛 / Palate: 6개 축 (단맛, 신맛, 짠맛, 감칠맛, 지방맛, 쓴맛)
  - 개성 / Characters: 드라이↔오일리, 가벼운↔무거운, 순한↔매운, 부드러운↔강렬한 (1~9)
  - 여운 / Finish: 짧다↔길다 (1~9)
  - 총평 / Overall
- **노트 보기**: 저장한 노트를 PDF와 비슷한 모양으로 보여줍니다. 여기서 수정과 삭제를 할 수 있습니다.
- 데이터는 폰 안에만 저장됩니다(앱 전용 폴더의 `whisky_notes.json`과 `photos/`).

레이더 차트는 **누르거나 끌어서** 값을 정합니다. 중심이 0이고 바깥 원이 10입니다.
각 축 이름 옆에 값이 표시되고, 향과 비후방 후각은 이름 옆 **(?)** 를 누르면 예시(예: 이탄 → 병원, 훈제, 이끼 …)가 나옵니다.

## 코드 구조

```
lib/
  main.dart                     앱 시작
  theme.dart                    PDF 색감 (짙은 갈색, 금색, 크림색)
  models/tasting_note.dart      노트 데이터와 항목 정의 (축 이름, 개성 막대 등)
  data/note_store.dart          저장/불러오기 (JSON 파일 + 사진 폴더)
  services/
    bottle_scanner.dart         병 오려내기, 라벨 글자 읽기 (ML Kit)
    label_parser.dart           라벨 글자 → 이름 / 숙성 연수 / 종류 / 지역 추측
  data/app_settings.dart        설정 (진열장 분위기) 저장
  screens/
    note_list_screen.dart       첫 화면 (진열장 / 목록)
    bottle_camera_screen.dart   병 모양 가이드 틀이 있는 카메라
    settings_screen.dart        설정 화면
    note_edit_screen.dart       작성/수정 화면
    note_detail_screen.dart     보기 화면
  widgets/
    cabinet_view.dart           진열장 (선반, 조명, 기울이기)
    whisky_bottle.dart          위스키 병 그리기
    radar_chart.dart            원형 레이더 차트 (축 이름, 값, (?) 예시, 터치 입력)
    flavor_wheel.dart           차트 칸 (안내 문구 + 차트)
    color_scale.dart            색상 막대
    character_slider.dart       개성 막대
    sheet_section.dart          PDF 스타일 제목 막대가 달린 칸
    note_photo.dart             사진 표시
test/widget_test.dart           저장 형식, 노트 작성, 진열장 설정 테스트
test/scan_test.dart             라벨 읽기, 병 고르기, 사진으로 빈 칸 채우기 테스트
```

축 이름이나 (?) 예시를 바꾸고 싶으면 `lib/models/tasting_note.dart`의 `aromaAxes`, `palateAxes`, `characterScales`만 고치면 됩니다.

## Windows에서 실행하기

### 1. 설치 (한 번만)

1. **Flutter SDK**: https://docs.flutter.dev/get-started/install/windows 에서 받아 `C:\src\flutter`처럼 공백 없는 경로에 풀고, `C:\src\flutter\bin`을 PATH에 추가합니다.
   VS Code에서 `Ctrl+Shift+P` → `Flutter: New Project`를 실행하면 SDK를 자동으로 내려받게 할 수도 있습니다.
2. **Android Studio**: 설치한 뒤 처음 실행할 때 마법사로 Android SDK를 설치합니다.
   그다음 `More Actions → SDK Manager → SDK Tools`에서 **Android SDK Command-line Tools**를 체크해서 설치합니다.
3. PowerShell에서 실행:
   ```bash
   flutter doctor --android-licenses
   ```
   ```bash
   flutter doctor
   ```
   `Android toolchain`에 체크 표시가 나오면 준비 완료입니다.
   - `Visual Studio` 항목은 Windows 데스크톱 앱을 만들 때만 필요하므로 경고가 나와도 무시해도 됩니다.
   - `Xcode`는 Windows에서는 항목에 나오지 않습니다(iOS 빌드는 Mac 필요).

### 2. 폰 준비 (한 번만)

1. 설정 → 휴대전화 정보 → 소프트웨어 정보 → **빌드 번호를 7번** 누르면 개발자 옵션이 켜집니다.
2. 설정 → 개발자 옵션 → **USB 디버깅** 켜기
3. USB로 PC에 연결하고 폰에 뜨는 "USB 디버깅 허용"을 승인합니다.

### 3. 코드 받아서 실행

```bash
git clone https://github.com/mw-JHC/Claude_based_test.git
```
```bash
cd Claude_based_test
```
```bash
git checkout claude/gallant-gates-erz54u
```
```bash
flutter pub get
```
```bash
flutter run
```

앱이 폰에 설치되고 실행됩니다. 실행 중에 코드를 저장하면 핫 리로드로 바로 반영됩니다(터미널에서 `r` 키로도 가능).

VS Code에서는 폴더를 열고 오른쪽 아래에서 연결된 폰을 고른 뒤 `F5`를 누르면 됩니다.

### 테스트

```bash
flutter test
```

## 배경 제거와 글자 인식에 대해

- 둘 다 구글 ML Kit을 써서 **폰 안에서** 처리합니다. 사진이 인터넷으로 나가지 않습니다.
- 배경 제거 모델은 Google Play 서비스가 처음 한 번 내려받습니다. 에뮬레이터라면 **Google Play가 들어간 시스템 이미지**여야 하고, 처음에는 인터넷 연결이 필요합니다.
- 배경 제거는 현재 **안드로이드에서만** 됩니다. iOS에서는 원본 사진을 쓰고, 글자 인식은 iOS에서도 됩니다.
- 단색 배경 앞에서 병을 정면으로 찍으면 가장 잘 오려집니다. 결과가 마음에 안 들면 노트 화면에서 "원본 사진"을 고르면 됩니다.

## 나중에 iOS에서 실행하기

Mac에서 Xcode를 설치하고 `ios/Runner.xcworkspace`를 연 뒤 Signing에 Apple ID를 넣고 `flutter run`을 실행하면 됩니다.
카메라와 사진 보관함 권한 문구는 이미 `ios/Runner/Info.plist`에 들어 있습니다.
