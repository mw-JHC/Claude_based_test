import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:material_ui/material_ui.dart';

import '../data/app_settings.dart';
import '../data/note_store.dart';
import '../models/tasting_note.dart';
import '../theme.dart';
import 'whisky_bottle.dart';

/// 위스키를 진열장에 세워서 보여주는 화면. [style]에 따라 분위기가 바뀝니다.
///
/// 진열장 한 칸(페이지)은 화면 높이에 맞는 만큼의 선반을 갖고, 병이 더 많으면
/// 옆으로 넘겨 다음 진열장을 봅니다. 넘길 때 진열장이 입체적으로 돌아갑니다.
/// 병을 누르면 [onOpen]이 불립니다.
///
/// [onReorder]가 있으면 병을 길게 눌러 끌어서 자리를 바꿀 수 있습니다.
/// 끄는 동안 다른 병들이 비켜서고, 화면 가장자리로 끌면 옆 진열장으로 넘어갑니다.
class CabinetView extends StatefulWidget {
  const CabinetView({
    super.key,
    required this.store,
    required this.notes,
    required this.onOpen,
    this.style = CabinetStyle.woodShop,
    this.onReorder,
    this.emptyMessage,
  });

  final NoteStore store;
  final List<TastingNote> notes;
  final void Function(TastingNote note) onOpen;
  final CabinetStyle style;

  /// 끌어서 놓으면 새 순서(노트 id 목록)로 불립니다. null이면 순서를 못 바꿉니다.
  final void Function(List<String> ids)? onReorder;

  /// 진열할 병이 없을 때 진열장 위에 띄울 안내.
  final Widget? emptyMessage;

  @override
  State<CabinetView> createState() => _CabinetViewState();
}

/// 진열장 한 칸의 크기 계산 결과.
class _Layout {
  const _Layout(this.perRow, this.rows, this.bottle);
  final int perRow;
  final int rows;

  /// 병 높이. 화면이 낮으면 병을 조금 줄여서 선반을 더 놓습니다.
  final double bottle;
  int get capacity => perRow * rows;
}

class _CabinetViewState extends State<CabinetView> {
  final _pages = PageController();
  final _pagesBox = GlobalKey();
  int _page = 0;
  int _pageCount = 1;

  /// 끌고 있는 병과, 지금 놓으면 들어갈 자리
  String? _dragId;
  int? _hover;

  /// 놓은 직후 잠깐 동안도 병들이 부드럽게 자리를 잡도록
  bool _settling = false;

  /// 병마다 마지막으로 그려진 화면 위치 (자리 이동 애니메이션용)
  final Map<String, Offset> _positions = {};

  DateTime? _edgeSince;
  int _edgeDir = 0;

  Timer? _settleTimer;

  bool get _animateMoves => _dragId != null || _settling;

  @override
  void dispose() {
    _settleTimer?.cancel();
    _pages.dispose();
    super.dispose();
  }

  /// 화면 크기에 맞춰 한 진열장에 들어갈 줄 수, 한 줄의 병 수, 병 크기를 정합니다.
  _Layout _layout(Size size) {
    // (칸 최소 너비, 테두리 높이, 선반 최소 높이, 선반에서 병 말고 차지하는 높이,
    //  병 최소/최대 높이)
    final (
      slot,
      overhead,
      minShelf,
      fixed,
      minBottle,
      maxBottle,
    ) = switch (widget.style) {
      CabinetStyle.woodShop => (76.0, 40.0, 172.0, 64.0, 100.0, 160.0),
      CabinetStyle.backBar => (76.0, 34.0, 180.0, 70.0, 100.0, 160.0),
      CabinetStyle.museum => (150.0, 24.0, 262.0, 150.0, 110.0, 190.0),
    };
    final perRow = widget.style == CabinetStyle.museum
        ? 2
        : math.max(2, ((size.width - 64) / slot).floor());
    final usable = size.height - overhead;
    final rows = math.max(1, (usable / minShelf).floor());
    final bottle = (usable / rows - fixed).clamp(minBottle, maxBottle);
    return _Layout(perRow, rows, bottle);
  }

  double get _pagePosition {
    if (_pages.hasClients && _pages.position.hasContentDimensions) {
      return _pages.page ?? _page.toDouble();
    }
    return _page.toDouble();
  }

  /// 끄는 중이면 끌고 있는 병을 놓을 자리로 옮긴 순서 (미리보기).
  List<TastingNote> get _display {
    final notes = widget.notes;
    final id = _dragId, hover = _hover;
    if (id == null || hover == null) return notes;
    final dragged = notes.where((n) => n.id == id).firstOrNull;
    if (dragged == null) return notes;
    final rest = [...notes]..remove(dragged);
    return rest..insert(hover.clamp(0, rest.length), dragged);
  }

  void _startDrag(TastingNote note) {
    HapticFeedback.mediumImpact();
    setState(() {
      _dragId = note.id;
      _hover = widget.notes.indexOf(note);
    });
  }

  void _hoverAt(int index) {
    if (_dragId == null || _hover == index) return;
    HapticFeedback.selectionClick();
    setState(() => _hover = index);
  }

  void _drop(Offset feedbackTopLeft) {
    final id = _dragId;
    if (id == null) return;
    final order = _display.map((n) => n.id).toList();
    // 놓은 병은 손가락 자리에서 선반 자리로 미끄러져 들어갑니다.
    _positions[id] = feedbackTopLeft;
    _finishDrag();
    widget.onReorder?.call(order);
  }

  void _finishDrag() {
    _edgeSince = null;
    _edgeDir = 0;
    if (!mounted) return;
    setState(() {
      _dragId = null;
      _hover = null;
      _settling = true;
    });
    _settleTimer?.cancel();
    _settleTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _settling = false);
    });
  }

  /// 끌고 있는 병이 화면 가장자리에 잠시 머물면 옆 진열장으로 넘깁니다.
  void _dragMoved(Offset center) {
    final box = _pagesBox.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;
    final local = box.globalToLocal(center);
    final dir = local.dx < 36
        ? -1
        : local.dx > box.size.width - 36
        ? 1
        : 0;
    if (dir == 0) {
      _edgeSince = null;
      _edgeDir = 0;
      return;
    }
    final now = DateTime.now();
    if (_edgeDir != dir) {
      _edgeDir = dir;
      _edgeSince = now;
      return;
    }
    if (now.difference(_edgeSince!) < const Duration(milliseconds: 550)) return;
    final target = _page + dir;
    _edgeSince = now; // 계속 머물면 다음 칸도 넘김
    if (target < 0 || target >= _pageCount) return;
    _pages.animateToPage(
      target,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _figure(TastingNote note, double height, {double reflection = 0}) =>
      BottleFigure(
        note: note,
        cutout: widget.store.storage.image(note.cutout),
        photo: widget.store.storage.image(note.photo),
        height: height,
        reflection: reflection,
      );

  /// 선반 위의 병 한 칸: 누르면 열기, 길게 누르고 끌면 자리 바꾸기.
  Widget _bottle(
    TastingNote note,
    int index,
    double height, {
    double reflection = 0,
  }) {
    final dragging = note.id == _dragId;
    Widget bottle = _PressableBottle(
      label: note.name,
      onTap: () => widget.onOpen(note),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        // 끌고 있는 병의 원래 자리에는 흐린 자국만 남깁니다.
        opacity: dragging ? 0.22 : 1,
        child: _figure(note, height, reflection: reflection),
      ),
    );
    if (widget.onReorder != null) {
      bottle = LongPressDraggable<String>(
        data: note.id,
        delay: const Duration(milliseconds: 280),
        hapticFeedbackOnStart: false,
        onDragStarted: () => _startDrag(note),
        // 병이 새 자리로 미끄러지는 중에 손을 떼면 놓을 자리를 못 찾을 수 있어서,
        // 그때도 미리보기로 보여준 자리에 놓습니다.
        onDraggableCanceled: (_, offset) => _drop(offset),
        feedback: _DragFeedback(
          onMove: _dragMoved,
          child: _figure(note, height),
        ),
        childWhenDragging: bottle,
        child: bottle,
      );
      bottle = _target(index, bottle);
    }
    return _Flip(
      id: note.id,
      positions: _positions,
      enabled: _animateMoves,
      child: bottle,
    );
  }

  /// 병을 놓을 수 있는 자리. 끌고 있는 병이 올라오면 그 자리로 미리 옮겨 봅니다.
  Widget _target(int index, Widget child) => DragTarget<String>(
    onWillAcceptWithDetails: (_) {
      _hoverAt(index);
      return true;
    },
    onAcceptWithDetails: (d) => _drop(d.offset),
    builder: (context, _, _) => child,
  );

  /// 비어 있는 칸: 끄는 중에만 놓을 자리로 보입니다.
  Widget _emptySlot(int index, double height) {
    if (widget.onReorder == null) return const SizedBox.shrink();
    return _target(
      index,
      AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: height * 0.42,
        height: height * 0.9,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: _dragId == null
              ? null
              : Border.all(color: NoteColors.gold.withValues(alpha: 0.35)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final size = Size(box.maxWidth, box.maxHeight);
        final layout = _layout(size);
        final notes = _display;
        // 끄는 동안 마지막 진열장 뒤 빈 칸에도 놓을 수 있게 칸 수는 원래대로.
        final pageCount = math.max(
          1,
          (widget.notes.length / layout.capacity).ceil(),
        );
        _pageCount = pageCount;
        if (_page >= pageCount) {
          // 필터나 삭제로 병이 줄어 마지막 진열장이 사라졌을 때.
          _page = pageCount - 1;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_pages.hasClients) _pages.jumpToPage(_page);
          });
        }

        final pages = PageView.builder(
          key: _pagesBox,
          controller: _pages,
          itemCount: pageCount,
          // 한 칸뿐이어도 끌면 살짝 돌아갔다가 돌아옵니다.
          physics: const BouncingScrollPhysics(),
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (context, i) {
            final start = i * layout.capacity;
            return AnimatedBuilder(
              animation: _pages,
              builder: (context, _) {
                // 0이면 정면, ±1이면 옆으로 완전히 돌아간 진열장.
                final delta = (i - _pagePosition).clamp(-1.0, 1.0);
                return Transform(
                  alignment: delta > 0
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0012)
                    ..rotateY(delta * 0.85),
                  child: _cabinet(layout, notes, start, delta * 0.35),
                );
              },
            );
          },
        );

        return Stack(
          children: [
            Positioned.fill(child: pages),
            if (widget.notes.isEmpty && widget.emptyMessage != null)
              Center(child: widget.emptyMessage),
            // 몇 번째 진열장인지 (진열장 아래 테두리 위에 겹쳐 표시)
            if (pageCount > 1)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: IgnorePointer(child: _pageDots(pageCount)),
              ),
          ],
        );
      },
    );
  }

  Widget _pageDots(int pageCount) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var i = 0; i < pageCount && i < 8; i++)
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: i == _page ? 16 : 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: i == _page
                ? NoteColors.amber
                : NoteColors.text.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      const SizedBox(width: 6),
      Text(
        '${_page + 1}/$pageCount',
        style: const TextStyle(fontSize: 11, color: NoteColors.text),
      ),
    ],
  );

  /// 한 진열장: [all] 중 [start]번째부터 이 진열장 칸 수만큼.
  Widget _cabinet(
    _Layout layout,
    List<TastingNote> all,
    int start,
    double tilt,
  ) {
    final rows = [
      for (var r = 0; r < layout.rows; r++)
        (
          start + r * layout.perRow,
          all.sublist(
            math.min(start + r * layout.perRow, all.length),
            math.min(start + (r + 1) * layout.perRow, all.length),
          ),
        ),
    ];
    return switch (widget.style) {
      CabinetStyle.woodShop => _woodShop(layout, rows, tilt),
      CabinetStyle.backBar => _backBar(layout, rows, tilt),
      CabinetStyle.museum => _museum(layout, rows, tilt),
    };
  }

  // ───────────────────────── 고급 위스키숍 원목장 ─────────────────────────

  Widget _woodShop(
    _Layout layout,
    List<(int, List<TastingNote>)> rows,
    double tilt,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5A3420), Color(0xFF3A2013), Color(0xFF4E2C1A)],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF24140B), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: NoteColors.gold.withValues(alpha: 0.6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (base, row) in rows)
              Expanded(
                child: _WoodShelf(
                  slots: layout.perRow,
                  tilt: tilt,
                  notes: row,
                  bottle: (n) =>
                      _bottle(n, base + row.indexOf(n), layout.bottle),
                  emptySlot: (i) => _emptySlot(base + i, layout.bottle),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── 바 뒤편 진열장 ─────────────────────────

  Widget _backBar(
    _Layout layout,
    List<(int, List<TastingNote>)> rows,
    double tilt,
  ) {
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
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(10),
      child: ClipRect(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (base, row) in rows)
              Expanded(
                child: _BarShelf(
                  slots: layout.perRow,
                  tilt: tilt,
                  notes: row,
                  bottle: (n, mirror) => mirror
                      ? _figure(n, layout.bottle)
                      : _bottle(
                          n,
                          base + row.indexOf(n),
                          layout.bottle,
                          reflection: 16,
                        ),
                  emptySlot: (i) => _emptySlot(base + i, layout.bottle),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── 박물관 유리 케이스 ─────────────────────────

  Widget _museum(
    _Layout layout,
    List<(int, List<TastingNote>)> rows,
    double tilt,
  ) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0B0B0D), Color(0xFF16151A), Color(0xFF0E0D10)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (base, row) in rows)
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < 2; i++)
                      Expanded(
                        // 케이스 전체가 놓을 자리
                        child: _maybeTarget(
                          base + i,
                          _MuseumCase(
                            note: i < row.length ? row[i] : null,
                            tilt: tilt,
                            bottle: (n) => _bottle(
                              n,
                              base + i,
                              layout.bottle,
                              reflection: 14,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _maybeTarget(int index, Widget child) =>
      widget.onReorder == null ? child : _target(index, child);
}

/// 끌고 있는 병: 살짝 들려 커지고, 움직이는 방향으로 기울었다가 멈추면 바로 섭니다.
class _DragFeedback extends StatefulWidget {
  const _DragFeedback({required this.child, required this.onMove});

  final Widget child;

  /// 매 프레임 병 가운데의 화면 위치 (가장자리 넘김용)
  final void Function(Offset center) onMove;

  @override
  State<_DragFeedback> createState() => _DragFeedbackState();
}

class _DragFeedbackState extends State<_DragFeedback>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick)..start();
  Offset? _last;
  double _tilt = 0;
  double _lift = 0;

  void _tick(Duration _) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return;
    final pos = box.localToGlobal(box.size.center(Offset.zero));
    final dx = _last == null ? 0.0 : pos.dx - _last!.dx;
    _last = pos;
    widget.onMove(pos);
    // 움직이는 방향으로 기울고, 멈추면 스프링처럼 돌아옵니다.
    final target = (dx * 0.045).clamp(-0.45, 0.45);
    setState(() {
      _tilt += (target - _tilt) * 0.22;
      _lift += (1 - _lift) * 0.2;
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Transform.translate(
        offset: Offset(0, -10 * _lift),
        child: Transform.rotate(
          angle: _tilt,
          alignment: Alignment.bottomCenter,
          child: Transform.scale(
            scale: 1 + 0.12 * _lift,
            child: DecoratedBox(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45 * _lift),
                    blurRadius: 24,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// 자리가 바뀐 병이 예전 자리에서 새 자리로 미끄러져 가게 합니다.
/// (그려진 뒤 화면 위치를 재서, 바뀌었으면 그 차이만큼 되돌렸다가 0으로)
class _Flip extends StatefulWidget {
  const _Flip({
    required this.id,
    required this.positions,
    required this.enabled,
    required this.child,
  });

  final String id;
  final Map<String, Offset> positions;
  final bool enabled;
  final Widget child;

  @override
  State<_Flip> createState() => _FlipState();
}

class _FlipState extends State<_Flip> with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );
  Offset _from = Offset.zero;

  Offset get _current =>
      _from * (1 - Curves.easeOutCubic.transform(_anim.value));

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _measure(Duration _) {
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return;
    final now = box.localToGlobal(Offset.zero);
    final before = widget.positions[widget.id];
    widget.positions[widget.id] = now;
    if (!widget.enabled || before == null) return;
    final jump = before + _current - now;
    // 진열장을 넘길 때처럼 아주 멀리 가는 경우는 애니메이션하지 않습니다.
    if (jump.distance < 1 || jump.distance > 900) return;
    _from = jump;
    _anim.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback(_measure);
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) =>
          Transform.translate(offset: _current, child: child),
      child: widget.child,
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
    required this.emptySlot,
  });

  static const board = 40.0;

  final int slots;
  final double tilt;
  final List<TastingNote> notes;
  final Widget Function(TastingNote) bottle;

  /// 빈 칸 (끌어 놓을 자리)
  final Widget Function(int slot) emptySlot;

  @override
  Widget build(BuildContext context) {
    // 기울일 때 병이 뒤판보다 더 많이 움직여서 깊이감이 생깁니다.
    final parallax = tilt * 28;
    return SizedBox.expand(
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
              emptySlot,
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
    final badge = _badge(note);
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
          if (badge != null)
            Text(
              ' · $badge',
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
    required this.emptySlot,
  });

  static const glass = 30.0;

  final int slots;
  final double tilt;
  final List<TastingNote> notes;

  /// 빈 칸 (끌어 놓을 자리)
  final Widget Function(int slot) emptySlot;

  /// mirror=true면 거울에 비친 (누를 수 없는) 병.
  final Widget Function(TastingNote, bool mirror) bottle;

  @override
  Widget build(BuildContext context) {
    final parallax = tilt * 30;
    return SizedBox.expand(
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
              emptySlot,
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
                [n.name, ?_badge(n)].join(' · '),
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
    return SizedBox.expand(
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
      if (note.regionLabel.isNotEmpty) note.regionLabel,
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
            [sub, ?_badge(note)].where((s) => s.isNotEmpty).join('  ·  '),
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

/// 이름표에 이름과 함께 붙는 값: 진열장에서는 점수, 빈 병은 비운 날.
String? _badge(TastingNote n) {
  final e = n.emptiedAt;
  if (e != null) {
    final date =
        '${e.year % 100}.${e.month.toString().padLeft(2, '0')}.${e.day.toString().padLeft(2, '0')}';
    // 같은 병을 여러 번 비워 합친 기록은 병 수도 함께
    return n.emptiedCount > 1 ? '$date ×${n.emptiedCount}' : date;
  }
  return n.score == null ? null : _fmt(n.score!);
}

String _fmt(double v) =>
    v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(1);

/// [slots]칸으로 나눠 병(또는 이름표)을 놓습니다. 남는 칸은 비워 둡니다.
Widget _slotRow(
  int slots,
  List<TastingNote> notes,
  Widget Function(TastingNote) build, [
  CrossAxisAlignment align = CrossAxisAlignment.center,
  Widget Function(int slot)? empty,
]) {
  return Row(
    crossAxisAlignment: align,
    children: [
      for (var i = 0; i < slots; i++)
        Expanded(
          child: i < notes.length
              ? Center(child: build(notes[i]))
              : (empty == null
                    ? const SizedBox.shrink()
                    : Center(child: empty(i))),
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
