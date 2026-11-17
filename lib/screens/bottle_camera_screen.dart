import 'package:camera/camera.dart';
import 'package:material_ui/material_ui.dart';

import '../theme.dart';
import '../l10n/tr.dart';

/// 병 모양 가이드 틀이 겹쳐진 카메라 화면.
///
/// 병을 틀 안에 정면으로 맞추고 찍으면 배경 제거와 라벨 읽기가 잘 됩니다.
/// 찍은 사진의 파일 경로를 돌려줍니다 (취소하면 null).
class BottleCameraScreen extends StatefulWidget {
  const BottleCameraScreen({super.key});

  @override
  State<BottleCameraScreen> createState() => _BottleCameraScreenState();
}

class _BottleCameraScreenState extends State<BottleCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  String? _error;
  bool _taking = false;
  bool _flash = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 앱이 뒤로 가면 카메라를 놓아주고, 돌아오면 다시 켭니다.
    final c = _controller;
    if (state == AppLifecycleState.inactive) {
      _controller = null;
      c?.dispose();
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed && c == null) {
      _start();
    }
  }

  Future<void> _start() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(
          () => _error = tr('사용할 수 있는 카메라가 없습니다.', 'No camera available.'),
        );
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.veryHigh,
        enableAudio: false,
      );
      await controller.initialize();
      await controller.setFlashMode(FlashMode.off);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _error = null;
      });
    } on CameraException catch (e) {
      setState(
        () => _error = e.code == 'CameraAccessDenied'
            ? tr(
                '카메라 권한이 필요합니다. 설정에서 카메라 권한을 허용해 주세요.',
                'Camera permission is needed. Please allow it in the system settings.',
              )
            : tr(
                '카메라를 켜지 못했습니다: ${e.description ?? e.code}',
                'Could not start the camera: ${e.description ?? e.code}',
              ),
      );
    }
  }

  Future<void> _take() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _taking) return;
    setState(() => _taking = true);
    try {
      final file = await c.takePicture();
      if (mounted) Navigator.of(context).pop(file.path);
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() => _taking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              '사진을 찍지 못했습니다: ${e.description ?? e.code}',
              'Could not take the photo: ${e.description ?? e.code}',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _toggleFlash() async {
    final c = _controller;
    if (c == null) return;
    final next = !_flash;
    await c.setFlashMode(next ? FlashMode.torch : FlashMode.off);
    setState(() => _flash = next);
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Expanded(
              child: Center(
                child: _error != null
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      )
                    : c == null || !c.value.isInitialized
                    ? const CircularProgressIndicator(color: NoteColors.gold)
                    : Stack(
                        children: [
                          CameraPreview(c),
                          const Positioned.fill(child: BottleGuideOverlay()),
                        ],
                      ),
              ),
            ),
            _bottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _topBar() => Padding(
    padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
    child: Row(
      children: [
        IconButton(
          tooltip: tr('닫기', 'Close'),
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close, color: Colors.white),
        ),
        Expanded(
          child: Text(
            tr(
              '병을 틀 안에 정면으로 맞춰 주세요\n라벨이 잘 보이게, 단색 배경이면 더 좋아요',
              'Fit the bottle inside the frame, facing you\nKeep the label visible — a plain background works best',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
          ),
        ),
        IconButton(
          tooltip: _flash ? tr('조명 끄기', 'Torch off') : tr('조명 켜기', 'Torch on'),
          onPressed: _controller == null ? null : _toggleFlash,
          icon: Icon(
            _flash ? Icons.flash_on : Icons.flash_off,
            color: _flash ? NoteColors.gold : Colors.white,
          ),
        ),
      ],
    ),
  );

  Widget _bottomBar() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20),
    child: Semantics(
      button: true,
      label: tr('촬영', 'Take photo'),
      child: GestureDetector(
        onTap: _take,
        child: Container(
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
          ),
          padding: const EdgeInsets.all(5),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _taking ? NoteColors.gold : Colors.white,
            ),
          ),
        ),
      ),
    ),
  );
}

/// 카메라 화면 위에 병 실루엣 틀을 그리고, 틀 바깥은 어둡게 덮습니다.
class BottleGuideOverlay extends StatelessWidget {
  const BottleGuideOverlay({super.key});

  @override
  Widget build(BuildContext context) =>
      IgnorePointer(child: CustomPaint(painter: _GuidePainter()));
}

class _GuidePainter extends CustomPainter {
  /// 화면 크기에 맞춘 병 실루엣 (가운데, 화면 높이의 약 80%).
  static Path bottle(Size s) {
    final h = s.height * 0.80;
    final w = (h * 0.36).clamp(0.0, s.width * 0.62);
    final cx = s.width / 2;
    final top = (s.height - h) / 2;
    final neck = w * 0.34;
    final shoulderTop = top + h * 0.30;
    final shoulderBottom = top + h * 0.42;
    final bottom = top + h;
    final r = w * 0.10;
    final l = cx - w / 2, rr = cx + w / 2;
    final nl = cx - neck / 2, nr = cx + neck / 2;
    return Path()
      ..moveTo(nl, top + 6)
      ..quadraticBezierTo(nl, top, nl + 6, top)
      ..lineTo(nr - 6, top)
      ..quadraticBezierTo(nr, top, nr, top + 6)
      ..lineTo(nr, shoulderTop)
      ..cubicTo(
        nr,
        shoulderTop + (shoulderBottom - shoulderTop) * 0.6,
        rr,
        shoulderTop + (shoulderBottom - shoulderTop) * 0.4,
        rr,
        shoulderBottom,
      )
      ..lineTo(rr, bottom - r)
      ..quadraticBezierTo(rr, bottom, rr - r, bottom)
      ..lineTo(l + r, bottom)
      ..quadraticBezierTo(l, bottom, l, bottom - r)
      ..lineTo(l, shoulderBottom)
      ..cubicTo(
        l,
        shoulderTop + (shoulderBottom - shoulderTop) * 0.4,
        nl,
        shoulderTop + (shoulderBottom - shoulderTop) * 0.6,
        nl,
        shoulderTop,
      )
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final guide = bottle(size);
    final outside = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      guide,
    );
    canvas.drawPath(
      outside,
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );

    // 점선 테두리
    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = NoteColors.gold;
    for (final metric in guide.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 16) {
        canvas.drawPath(metric.extractPath(d, d + 9), dash);
      }
    }
    // 가운데 세로선: 병을 똑바로 세우는 기준
    final b = guide.getBounds();
    final center = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    for (var y = b.top + b.height * 0.45; y < b.bottom - 10; y += 14) {
      canvas.drawLine(
        Offset(b.center.dx, y),
        Offset(b.center.dx, y + 6),
        center,
      );
    }
  }

  @override
  bool shouldRepaint(_GuidePainter old) => false;
}
