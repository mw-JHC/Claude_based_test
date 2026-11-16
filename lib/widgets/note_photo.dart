import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// 노트 사진. 이미지가 없으면 위스키 잔 아이콘을 보여줍니다.
///
/// [cutout]이 true면 배경을 지운 병 사진으로 보고, 어두운 조명 배경 위에
/// 잘리지 않게(contain) 세워서 보여줍니다.
class NotePhoto extends StatelessWidget {
  const NotePhoto({
    super.key,
    this.image,
    this.cutout = false,
    this.fit = BoxFit.cover,
    this.icon = 48,
  });

  final ImageProvider? image;
  final bool cutout;
  final BoxFit fit;
  final double icon;

  @override
  Widget build(BuildContext context) {
    final img = image;
    final placeholder = Container(
      color: NoteColors.paper,
      alignment: Alignment.center,
      child: Icon(Icons.local_bar, size: icon, color: NoteColors.hint),
    );
    if (img == null) return placeholder;
    if (!cutout) {
      return Image(
        image: img,
        fit: fit,
        errorBuilder: (_, _, _) => placeholder,
      );
    }
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.4),
          radius: 1.0,
          colors: [Color(0xFF5A3A22), Color(0xFF1E120A)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Image(
          image: img,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => placeholder,
        ),
      ),
    );
  }
}
