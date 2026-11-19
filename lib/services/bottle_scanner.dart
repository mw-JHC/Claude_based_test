import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_subject_segmentation/google_mlkit_subject_segmentation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'label_parser.dart';

/// 병 사진에서 배경을 지우고(병만 오려내기) 라벨 글자를 읽습니다.
abstract class BottleScanner {
  /// 병만 오려낸 투명 배경 PNG. 지원하지 않는 기기이거나 실패하면 null.
  Future<Uint8List?> cutout(String imagePath);

  /// 라벨 글자. 실패하면 빈 목록.
  Future<List<OcrLine>> readText(String imagePath);
}

/// 구글 ML Kit을 쓰는 실제 구현. 폰 안에서 처리되고 사진이 밖으로 나가지 않습니다.
///
/// 배경 제거는 현재 안드로이드에서만 됩니다 (iOS에서는 null을 돌려줘서
/// 원본 사진을 쓰게 됩니다).
class MlKitBottleScanner implements BottleScanner {
  const MlKitBottleScanner();

  @override
  Future<Uint8List?> cutout(String imagePath) async {
    final segmenter = SubjectSegmenter(
      options: SubjectSegmenterOptions(
        enableForegroundBitmap: false,
        enableForegroundConfidenceMask: false,
        enableMultipleSubjects: SubjectResultOptions(
          enableConfidenceMask: false,
          enableSubjectBitmap: true,
        ),
      ),
    );
    try {
      // 폰에서 처음 쓰면 구글 서비스가 배경 제거 모듈을 내려받는 동안
      // "기다려 주세요" 오류가 나서, 잠깐씩 기다리며 몇 번 다시 해 봅니다.
      for (var attempt = 0; ; attempt++) {
        try {
          final result = await segmenter.processImage(
            InputImage.fromFilePath(imagePath),
          );
          return pickBottle(result.subjects)?.bitmap;
        } on PlatformException catch (e) {
          debugPrint('배경 제거 실패: ${e.code} ${e.message}');
          final text = '${e.code} ${e.message}'.toLowerCase();
          final downloading =
              text.contains('download') || text.contains('wait');
          if (!downloading || attempt >= 4) return null;
          await Future<void>.delayed(const Duration(seconds: 3));
        }
      }
    } on MissingPluginException {
      return null;
    } finally {
      await segmenter.close().catchError((_) {});
    }
  }

  @override
  Future<List<OcrLine>> readText(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final text = await recognizer.processImage(
        InputImage.fromFilePath(imagePath),
      );
      return [
        for (final block in text.blocks)
          for (final line in block.lines)
            OcrLine(line.text, line.boundingBox.height),
      ];
    } on MissingPluginException {
      return const [];
    } on PlatformException catch (e) {
      debugPrint('글자 인식 실패: ${e.code} ${e.message}');
      return const [];
    } finally {
      await recognizer.close().catchError((_) {});
    }
  }

  /// 사진에 여러 물체(컵, 키보드 …)가 잡혔을 때 병을 고릅니다.
  /// 세로로 길고 큰 물체일수록 병일 가능성이 높습니다.
  @visibleForTesting
  static Subject? pickBottle(List<Subject> subjects) {
    Subject? best;
    var bestScore = 0.0;
    for (final s in subjects) {
      if (s.bitmap == null) continue;
      final area = (s.width * s.height).toDouble();
      final tall = s.height > s.width * 1.2 ? 2.0 : 1.0;
      final score = area * tall;
      if (score > bestScore) {
        best = s;
        bestScore = score;
      }
    }
    return best;
  }
}
