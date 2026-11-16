import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/physics.dart';
import 'package:material_ui/material_ui.dart';

import '../data/app_settings.dart';
import '../data/note_store.dart';
import '../models/tasting_note.dart';
import '../theme.dart';
import 'whisky_bottle.dart';

/// 위스키를 진열장에 세워서 보여주는 화면. [style]에 따라 분위기가 바뀝니다.
///
/// 좌우로 끌면 진열장이 원근감 있게 살짝 돌아가고, 손을 떼면
/// 스프링처럼 제자리로 돌아옵니다. 병을 누르면 [onOpen]이 불립니다.
class CabinetView extends StatefulWidget {
  const CabinetView({
    super.key,
    required this.store,
    required this.notes,
    required this.onOpen,
    this.style = CabinetStyle.woodShop,
    this.emptyMessage,
  });

  final NoteStore store;
  final List<TastingNote> notes;
  final void Function(TastingNote note) onOpen;
  final CabinetStyle style;

  /// 진열할 병이 없을 때 진열장 위에 띄울 안내.
  final Widget? emptyMessage;

  @override
  State<CabinetView> createState() => _CabinetViewState();
}

class _CabinetViewState extends State<CabinetView>
    with SingleTickerProviderStateMixin {
  static const _maxTilt = 0.32;

  late final AnimationController _tilt = AnimationController.unbounded(
    vsync: this,
  )..addListener(() => setState(() {}));

  @override
  void dispose() {
    _tilt.dispose();
    super.dispose();
  }

  void _drag(DragUpdateDetails d) {
    _tilt.stop();
    _tilt.value = (_tilt.value + d.delta.dx * 0.004).clamp(-_maxTilt, _maxTilt);
  }

  void _release(DragEndDetails d) {
    _tilt.animateWith(
      SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 140, damping: 9),
        _tilt.value,
        0,
        (d.primaryVelocity ?? 0) * 0.004,
      ),
    );
  }

  /// 한 줄에 [perRow]병씩 나눈 줄 목록. 빈 진열장도 보기 좋게 최소 [minRows]줄.
  List<List<TastingNote>> _rows(int perRow, int minRows) {
    final notes = widget.notes;
    final count = math.max(minRows, (notes.length / perRow).ceil());
    return [
      for (var r = 0; r < count; r++)
        notes.sublist(
          math.min(r * perRow, notes.length),
          math.min((r + 1) * perRow, notes.length),
        ),
    ];
  }

  Widget _bottle(TastingNote note, double height, {double reflection = 0}) =>
      _PressableBottle(
        label: note.name,
        onTap: () => widget.onOpen(note),
        child: BottleFigure(
          note: note,
          cutout: widget.store.storage.image(note.cutout),
          photo: widget.store.storage.image(note.photo),
          height: height,
          reflection: reflection,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final tilt = _tilt.value;
        final cabinet = switch (widget.style) {
          CabinetStyle.woodShop => _woodShop(box.maxWidth, tilt),
          CabinetStyle.backBar => _backBar(box.maxWidth, tilt),
          CabinetStyle.museum => _museum(box.maxWidth, tilt),
        };
        return GestureDetector(
          onHorizontalDragUpdate: _drag,
          onHorizontalDragEnd: _release,
          child: Stack(
            children: [
              Positioned.fill(
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0014)
                    ..rotateY(tilt),
                  child: cabinet,
                ),
              ),
              if (widget.notes.isEmpty && widget.emptyMessage != null)
                Center(child: widget.emptyMessage),
            ],
          ),
        );
      },
    );
  }

  // ───────────────────────── 고급 위스키숍 원목장 ─────────────────────────

  Widget _woodShop(double width, double tilt) {
    final perRow = math.max(2, ((width - 72) / 84).floor());
    final rows = _rows(perRow, 3);
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5A3420), Color(0xFF3A2013), Color(0xFF4E2C1A)],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
        border: Border.all(color: const Color(0xFF24140B), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: NoteColors.gold.withValues(alpha: 0.6)),
        ),
        child: ListView.builder(
          padding: const EdgeInsets.only(bottom: 96),
          itemCount: rows.length,
          itemBuilder: (_, r) => _WoodShelf(
            slots: perRow,
            tilt: tilt,
            notes: rows[r],
            bottle: (n) => _bottle(n, 150),
          ),
        ),
      ),
    );
  }

  // ───────────────────────── 바 뒤편 진열장 ─────────────────────────

  Widget _backBar(double width, double tilt) {
    final perRow = math.max(2, ((width - 60) / 84).floor());
    final rows = _rows(perRow, 3);
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      decoration: BoxDecoration(
        // 짙은 호두나무 프레임 + 얇은 금속 테두리
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2B1810), Color(0xFF1A0E08)],
        ),
        border: Border.all(color: const Color(0xFF8C7A5B), width: 1.5),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
      child: ClipRect(
        child: ListView.builder(
          padding: const EdgeInsets.only(bottom: 96),
          itemCount: rows.length,
          itemBuilder: (_, r) => _BarShelf(
            slots: perRow,
            tilt: tilt,
            notes: rows[r],
            bottle: (n, mirror) => mirror
                ? BottleFigure(
                    note: n,
                    cutout: widget.store.storage.image(n.cutout),
                    photo: widget.store.storage.image(n.photo),
                    height: 150,
                  )
                : _bottle(n, 150, reflection: 16),
          ),
        ),
      ),
    );
  }

  // ───────────────────────── 박물관 유리 케이스 ─────────────────────────

  Widget _museum(double width, double tilt) {
    const perRow = 2;
    final rows = _rows(perRow, 2);
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0B0B0D), Color(0xFF16151A), Color(0xFF0E0D10)],
        ),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 96),
        itemCount: rows.length,
        itemBuilder: (_, r) => Row(
          children: [
            for (var i = 0; i < perRow; i++)
              Expanded(
                child: _MuseumCase(
                  note: i < rows[r].length ? rows[r][i] : null,
                  tilt: tilt,
                  bottle: (n) => _bottle(n, 180, reflection: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════ 원목장 선반 ═════════════════════════════

class _WoodShelf extends StatelessWidget {
  const _WoodShelf({
    required this.slots,
    required this.tilt,
    required this.notes,
    required this.bottle,
  });

  static const height = 220.0;
  static const board = 40.0;

  final int slots;
  final double tilt;
  final List<TastingNote> notes;
  final Widget Function(TastingNote) bottle;

  @override
  Widget build(BuildContext context) {
    // 기울일 때 병이 뒤판보다 더 많이 움직여서 깊이감이 생깁니다.
    final parallax = tilt * 28;
    return SizedBox(
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 뒤판: 세로 나뭇결 + 위에서 비추는 조명
          Positioned.fill(
            bottom: board - 10,
            child: CustomPaint(painter: _WoodBackPainter(tilt)),
          ),
          _topShadow(),
          ..._sideShadows(board - 10),
          // 병 뒤로 번지는 은은한 빛
          Positioned(
            left: 12 + parallax * 0.5,
            right: 12 - parallax * 0.5,
            bottom: board - 10,
            height: 150,
            child: Row(
              children: [
                for (var i = 0; i < slots; i++)
                  Expanded(
                    child: i < notes.length
                        ? const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                center: Alignment(0, 0.2),
                                radius: 0.7,
                                colors: [Color(0x55FFC56B), Color(0x00FFC56B)],
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: board,
            child: CustomPaint(painter: _WoodBoardPainter()),
          ),
          Positioned(
            left: 12 + parallax,
            right: 12 - parallax,
            bottom: board - 14,
            child: _slotRow(
              slots,
              notes,
              (n) => bottle(n),
              CrossAxisAlignment.end,
            ),
          ),
          Positioned(
            left: 12 + parallax * 0.6,
            right: 12 - parallax * 0.6,
            bottom: 6,
            height: 20,
            child: _slotRow(slots, notes, (n) => _BrassPlate(note: n)),
          ),
        ],
      ),
    );
  }
}

class _WoodBackPainter extends CustomPainter {
  _WoodBackPainter(this.tilt);
  final double tilt;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1C0F07), Color(0xFF2F1B0F)],
        ).createShader(rect),
    );
    // 세로 판자 이음새와 나뭇결
    final seam = Paint()..color = Colors.black.withValues(alpha: 0.35);
    final grain = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = const Color(0xFF6B4026).withValues(alpha: 0.18);
    const plank = 46.0;
    for (var x = 0.0; x < size.width; x += plank) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 1.2, size.height), seam);
      for (var k = 1; k < 4; k++) {
        final gx = x + k * plank / 4;
        final p = Path()..moveTo(gx, 0);
        for (var y = 0.0; y < size.height; y += 30) {
          p.quadraticBezierTo(
            gx + ((y ~/ 30 + k).isEven ? 2 : -2),
            y + 15,
            gx,
            y + 30,
          );
        }
        canvas.drawPath(p, grain);
      }
    }
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(-tilt * 1.5, -1.2),
          radius: 1.1,
          colors: [
            const Color(0xFFFFC56B).withValues(alpha: 0.32),
            const Color(0x00FFC56B),
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_WoodBackPainter old) => old.tilt != tilt;
}

/// 선반 판: 윗면(원근으로 뒤가 좁아짐) + 나뭇결 앞면 + 금색 테두리.
class _WoodBoardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.clipRect(Offset.zero & size);
    const topDepth = 14.0;
    const inset = 16.0;

    final top = Path()
      ..moveTo(inset, 0)
      ..lineTo(w - inset, 0)
      ..lineTo(w, topDepth)
      ..lineTo(0, topDepth)
      ..close();
    canvas.drawPath(
      top,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF4A2A17), Color(0xFF8A5A34)],
        ).createShader(Rect.fromLTWH(0, 0, w, topDepth)),
    );

    final front = Rect.fromLTWH(0, topDepth, w, h - topDepth);
    canvas.drawRect(
      front,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF7A4A2A), Color(0xFF5A321C), Color(0xFF3E2213)],
        ).createShader(front),
    );
    final grain = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.black.withValues(alpha: 0.12)
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = topDepth + 5 + i * 5.5;
      final path = Path()..moveTo(0, y);
      for (var x = 0.0; x <= w; x += 24) {
        path.quadraticBezierTo(
          x + 12,
          y + ((i + x ~/ 24).isEven ? 1.5 : -1.5),
          x + 24,
          y,
        );
      }
      canvas.drawPath(path, grain);
    }
    canvas.drawRect(
      Rect.fromLTWH(0, topDepth, w, 1.5),
      Paint()..color = NoteColors.gold.withValues(alpha: 0.75),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, h - 2, w, 2),
      Paint()..color = Colors.black.withValues(alpha: 0.5),
    );
  }

  @override
  bool shouldRepaint(_WoodBoardPainter old) => false;
}

class _BrassPlate extends StatelessWidget {
  const _BrassPlate({required this.note});

  final TastingNote note;

  @override
  Widget build(BuildContext context) {
    final score = note.score;
    const style = TextStyle(
      fontSize: 9.5,
      fontWeight: FontWeight.bold,
      color: Color(0xFF2A1A0A),
    );
    return Container(
      constraints: const BoxConstraints(maxWidth: 80),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF1D58A), Color(0xFFC79A3A), Color(0xFF9C7424)],
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 2, offset: Offset(0, 1)),
        ],
      ),
      alignment: Alignment.center,
      // 이름이 길어도 점수는 잘리지 않도록 따로 둡니다.
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              note.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          if (score != null)
            Text(
              ' · ${_fmt(score)}',
              style: style.copyWith(color: const Color(0xFF7A1E0A)),
            ),
        ],
      ),
    );
  }
}

// ═════════════════════════════ 바 뒤편 선반 ═════════════════════════════

class _BarShelf extends StatelessWidget {
  const _BarShelf({
    required this.slots,
    required this.tilt,
    required this.notes,
    required this.bottle,
  });

  static const height = 236.0;
  static const glass = 30.0;

  final int slots;
  final double tilt;
  final List<TastingNote> notes;

  /// mirror=true면 거울에 비친 (누를 수 없는) 병.
  final Widget Function(TastingNote, bool mirror) bottle;

  @override
  Widget build(BuildContext context) {
    final parallax = tilt * 30;
    return SizedBox(
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 거울 뒤판
          Positioned.fill(child: CustomPaint(painter: _MirrorPainter(tilt))),
          // 거울에 비친 병 (흐리고 반대로 움직여서 깊이감)
          Positioned(
            left: 12 - parallax * 0.6,
            right: 12 + parallax * 0.6,
            bottom: glass + 4,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.16,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 1.2, sigmaY: 1.2),
                  child: _slotRow(
                    slots,
                    notes,
                    (n) => Transform.scale(
                      scale: 0.94,
                      alignment: Alignment.bottomCenter,
                      child: bottle(n, true),
                    ),
                    CrossAxisAlignment.end,
                  ),
                ),
              ),
            ),
          ),
          // 선반 위쪽 LED 조명 줄과 아래로 퍼지는 빛
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 120,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFFFFC77A).withValues(alpha: 0.42),
                    const Color(0x00FFC77A),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 6,
            right: 6,
            top: 0,
            height: 3,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFFFE2B0),
                borderRadius: BorderRadius.circular(2),
                boxShadow: const [
                  BoxShadow(color: Color(0xCCFFB860), blurRadius: 10),
                ],
              ),
            ),
          ),
          // 유리 선반
          Positioned(
            left: 0,
            right: 0,
            bottom: 14,
            height: glass - 14,
            child: CustomPaint(painter: _GlassShelfPainter()),
          ),
          // 병 (+ 유리에 비친 반사)
          Positioned(
            left: 12 + parallax,
            right: 12 - parallax,
            bottom: 14,
            child: _slotRow(
              slots,
              notes,
              (n) => bottle(n, false),
              CrossAxisAlignment.end,
            ),
          ),
          // 선반 아래 작은 이름
          Positioned(
            left: 12 + parallax * 0.8,
            right: 12 - parallax * 0.8,
            bottom: 0,
            height: 14,
            child: _slotRow(
              slots,
              notes,
              (n) => Text(
                n.score == null ? n.name : '${n.name} · ${_fmt(n.score!)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 9,
                  letterSpacing: 0.3,
                  color: Color(0xFFE9D6B0),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MirrorPainter extends CustomPainter {
  _MirrorPainter(this.tilt);
  final double tilt;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E1A17), Color(0xFF2C2622), Color(0xFF141110)],
        ).createShader(rect),
    );
    // 거울 표면을 비스듬히 지나가는 반사광 (기울이면 같이 움직임)
    final shift = tilt * size.width * 0.8;
    for (final (x, w, a) in [
      (0.25, 26.0, 0.05),
      (0.32, 8.0, 0.06),
      (0.7, 40.0, 0.035),
    ]) {
      final left = size.width * x + shift;
      final band = Path()
        ..moveTo(left, 0)
        ..lineTo(left + w, 0)
        ..lineTo(left + w - 60, size.height)
        ..lineTo(left - 60, size.height)
        ..close();
      canvas.drawPath(band, Paint()..color = Colors.white.withValues(alpha: a));
    }
    // 거울 테두리 이음새
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 1, size.width, 1),
      Paint()..color = Colors.black54,
    );
  }

  @override
  bool shouldRepaint(_MirrorPainter old) => old.tilt != tilt;
}

class _GlassShelfPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    const inset = 14.0;
    final top = Path()
      ..moveTo(inset, 0)
      ..lineTo(w - inset, 0)
      ..lineTo(w, h - 4)
      ..lineTo(0, h - 4)
      ..close();
    canvas.drawPath(
      top,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.06),
            Colors.white.withValues(alpha: 0.16),
          ],
        ).createShader(Offset.zero & size),
    );
    // 유리 앞 모서리 (빛을 받아 밝게)
    canvas.drawRect(
      Rect.fromLTWH(0, h - 4, w, 4),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0x5598E0D8), Color(0xAAE8FFF8), Color(0x5598E0D8)],
        ).createShader(Rect.fromLTWH(0, h - 4, w, 4)),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, h, w, 6),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x66000000), Color(0x00000000)],
        ).createShader(Rect.fromLTWH(0, h, w, 6)),
    );
  }

  @override
  bool shouldRepaint(_GlassShelfPainter old) => false;
}

// ═════════════════════════════ 박물관 케이스 ═════════════════════════════

class _MuseumCase extends StatelessWidget {
  const _MuseumCase({
    required this.note,
    required this.tilt,
    required this.bottle,
  });

  final TastingNote? note;
  final double tilt;
  final Widget Function(TastingNote) bottle;

  @override
  Widget build(BuildContext context) {
    final n = note;
    return SizedBox(
      height: 330,
      child: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // 위에서 떨어지는 스포트라이트
                Positioned.fill(
                  child: CustomPaint(
                    painter: _SpotlightPainter(on: n != null, tilt: tilt),
                  ),
                ),
                if (n != null)
                  Positioned(
                    bottom: 0,
                    left: tilt * 18,
                    right: -tilt * 18,
                    child: Center(child: bottle(n)),
                  ),
                // 유리 케이스 (병 위에 덮이는 유리 반사)
                Positioned.fill(
                  left: 10,
                  right: 10,
                  top: 6,
                  child: IgnorePointer(
                    child: CustomPaint(painter: _GlassCasePainter(tilt)),
                  ),
                ),
              ],
            ),
          ),
          // 받침대
          SizedBox(
            height: 46,
            child: CustomPaint(
              painter: _PedestalPainter(),
              size: const Size(double.infinity, 46),
            ),
          ),
          const SizedBox(height: 8),
          // 설명판
          SizedBox(height: 52, child: n == null ? null : _Plaque(note: n)),
        ],
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({required this.on, required this.tilt});
  final bool on;
  final double tilt;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final top = w / 2 + tilt * 30;
    final cone = Path()
      ..moveTo(top - 8, 0)
      ..lineTo(top + 8, 0)
      ..lineTo(w * 0.86, h)
      ..lineTo(w * 0.14, h)
      ..close();
    canvas.drawPath(
      cone,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: on ? 0.16 : 0.05),
            Colors.white.withValues(alpha: on ? 0.05 : 0.01),
          ],
        ).createShader(Offset.zero & size),
    );
    // 바닥(받침대 윗면)에 맺힌 빛
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w / 2, h), width: w * 0.8, height: 22),
      Paint()
        ..color = Colors.white.withValues(alpha: on ? 0.22 : 0.06)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    // 조명 기구
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(top, 3), width: 22, height: 6),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF3A3A40),
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) => old.on != on || old.tilt != tilt;
}

class _GlassCasePainter extends CustomPainter {
  _GlassCasePainter(this.tilt);
  final double tilt;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.18),
    );
    // 유리 뚜껑 윗면
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, 3),
      Paint()..color = Colors.white.withValues(alpha: 0.12),
    );
    // 비스듬한 유리 반사 (기울이면 미끄러짐)
    final x = size.width * (0.15 - tilt * 0.8);
    final glare = Path()
      ..moveTo(x, 0)
      ..lineTo(x + 18, 0)
      ..lineTo(x + 18 - size.height * 0.35, size.height)
      ..lineTo(x - size.height * 0.35, size.height)
      ..close();
    canvas.save();
    canvas.clipRect(rect);
    canvas.drawPath(
      glare,
      Paint()..color = Colors.white.withValues(alpha: 0.05),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlassCasePainter old) => old.tilt != tilt;
}

class _PedestalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    const topH = 12.0;
    final left = 4.0, right = w - 4;
    final top = Path()
      ..moveTo(left + 10, 0)
      ..lineTo(right - 10, 0)
      ..lineTo(right, topH)
      ..lineTo(left, topH)
      ..close();
    canvas.drawPath(
      top,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3A3A40), Color(0xFF55555C)],
        ).createShader(Rect.fromLTWH(0, 0, w, topH)),
    );
    final front = Rect.fromLTRB(left, topH, right, h);
    canvas.drawRect(
      front,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2A2A2F), Color(0xFF18181C)],
        ).createShader(front),
    );
    canvas.drawRect(
      Rect.fromLTRB(left, topH, right, topH + 1),
      Paint()..color = Colors.white.withValues(alpha: 0.25),
    );
  }

  @override
  bool shouldRepaint(_PedestalPainter old) => false;
}

class _Plaque extends StatelessWidget {
  const _Plaque({required this.note});

  final TastingNote note;

  @override
  Widget build(BuildContext context) {
    final sub = [
      note.type?.label,
      if (note.region.isNotEmpty) note.region,
    ].whereType<String>().join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        children: [
          Container(height: 1, color: NoteColors.gold.withValues(alpha: 0.6)),
          const SizedBox(height: 5),
          Text(
            note.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFEDE3CF),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          Text(
            [
              sub,
              if (note.score != null) _fmt(note.score!),
            ].where((s) => s.isNotEmpty).join('  ·  '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF9A8F7C), fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════ 공통 ═════════════════════════════

String _fmt(double v) =>
    v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(1);

/// [slots]칸으로 나눠 병(또는 이름표)을 놓습니다. 남는 칸은 비워 둡니다.
Widget _slotRow(
  int slots,
  List<TastingNote> notes,
  Widget Function(TastingNote) build, [
  CrossAxisAlignment align = CrossAxisAlignment.center,
]) {
  return Row(
    crossAxisAlignment: align,
    children: [
      for (var i = 0; i < slots; i++)
        Expanded(
          child: i < notes.length
              ? Center(child: build(notes[i]))
              : const SizedBox.shrink(),
        ),
    ],
  );
}

Widget _topShadow() => const Positioned(
  left: 0,
  right: 0,
  top: 0,
  height: 18,
  child: DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xAA000000), Color(0x00000000)],
      ),
    ),
  ),
);

List<Widget> _sideShadows(double bottom) => [
  for (final left in [true, false])
    Positioned(
      top: 0,
      bottom: bottom,
      left: left ? 0 : null,
      right: left ? null : 0,
      width: 22,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: left ? Alignment.centerLeft : Alignment.centerRight,
            end: left ? Alignment.centerRight : Alignment.centerLeft,
            colors: const [Color(0xCC000000), Color(0x00000000)],
          ),
        ),
      ),
    ),
];

/// 누르면 살짝 들렸다가 [onTap]을 부르는 병.
class _PressableBottle extends StatefulWidget {
  const _PressableBottle({
    required this.label,
    required this.onTap,
    required this.child,
  });

  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  State<_PressableBottle> createState() => _PressableBottleState();
}

class _PressableBottleState extends State<_PressableBottle> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedSlide(
        offset: _down ? const Offset(0, -0.04) : Offset.zero,
        duration: const Duration(milliseconds: 120),
        child: AnimatedScale(
          scale: _down ? 1.05 : 1,
          duration: const Duration(milliseconds: 120),
          child: Semantics(
            button: true,
            label: widget.label,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
