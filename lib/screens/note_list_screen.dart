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
import 'settings_screen.dart';

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

  /// true: 진열장 보기, false: 목록 보기
  bool _cabinet = true;

  bool _matches(TastingNote n) {
    if (_type != null && n.type != _type) return false;
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return [
      n.name,
      n.region,
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
            final all = store.notes;
            final notes = all.where(_matches).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(all),
                if (all.isNotEmpty) ...[_searchBar(), _typeFilter(all)],
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
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
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
                    fontSize: 30,
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
            tooltip: _cabinet ? '목록으로 보기' : '진열장으로 보기',
            icon: _cabinet ? Icons.view_agenda_outlined : Icons.shelves,
            onPressed: () => setState(() => _cabinet = !_cabinet),
          ),
          const SizedBox(width: 8),
          _RoundIconButton(
            tooltip: '설정',
            icon: Icons.tune,
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

  /// 가지고 있는 종류만 필터로 보여줍니다.
  Widget _typeFilter(List<TastingNote> all) {
    final types = WhiskyType.values
        .where((t) => all.any((n) => n.type == t))
        .toList();
    if (types.length < 2) return const SizedBox.shrink();
    Widget chip(String label, WhiskyType? t) {
      final on = _type == t;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Semantics(
          button: true,
          selected: on,
          child: GestureDetector(
            onTap: () => setState(() => _type = t),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? NoteColors.amber : NoteColors.surfaceHigh,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: on ? NoteColors.ink : NoteColors.text,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [chip('전체', null), for (final t in types) chip(t.label, t)],
      ),
    );
  }
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
      if (note.region.isNotEmpty) note.region,
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
