import 'package:material_ui/material_ui.dart';

import '../data/note_store.dart';
import '../models/tasting_note.dart';
import '../theme.dart';
import '../widgets/sheet_section.dart';
import '../l10n/tr.dart';

/// 내 위스키 통계: 순위, 진열장과 빈 병이 어디 산인지, 무엇을 주로 마셨는지.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key, required this.store});

  final NoteStore store;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

/// 통계를 볼 범위
enum _Scope { library, memory, total }

/// 점수 순위 펼침 정도: 1위만 / 10위까지 / 전부
enum _RankView { top1, top10 }

class _StatsScreenState extends State<StatsScreen> {
  _Scope _scope = _Scope.library;
  _RankView _rank = _RankView.top1;
  bool _originsOpen = true;
  bool _typesOpen = false;

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return Scaffold(
      appBar: AppBar(title: const Text('Statistics')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final library = store.library;
          final memories = store.memories;
          final all = store.notes;
          if (all.isEmpty) {
            return Center(
              child: Text(
                tr(
                  '위스키를 기록하면 통계가 여기에 나타나요',
                  'Your statistics appear here once you add whiskies',
                ),
                style: TextStyle(color: NoteColors.hint),
              ),
            );
          }
          final scored = all.where((n) => n.score != null).toList();
          final avg = scored.isEmpty
              ? null
              : scored.map((n) => n.score!).reduce((a, b) => a + b) /
                    scored.length;
          final stories = all.fold<int>(0, (s, n) => s + n.stories.length);
          final scope = switch (_scope) {
            _Scope.library => library,
            _Scope.memory => memories,
            _Scope.total => all,
          };
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              Row(
                children: [
                  _Tile(ko: '진열 중', en: 'Cabinet', value: '${library.length}'),
                  const SizedBox(width: 8),
                  _Tile(
                    ko: '비운 병',
                    en: 'Emptied',
                    value: '${store.emptiedBottles}',
                  ),
                  const SizedBox(width: 8),
                  _Tile(ko: '이야기', en: 'Stories', value: '$stories'),
                  const SizedBox(width: 8),
                  _Tile(
                    ko: '평균 점수',
                    en: 'Average',
                    value: avg == null ? '–' : avg.toStringAsFixed(0),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _ranking(scored, all.length),
              const SizedBox(height: 6),
              SegmentedButton<_Scope>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: _Scope.library,
                    label: Text('Whisky Library'),
                  ),
                  ButtonSegment(value: _Scope.memory, label: Text('Memory')),
                  ButtonSegment(value: _Scope.total, label: Text('Total')),
                ],
                selected: {_scope},
                onSelectionChanged: (v) => setState(() => _scope = v.first),
              ),
              const SizedBox(height: 14),
              _Collapsible(
                title: '생산지',
                subtitle: 'Origins',
                open: _originsOpen,
                onToggle: () => setState(() => _originsOpen = !_originsOpen),
                bars: _byOrigin(scope),
              ),
              _Collapsible(
                title: '종류',
                subtitle: 'Type',
                open: _typesOpen,
                onToggle: () => setState(() => _typesOpen = !_typesOpen),
                bars: _byType(scope),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 점수 순위 칸: 처음엔 1위만, ▼로 10위까지, 그 이상은 새 화면에서.
  Widget _ranking(List<TastingNote> scored, int total) {
    final ranking = rankByScore(scored);
    final shown = switch (_rank) {
      _RankView.top1 => ranking.where((r) => r.rank == 1).length,
      // 10위 안에 공동 순위가 겹쳐도 최대 10병만
      _RankView.top10 => ranking.length < 10 ? ranking.length : 10,
    };
    return SheetSection(
      title: '최고 점수',
      subtitle: 'Top rated',
      trailing: ranking.length <= 1
          ? null
          : IconButton(
              tooltip: _rank == _RankView.top1
                  ? tr('10위까지 보기', 'Show top 10')
                  : tr('접기', 'Collapse'),
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(
                () => _rank = _rank == _RankView.top1
                    ? _RankView.top10
                    : _RankView.top1,
              ),
              icon: AnimatedRotation(
                turns: _rank == _RankView.top1 ? 0 : 0.5,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.keyboard_arrow_down),
              ),
            ),
      child: ranking.isEmpty
          ? Text(
              tr('점수를 매긴 위스키가 없어요.', 'No scored whiskies yet.'),
              style: TextStyle(color: NoteColors.hint),
            )
          : AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final r in ranking.take(shown)) _RankRow(entry: r),
                  if (_rank == _RankView.top10 && ranking.length > shown)
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RankingScreen(store: widget.store),
                        ),
                      ),
                      child: Text(
                        tr(
                          '…  전체 ${ranking.length}병 순위 보기',
                          '…  Full ranking (${tr.bottles(ranking.length)})',
                        ),
                      ),
                    ),
                  if (_rank == _RankView.top10 && scored.length < total)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        tr(
                          '점수 없는 ${total - scored.length}병은 순위에서 빠졌어요',
                          '${tr.bottles(total - scored.length)} without a score are not ranked',
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: NoteColors.faint,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  /// 산지별 병 수. Scotland는 세부 지역 분포도 함께.
  List<_Bar> _byOrigin(List<TastingNote> notes) {
    final bars = <_Bar>[];
    for (final o in WhiskyOrigin.values) {
      final group = notes.where((n) => n.origin == o).toList();
      if (group.isEmpty) continue;
      final subs = <String, int>{};
      for (final n in group) {
        if (n.subRegion.isNotEmpty) {
          subs[n.subRegion] = (subs[n.subRegion] ?? 0) + _bottles([n]);
        }
      }
      final detail =
          (subs.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
              .map((e) => '${e.key} ${e.value}')
              .join(' · ');
      bars.add(_Bar(o.label, _bottles(group), detail));
    }
    final unknown = _bottles(notes.where((n) => n.origin == null));
    if (unknown > 0) bars.add(_Bar(tr('미입력', 'Not set'), unknown, ''));
    return bars..sort((a, b) => b.count.compareTo(a.count));
  }

  /// 병 수: 합쳐진 빈 병 기록은 그 안의 병 수만큼 셉니다.
  static int _bottles(Iterable<TastingNote> notes) => notes.fold(
    0,
    (sum, n) => sum + (n.isEmpty && n.emptiedCount > 1 ? n.emptiedCount : 1),
  );

  List<_Bar> _byType(List<TastingNote> notes) {
    final bars = [
      for (final t in WhiskyType.values)
        _Bar(t.label, _bottles(notes.where((n) => n.type == t)), ''),
    ].where((b) => b.count > 0).toList();
    final unknown = _bottles(notes.where((n) => n.type == null));
    if (unknown > 0) bars.add(_Bar(tr('미입력', 'Not set'), unknown, ''));
    return bars..sort((a, b) => b.count.compareTo(a.count));
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.ko, required this.en, required this.value});

  final String ko;
  final String en;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: NoteColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NoteColors.line.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontFamily: serif,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: NoteColors.text,
            ),
          ),
          const SizedBox(height: 4),
          BiLabel(ko, en, size: 12, stacked: true, center: true),
        ],
      ),
    ),
  );
}

class _Bar {
  const _Bar(this.label, this.count, this.detail);
  final String label;
  final int count;

  /// 막대 아래 작은 글씨 (예: Islay 2 · Speyside 1)
  final String detail;
}

/// 가로 막대: 한 가지 색(호박색)으로 양만 보여줍니다.
class _Bars extends StatelessWidget {
  const _Bars(this.bars);

  final List<_Bar> bars;

  @override
  Widget build(BuildContext context) {
    if (bars.isEmpty) {
      return Text(
        tr('기록이 없어요.', 'Nothing recorded.'),
        style: TextStyle(color: NoteColors.hint),
      );
    }
    final total = bars.fold<int>(0, (s, b) => s + b.count);
    final maxCount = bars.map((b) => b.count).reduce((a, b) => a > b ? a : b);
    return Column(
      children: [
        for (final b in bars)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        b.label,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: NoteColors.text,
                        ),
                      ),
                    ),
                    Text(
                      '${tr.bottles(b.count)}  ${(b.count * 100 / total).round()}%',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: NoteColors.hint,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                LayoutBuilder(
                  builder: (context, c) => Stack(
                    children: [
                      Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: NoteColors.surfaceHigh,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      Container(
                        height: 8,
                        width: c.maxWidth * b.count / maxCount,
                        decoration: BoxDecoration(
                          gradient: NoteColors.accentGradient,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
                if (b.detail.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    b.detail,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: NoteColors.faint,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.entry});

  final RankEntry entry;

  @override
  Widget build(BuildContext context) {
    final rank = entry.rank;
    final tied = entry.tied;
    final note = entry.note;
    final s = note.score!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$rank',
                  style: const TextStyle(
                    fontFamily: serif,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: NoteColors.gold,
                  ),
                ),
                if (tied)
                  Text(
                    tr('공동', 'tied'),
                    style: TextStyle(fontSize: 9.5, color: NoteColors.hint),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: NoteColors.text,
                  ),
                ),
                if (note.regionLabel.isNotEmpty || note.isEmpty)
                  Text(
                    [
                      if (note.regionLabel.isNotEmpty) note.regionLabel,
                      if (note.isEmpty) tr('빈 병', 'Empty'),
                    ].join(' · '),
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: NoteColors.hint,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            s == s.roundToDouble() ? '${s.toInt()}' : s.toStringAsFixed(1),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: NoteColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

/// 접었다 폈다 하는 통계 칸. 접혀 있어도 상위 세 개를 한 줄로 보여줍니다.
class _Collapsible extends StatelessWidget {
  const _Collapsible({
    required this.title,
    required this.subtitle,
    required this.open,
    required this.onToggle,
    required this.bars,
  });

  final String title;
  final String subtitle;
  final bool open;
  final VoidCallback onToggle;
  final List<_Bar> bars;

  @override
  Widget build(BuildContext context) {
    final summary = bars
        .take(3)
        .map((b) => '${b.label} ${b.count}')
        .join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: NoteColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: NoteColors.line.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
              child: Row(
                children: [
                  BiLabel(title, subtitle, size: 16),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      open ? '' : summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 12,
                        color: NoteColors.hint,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      color: NoteColors.hint,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: open
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: _Bars(bars),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// 순위 한 줄: 순위, 공동 여부, 위스키
class RankEntry {
  const RankEntry(this.rank, this.tied, this.note);
  final int rank;

  /// 같은 점수의 병이 더 있으면 true (tr("공동", 'tied'))
  final bool tied;
  final TastingNote note;
}

/// 점수 높은 순 순위. 같은 점수는 같은 순위이고 다음 순위는 그만큼 건너뜁니다
/// (95, 90, 90, 85 → 1, 2, 2, 4). 점수 없는 병은 빠집니다.
List<RankEntry> rankByScore(Iterable<TastingNote> notes) {
  final scored = notes.where((n) => n.score != null).toList()
    ..sort((a, b) => b.score!.compareTo(a.score!));
  final counts = <double, int>{};
  for (final n in scored) {
    counts[n.score!] = (counts[n.score!] ?? 0) + 1;
  }
  return [
    for (final (i, n) in scored.indexed)
      RankEntry(
        // 앞에 있는 더 높은 점수 병 수 + 1
        i == 0 || scored[i - 1].score! != n.score!
            ? i + 1
            : 1 + scored.indexWhere((o) => o.score! == n.score!),
        counts[n.score!]! > 1,
        n,
      ),
  ];
}

/// 등록된 모든 위스키의 점수 순위 (진열장 + 빈 병). 병이 많아도 스크롤로 봅니다.
class RankingScreen extends StatelessWidget {
  const RankingScreen({super.key, required this.store});

  final NoteStore store;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ranking')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final all = store.notes;
          final ranking = rankByScore(all);
          final unscored = all.length - ranking.length;
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            itemCount: ranking.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                // 제목과 병 수 (좁은 화면에서도 넘치지 않게 두 줄)
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const BiLabel('전체 순위', 'All whiskies', size: 16),
                      const SizedBox(height: 4),
                      Text(
                        unscored > 0
                            ? tr(
                                '${ranking.length}병 · 점수 없음 $unscored병',
                                '${tr.bottles(ranking.length)} · $unscored without a score',
                              )
                            : tr.bottles(ranking.length),
                        style: const TextStyle(
                          fontSize: 12,
                          color: NoteColors.hint,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return Container(
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: NoteColors.line, width: 0.5),
                  ),
                ),
                child: _RankRow(entry: ranking[i - 1]),
              );
            },
          );
        },
      ),
    );
  }
}
