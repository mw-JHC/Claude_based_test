# Whisky Library

손으로 쓰던 위스키 테이스팅 노트 PDF 양식을 그대로 옮긴 Flutter 앱입니다. 안드로이드에서 먼저 쓰고, 나중에 iOS에서도 같은 코드로 빌드할 수 있습니다.

## 기능 (v0.1)

- **진열장 보기**: 마셔본 위스키를 나무 진열장 선반에 병 모양으로 세워서 보여줍니다.
  - 병 안의 위스키 색은 노트의 색상 값, 병 모양과 뚜껑은 종류(Single Malt, Bourbon 등)에 따라 달라집니다.
  - 라벨에는 사진이 있으면 사진, 없으면 이름이 들어가고, 선반의 황동 이름표에 이름과 점수가 표시됩니다.
  - 진열장을 좌우로 끌면 입체적으로 살짝 돌아갔다가 제자리로 돌아옵니다. 병을 누르면 노트가 열립니다.
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

## 코드 구조

```
lib/
  main.dart                     앱 시작
  theme.dart                    PDF 색감 (짙은 갈색, 금색, 크림색)
  models/tasting_note.dart      노트 데이터와 항목 정의 (축 이름, 개성 막대 등)
  data/note_store.dart          저장/불러오기 (JSON 파일 + 사진 폴더)
  screens/
    note_list_screen.dart       목록 화면
    note_edit_screen.dart       작성/수정 화면
    note_detail_screen.dart     보기 화면
  widgets/
    cabinet_view.dart           진열장 (선반, 조명, 기울이기)
    whisky_bottle.dart          위스키 병 그리기
    radar_chart.dart            원형 레이더 차트 (직접 그림, 터치 입력)
    flavor_wheel.dart           차트 + 항목 설명 칩
    color_scale.dart            색상 막대
    character_slider.dart       개성 막대
    sheet_section.dart          PDF 스타일 제목 막대가 달린 칸
    note_photo.dart             사진 표시
test/widget_test.dart           저장 형식과 노트 작성 흐름 테스트
```

축 이름이나 설명을 바꾸고 싶으면 `lib/models/tasting_note.dart`의 `aromaAxes`, `palateAxes`, `characterScales`만 고치면 됩니다.

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

## 나중에 iOS에서 실행하기

Mac에서 Xcode를 설치하고 `ios/Runner.xcworkspace`를 연 뒤 Signing에 Apple ID를 넣고 `flutter run`을 실행하면 됩니다.
카메라와 사진 보관함 권한 문구는 이미 `ios/Runner/Info.plist`에 들어 있습니다.
