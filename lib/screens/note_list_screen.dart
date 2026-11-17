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

  void _add() => Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => NoteEditScreen(store: widget.store)),
  );

  void _reorder(List<String> ids) => widget.store.reorder(ids);

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return Scaffold(
      body: SafeArea(
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
                            onReorder: _reorder,
                            emptyMessage: all.isEmpty
                                ? const _EmptyState(onDark: true)
                                : const _NoMatch(),
                          ),
                        )
                      : all.isEmpty
                      ? const _EmptyState()
                      : notes.isEmpty
                      ? const _NoMatch()
                      // 목록에서도 길게 눌러 끌면 순서가 바뀝니다.
                      : ReorderableListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          itemCount: notes.length,
                          onReorderItem: (from, to) {
                            final ids = notes.map((n) => n.id).toList();
                            ids.insert(to, ids.removeAt(from));
                            _reorder(ids);
                          },
                          proxyDecorator: (child, _, _) => Material(
                            color: Colors.transparent,
                            elevation: 12,
                            shadowColor: Colors.black,
                            borderRadius: BorderRadius.circular(20),
                            child: child,
                          ),
                          itemBuilder: (context, i) => Padding(
                            key: ValueKey(notes[i].id),
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _NoteCard(
                              store: store,
                              note: notes[i],
                              onTap: () => _open(notes[i]),
                            ),
                          ),
                        ),
                ),
                _bottomBar(memoryCount),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _header(List<TastingNote> all) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        children: [
          // 새 병 추가: 늘 제목 옆 같은 자리에
          Tooltip(
            message: 'Add Whisky',
            child: Semantics(
              button: true,
              label: 'Add Whisky',
              child: Material(
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: Ink(
                  decoration: const BoxDecoration(
                    gradient: NoteColors.accentGradient,
                  ),
                  child: InkWell(
                    onTap: _add,
                    child: const SizedBox(
                      width: 48,
                      height: 48,
                      child: Icon(Icons.add, color: NoteColors.ink, size: 26),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Whisky Library',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: serif,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                    color: NoteColors.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${all.length}병',
                  style: const TextStyle(
                    fontSize: 13,
                    color: NoteColors.hint,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 아래 줄: 통계 · 보기 전환 · 설정 · Memories. 진열장/목록 어느 쪽이든 같은 자리.
  Widget _bottomBar(int memoryCount) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
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
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _openMemories,
              icon: const Icon(Icons.auto_stories_outlined, size: 18),
              label: Text(
                memoryCount > 0 ? 'Memories  $memoryCount' : 'Memories',
                overflow: TextOverflow.ellipsis,
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: NoteColors.gold,
                side: BorderSide(color: NoteColors.gold.withValues(alpha: 0.5)),
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: const StadiumBorder(),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
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
          '왼쪽 위 + 버튼으로 첫 병을 진열해 보세요.',
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
