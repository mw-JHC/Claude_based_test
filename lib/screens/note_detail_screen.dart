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
import 'story_edit_screen.dart';
import '../l10n/tr.dart';

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
        title: Text(tr('노트 삭제', 'Delete note')),
        content: Text(
          tr(
            '"${note.name}" 노트를 삭제할까요?\n삭제하면 되돌릴 수 없습니다.',
            'Delete the note for "${note.name}"?\nThis cannot be undone.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(tr('취소', 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(
              tr('삭제', 'Delete'),
              style: TextStyle(color: Color(0xFFE0605E)),
            ),
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
                    tooltip: tr('수정', 'Edit'),
                    icon: Icons.edit_outlined,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            NoteEditScreen(store: store, original: note),
                      ),
                    ),
                  ),
                  _circleAction(
                    tooltip: tr('삭제', 'Delete'),
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
                    _Stories(note: note, store: store),
                    const SizedBox(height: 6),
                    _emptyButton(context, note),
                    const SizedBox(height: 18),
                    Center(
                      child: Text(
                        [
                          tr(
                            '${_date(note.createdAt)} 기록',
                            'Added ${_date(note.createdAt)}',
                          ),
                          if (note.emptiedAt != null)
                            tr(
                              '${_date(note.emptiedAt!)} 비움',
                              'Emptied ${_date(note.emptiedAt!)}',
                            ),
                        ].join('  ·  '),
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

  /// 병 비우기 / 다시 진열장으로. 노트와 이야기는 지우지 않고 자리만 옮깁니다.
  Widget _emptyButton(BuildContext context, TastingNote note) {
    final empty = note.isEmpty;
    return OutlinedButton.icon(
      onPressed: () => _toggleEmpty(context, note),
      icon: Icon(empty ? Icons.shelves : Icons.local_drink_outlined),
      label: Text(
        empty
            ? tr('다시 진열장에 놓기', 'Put back in the cabinet')
            : tr('병 비우기 (Empty)', 'Empty bottle'),
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        foregroundColor: empty ? NoteColors.text : NoteColors.gold,
        side: BorderSide(
          color: empty
              ? NoteColors.line
              : NoteColors.gold.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Future<void> _toggleEmpty(BuildContext context, TastingNote note) async {
    void snack(String text) =>
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(text)));

    if (note.isEmpty) {
      await store.restore(note);
      if (context.mounted) snack(tr('진열장에 다시 놓았어요.', 'Back in the cabinet.'));
      return;
    }

    // 같은 이름으로 이미 비운 병이 있으면, 그 기록에 합칠지 물어봅니다.
    final previous = store
        .sameName(note.name, except: note.id)
        .where((n) => n.isEmpty)
        .toList();
    final choice = await showDialog<_EmptyChoice>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('병을 비울까요?', 'Empty this bottle?')),
        content: Text(
          previous.isEmpty
              ? tr(
                  '진열장에서 Memory Library로 옮겨집니다.\n노트와 이야기는 그대로 남아요.',
                  'It moves from your cabinet to the Memory Library.\nThe note and stories are kept.',
                )
              : tr(
                  'Memory Library에 이미 "${note.name}" 빈 병이 '
                      '${store.emptiedWithName(note.name)}병 있어요.\n\n'
                      '기존 빈 병 기록에 합치면 이야기를 날짜순으로 함께 모으고 '
                      '비운 병 수를 하나 늘립니다.',
                  'The Memory Library already has '
                      '${tr.bottles(store.emptiedWithName(note.name))} of "${note.name}".\n\n'
                      'Merging adds this bottle to that record: stories are combined '
                      'by date and the empty bottle count goes up by one.',
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(tr('취소', 'Cancel')),
          ),
          if (previous.isNotEmpty)
            TextButton(
              onPressed: () => Navigator.pop(c, _EmptyChoice.separate),
              child: Text(tr('따로 보관', 'Keep separate')),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(
              c,
              previous.isEmpty ? _EmptyChoice.separate : _EmptyChoice.merge,
            ),
            child: Text(
              previous.isEmpty
                  ? tr('비우기', 'Empty')
                  : tr('기존 기록에 합치기', 'Merge with record'),
            ),
          ),
        ],
      ),
    );
    if (choice == null || !context.mounted) return;

    if (choice == _EmptyChoice.separate) {
      await store.empty(note);
      if (context.mounted) {
        snack(
          tr(
            'Memory Library로 옮겼어요. 고마웠어, ${note.name}!',
            'Moved to the Memory Library. Cheers, ${note.name}!',
          ),
        );
      }
      return;
    }
    // 합치면 이 노트는 기존 빈 병 기록으로 들어가므로, 그 기록 화면으로 바꿉니다.
    final merged = await store.mergeInto(note, previous.first);
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => NoteDetailScreen(store: store, noteId: merged.id),
      ),
    );
    snack(
      tr(
        '기존 빈 병 기록에 합쳤어요. "${note.name}" 빈 병 '
            '${store.emptiedWithName(note.name)}병',
        'Merged. "${note.name}": '
            '${tr.bottles(store.emptiedWithName(note.name))} emptied',
      ),
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
      if (note.regionLabel.isNotEmpty) (Icons.place_outlined, note.regionLabel),
      if (note.ageCask.isNotEmpty) (Icons.hourglass_bottom, note.ageCask),
      if (note.emptiedAt != null)
        (
          Icons.auto_stories_outlined,
          tr(
            '빈 병 · ${_date(note.emptiedAt!)}',
            'Empty · ${_date(note.emptiedAt!)}',
          ),
        ),
      // 같은 이름으로 비운 병이 여러 병이면 모두 몇 병인지
      if (note.isEmpty && store.emptiedWithName(note.name) > 1)
        (
          Icons.layers_outlined,
          tr(
            '같은 병 ${store.emptiedWithName(note.name)}병 비움',
            '${tr.bottles(store.emptiedWithName(note.name))} of this emptied',
          ),
        ),
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
            const BiLabel('점수', 'Score', size: 12),
          ],
        ),
      ],
    );
  }

  Widget _stats(TastingNote note) {
    String? num(double? v, String unit) =>
        v == null ? null : '${v == v.roundToDouble() ? v.toInt() : v}$unit';
    Widget tile(String ko, String en, Widget value) => Expanded(
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
            BiLabel(ko, en, size: 12),
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
        tile('도수', 'ABV', v(num(note.abv, '%'))),
        const SizedBox(width: 8),
        tile('가격', 'Price', v(note.price)),
        const SizedBox(width: 8),
        tile(
          '색상',
          'Color',
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
                    Text(formatColor(note.color!), style: valueStyle),
                  ],
                ),
        ),
      ],
    );
  }

  static String _date(DateTime d) => tr.date(d);
}

class _CircleBack extends StatelessWidget {
  const _CircleBack();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(6),
    child: IconButton(
      tooltip: tr('뒤로', 'Back'),
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
    if (cutout == null && photo != null && !note.drawn) {
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
            segments: [
              ButtonSegment(value: 0, label: Text(tr('향', 'Nose'))),
              ButtonSegment(value: 1, label: Text(tr('맛', 'Palate'))),
              ButtonSegment(value: 2, label: Text(tr('비후방', 'Retronasal'))),
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

/// 이 병과 함께한 이야기들 (날짜별) + 이야기 추가 버튼.
class _Stories extends StatelessWidget {
  const _Stories({required this.note, required this.store});

  final TastingNote note;
  final NoteStore store;

  void _edit(BuildContext context, [StoryEntry? story]) =>
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              StoryEditScreen(store: store, note: note, story: story),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final stories = note.storiesByDate;
    return SheetSection(
      title: '이야기',
      subtitle: 'Stories',
      trailing: stories.isEmpty
          ? null
          : Text(
              '${stories.length}',
              style: const TextStyle(color: NoteColors.hint, fontSize: 13),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (stories.isEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                tr(
                  '이 병을 마신 날의 맛, 함께한 사람, 사진을 남겨 보세요.',
                  'Note how it tasted, who you shared it with and add photos each time you pour.',
                ),
                style: TextStyle(color: NoteColors.hint, height: 1.5),
              ),
            ),
          for (final (i, story) in stories.indexed)
            _StoryCard(
              story: story,
              store: store,
              last: i == stories.length - 1,
              onTap: () => _edit(context, story),
            ),
          FilledButton.tonalIcon(
            onPressed: () => _edit(context),
            icon: const Icon(Icons.add),
            label: const Text('Add Story'),
            style: FilledButton.styleFrom(
              backgroundColor: NoteColors.surfaceHigh,
              foregroundColor: NoteColors.gold,
              minimumSize: const Size.fromHeight(46),
            ),
          ),
        ],
      ),
    );
  }
}

/// 이야기 한 편: 왼쪽에 날짜 타임라인, 오른쪽에 내용과 사진.
class _StoryCard extends StatelessWidget {
  const _StoryCard({
    required this.story,
    required this.store,
    required this.last,
    required this.onTap,
  });

  final StoryEntry story;
  final NoteStore store;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 타임라인 점과 선
            SizedBox(
              width: 20,
              child: Column(
                children: [
                  const SizedBox(height: 4),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: NoteColors.accentGradient,
                    ),
                  ),
                  if (!last)
                    Expanded(
                      child: Container(width: 1.5, color: NoteColors.line),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      storyDate(story.date),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: NoteColors.gold,
                      ),
                    ),
                    if (story.companions.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.people_outline,
                            size: 14,
                            color: NoteColors.hint,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              story.companions,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: NoteColors.hint,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (story.text.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        story.text,
                        style: const TextStyle(
                          fontSize: 14.5,
                          height: 1.55,
                          color: NoteColors.text,
                        ),
                      ),
                    ],
                    if (story.photos.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 92,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: story.photos.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 6),
                          itemBuilder: (context, i) {
                            final img = store.storage.image(story.photos[i]);
                            return GestureDetector(
                              onTap: img == null
                                  ? null
                                  : () => _showPhoto(context, img),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: SizedBox(
                                  width: 92,
                                  child: img == null
                                      ? Container(color: NoteColors.surfaceHigh)
                                      : Image(image: img, fit: BoxFit.cover),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 사진을 누르면 크게 봅니다 (두 손가락으로 확대).
  void _showPhoto(BuildContext context, ImageProvider image) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (c) => GestureDetector(
        onTap: () => Navigator.of(c).pop(),
        child: InteractiveViewer(
          child: Center(child: Image(image: image)),
        ),
      ),
    );
  }
}

enum _EmptyChoice { separate, merge }
