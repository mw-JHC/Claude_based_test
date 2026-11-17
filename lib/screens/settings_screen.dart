import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/app_settings.dart';
import '../data/backup.dart';
import '../data/note_store.dart';
import '../data/sample_data.dart';
import '../theme.dart';
import '../widgets/cabinet_view.dart';
import '../widgets/sheet_section.dart';
import '../l10n/tr.dart';

/// 설정 화면. 진열장 분위기를 고릅니다.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.settings,
    required this.store,
  });

  final AppSettings settings;
  final NoteStore store;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            SheetSection(
              title: '언어',
              subtitle: 'Language',
              child: SegmentedButton<AppLanguage>(
                showSelectedIcon: false,
                segments: [
                  for (final l in AppLanguage.values)
                    ButtonSegment(value: l, label: Text(l.nativeName)),
                ],
                selected: {settings.language},
                // 바꾸면 앱 전체가 새 언어로 다시 그려집니다.
                onSelectionChanged: (v) => settings.setLanguage(v.first),
              ),
            ),
            SheetSection(
              title: '진열장 분위기',
              subtitle: 'Cabinet',
              child: Column(
                children: [
                  for (final style in CabinetStyle.values)
                    _StyleOption(
                      style: style,
                      selected: settings.cabinetStyle == style,
                      store: store,
                      onTap: () => settings.setCabinetStyle(style),
                    ),
                ],
              ),
            ),
            SheetSection(
              title: '백업 및 복원',
              subtitle: 'Backup',
              child: _BackupButtons(store: store),
            ),
            SheetSection(
              title: '샘플 데이터',
              subtitle: 'Samples',
              child: _SampleButtons(store: store),
            ),
            const SheetSection(
              title: '앱 정보',
              subtitle: 'About',
              child: _About(),
            ),
          ],
        ),
      ),
    );
  }
}

/// 샘플 위스키 40병 넣기 / 지우기 (직접 넣은 병은 건드리지 않음).
class _SampleButtons extends StatefulWidget {
  const _SampleButtons({required this.store});

  final NoteStore store;

  @override
  State<_SampleButtons> createState() => _SampleButtonsState();
}

class _SampleButtonsState extends State<_SampleButtons> {
  bool _busy = false;

  Future<void> _run(Future<int> Function(NoteStore) job, String done) async {
    setState(() => _busy = true);
    final count = await job(widget.store);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(done.replaceAll('{n}', '$count'))));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr(
            '여러 산지·종류의 위스키 40병(빈 병 8병, 이야기 포함)을 넣어 기능을 시험해 볼 수 있어요. '
                '지우기는 샘플만 지우고 직접 넣은 병은 그대로 둡니다.',
            'Add 40 whiskies from many origins and styles (8 empty, with stories) to try things out. '
                'Removing them only deletes the samples, never your own bottles.',
          ),
          style: TextStyle(color: NoteColors.hint, fontSize: 12.5, height: 1.5),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () => _run(
                        addSampleWhiskies,
                        tr('샘플 {n}병을 넣었어요.', 'Added {n} sample bottles.'),
                      ),
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.playlist_add),
                label: Text(tr('샘플 40병 넣기', 'Add 40 samples')),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => _run(
                        removeSampleWhiskies,
                        tr('샘플 {n}병을 지웠어요.', 'Removed {n} sample bottles.'),
                      ),
                icon: const Icon(Icons.delete_sweep_outlined),
                label: Text(tr('샘플 지우기', 'Remove samples')),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 진열장 스타일 하나: 이름, 설명, 내 위스키로 그린 작은 미리보기.
class _StyleOption extends StatelessWidget {
  const _StyleOption({
    required this.style,
    required this.selected,
    required this.store,
    required this.onTap,
  });

  final CabinetStyle style;
  final bool selected;
  final NoteStore store;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 미리보기는 실제 진열장의 첫 줄만 잘라서 보여줍니다.
    final sample = store.library.take(4).toList();
    return Semantics(
      button: true,
      selected: selected,
      label: style.label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: NoteColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? NoteColors.amber : NoteColors.line,
              width: selected ? 3 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 170,
                child: IgnorePointer(
                  child: ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.topCenter,
                      maxHeight: 420,
                      child: SizedBox(
                        height: 420,
                        child: CabinetView(
                          store: store,
                          notes: sample,
                          style: style,
                          onOpen: (_) {},
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            style.label,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            style.description,
                            style: const TextStyle(
                              fontSize: 12,
                              color: NoteColors.hint,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      selected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: selected ? NoteColors.amber : NoteColors.faint,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 백업 파일 만들기(공유) / 백업 파일에서 복원.
class _BackupButtons extends StatefulWidget {
  const _BackupButtons({required this.store});

  final NoteStore store;

  @override
  State<_BackupButtons> createState() => _BackupButtonsState();
}

class _BackupButtonsState extends State<_BackupButtons> {
  bool _busy = false;

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final info = await PackageInfo.fromPlatform();
      final bytes = await BackupService(widget.store)
          .build(appVersion: info.version);
      final d = DateTime.now();
      final stamp =
          '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/WhiskyLibrary_backup_$stamp.zip');
      await file.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/zip')],
          subject: tr('Whisky Library 백업', 'Whisky Library backup'),
          // 태블릿에서 공유 창 위치
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (e) {
      if (mounted) {
        _snack(tr('백업 파일을 만들지 못했어요: $e', 'Could not create the backup: $e'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
    );
    if (picked == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final bytes = await picked.readAsBytes();
      final service = BackupService(widget.store);
      final summary = service.inspect(bytes);
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(tr('백업에서 복원할까요?', 'Restore from backup?')),
          content: Text(
            tr(
              '백업 파일: 위스키 ${summary.notes}병, 사진 ${summary.photos}장'
                  '${summary.createdAt == null ? '' : '\n만든 날: ${tr.date(summary.createdAt!)}'}\n\n'
                  '지금 앱에 있는 기록은 모두 백업 내용으로 바뀝니다.',
              'Backup: ${tr.bottles(summary.notes)}, ${summary.photos} photos'
                  '${summary.createdAt == null ? '' : '\nCreated: ${tr.date(summary.createdAt!)}'}\n\n'
                  'Everything currently in the app will be replaced by the backup.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(tr('취소', 'Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(tr('복원', 'Restore')),
            ),
          ],
        ),
      );
      if (ok != true) return;
      final count = await service.restore(bytes);
      if (mounted) {
        _snack(tr('위스키 $count병을 복원했어요.', 'Restored ${tr.bottles(count)}.'));
      }
    } on BackupException catch (e) {
      if (mounted) _snack(e.message);
    } catch (e) {
      if (mounted) _snack(tr('복원하지 못했어요: $e', 'Could not restore: $e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr(
            '기록은 이 폰 안에만 저장돼요. 폰을 바꾸거나 앱을 지우기 전에 백업 파일을 '
                '만들어 Google Drive나 메일로 보관하세요. 사진과 이야기까지 모두 들어갑니다.',
            'Your notes live only on this phone. Before changing phones or uninstalling, '
                'create a backup file and keep it in Google Drive or your mail. Photos and stories are included.',
          ),
          style: TextStyle(color: NoteColors.hint, fontSize: 12.5, height: 1.5),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _busy ? null : _export,
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.ios_share),
                label: Text(tr('백업 만들기', 'Create backup')),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _import,
                icon: const Icon(Icons.settings_backup_restore),
                label: Text(tr('복원하기', 'Restore')),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 앱 버전, 개인정보 안내, 오픈소스 라이선스.
class _About extends StatelessWidget {
  const _About();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snap) => _row(
            Icons.local_bar_outlined,
            'Whisky Library',
            snap.hasData
                ? '${tr('버전', 'Version')} ${snap.data!.version} (${snap.data!.buildNumber})'
                : '',
          ),
        ),
        _row(
          Icons.lock_outline,
          tr('개인정보', 'Privacy'),
          tr(
            '모든 기록과 사진은 이 폰에만 저장되고 어디에도 보내지 않아요. '
                '사진 배경 지우기와 라벨 읽기도 폰 안에서 처리됩니다.',
            'All notes and photos stay on this phone and are never uploaded. '
                'Background removal and label reading also run on the device.',
          ),
        ),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: () => showLicensePage(
            context: context,
            applicationName: 'Whisky Library',
            applicationIcon: Padding(
              padding: const EdgeInsets.all(12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  'assets/brand/icon_full.png',
                  width: 64,
                  height: 64,
                ),
              ),
            ),
          ),
          icon: const Icon(Icons.description_outlined),
          label: Text(tr('오픈소스 라이선스', 'Open-source licences')),
        ),
      ],
    );
  }

  Widget _row(IconData icon, String title, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: NoteColors.gold),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: NoteColors.text,
                ),
              ),
              if (text.isNotEmpty)
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: NoteColors.hint,
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
