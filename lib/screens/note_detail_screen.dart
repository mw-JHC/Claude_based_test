import 'package:material_ui/material_ui.dart';

import '../data/note_store.dart';
import '../models/tasting_note.dart';
import '../theme.dart';
import '../widgets/character_slider.dart';
import '../widgets/color_scale.dart';
import '../widgets/flavor_wheel.dart';
import '../widgets/sheet_section.dart';
import '../widgets/whisky_bottle.dart';
import 'note_edit_screen.dart';

/// 저장된 노트를 보는 화면.
class NoteDetailScreen extends StatelessWidget {
  const NoteDetailScreen({
    super.key,
    required this.store,
    required this.noteId,
  });

  final NoteStore store;
  final String noteId;

  Future<void> _delete(BuildContext context, TastingNote note) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('노트 삭제'),
        content: Text('"${note.name}" 노트를 삭제할까요?\n삭제하면 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('삭제', style: TextStyle(color: Color(0xFFE0605E))),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await store.delete(note.id);
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final note = store.byId(noteId);
        if (note == null) return const Scaffold();
        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 360,
                backgroundColor: NoteColors.bg,
                leading: const _CircleBack(),
                actions: [
                  _circleAction(
                    tooltip: '수정',
                    icon: Icons.edit_outlined,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            NoteEditScreen(store: store, original: note),
                      ),
                    ),
                  ),
                  _circleAction(
                    tooltip: '삭제',
                    icon: Icons.delete_outline,
                    onPressed: () => _delete(context, note),
                  ),
                  const SizedBox(width: 8),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.parallax,
                  background: _Hero(note: note, store: store),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                sliver: SliverList.list(
                  children: [
                    _titleBlock(note),
                    const SizedBox(height: 16),
                    _stats(note),
                    const SizedBox(height: 14),
                    _FlavorCard(note: note),
                    SheetSection(
                      title: '개성',
                      subtitle: 'Character',
                      child: Column(
                        children: [
                          for (final s in characterScales)
                            CharacterSlider(
                              scale: s,
                              value: note.characters[s.key]!,
                            ),
                          const SizedBox(height: 6),
                          const Divider(),
                          const SizedBox(height: 6),
                          CharacterSlider(
                            scale: finishScale,
                            value: note.finish,
                          ),
                        ],
                      ),
                    ),
                    if (note.overall.isNotEmpty)
                      SheetSection(
                        title: '총평',
                        subtitle: 'Overall',
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 3,
                              height: 40,
                              margin: const EdgeInsets.only(right: 12, top: 2),
                              decoration: BoxDecoration(
                                gradient: NoteColors.accentGradient,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                note.overall,
                                style: const TextStyle(
                                  fontSize: 15,
                                  height: 1.6,
                                  color: NoteColors.text,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Center(
                      child: Text(
                        '${_date(note.createdAt)} 기록',
                        style: const TextStyle(
                          fontSize: 12,
                          color: NoteColors.faint,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _circleAction({
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) => Padding(
    padding: const EdgeInsets.only(left: 6),
    child: IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      style: IconButton.styleFrom(
        backgroundColor: NoteColors.bg.withValues(alpha: 0.6),
        foregroundColor: NoteColors.text,
      ),
    ),
  );

  Widget _titleBlock(TastingNote note) {
    final pills = [
      if (note.type != null) (Icons.local_bar_outlined, note.type!.label),
      if (note.region.isNotEmpty) (Icons.place_outlined, note.region),
      if (note.ageCask.isNotEmpty) (Icons.hourglass_bottom, note.ageCask),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                note.name,
                style: const TextStyle(
                  fontFamily: serif,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                  color: NoteColors.text,
                ),
              ),
              if (pills.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final (icon, text) in pills)
                      InfoPill(text, icon: icon),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          children: [
            ScoreRing(score: note.score, size: 70),
            const SizedBox(height: 4),
            const Text(
              'SCORE',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.5,
                color: NoteColors.hint,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _stats(TastingNote note) {
    String? num(double? v, String unit) =>
        v == null ? null : '${v == v.roundToDouble() ? v.toInt() : v}$unit';
    Widget tile(String label, Widget value) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: NoteColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: NoteColors.line.withValues(alpha: 0.6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: NoteColors.hint),
            ),
            const SizedBox(height: 6),
            value,
          ],
        ),
      ),
    );
    const valueStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: NoteColors.text,
    );
    Text v(String? s) => Text(
      s == null || s.isEmpty ? '–' : s,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: valueStyle,
    );
    return Row(
      children: [
        tile('도수', v(num(note.abv, '%'))),
        const SizedBox(width: 8),
        tile('가격', v(note.price)),
        const SizedBox(width: 8),
        tile(
          '색상',
          note.color == null
              ? v(null)
              : Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: whiskyColor(note.color!),
                        shape: BoxShape.circle,
                        border: Border.all(color: NoteColors.line),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(note.color!.toStringAsFixed(1), style: valueStyle),
                  ],
                ),
        ),
      ],
    );
  }

  static String _date(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
}

class _CircleBack extends StatelessWidget {
  const _CircleBack();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(6),
    child: IconButton(
      tooltip: '뒤로',
      onPressed: () => Navigator.of(context).maybePop(),
      icon: const Icon(Icons.arrow_back, size: 20),
      style: IconButton.styleFrom(
        backgroundColor: NoteColors.bg.withValues(alpha: 0.6),
        foregroundColor: NoteColors.text,
      ),
    ),
  );
}

/// 위쪽 큰 그림: 조명 받은 병 (배경 제거 사진 > 그린 병), 또는 원본 사진.
class _Hero extends StatelessWidget {
  const _Hero({required this.note, required this.store});

  final TastingNote note;
  final NoteStore store;

  @override
  Widget build(BuildContext context) {
    final cutout = store.storage.image(note.cutout);
    final photo = store.storage.image(note.photo);
    final glow = note.color == null
        ? NoteColors.amber
        : whiskyColor(note.color!);

    // 배경을 지우지 않은 사진만 있으면 사진을 꽉 채워 보여줍니다.
    if (cutout == null && photo != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image(image: photo, fit: BoxFit.cover),
          const _BottomFade(),
        ],
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, 0.1),
              radius: 0.85,
              colors: [glow.withValues(alpha: 0.45), NoteColors.bg],
            ),
          ),
        ),
        // 바닥에 비친 빛
        Align(
          alignment: const Alignment(0, 0.86),
          child: Container(
            width: 200,
            height: 26,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
              boxShadow: [
                BoxShadow(
                  color: glow.withValues(alpha: 0.35),
                  blurRadius: 30,
                  spreadRadius: 4,
                ),
              ],
            ),
          ),
        ),
        Align(
          alignment: const Alignment(0, 0.95),
          child: Padding(
            padding: const EdgeInsets.only(top: 80),
            child: BottleFigure(
              note: note,
              cutout: cutout,
              photo: photo,
              height: 250,
              reflection: 24,
              reflectionOpacity: 0.18,
            ),
          ),
        ),
        const _BottomFade(),
      ],
    );
  }
}

class _BottomFade extends StatelessWidget {
  const _BottomFade();

  @override
  Widget build(BuildContext context) => const IgnorePointer(
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.6, 1],
          colors: [Color(0x00110D0B), NoteColors.bg],
        ),
      ),
    ),
  );
}

/// 향 / 맛 / 비후방 후각 차트를 탭으로 바꿔 보는 카드.
class _FlavorCard extends StatefulWidget {
  const _FlavorCard({required this.note});

  final TastingNote note;

  @override
  State<_FlavorCard> createState() => _FlavorCardState();
}

class _FlavorCardState extends State<_FlavorCard> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final n = widget.note;
    final (axes, values, color) = switch (_tab) {
      0 => (aromaAxes, n.nose, NoteColors.amber),
      1 => (palateAxes, n.palate, palateColor),
      _ => (aromaAxes, n.retronasal, retronasalColor),
    };
    return SheetSection(
      title: '풍미',
      subtitle: 'Flavour',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 0, label: Text('향')),
              ButtonSegment(value: 1, label: Text('맛')),
              ButtonSegment(value: 2, label: Text('비후방')),
            ],
            selected: {_tab},
            onSelectionChanged: (v) => setState(() => _tab = v.first),
          ),
          const SizedBox(height: 8),
          FlavorWheel(axes: axes, values: values, color: color),
        ],
      ),
    );
  }
}
