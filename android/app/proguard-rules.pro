# ML Kit 글자 인식 플러그인은 중국어/일본어/한국어/데바나가리 모델을 선택 사항으로
# 참조합니다. 이 앱은 라틴 문자 모델만 쓰므로, 릴리스 빌드(R8)에서 나머지 모델
# 클래스가 없다는 경고를 무시합니다.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
