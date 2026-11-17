import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../models/tasting_note.dart';
import '../theme.dart';
import 'color_scale.dart';

/// 병 마개 종류
enum Closure {
  /// 나무 머리 + 코르크 (싱글 몰트에 흔함)
  woodStopper,

  /// 금속 돌림 마개
  screwCap,
}

/// 라벨 색 조합
enum LabelStyle { cream, black, white, kraft }

/// 병 모양과 꾸밈. 종류마다 다르게 보여서 진열장에 변화가 생깁니다.
class BottleShape {
  const BottleShape({
    required this.body,
    required this.neck,
    required this.shoulderTop,
    required this.shoulderBottom,
    required this.corner,
    required this.shoulder,
    required this.closure,
    required this.capColor,
    required this.capsuleColor,
    required this.label,
    this.glassTint = const Color(0xFFE8F0EC),
    this.collar = true,
  });

  /// 몸통 너비 (그림 너비 대비, 1이면 꽉 참)
  final double body;

  /// 목 너비 (그림 너비 대비)
  final double neck;

  /// 어깨가 시작/끝나는 높이 (병 높이 대비)
  final double shoulderTop;
  final double shoulderBottom;

  /// 몸통 아래 모서리 둥글기 (그림 너비 대비)
  final double corner;

  /// 어깨 곡선: (목에서 옆으로 나가는 정도, 처음 내려가는 정도, 몸통에 닿기 전 둥글기)
  final (double, double, double) shoulder;

  final Closure closure;

  /// 마개 머리 색 (나무/금속)
  final Color capColor;

  /// 목을 감싼 포일 색
  final Color capsuleColor;
  final LabelStyle label;

  /// 유리 색 (투명 유리도 아주 살짝 초록빛)
  final Color glassTint;

  /// 목에 두르는 작은 띠 라벨
  final bool collar;

  static const _round = (0.62, 0.0, 0.6);
  static const _square = (0.9, 0.06, 0.02);
  static const _sloped = (0.3, 0.45, 0.35);

  /// 클래식 싱글 몰트: 둥근 어깨, 나무 마개, 크림색 라벨
  static const _classic = BottleShape(
    body: 0.94,
    neck: 0.30,
    shoulderTop: 0.30,
    shoulderBottom: 0.44,
    corner: 0.10,
    shoulder: _round,
    closure: Closure.woodStopper,
    capColor: Color(0xFF5A3720),
    capsuleColor: Color(0xFF2A1A12),
    label: LabelStyle.cream,
  );

  /// 각진 병 (아메리칸, 블렌디드 그레인): 짧은 목, 종이색 라벨
  static const _squareBottle = BottleShape(
    body: 0.98,
    neck: 0.30,
    shoulderTop: 0.33,
    shoulderBottom: 0.38,
    corner: 0.03,
    shoulder: _square,
    closure: Closure.woodStopper,
    capColor: Color(0xFF3B2416),
    capsuleColor: Color(0xFF7A1418),
    label: LabelStyle.kraft,
  );

  /// 아메리칸 위스키는 각진 병, 나머지는 종류에 따라 모양을 고릅니다.
  static BottleShape of(WhiskyType? type, [WhiskyOrigin? origin]) =>
      origin == WhiskyOrigin.american ? _squareBottle : _ofType(type);

  static BottleShape _ofType(WhiskyType? type) => switch (type) {
    WhiskyType.singleMalt || null => _classic,
    // 블렌디드: 각진 어깨, 금속 마개, 검정 라벨
    WhiskyType.blended => const BottleShape(
      body: 0.96,
      neck: 0.32,
      shoulderTop: 0.33,
      shoulderBottom: 0.41,
      corner: 0.06,
      shoulder: (0.6, 0.2, 0.15),
      closure: Closure.screwCap,
      capColor: Color(0xFF8A7650),
      capsuleColor: Color(0xFF8A7650),
      label: LabelStyle.black,
      collar: false,
    ),
    WhiskyType.blendedGrain => _squareBottle,
    // 싱글 그레인: 길고 가는 목, 비스듬한 어깨, 흰 라벨
    WhiskyType.singleGrain => const BottleShape(
      body: 0.86,
      neck: 0.26,
      shoulderTop: 0.26,
      shoulderBottom: 0.46,
      corner: 0.12,
      shoulder: _sloped,
      closure: Closure.screwCap,
      capColor: Color(0xFF1B1B1E),
      capsuleColor: Color(0xFF1B1B1E),
      label: LabelStyle.white,
      collar: false,
    ),
    // 블렌디드 몰트: 넓적한 플라스크, 초록빛 유리
    WhiskyType.blendedMalt => const BottleShape(
      body: 1.0,
      neck: 0.28,
      shoulderTop: 0.30,
      shoulderBottom: 0.47,
      corner: 0.22,
      shoulder: _round,
      closure: Closure.woodStopper,
      capColor: Color(0xFF6B4528),
      capsuleColor: Color(0xFF1F3A2A),
      label: LabelStyle.cream,
      glassTint: Color(0xFFB9D8B8),
    ),
  };
}

/// 진열장에 놓이는 위스키 병 한 개 (그린 병).
///
/// 액체 색은 노트의 색상 값을 쓰고, 라벨에는 사진이 있으면 사진을,
/// 없으면 이름과 숙성 연수, 종류를 인쇄한 것처럼 보여줍니다.
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
    final shape = BottleShape.of(note.type, note.origin);
    final liquid = whiskyColor(note.color ?? 0.4);
    final bodyW = width * shape.body;
    final labelTop = height * (shape.shoulderBottom + 0.08);
    final labelHeight = height * 0.32;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _BottlePainter(
                shape: shape,
                liquid: liquid,
                empty: note.isEmpty,
              ),
            ),
          ),
          Positioned(
            left: (width - bodyW) / 2 + bodyW * 0.09,
            right: (width - bodyW) / 2 + bodyW * 0.09,
            top: labelTop,
            height: labelHeight,
            child: _Label(
              note: note,
              photo: photo,
              style: shape.label,
              // 작은 병(목록 썸네일)에는 글자가 읽히지 않으니 무늬만
              scale: height < 110 ? null : height / 150,
            ),
          ),
          // 라벨 위로도 유리 반사광이 지나갑니다.
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

/// 병에 붙은 종이 라벨 (둥근 병이라 양끝이 어둡게 휘어 보임).
class _Label extends StatelessWidget {
  const _Label({
    required this.note,
    required this.style,
    this.photo,
    this.scale,
  });

  final TastingNote note;
  final LabelStyle style;
  final ImageProvider? photo;

  /// 글자 크기 배율. null이면 글자 없이 무늬만.
  final double? scale;

  (Color paper, Color ink, Color accent) get _colors => switch (style) {
    LabelStyle.cream => (
      const Color(0xFFF2E3C2),
      const Color(0xFF2A1A0E),
      const Color(0xFFB4873A),
    ),
    LabelStyle.black => (
      const Color(0xFF15120F),
      const Color(0xFFE9CF8E),
      const Color(0xFFC9A14E),
    ),
    LabelStyle.white => (
      const Color(0xFFF7F5F0),
      const Color(0xFF1D1D1F),
      const Color(0xFF9A9A9A),
    ),
    LabelStyle.kraft => (
      const Color(0xFFD9C29A),
      const Color(0xFF3A1F10),
      const Color(0xFF8E2A1E),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final p = photo;
    final Widget content = p != null
        ? Image(
            image: p,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _printed(),
          )
        : _printed();
    return ClipRRect(
      borderRadius: BorderRadius.circular(1.5),
      child: Stack(
        fit: StackFit.expand,
        children: [
          content,
          // 둥근 병에 붙은 라벨: 양 끝으로 갈수록 어둡게, 가운데 은은한 빛
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0x88000000),
                  Color(0x1A000000),
                  Color(0x0DFFFFFF),
                  Color(0x00000000),
                  Color(0x26000000),
                  Color(0x99000000),
                ],
                stops: [0, 0.16, 0.38, 0.6, 0.82, 1],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 인쇄된 라벨: 테두리 두 줄, 이름(세리프), 가는 선, 숙성 연수와 종류.
  Widget _printed() {
    final (paper, ink, accent) = _colors;
    final k = scale;
    final age = RegExp(r'(\d{1,2})').firstMatch(note.ageCask)?.group(1);
    // 라벨에는 숙성 연수를 따로 크게 쓰니 이름 끝의 숫자는 뺍니다.
    final name = note.name
        .replaceAll(
          RegExp(r'\s+\d{1,2}\s*(y(ea)?rs?( old)?|yo)?$', caseSensitive: false),
          '',
        )
        .toUpperCase();
    // 가장 긴 단어가 한 줄에 들어가는 크기 (단어 중간에서 끊기지 않게)
    final longest = name
        .split(RegExp(r'\s+'))
        .fold(1, (m, w) => math.max(m, w.length));
    double nameSize(double width) =>
        math.min(7.5 * (k ?? 1), (width - 4) / (longest * 0.78));
    return Container(
      color: paper,
      padding: const EdgeInsets.all(1.6),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: accent, width: 0.8),
        ),
        padding: const EdgeInsets.all(1.2),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: accent.withValues(alpha: 0.6),
              width: 0.4,
            ),
          ),
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(
            horizontal: 2,
            vertical: k == null ? 0 : 2 * k,
          ),
          child: k == null
              // 글자 대신 인쇄된 줄 무늬만
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 2.5,
                      width: 18,
                      color: ink.withValues(alpha: 0.7),
                    ),
                    const SizedBox(height: 3),
                    Container(height: 1, width: 12, color: accent),
                  ],
                )
              // 라벨 너비에 맞춰 이름은 두 줄까지 줄바꿈, 넘치면 전체를 조금 줄임
              : LayoutBuilder(
                  builder: (context, box) => FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizedBox(
                      width: math.max(1.0, box.maxWidth),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            name,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: serif,
                              fontWeight: FontWeight.w700,
                              fontSize: nameSize(box.maxWidth),
                              height: 1.05,
                              letterSpacing: 0.2 * k,
                              color: ink,
                            ),
                          ),
                          SizedBox(height: 2.5 * k),
                          Container(height: 0.6, width: 22 * k, color: accent),
                          if (age != null) ...[
                            SizedBox(height: 2 * k),
                            Text(
                              age,
                              style: TextStyle(
                                fontFamily: serif,
                                fontWeight: FontWeight.w700,
                                fontSize: 13 * k,
                                height: 1,
                                color: accent,
                              ),
                            ),
                            Text(
                              'YEARS OLD',
                              style: TextStyle(
                                fontSize: 3.4 * k,
                                letterSpacing: 0.8 * k,
                                fontWeight: FontWeight.w700,
                                color: ink.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                          if (note.type != null) ...[
                            SizedBox(height: 2 * k),
                            Text(
                              note.type!.label.toUpperCase(),
                              style: TextStyle(
                                fontSize: 3.6 * k,
                                letterSpacing: 0.6 * k,
                                fontWeight: FontWeight.w600,
                                color: ink.withValues(alpha: 0.75),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

/// 병의 겉모양. [inset]만큼 안쪽으로 줄이면 유리 두께 안쪽(액체가 차는 곳).
Path _bottlePath(Size size, BottleShape s, {double inset = 0}) {
  final w = size.width, h = size.height;
  final bw = w * s.body;
  final l = (w - bw) / 2 + inset, r = (w + bw) / 2 - inset;
  final neckW = w * s.neck - inset * 2;
  final nl = (w - neckW) / 2, nr = nl + neckW;
  final top = h * 0.085 + inset;
  final st = h * s.shoulderTop, sb = h * s.shoulderBottom;
  final bottom = h - inset * 1.8; // 바닥 유리는 더 두꺼움
  final c = math.max(0.0, w * s.corner - inset);
  final (a, b, d) = s.shoulder;
  return Path()
    ..moveTo(nl, top)
    ..lineTo(nr, top)
    ..lineTo(nr, st)
    ..cubicTo(
      nr + (r - nr) * a,
      st + (sb - st) * b,
      r,
      st + (sb - st) * (1 - d),
      r,
      sb,
    )
    ..lineTo(r, bottom - c)
    ..quadraticBezierTo(r, bottom, r - c, bottom)
    ..lineTo(l + c, bottom)
    ..quadraticBezierTo(l, bottom, l, bottom - c)
    ..lineTo(l, sb)
    ..cubicTo(
      l,
      st + (sb - st) * (1 - d),
      nl - (nl - l) * a,
      st + (sb - st) * b,
      nl,
      st,
    )
    ..close();
}

class _BottlePainter extends CustomPainter {
  _BottlePainter({
    required this.shape,
    required this.liquid,
    this.empty = false,
  });

  final BottleShape shape;
  final Color liquid;

  /// 빈 병이면 바닥에 마지막 한 모금만 남깁니다.
  final bool empty;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final s = shape;
    final bw = w * s.body;
    final bl = (w - bw) / 2, br = bl + bw;
    final glass = math.max(1.2, w * 0.045); // 유리 두께
    final outer = _bottlePath(size, s);
    final inner = _bottlePath(size, s, inset: glass);
    Color dark(Color c, double t) => Color.lerp(c, Colors.black, t)!;
    Color light(Color c, double t) => Color.lerp(c, Colors.white, t)!;

    // ── 선반 위 그림자와, 위스키를 통과한 빛이 선반에 맺힌 따뜻한 빛
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w / 2, h),
        width: bw * 1.3,
        height: h * 0.05,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.6)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.06),
    );
    if (!empty) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(w / 2 + bw * 0.08, h + h * 0.012),
          width: bw * 0.9,
          height: h * 0.035,
        ),
        Paint()
          ..color = light(liquid, 0.2).withValues(alpha: 0.35)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.05),
      );
    }

    // ── 유리 (빈 부분은 뒤 배경이 비치는 옅은 색)
    canvas.drawPath(
      outer,
      Paint()
        ..shader = LinearGradient(
          colors: [
            s.glassTint.withValues(alpha: 0.22),
            s.glassTint.withValues(alpha: 0.08),
            s.glassTint.withValues(alpha: 0.05),
            s.glassTint.withValues(alpha: 0.18),
          ],
          stops: const [0, 0.3, 0.7, 1],
        ).createShader(Rect.fromLTRB(bl, 0, br, h)),
    );

    // ── 위스키
    final level = empty
        ? h - glass * 1.8 - h * 0.035
        : h * (s.shoulderBottom - 0.035);
    final menH = math.max(2.0, bw * 0.09); // 위에서 내려다본 액면 타원 높이
    canvas.save();
    canvas.clipPath(inner);
    final liquidRect = Rect.fromLTRB(0, level, w, h);
    // 원통 음영: 가장자리 어둡고, 왼쪽 가운데 밝게
    canvas.drawRect(
      liquidRect,
      Paint()
        ..shader = LinearGradient(
          colors: [
            dark(liquid, 0.55),
            dark(liquid, 0.1),
            light(liquid, 0.22),
            liquid,
            dark(liquid, 0.25),
            dark(liquid, 0.65),
          ],
          stops: const [0, 0.14, 0.32, 0.55, 0.82, 1],
        ).createShader(Rect.fromLTRB(bl, 0, br, h)),
    );
    // 깊을수록 진하게
    canvas.drawRect(
      liquidRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.08),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.28),
          ],
          stops: const [0, 0.35, 1],
        ).createShader(liquidRect),
    );
    // 액면: 위에서 살짝 내려다본 타원
    final surface = Rect.fromCenter(
      center: Offset(w / 2, level),
      width: bw,
      height: menH,
    );
    canvas.drawOval(
      surface,
      Paint()
        ..shader = LinearGradient(
          colors: [dark(liquid, 0.2), light(liquid, 0.35), dark(liquid, 0.15)],
        ).createShader(surface),
    );
    canvas.drawArc(
      surface,
      0.15,
      math.pi - 0.3,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.8, w * 0.015)
        ..color = light(liquid, 0.6).withValues(alpha: 0.8),
    );
    canvas.restore();

    // ── 두꺼운 바닥 유리 (안쪽이 오목하게 비침)
    final baseTop = h - glass * 1.8;
    final base = Rect.fromLTRB(bl + glass, baseTop - h * 0.012, br - glass, h);
    canvas.save();
    canvas.clipPath(outer);
    canvas.drawRect(
      Rect.fromLTRB(bl, baseTop, br, h),
      Paint()
        ..color = (empty ? s.glassTint : dark(liquid, 0.3)).withValues(
          alpha: 0.35,
        ),
    );
    canvas.drawArc(
      base,
      math.pi * 1.1,
      math.pi * 0.8,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.6, w * 0.012)
        ..color = Colors.white.withValues(alpha: 0.35),
    );
    canvas.restore();

    // ── 유리 가장자리: 두께가 보이도록 안쪽 테두리를 밝게
    canvas.drawPath(
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.6, w * 0.012)
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.35),
            Colors.white.withValues(alpha: 0.05),
            Colors.white.withValues(alpha: 0.2),
          ],
        ).createShader(Rect.fromLTRB(bl, 0, br, h)),
    );
    canvas.drawPath(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.8, w * 0.016)
        ..color = Colors.black.withValues(alpha: 0.55),
    );

    // ── 목 띠 라벨
    final neckW = w * s.neck;
    final nl = (w - neckW) / 2;
    if (s.collar) {
      final cy = h * (s.shoulderTop - 0.035);
      final collar = Rect.fromLTWH(
        nl - 0.5,
        cy - h * 0.022,
        neckW + 1,
        h * 0.044,
      );
      canvas.drawRect(
        collar,
        Paint()
          ..shader = LinearGradient(
            colors: [
              dark(s.capsuleColor, 0.4),
              light(s.capsuleColor, 0.25),
              s.capsuleColor,
              dark(s.capsuleColor, 0.5),
            ],
            stops: const [0, 0.35, 0.6, 1],
          ).createShader(collar),
      );
      canvas.drawRect(
        Rect.fromLTWH(collar.left, collar.center.dy - 0.4, collar.width, 0.8),
        Paint()..color = NoteColors.gold.withValues(alpha: 0.9),
      );
    }

    // ── 마개
    _closure(canvas, size, nl, neckW);
  }

  void _closure(Canvas canvas, Size size, double nl, double neckW) {
    final w = size.width, h = size.height;
    final s = shape;
    Color dark(Color c, double t) => Color.lerp(c, Colors.black, t)!;
    Color light(Color c, double t) => Color.lerp(c, Colors.white, t)!;
    LinearGradient metal(Color c) => LinearGradient(
      colors: [dark(c, 0.55), light(c, 0.45), c, dark(c, 0.2), dark(c, 0.65)],
      stops: const [0, 0.25, 0.45, 0.75, 1],
    );

    // 목을 감싼 포일 (마개 바로 아래)
    final foilTop = h * 0.085;
    final foilBottom = h * (s.closure == Closure.woodStopper ? 0.16 : 0.13);
    final foil = Rect.fromLTRB(nl - 0.6, foilTop, nl + neckW + 0.6, foilBottom);
    canvas.drawRect(
      foil,
      Paint()..shader = metal(s.capsuleColor).createShader(foil),
    );
    canvas.drawRect(
      Rect.fromLTWH(foil.left, foil.bottom - 1, foil.width, 1),
      Paint()..color = dark(s.capsuleColor, 0.6),
    );

    if (s.closure == Closure.woodStopper) {
      // 나무 머리: 목보다 넓고 위가 둥금
      final headW = neckW * 1.32;
      final head = RRect.fromRectAndCorners(
        Rect.fromLTWH((w - headW) / 2, 0, headW, h * 0.09),
        topLeft: Radius.circular(headW * 0.18),
        topRight: Radius.circular(headW * 0.18),
        bottomLeft: const Radius.circular(1),
        bottomRight: const Radius.circular(1),
      );
      canvas.drawRRect(
        head,
        Paint()
          ..shader = LinearGradient(
            colors: [
              dark(s.capColor, 0.5),
              light(s.capColor, 0.25),
              s.capColor,
              dark(s.capColor, 0.55),
            ],
            stops: const [0, 0.3, 0.6, 1],
          ).createShader(head.outerRect),
      );
      // 나뭇결
      final grain = Paint()
        ..color = dark(s.capColor, 0.45).withValues(alpha: 0.5)
        ..strokeWidth = 0.5;
      for (var i = 1; i < 4; i++) {
        final x = head.left + head.width * i / 4;
        canvas.drawLine(
          Offset(x, head.top + 2),
          Offset(x + 0.6, head.bottom - 1),
          grain,
        );
      }
      // 머리 아래 그림자 띠
      canvas.drawRect(
        Rect.fromLTWH(head.left, head.bottom - 1.2, head.width, 1.2),
        Paint()..color = Colors.black.withValues(alpha: 0.45),
      );
    } else {
      // 금속 돌림 마개: 세로 홈
      final capW = neckW * 1.12;
      final cap = RRect.fromRectAndRadius(
        Rect.fromLTWH((w - capW) / 2, h * 0.005, capW, h * 0.1),
        const Radius.circular(1.5),
      );
      canvas.drawRRect(
        cap,
        Paint()..shader = metal(s.capColor).createShader(cap.outerRect),
      );
      final ridge = Paint()
        ..color = Colors.black.withValues(alpha: 0.28)
        ..strokeWidth = 0.5;
      final n = math.max(4, (capW / 2.2).floor());
      for (var i = 1; i < n; i++) {
        final x = cap.left + cap.width * i / n;
        canvas.drawLine(
          Offset(x, cap.top + 1.5),
          Offset(x, cap.bottom - 1),
          ridge,
        );
      }
      canvas.drawRect(
        Rect.fromLTWH(cap.left, cap.top, cap.width, 1.2),
        Paint()..color = Colors.white.withValues(alpha: 0.35),
      );
    }
  }

  @override
  bool shouldRepaint(_BottlePainter old) =>
      old.liquid != liquid || old.shape != shape || old.empty != empty;
}

/// 유리 표면의 반사광: 왼쪽 넓은 빛과 가는 선, 어깨의 둥근 빛, 오른쪽 가장자리 빛,
/// 창문이 비친 듯한 작은 사각 빛. 라벨 위에도 덮입니다.
class _GlassShinePainter extends CustomPainter {
  _GlassShinePainter(this.shape);

  final BottleShape shape;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final s = shape;
    final bw = w * s.body;
    final bl = (w - bw) / 2;
    final sb = h * s.shoulderBottom;
    canvas.save();
    canvas.clipPath(_bottlePath(size, s));

    // 왼쪽 넓고 부드러운 빛
    final soft = Rect.fromLTRB(
      bl + bw * 0.1,
      sb - h * 0.02,
      bl + bw * 0.24,
      h - h * 0.05,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(soft, Radius.circular(bw * 0.07)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.32),
            Colors.white.withValues(alpha: 0.12),
            Colors.white.withValues(alpha: 0.02),
          ],
        ).createShader(soft)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, bw * 0.03),
    );
    // 날카로운 가는 빛
    canvas.drawRect(
      Rect.fromLTRB(bl + bw * 0.135, sb, bl + bw * 0.155, h * 0.9),
      Paint()..color = Colors.white.withValues(alpha: 0.55),
    );
    // 어깨의 둥근 빛
    final neckW = w * s.neck;
    canvas.drawArc(
      Rect.fromLTRB(
        bl + bw * 0.08,
        h * s.shoulderTop,
        w / 2 + neckW * 0.2,
        sb + h * 0.06,
      ),
      math.pi * 1.05,
      math.pi * 0.35,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, bw * 0.035)
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.42),
    );
    // 목의 세로 빛
    final nl = (w - neckW) / 2;
    canvas.drawRect(
      Rect.fromLTRB(
        nl + neckW * 0.18,
        h * 0.17,
        nl + neckW * 0.3,
        h * s.shoulderTop,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.3),
    );
    // 오른쪽 가장자리 빛 (뒤에서 오는 조명)
    canvas.drawRect(
      Rect.fromLTRB(bl + bw * 0.86, sb + h * 0.02, bl + bw * 0.885, h * 0.93),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.8),
    );
    // 창문이 비친 듯한 작은 사각 빛
    final win = Rect.fromLTWH(
      bl + bw * 0.66,
      sb + h * 0.04,
      bw * 0.08,
      h * 0.07,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(win, const Radius.circular(1)),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.13)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.6),
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
    final image = Image(
      image: c,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => drawn,
    );
    if (!note.isEmpty) return image;
    // 빈 병 사진은 바랜 추억처럼 색을 빼고 살짝 투명하게.
    return Opacity(
      opacity: 0.85,
      child: ColorFiltered(colorFilter: _faded, child: image),
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

/// 채도를 낮추고 따뜻한 세피아 기운을 더하는 색 필터.
const _faded = ColorFilter.matrix(<double>[
  0.50, 0.40, 0.10, 0, 12, //
  0.35, 0.55, 0.10, 0, 6, //
  0.25, 0.35, 0.40, 0, 0, //
  0, 0, 0, 1, 0, //
]);
