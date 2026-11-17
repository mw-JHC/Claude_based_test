import 'package:material_ui/material_ui.dart';

import '../data/app_settings.dart';
import '../data/note_store.dart';
import '../data/sample_data.dart';
import '../theme.dart';
import 'note_edit_screen.dart';
import 'note_list_screen.dart';
import '../l10n/tr.dart';

/// 처음 실행할 때 한 번 보여주는 환영 화면.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, required this.store, required this.settings});

  final NoteStore store;
  final AppSettings settings;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _busy = false;

  Future<void> _start({required bool samples}) async {
    setState(() => _busy = true);
    if (samples) await addSampleWhiskies(widget.store);
    await widget.settings.setOnboarded();
    if (!mounted) return;
    final nav = Navigator.of(context);
    nav.pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            NoteListScreen(store: widget.store, settings: widget.settings),
      ),
    );
    // 직접 시작하면 바로 첫 병 입력 화면을 엽니다.
    if (!samples) {
      nav.push(
        MaterialPageRoute(builder: (_) => NoteEditScreen(store: widget.store)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.55),
            radius: 1.1,
            colors: [Color(0xFF3A2212), NoteColors.bg],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            children: [
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Image.asset(
                    'assets/brand/icon_full.png',
                    width: 120,
                    height: 120,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Whisky Library',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: serif,
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  color: NoteColors.text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                tr(
                  '마셔본 위스키를 진열장에 세우고,\n한 잔과 함께한 기억을 남기세요.',
                  'Line up every whisky you have tasted\nand keep the memories of each dram.',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: NoteColors.hint,
                ),
              ),
              const SizedBox(height: 28),
              _Feature(
                icon: Icons.shelves,
                title: tr('나만의 진열장', 'Your own cabinet'),
                text: tr(
                  '원목장, 바 진열장, 박물관 케이스. 길게 눌러 끌면 자리를 바꿔요.',
                  'Wood cabinet, back bar or museum cases. Long-press and drag to rearrange.',
                ),
              ),
              _Feature(
                icon: Icons.photo_camera_outlined,
                title: tr('병 사진으로 바로 기록', 'Snap the bottle'),
                text: tr(
                  '배경을 지워 진열장에 세우고, 라벨을 읽어 이름을 채워요.',
                  'The background is removed so the bottle stands on your shelf, and the label fills in the name.',
                ),
              ),
              _Feature(
                icon: Icons.radar,
                title: tr(
                  '향 · 맛 · 개성 테이스팅 노트',
                  'Nose · palate · character notes',
                ),
                text: tr(
                  '차트를 눌러 강도를 정하고, 마신 날마다 이야기를 남겨요.',
                  'Tap the charts to rate intensity and add a story every time you pour.',
                ),
              ),
              _Feature(
                icon: Icons.auto_stories_outlined,
                title: 'Memory Library',
                text: tr(
                  '다 마신 병은 지우지 않고 빈 병 전시장에 추억으로 남아요.',
                  'Finished bottles are not deleted — they live on in your empty-bottle gallery.',
                ),
              ),
              SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _busy ? null : () => _start(samples: false),
                icon: const Icon(Icons.add),
                label: Text(tr('첫 병 진열하기', 'Add your first bottle')),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                ),
              ),
              SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _start(samples: true),
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.visibility_outlined),
                label: Text(tr('샘플 위스키로 둘러보기', 'Explore with sample whiskies')),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                tr(
                  '샘플은 설정에서 언제든 지울 수 있어요.',
                  'You can remove the samples in Settings at any time.',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: NoteColors.faint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: NoteColors.surfaceHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: NoteColors.gold, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: NoteColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.45,
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
}
