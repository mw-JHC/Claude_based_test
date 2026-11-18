# 친구들에게 보낼 다운로드 링크 만들기 (안드로이드, 무료)

GitHub가 앱 파일(APK)을 직접 만들어서 아래 링크에 올립니다.

- 다운로드 페이지: https://github.com/mw-JHC/Claude_based_test/releases/latest
- APK 바로 받기: https://github.com/mw-JHC/Claude_based_test/releases/latest/download/WhiskyLibrary.apk

처음 한 번만 아래 1~3단계를 하면 됩니다. 그다음부터는 `main`에 앱을 고친 내용이 올라갈 때마다 새 버전이 같은 링크에 자동으로 올라갑니다.

## 1. 서명 키 만들기 (PC에서 한 번)

앱 업데이트는 **처음과 같은 키로 서명해야** 기존 앱 위에 설치됩니다. 이 키 파일과 비밀번호는 잃어버리지 않게 따로 백업해 두세요.
`RELEASE.md`를 보고 이미 `whisky-library-upload.jks`를 만들었다면 그 키를 그대로 쓰고 2단계로 넘어가세요.

PowerShell에서:

```powershell
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkey -v -keystore $env:USERPROFILE\whisky-library-upload.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

- 키스토어 비밀번호를 두 번 묻고, 이름과 지역 같은 정보를 묻습니다. 아무 값이나 넣어도 됩니다.
- 마지막에 키 비밀번호를 물으면 그냥 Enter를 누르세요. 키스토어 비밀번호와 같은 비밀번호가 됩니다.
- `keytool.exe`를 찾을 수 없다고 나오면 `flutter doctor -v` 결과에서 `Java binary at:` 줄의 폴더에 있는 `keytool.exe` 경로로 바꿔서 실행하세요.

## 2. GitHub에 키 넣기 (Secrets)

키 파일을 글자로 바꿔 클립보드에 복사합니다:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("$env:USERPROFILE\whisky-library-upload.jks")) | Set-Clipboard
```

https://github.com/mw-JHC/Claude_based_test/settings/secrets/actions 에서 **New repository secret**을 눌러 아래 값을 하나씩 넣습니다.

| Name | Secret (값) |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | 방금 복사한 긴 글자 (Ctrl+V) |
| `ANDROID_STORE_PASSWORD` | 1단계의 키스토어 비밀번호 |
| `ANDROID_KEY_PASSWORD` | 키 비밀번호. 1단계에서 Enter를 눌렀다면 키스토어 비밀번호와 같은 값 |
| `ANDROID_KEY_ALIAS` | `upload` |

Secrets는 저장소가 공개여도 다른 사람에게 보이지 않습니다. 키 파일(`.jks`)은 git에 올라가지 않게 막혀 있습니다.

## 3. 첫 버전 만들기

https://github.com/mw-JHC/Claude_based_test/actions/workflows/android-apk.yml 에서 **Run workflow → Run workflow**를 누릅니다.
10~15분 뒤 초록색 체크가 뜨면 위 링크에 APK가 올라와 있습니다.

## 친구들에게 보낼 메시지 (예시)

> 내가 만든 위스키 기록 앱이야 🥃 (안드로이드만 가능)
> https://github.com/mw-JHC/Claude_based_test/releases/latest/download/WhiskyLibrary.apk
> 1. 링크를 눌러 받은 파일을 열어.
> 2. "출처를 알 수 없는 앱" 설치를 허용해 줘.
> 3. Play 프로텍트 경고가 뜨면 "세부정보 → 무시하고 설치"를 누르면 돼.
> 새 버전이 나오면 같은 링크로 다시 설치하면 기록은 그대로 남아.

## 알아 둘 점

- **아이폰은 이 방법으로 설치할 수 없습니다.** 애플 개발자 계정과 TestFlight가 필요합니다.
- 각자의 기록은 각자의 폰에만 저장됩니다. 친구들끼리 공유되지 않습니다.
- 나중에 구글 플레이에 정식으로 올리면 플레이 버전은 서명이 달라서 이 APK 위에 바로 업데이트되지 않습니다. 그때는 설정 → 백업으로 기록을 저장하고, 앱을 지운 다음 플레이에서 설치하고 복원하면 됩니다.
- 빌드가 빨간 X로 실패하면 Actions 탭에서 실패한 단계를 열어 로그를 확인하세요. 위의 서명 키 값이 틀린 경우가 많습니다.
