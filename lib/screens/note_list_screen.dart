import 'package:material_ui/material_ui.dart';

import '../data/app_settings.dart';
import '../data/note_store.dart';
import '../models/tasting_note.dart';
import '../theme.dart';
import '../widgets/cabinet_view.dart';
import '../widgets/color_scale.dart';
import '../widgets/sheet_section.dart';
import '../widgets/whisky_bottle.dart';
import 'note_detail_screen.dart';
import 'note_edit_screen.dart';
import 'memory_library_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';

/// 첫 화면: 내 위스키 진열장 (또는 목록).
class NoteListScreen extends StatefulWidget {
  const NoteListScreen({
    super.key,
    required this.store,
    required this.settings,
  });

  final NoteStore store;
  final AppSettings settings;

  @override
  State<NoteListScreen> createState() => _NoteListScreenState();
}

class _NoteListScreenState extends State<NoteListScreen> {
  String _query = '';

  /// 종류 필터 (null이면 전체)
  WhiskyType? _type;

  /// 산지 필터 (null이면 전체)
  WhiskyOrigin? _origin;

  /// true: 진열장 보기, false: 목록 보기
  bool _cabinet = true;

  bool _matches(TastingNote n) {
    if (_type != null && n.type != _type) return false;
    if (_origin != null && n.origin != _origin) return false;
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return [
      n.name,
      n.regionLabel,
      n.ageCask,
      n.type?.label ?? '',
      n.overall,
    ].any((s) => s.toLowerCase().contains(q));
  }

  void _open(TastingNote note) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => NoteDetailScreen(store: widget.store, noteId: note.id),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => NoteEditScreen(store: store))),
        icon: const Icon(Icons.add),
        label: const Text('Add Whisky'),
      ),
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: Listenable.merge([store, widget.settings]),
          builder: (context, _) {
            final style = widget.settings.cabinetStyle;
            // 비운 병은 Memory Library로 갑니다.
            final all = store.library;
            final memoryCount = store.memories.length;
            final notes = all.where(_matches).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(all),
                if (all.isNotEmpty) ...[_searchBar(), _filters(all)],
                const SizedBox(height: 8),
                Expanded(
                  child: !store.loaded
                      ? const Center(child: CircularProgressIndicator())
                      : _cabinet
                      ? ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                          child: CabinetView(
                            store: store,
                            style: style,
                            notes: notes,
                            onOpen: _open,
                            onPickStyle: _pickStyle,
                            onOpenMemories: _openMemories,
                            memoryCount: memoryCount,
                            emptyMessage: all.isEmpty
                                ? const _EmptyState(onDark: true)
                                : const _NoMatch(),
                          ),
                        )
                      : all.isEmpty
                      ? const _EmptyState()
                      : notes.isEmpty
                      ? const _NoMatch()
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          itemCount: notes.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, i) => _NoteCard(
                            store: store,
                            note: notes[i],
                            onTap: () => _open(notes[i]),
                          ),
                        ),
                ),
                // 목록 보기에서도 Memory Library로 갈 수 있게
                if (!_cabinet)
                  SizedBox(
                    height: 58,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16, right: 176),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: _openMemories,
                          icon: const Icon(
                            Icons.auto_stories_outlined,
                            size: 17,
                          ),
                          label: Text(
                            memoryCount > 0
                                ? 'Memories $memoryCount'
                                : 'Memories',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: NoteColors.gold,
                            side: BorderSide(
                              color: NoteColors.gold.withValues(alpha: 0.5),
                            ),
                            minimumSize: const Size(0, 38),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: const StadiumBorder(),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _header(List<TastingNote> all) {
    final scored = all.where((n) => n.score != null).toList();
    final avg = scored.isEmpty
        ? null
        : scored.map((n) => n.score!).reduce((a, b) => a + b) / scored.length;
    final stats = [
      '${all.length}병',
      if (avg != null) '평균 ${avg.toStringAsFixed(0)}점',
    ].join('  ·  ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Whisky Library',
                  style: TextStyle(
                    fontFamily: serif,
                    fontSize: 27,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                    color: NoteColors.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  stats,
                  style: const TextStyle(
                    fontSize: 13,
                    color: NoteColors.hint,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          _RoundIconButton(
            tooltip: '통계',
            icon: Icons.insights_outlined,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => StatsScreen(store: widget.store),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _RoundIconButton(
            tooltip: _cabinet ? '목록으로 보기' : '진열장으로 보기',
            icon: _cabinet ? Icons.view_agenda_outlined : Icons.shelves,
            onPressed: () => setState(() => _cabinet = !_cabinet),
          ),
          const SizedBox(width: 8),
          _RoundIconButton(
            tooltip: '설정',
            icon: Icons.settings_outlined,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SettingsScreen(
                  settings: widget.settings,
                  store: widget.store,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _searchBar() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
    child: TextField(
      onChanged: (v) => setState(() => _query = v.trim()),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search, size: 20),
        hintText: '이름, 지역, 종류로 검색',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: NoteColors.amber),
        ),
      ),
    ),
  );

  /// 가지고 있는 산지와 종류만 필터로 보여줍니다. 둘은 함께 걸 수 있습니다.
  Widget _filters(List<TastingNote> all) {
    final origins = WhiskyOrigin.values
        .where((o) => all.any((n) => n.origin == o))
        .toList();
    final types = WhiskyType.values
        .where((t) => all.any((n) => n.type == t))
        .toList();
    if (origins.length < 2 && types.length < 2) return const SizedBox.shrink();
    Widget pill(String label, bool on, VoidCallback onTap) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: SelectPill(label: label, selected: on, onTap: onTap),
    );
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          pill('전체', _origin == null && _type == null, () {
            setState(() {
              _origin = null;
              _type = null;
            });
          }),
          if (origins.length >= 2)
            for (final o in origins)
              pill(o.label, _origin == o, () {
                setState(() => _origin = _origin == o ? null : o);
              }),
          if (origins.length >= 2 && types.length >= 2)
            Container(
              width: 1,
              margin: const EdgeInsets.fromLTRB(2, 8, 10, 8),
              color: NoteColors.line,
            ),
          if (types.length >= 2)
            for (final t in types)
              pill(t.label, _type == t, () {
                setState(() => _type = _type == t ? null : t);
              }),
        ],
      ),
    );
  }

  void _openMemories() => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) =>
          MemoryLibraryScreen(store: widget.store, settings: widget.settings),
    ),
  );

  /// 진열장 아래 이름을 누르면 바로 분위기를 바꿀 수 있습니다.
  Future<void> _pickStyle() async {
    final settings = widget.settings;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: NoteColors.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  '진열장 분위기',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: NoteColors.text,
                  ),
                ),
              ),
              for (final style in CabinetStyle.values)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  selected: settings.cabinetStyle == style,
                  selectedTileColor: NoteColors.surfaceHigh,
                  leading: Icon(_styleIcon(style), color: NoteColors.gold),
                  title: Text(
                    style.label,
                    style: const TextStyle(
                      color: NoteColors.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    style.description,
                    style: const TextStyle(
                      color: NoteColors.hint,
                      fontSize: 12,
                    ),
                  ),
                  trailing: settings.cabinetStyle == style
                      ? const Icon(Icons.check_circle, color: NoteColors.amber)
                      : null,
                  onTap: () {
                    settings.setCabinetStyle(style);
                    Navigator.of(c).pop();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _styleIcon(CabinetStyle s) => switch (s) {
    CabinetStyle.woodShop => Icons.door_sliding_outlined,
    CabinetStyle.backBar => Icons.wine_bar_outlined,
    CabinetStyle.museum => Icons.museum_outlined,
  };
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 21),
      style: IconButton.styleFrom(
        backgroundColor: NoteColors.surface,
        foregroundColor: NoteColors.text,
        fixedSize: const Size(44, 44),
        side: const BorderSide(color: NoteColors.line),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.store,
    required this.note,
    required this.onTap,
  });

  final NoteStore store;
  final TastingNote note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sub = [
      if (note.regionLabel.isNotEmpty) note.regionLabel,
      if (note.ageCask.isNotEmpty) note.ageCask,
      if (note.abv != null) '${note.abv}%',
    ].join(' · ');
    return Material(
      color: NoteColors.surface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              // 병 썸네일: 어두운 조명 배경 위에 세운 병
              Container(
                width: 70,
                height: 96,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.3),
                    radius: 1,
                    colors: [
                      (note.color == null
                              ? NoteColors.amber
                              : whiskyColor(note.color!))
                          .withValues(alpha: 0.35),
                      NoteColors.ink,
                    ],
                  ),
                ),
                alignment: Alignment.bottomCenter,
                padding: const EdgeInsets.only(bottom: 6),
                child: BottleFigure(
                  note: note,
                  cutout: store.storage.image(note.cutout),
                  photo: store.storage.image(note.photo),
                  height: 82,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (note.type != null)
                      Text(
                        note.type!.label.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10.5,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w600,
                          color: NoteColors.gold,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      note.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: serif,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: NoteColors.text,
                      ),
                    ),
                    if (sub.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: NoteColors.hint,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ScoreRing(score: note.score, size: 48),
              const SizedBox(width: 6),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoMatch extends StatelessWidget {
  const _NoMatch();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Text('찾는 위스키가 없어요', style: TextStyle(color: NoteColors.hint)),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.onDark = false});

  /// 진열장 위에 띄울 때는 반투명 상자 안에 보여줍니다.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: NoteColors.accentGradient,
          ),
          child: const Icon(Icons.local_bar, size: 30, color: NoteColors.ink),
        ),
        const SizedBox(height: 16),
        const Text(
          '아직 기록한 위스키가 없습니다',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: NoteColors.text,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          '"Add Whisky"로 첫 병을 진열해 보세요.',
          textAlign: TextAlign.center,
          style: TextStyle(color: NoteColors.hint),
        ),
      ],
    );
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: onDark
            ? Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: NoteColors.bg.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: NoteColors.line),
                ),
                child: content,
              )
            : content,
      ),
    );
  }
}
