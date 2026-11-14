import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:material_ui/material_ui.dart';

import '../data/note_store.dart';
import '../models/tasting_note.dart';
import '../theme.dart';
import 'whisky_bottle.dart';

/// 위스키를 나무 진열장 선반에 세워서 보여주는 화면.
///
/// 원근 변환, 조명, 음영으로 입체감을 냅니다. 좌우로 끌면 진열장이
/// 살짝 돌아가고, 손을 떼면 스프링처럼 제자리로 돌아옵니다.
class CabinetView extends StatefulWidget {
  const CabinetView({
    super.key,
    required this.store,
    required this.notes,
    required this.onOpen,
    this.emptyMessage,
  });

  final NoteStore store;
  final List<TastingNote> notes;
  final void Function(TastingNote note) onOpen;

  /// 진열할 병이 없을 때 진열장 위에 띄울 안내.
  final Widget? emptyMessage;

  @override
  State<CabinetView> createState() => _CabinetViewState();
}

class _CabinetViewState extends State<CabinetView>
    with SingleTickerProviderStateMixin {
  static const _maxTilt = 0.32;
  static const _frame = 12.0;
  static const _slotWidth = 84.0;

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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final inner = box.maxWidth - 2 * _frame - 24;
        final perShelf = math.max(2, (inner / _slotWidth).floor());
        final rows = math.max(3, (widget.notes.length / perShelf).ceil());
        final tilt = _tilt.value;

        final cabinet = Container(
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
          padding: const EdgeInsets.fromLTRB(_frame, _frame, _frame, 0),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: NoteColors.gold.withValues(alpha: 0.6),
                width: 1,
              ),
            ),
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: rows,
              itemBuilder: (context, r) {
                final start = r * perShelf;
                final end = math.min(start + perShelf, widget.notes.length);
                final notes = start < end
                    ? widget.notes.sublist(start, end)
                    : const <TastingNote>[];
                return _Shelf(
                  notes: notes,
                  slots: perShelf,
                  tilt: tilt,
                  store: widget.store,
                  onOpen: widget.onOpen,
                );
              },
            ),
          ),
        );

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
}

class _Shelf extends StatelessWidget {
  const _Shelf({
    required this.notes,
    required this.slots,
    required this.tilt,
    required this.store,
    required this.onOpen,
  });

  static const height = 216.0;
  static const boardHeight = 40.0;

  final List<TastingNote> notes;
  final int slots;
  final double tilt;
  final NoteStore store;
  final void Function(TastingNote) onOpen;

  @override
  Widget build(BuildContext context) {
    // 기울일 때 병이 뒤판보다 더 많이 움직여서 깊이감이 생깁니다.
    final parallax = tilt * 28;
    return SizedBox(
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 뒤판 + 위에서 비추는 조명
          Positioned.fill(
            bottom: boardHeight - 10,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF1A0E07), Color(0xFF2E1B0F)],
                ),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(-tilt * 1.5, -1.2),
                    radius: 1.1,
                    colors: [
                      const Color(0xFFFFC56B).withValues(alpha: 0.38),
                      const Color(0xFFFFC56B).withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // 위쪽 선반이 드리우는 그림자
          const Positioned(
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
          ),
          // 좌우 옆벽의 안쪽 그림자
          for (final left in [true, false])
            Positioned(
              top: 0,
              bottom: boardHeight - 10,
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
          // 선반 판
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: boardHeight,
            child: CustomPaint(painter: _BoardPainter()),
          ),
          // 병
          Positioned(
            left: 12 + parallax,
            right: 12 - parallax,
            bottom: boardHeight - 14,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < slots; i++)
                  Expanded(
                    child: i < notes.length
                        ? Center(
                            child: _PressableBottle(
                              note: notes[i],
                              store: store,
                              onTap: () => onOpen(notes[i]),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
          // 선반 앞면의 황동 이름표
          Positioned(
            left: 12 + parallax * 0.6,
            right: 12 - parallax * 0.6,
            bottom: 6,
            height: 20,
            child: Row(
              children: [
                for (var i = 0; i < slots; i++)
                  Expanded(
                    child: i < notes.length
                        ? Center(child: _NamePlate(note: notes[i]))
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PressableBottle extends StatefulWidget {
  const _PressableBottle({
    required this.note,
    required this.store,
    required this.onTap,
  });

  final TastingNote note;
  final NoteStore store;
  final VoidCallback onTap;

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
        // 누르면 병을 살짝 들어 올립니다.
        offset: _down ? const Offset(0, -0.06) : Offset.zero,
        duration: const Duration(milliseconds: 120),
        child: AnimatedScale(
          scale: _down ? 1.06 : 1,
          duration: const Duration(milliseconds: 120),
          child: Semantics(
            button: true,
            label: widget.note.name,
            child: WhiskyBottle(
              note: widget.note,
              photo: widget.store.storage.photoFile(widget.note.photo),
            ),
          ),
        ),
      ),
    );
  }
}

class _NamePlate extends StatelessWidget {
  const _NamePlate({required this.note});

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
      constraints: const BoxConstraints(maxWidth: 84),
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
              ' · ${score == score.roundToDouble() ? score.toInt() : score}',
              style: style.copyWith(color: const Color(0xFF7A1E0A)),
            ),
        ],
      ),
    );
  }
}

/// 선반 판: 위쪽 윗면(원근으로 뒤가 좁아짐) + 앞면(나뭇결).
class _BoardPainter extends CustomPainter {
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
    // 나뭇결
    final grain = Paint()
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
      canvas.drawPath(path, grain..style = PaintingStyle.stroke);
    }
    // 앞 모서리의 금색 테두리와 하이라이트
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
  bool shouldRepaint(_BoardPainter old) => false;
}
