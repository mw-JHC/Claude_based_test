import 'package:material_ui/material_ui.dart';

import '../data/note_store.dart';
import '../models/tasting_note.dart';
import '../theme.dart';
import '../widgets/sheet_section.dart';

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
enum _RankView { top1, top10, all }

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
            return const Center(
              child: Text(
                '위스키를 기록하면 통계가 여기에 나타나요',
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
                  _Tile(label: '진열 중', value: '${library.length}'),
                  const SizedBox(width: 8),
                  _Tile(label: '비운 병', value: '${memories.length}'),
                  const SizedBox(width: 8),
                  _Tile(label: '이야기', value: '$stories'),
                  const SizedBox(width: 8),
                  _Tile(
                    label: '평균 점수',
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
                title: 'Origins',
                subtitle: '산지',
                open: _originsOpen,
                onToggle: () => setState(() => _originsOpen = !_originsOpen),
                bars: _byOrigin(scope),
              ),
              _Collapsible(
                title: 'Type',
                subtitle: '종류',
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

  /// 점수 순위. 같은 점수는 같은 순위 (1, 2, 2, 4 …).
  Widget _ranking(List<TastingNote> scored, int total) {
    final ranked = [...scored]..sort((a, b) => b.score!.compareTo(a.score!));
    final ranks = [
      for (final n in ranked)
        1 + ranked.where((o) => o.score! > n.score!).length,
    ];
    final shown = switch (_rank) {
      _RankView.top1 => ranked.isEmpty ? 0 : ranks.where((r) => r == 1).length,
      _RankView.top10 => ranks.where((r) => r <= 10).length,
      _RankView.all => ranked.length,
    };
    final canExpand = shown < ranked.length;
    return SheetSection(
      title: '최고 점수',
      subtitle: 'Top rated',
      trailing: ranked.isEmpty
          ? null
          : IconButton(
              tooltip: _rank == _RankView.top1 ? '10위까지 보기' : '접기',
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
      child: ranked.isEmpty
          ? const Text(
              '점수를 매긴 위스키가 없어요.',
              style: TextStyle(color: NoteColors.hint),
            )
          : AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: Column(
                children: [
                  for (var i = 0; i < shown; i++)
                    _RankRow(
                      rank: ranks[i],
                      tied: ranks.where((r) => r == ranks[i]).length > 1,
                      note: ranked[i],
                    ),
                  if (_rank == _RankView.top10 && canExpand)
                    TextButton(
                      onPressed: () => setState(() => _rank = _RankView.all),
                      child: Text('…  전체 ${ranked.length}병 순위 보기'),
                    ),
                  if (_rank != _RankView.top1 && scored.length < total)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '점수 없는 ${total - scored.length}병은 순위에서 빠졌어요',
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
          subs[n.subRegion] = (subs[n.subRegion] ?? 0) + 1;
        }
      }
      final detail =
          (subs.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
              .map((e) => '${e.key} ${e.value}')
              .join(' · ');
      bars.add(_Bar(o.label, group.length, detail));
    }
    final unknown = notes.where((n) => n.origin == null).length;
    if (unknown > 0) bars.add(_Bar('미입력', unknown, ''));
    return bars..sort((a, b) => b.count.compareTo(a.count));
  }

  List<_Bar> _byType(List<TastingNote> notes) {
    final bars = [
      for (final t in WhiskyType.values)
        _Bar(t.label, notes.where((n) => n.type == t).length, ''),
    ].where((b) => b.count > 0).toList();
    final unknown = notes.where((n) => n.type == null).length;
    if (unknown > 0) bars.add(_Bar('미입력', unknown, ''));
    return bars..sort((a, b) => b.count.compareTo(a.count));
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value});

  final String label;
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
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11.5, color: NoteColors.hint),
          ),
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
      return const Text('기록이 없어요.', style: TextStyle(color: NoteColors.hint));
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
                      '${b.count}병  ${(b.count * 100 / total).round()}%',
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
  const _RankRow({required this.rank, required this.note, this.tied = false});

  final int rank;

  /// 같은 점수의 병이 더 있으면 "공동"
  final bool tied;
  final TastingNote note;

  @override
  Widget build(BuildContext context) {
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
                  const Text(
                    '공동',
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
                      if (note.isEmpty) '빈 병',
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
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: serif,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: NoteColors.text,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: NoteColors.hint,
                    ),
                  ),
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
