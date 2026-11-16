import 'package:material_ui/material_ui.dart';

import '../models/tasting_note.dart';
import '../theme.dart';
import 'color_scale.dart';

/// 병 모양 (종류마다 다르게 보여서 진열장에 변화가 생깁니다).
class BottleShape {
  const BottleShape({
    required this.neck,
    required this.shoulderTop,
    required this.shoulderBottom,
    required this.corner,
    required this.capColor,
    this.capBand,
  });

  /// 목 너비 (병 너비 대비)
  final double neck;

  /// 어깨가 시작/끝나는 높이 (병 높이 대비)
  final double shoulderTop;
  final double shoulderBottom;

  /// 몸통 아래 모서리 둥글기 (병 너비 대비)
  final double corner;
  final Color capColor;
  final Color? capBand;

  static const _classic = BottleShape(
    neck: 0.30,
    shoulderTop: 0.30,
    shoulderBottom: 0.44,
    corner: 0.12,
    capColor: Color(0xFF2A1A12),
    capBand: NoteColors.gold,
  );

  static BottleShape of(WhiskyType? type) => switch (type) {
    WhiskyType.singleMalt || null => _classic,
    WhiskyType.blended => const BottleShape(
      neck: 0.32,
      shoulderTop: 0.34,
      shoulderBottom: 0.42,
      corner: 0.08,
      capColor: Color(0xFF8C1C13),
      capBand: NoteColors.gold,
    ),
    WhiskyType.bourbon => const BottleShape(
      neck: 0.34,
      shoulderTop: 0.36,
      shoulderBottom: 0.40,
      corner: 0.04,
      capColor: Color(0xFF7A0E0E),
    ),
    WhiskyType.japanese => const BottleShape(
      neck: 0.26,
      shoulderTop: 0.26,
      shoulderBottom: 0.38,
      corner: 0.18,
      capColor: Color(0xFF111111),
      capBand: Color(0xFFBDBDBD),
    ),
    WhiskyType.world => const BottleShape(
      neck: 0.30,
      shoulderTop: 0.28,
      shoulderBottom: 0.46,
      corner: 0.22,
      capColor: Color(0xFF1F3A2A),
      capBand: NoteColors.gold,
    ),
  };
}

/// 진열장에 놓이는 위스키 병 한 개.
///
/// 액체 색은 노트의 색상 값(0.0~2.0)을 쓰고, 라벨에는 사진이 있으면 사진을,
/// 없으면 이름을 보여줍니다.
class WhiskyBottle extends StatelessWidget {
  const WhiskyBottle({
    super.key,
    required this.note,
    this.photo,
    this.width = 62,
    this.height = 150,
  });

  final TastingNote note;
  final ImageProvider? photo;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final shape = BottleShape.of(note.type);
    final liquid = whiskyColor(note.color ?? 0.8);
    final labelTop = height * (shape.shoulderBottom + 0.10);
    final labelHeight = height * 0.30;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _BottlePainter(shape: shape, liquid: liquid),
            ),
          ),
          Positioned(
            left: width * 0.10,
            right: width * 0.10,
            top: labelTop,
            height: labelHeight,
            child: _Label(note: note, photo: photo),
          ),
          // 라벨 위에도 유리 반사광이 지나가도록 한 번 더 그립니다.
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _GlassShinePainter(shape)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.note, this.photo});

  final TastingNote note;
  final ImageProvider? photo;

  @override
  Widget build(BuildContext context) {
    final p = photo;
    final Widget content = p != null
        ? Image(image: p, fit: BoxFit.cover, errorBuilder: (_, _, _) => _text())
        : _text();
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: Stack(
        fit: StackFit.expand,
        children: [
          content,
          // 둥근 병에 붙은 라벨처럼 양 끝을 어둡게.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0x66000000),
                  Color(0x00000000),
                  Color(0x00000000),
                  Color(0x77000000),
                ],
                stops: [0, 0.3, 0.65, 1],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _text() => Container(
    decoration: BoxDecoration(
      color: const Color(0xFFF3E6C8),
      border: Border.all(color: NoteColors.gold, width: 1),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
    alignment: Alignment.center,
    child: Text(
      note.name,
      textAlign: TextAlign.center,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 8,
        height: 1.1,
        fontWeight: FontWeight.bold,
        color: NoteColors.ink,
      ),
    ),
  );
}

/// 병의 외곽선 (뚜껑 아래부터 바닥까지).
Path _bottlePath(Size size, BottleShape s) {
  final w = size.width, h = size.height;
  final neckW = w * s.neck;
  final nl = (w - neckW) / 2, nr = nl + neckW;
  final capBottom = h * 0.10;
  final st = h * s.shoulderTop, sb = h * s.shoulderBottom;
  final r = w * s.corner;
  return Path()
    ..moveTo(nl, capBottom)
    ..lineTo(nr, capBottom)
    ..lineTo(nr, st)
    ..cubicTo(
      nr + (w - nr) * 0.15,
      st + (sb - st) * 0.55,
      w,
      st + (sb - st) * 0.45,
      w,
      sb,
    )
    ..lineTo(w, h - r)
    ..quadraticBezierTo(w, h, w - r, h)
    ..lineTo(r, h)
    ..quadraticBezierTo(0, h, 0, h - r)
    ..lineTo(0, sb)
    ..cubicTo(
      0,
      st + (sb - st) * 0.45,
      nl - nl * 0.15,
      st + (sb - st) * 0.55,
      nl,
      st,
    )
    ..close();
}

class _BottlePainter extends CustomPainter {
  _BottlePainter({required this.shape, required this.liquid});

  final BottleShape shape;
  final Color liquid;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final body = _bottlePath(size, shape);

    // 선반 위 그림자
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w / 2, h), width: w * 1.25, height: 10),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    canvas.save();
    canvas.clipPath(body);

    // 빈 유리 부분 (어두운 배경이 비쳐 보이는 느낌)
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.white.withValues(alpha: 0.10),
    );

    // 위스키 (가운데가 밝고 가장자리가 어두운 원통 음영)
    final level = h * (shape.shoulderBottom - 0.04);
    Color dark(double t) => Color.lerp(liquid, Colors.black, t)!;
    Color light(double t) => Color.lerp(liquid, Colors.white, t)!;
    canvas.drawRect(
      Rect.fromLTRB(0, level, w, h),
      Paint()
        ..shader = LinearGradient(
          colors: [dark(0.55), liquid, light(0.18), liquid, dark(0.6)],
          stops: const [0, 0.28, 0.42, 0.7, 1],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
    // 액체 표면
    canvas.drawRect(
      Rect.fromLTRB(0, level, w, level + 2),
      Paint()..color = light(0.35).withValues(alpha: 0.8),
    );
    // 바닥 유리 두께
    canvas.drawRect(
      Rect.fromLTRB(0, h - 5, w, h),
      Paint()..color = Colors.black.withValues(alpha: 0.25),
    );
    canvas.restore();

    // 외곽선
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.black.withValues(alpha: 0.6),
    );

    // 뚜껑
    final capW = w * shape.neck * 1.25;
    final cap = RRect.fromRectAndRadius(
      Rect.fromLTWH((w - capW) / 2, 0, capW, h * 0.11),
      const Radius.circular(2),
    );
    final c = shape.capColor;
    canvas.drawRRect(
      cap,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Color.lerp(c, Colors.black, 0.5)!,
            Color.lerp(c, Colors.white, 0.25)!,
            c,
            Color.lerp(c, Colors.black, 0.6)!,
          ],
          stops: const [0, 0.35, 0.6, 1],
        ).createShader(cap.outerRect),
    );
    final band = shape.capBand;
    if (band != null) {
      canvas.drawRect(
        Rect.fromLTWH(cap.left, cap.bottom - 4, capW, 2),
        Paint()..color = band.withValues(alpha: 0.9),
      );
    }
  }

  @override
  bool shouldRepaint(_BottlePainter old) =>
      old.liquid != liquid || old.shape != shape;
}

/// 유리 표면의 세로 반사광.
class _GlassShinePainter extends CustomPainter {
  _GlassShinePainter(this.shape);

  final BottleShape shape;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.save();
    canvas.clipPath(_bottlePath(size, shape));
    final top = h * 0.12;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(w * 0.16, top, w * 0.25, h - 8),
        const Radius.circular(4),
      ),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.55),
            Colors.white.withValues(alpha: 0.18),
            Colors.white.withValues(alpha: 0.05),
          ],
        ).createShader(Rect.fromLTRB(0, top, w, h)),
    );
    canvas.drawRect(
      Rect.fromLTRB(w * 0.80, h * shape.shoulderBottom, w * 0.84, h - 10),
      Paint()..color = Colors.white.withValues(alpha: 0.12),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlassShinePainter old) => old.shape != shape;
}

/// 진열장에 세우는 병. 배경을 지운 사진(cutout)이 있으면 실제 병 사진을,
/// 없으면 그린 병을 보여줍니다.
///
/// [reflection]이 0보다 크면 유리 선반에 비친 반사를 병 아래에 그립니다.
class BottleFigure extends StatelessWidget {
  const BottleFigure({
    super.key,
    required this.note,
    required this.cutout,
    required this.photo,
    required this.height,
    this.reflection = 0,
    this.reflectionOpacity = 0.22,
  });

  final TastingNote note;
  final ImageProvider? cutout;
  final ImageProvider? photo;
  final double height;
  final double reflection;
  final double reflectionOpacity;

  Widget _bottle() {
    final c = cutout;
    final drawn = WhiskyBottle(
      note: note,
      photo: photo,
      width: height * 0.41,
      height: height,
    );
    if (c == null) return drawn;
    return Image(
      image: c,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => drawn,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottle = _bottle();
    if (reflection <= 0) return bottle;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        bottle,
        // 병을 뒤집어 아래쪽만 흐리게 보여줍니다.
        SizedBox(
          height: reflection,
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.topCenter,
              maxHeight: height,
              child: IgnorePointer(
                child: Opacity(
                  opacity: reflectionOpacity,
                  child: Transform.flip(
                    flipY: true,
                    child: ShaderMask(
                      blendMode: BlendMode.dstIn,
                      shaderCallback: (r) => const LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.white, Colors.transparent],
                        stops: [0, 0.3],
                      ).createShader(r),
                      child: _bottle(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
