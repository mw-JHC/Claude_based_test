import 'package:material_ui/material_ui.dart';

import '../data/note_store.dart';
import '../models/tasting_note.dart';
import '../theme.dart';
import '../widgets/sheet_section.dart';

/// 내 위스키 통계: 진열장과 빈 병이 어디 산인지, 무엇을 주로 마셨는지.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key, required this.store});

  final NoteStore store;

  @override
  Widget build(BuildContext context) {
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
              SheetSection(
                title: '진열장 산지',
                subtitle: 'In the cabinet',
                child: _Bars(_byOrigin(library)),
              ),
              SheetSection(
                title: '진열장 종류',
                subtitle: 'Types',
                child: _Bars(_byType(library)),
              ),
              SheetSection(
                title: '다 마신 병은 어디 산?',
                subtitle: 'Emptied',
                child: memories.isEmpty
                    ? const Text(
                        '아직 비운 병이 없어요.',
                        style: TextStyle(color: NoteColors.hint),
                      )
                    : _Bars(_byOrigin(memories)),
              ),
              if (scored.isNotEmpty)
                SheetSection(
                  title: '최고 점수',
                  subtitle: 'Top rated',
                  child: Column(
                    children: [
                      for (final (i, n)
                          in ([...scored]
                                ..sort((a, b) => b.score!.compareTo(a.score!)))
                              .take(5)
                              .indexed)
                        _RankRow(rank: i + 1, note: n),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// 산지별 병 수. Scotland는 세부 지역 분포도 함께.
  static List<_Bar> _byOrigin(List<TastingNote> notes) {
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

  static List<_Bar> _byType(List<TastingNote> notes) {
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
  const _RankRow({required this.rank, required this.note});

  final int rank;
  final TastingNote note;

  @override
  Widget build(BuildContext context) {
    final s = note.score!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(
              '$rank',
              style: const TextStyle(
                fontFamily: serif,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: NoteColors.gold,
              ),
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
