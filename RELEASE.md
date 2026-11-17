# Google Play 출시 가이드

Whisky Library를 Google Play에 올리기까지의 순서입니다. 코드 쪽 준비(아이콘, 시작 화면, 서명 설정, 스토어 이미지)는 끝나 있고, 아래는 **직접 하셔야 하는 일**입니다.

## 0. 출시 전에 정할 것

- **앱 ID** (`android/app/build.gradle.kts`의 `applicationId`, 지금 `com.jhc.whisky_note`)
  Play에 한 번 올리면 **영원히 바꿀 수 없습니다.** 바꾸려면 첫 업로드 전에 바꾸세요. 바꾸면 폰에 이미 설치된 앱과는 다른 앱이 되므로, 바꾸기 전에 설정 → 백업 만들기로 기록을 백업해 두세요.
- **버전**: `pubspec.yaml`의 `version: 1.0.0+1`
  업로드할 때마다 `+` 뒤 숫자(빌드 번호)를 하나씩 올려야 합니다. 예: `1.0.1+2`

## 1. 서명 키 만들기 (한 번만)

Play에 올리는 파일은 내 키로 서명해야 합니다. 이 키를 잃어버리면 앱을 업데이트할 수 없으니 **안전한 곳에 백업**하세요 (git에는 올라가지 않습니다).

PowerShell에서 (Android Studio에 들어 있는 `keytool` 사용):

```bash
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkey -v -keystore $env:USERPROFILE\whisky-library-upload.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

비밀번호와 이름 등을 묻습니다. 그다음 `android/key.properties.example`을 `android/key.properties`로 복사하고 비밀번호와 키 파일 경로를 채우세요.

## 2. 출시용 파일(AAB) 만들기

```bash
flutter build appbundle --release
```

결과: `build/app/outputs/bundle/release/app-release.aab`

먼저 폰에서 출시용으로 실행해 보는 것을 권합니다 (디버그와 동작이 다를 수 있음):

```bash
flutter run --release
```

## 3. Google Play Console

1. https://play.google.com/console 에서 개발자 계정 만들기 (1회 등록비 25달러, 신원 확인)
2. **앱 만들기** → 이름 `Whisky Library`, 기본 언어 한국어, 무료
3. **스토어 등록정보**: `store/LISTING.md`의 글과 `store/` 폴더 이미지 사용
   - 앱 아이콘: `store/icon_512.png`
   - 그래픽 이미지: `store/feature_graphic.jpg`
   - 휴대전화 스크린샷: `store/screenshots/screenshot_ko_*.jpg` (영어 등록정보에는 `_en_`)
4. **앱 콘텐츠**
   - 개인정보처리방침 URL: `store/PRIVACY.md` 내용을 웹에 올린 주소 (아래 참고)
   - 데이터 보안(Data safety): `store/LISTING.md`의 "데이터 보안 답변" 참고
   - 콘텐츠 등급 설문: 주류를 다루므로 **알코올 관련 항목에 "예"** 로 답하세요
   - 타겟층: 18세 이상 (주류 앱)
   - 광고: 없음
5. **테스트 → 비공개 테스트**에 AAB 업로드
   새로 만든 개인 개발자 계정은 프로덕션 출시 전에 비공개 테스트(테스터 여러 명, 일정 기간)를 거치도록 요구될 수 있습니다. Play Console의 안내를 따르세요.
6. 테스트가 끝나면 **프로덕션**으로 승격

### 개인정보처리방침 올리기 (무료)

가장 쉬운 방법은 GitHub Pages 또는 Google Sites에 `store/PRIVACY.md` 내용을 올리는 것입니다. 저장소를 공개하지 않으려면 Google Sites나 Notion 공개 페이지에 붙여 넣으면 됩니다.

## 4. iOS (나중에)

Mac에서 `ios/Runner.xcworkspace`를 Xcode로 열고 Apple 개발자 계정(연 99달러)으로 서명한 뒤 `flutter build ipa`. 아이콘과 시작 화면은 이미 준비돼 있습니다. 병 배경 지우기는 현재 안드로이드에서만 동작합니다.

## 스토어 이미지 다시 만들기

`store/source/`에 캡션 틀(`frame.html`), 그래픽 이미지(`feature.html`), 렌더 스크립트가 있습니다. 앱 아이콘 원본은 `assets/brand/*.svg`이고, 아이콘을 바꾼 뒤에는 아래 두 명령으로 다시 만듭니다.

```bash
dart run flutter_launcher_icons
```
```bash
dart run flutter_native_splash:create
```
