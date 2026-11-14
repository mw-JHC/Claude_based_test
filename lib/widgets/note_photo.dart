import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// 노트 사진. 파일이 없으면 위스키 잔 아이콘을 보여줍니다.
class NotePhoto extends StatelessWidget {
  const NotePhoto({
    super.key,
    this.file,
    this.fit = BoxFit.cover,
    this.icon = 48,
  });

  final File? file;
  final BoxFit fit;
  final double icon;

  @override
  Widget build(BuildContext context) {
    final f = file;
    final placeholder = Container(
      color: NoteColors.paper,
      alignment: Alignment.center,
      child: Icon(Icons.local_bar, size: icon, color: NoteColors.hint),
    );
    if (f == null) return placeholder;
    return Image.file(f, fit: fit, errorBuilder: (_, _, _) => placeholder);
  }
}
