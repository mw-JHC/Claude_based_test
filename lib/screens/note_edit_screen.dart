import 'dart:io';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../data/note_store.dart';
import '../models/tasting_note.dart';
import '../services/bottle_scanner.dart';
import '../services/label_parser.dart';
import '../theme.dart';
import '../widgets/character_slider.dart';
import '../widgets/color_scale.dart';
import '../widgets/flavor_wheel.dart';
import '../widgets/note_photo.dart';
import '../widgets/sheet_section.dart';
import 'bottle_camera_screen.dart';

/// 새 노트 작성 / 기존 노트 수정 화면. PDF 양식 순서를 따릅니다.
class NoteEditScreen extends StatefulWidget {
  const NoteEditScreen({
    super.key,
    required this.store,
    this.original,
    this.scanner = const MlKitBottleScanner(),
  });

  final NoteStore store;
  final TastingNote? original;

  /// 사진에서 병 오려내기와 라벨 읽기를 맡습니다 (테스트에서 바꿔 끼움).
  final BottleScanner scanner;

  @override
  State<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends State<NoteEditScreen> {
  late final TastingNote _note =
      widget.original?.copy() ?? TastingNote.create();

  late final _name = TextEditingController(text: _note.name);
  late final _region = TextEditingController(text: _note.region);
  late final _ageCask = TextEditingController(text: _note.ageCask);
  late final _abv = TextEditingController(text: _fmt(_note.abv));
  late final _price = TextEditingController(text: _note.price);
  late final _score = TextEditingController(text: _fmt(_note.score));
  late final _overall = TextEditingController(text: _note.overall);

  /// 새로 고른 사진 (저장할 때 앱 폴더로 복사).
  String? _pickedPhoto;

  /// 새로 고른 사진에서 배경을 지운 병 (PNG).
  Uint8List? _pickedCutout;

  /// 진열장에 배경을 지운 병을 쓸지, 원본 사진을 쓸지.
  late bool _useCutout = _note.cutout != null;
  bool _photoRemoved = false;
  bool _processing = false;
  bool _saving = false;

  /// 라벨에서 읽은 글자들 (눌러서 이름에 덧붙이기).
  List<String> _labelWords = const [];

  static String _fmt(double? v) {
    if (v == null) return '';
    return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  }

  static double? _parse(String s) =>
      double.tryParse(s.trim().replaceAll(',', '.'));

  @override
  void dispose() {
    for (final c in [
      _name,
      _region,
      _ageCask,
      _abv,
      _price,
      _score,
      _overall,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _takePhoto() async {
    final path = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BottleCameraScreen()),
    );
    if (path != null) await _usePhoto(path);
  }

  Future<void> _pickFromGallery() async {
    try {
      final x = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        imageQuality: 90,
      );
      if (x != null) await _usePhoto(x.path);
    } catch (e) {
      _snack('사진을 가져오지 못했습니다: $e');
    }
  }

  @visibleForTesting
  Future<void> usePhotoForTest(String path) => _usePhoto(path);

  /// 새 사진: 배경을 지우고 라벨을 읽어서 빈 칸을 채웁니다.
  Future<void> _usePhoto(String path) async {
    setState(() {
      _pickedPhoto = path;
      _pickedCutout = null;
      _photoRemoved = false;
      _processing = true;
    });
    final results = await Future.wait([
      widget.scanner.cutout(path),
      widget.scanner.readText(path),
    ]);
    if (!mounted) return;
    final cutout = results[0] as Uint8List?;
    final guess = parseLabel(results[1] as List<OcrLine>);
    final filled = _applyGuess(guess);
    setState(() {
      _processing = false;
      _pickedCutout = cutout;
      _useCutout = cutout != null;
      _labelWords = guess.words;
    });
    final parts = [
      if (cutout == null) '이 기기에서는 배경을 지우지 못해 원본 사진을 씁니다.',
      if (filled.isNotEmpty) '라벨에서 ${filled.join(', ')}을(를) 읽었어요. 틀리면 고쳐 주세요.',
    ];
    if (parts.isNotEmpty) _snack(parts.join('\n'));
  }

  /// 라벨에서 읽은 정보로 비어 있는 칸만 채웁니다. 채운 항목 이름을 돌려줍니다.
  List<String> _applyGuess(LabelGuess g) {
    final filled = <String>[];
    if (_name.text.trim().isEmpty && g.name != null) {
      _name.text = g.name!;
      filled.add('이름 "${g.name}"');
    }
    if (_ageCask.text.trim().isEmpty && g.age != null) {
      _ageCask.text = '${g.age}년';
      filled.add('숙성 ${g.age}년');
    }
    if (_region.text.trim().isEmpty && g.region != null) {
      _region.text = g.region!;
      filled.add('지역');
    }
    if (_note.type == null && g.type != null) {
      _note.type = g.type;
      filled.add('종류');
    }
    return filled;
  }

  void _addWord(String word) {
    final current = _name.text.trim();
    _name.text = current.isEmpty ? word : '$current $word';
    _name.selection = TextSelection.collapsed(offset: _name.text.length);
    setState(() {});
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('위스키 이름을 입력해 주세요.')));
      return;
    }
    setState(() => _saving = true);
    _note
      ..name = _name.text.trim()
      ..region = _region.text.trim()
      ..ageCask = _ageCask.text.trim()
      ..abv = _parse(_abv.text)
      ..price = _price.text.trim()
      ..score = _parse(_score.text)
      ..overall = _overall.text.trim();
    try {
      final storage = widget.store.storage;
      if (_pickedPhoto != null) {
        _note.photo = await storage.importPhoto(_pickedPhoto!, _note.id);
        _note.cutout = _pickedCutout != null && _useCutout
            ? await storage.importBytes(_pickedCutout!, _note.id, '.png')
            : null;
      } else if (_photoRemoved) {
        _note
          ..photo = null
          ..cutout = null;
      } else if (!_useCutout) {
        _note.cutout = null;
      }
      await widget.store.upsert(_note);
      if (mounted) Navigator.of(context).pop(_note);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('저장하지 못했습니다: $e')));
    }
  }

  ImageProvider? get _photoImage {
    if (_pickedPhoto != null) return FileImage(File(_pickedPhoto!));
    if (_photoRemoved) return null;
    return widget.store.storage.image(_note.photo);
  }

  ImageProvider? get _cutoutImage {
    if (_photoRemoved) return null;
    if (_pickedPhoto != null) {
      return _pickedCutout == null ? null : MemoryImage(_pickedCutout!);
    }
    return widget.store.storage.image(_note.cutout);
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.original == null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? '새 테이스팅 노트' : '노트 수정'),
        actions: [
          IconButton(
            tooltip: '저장',
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.check),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _photoSection(),
            _basicInfo(),
            SheetSection(
              title: '색상',
              subtitle: 'Color',
              child: ColorScalePicker(
                value: _note.color,
                onChanged: (v) => setState(() => _note.color = v),
              ),
            ),
            SheetSection(
              title: '향',
              subtitle: 'Nose',
              child: FlavorWheel(
                axes: aromaAxes,
                values: _note.nose,
                onChanged: (i, v) => setState(() => _note.nose[i] = v),
              ),
            ),
            SheetSection(
              title: '맛',
              subtitle: 'Palate',
              child: FlavorWheel(
                axes: palateAxes,
                values: _note.palate,
                color: const Color(0xFFB0202A),
                onChanged: (i, v) => setState(() => _note.palate[i] = v),
              ),
            ),
            SheetSection(
              title: '비후방 후각',
              subtitle: 'Retronasal',
              child: FlavorWheel(
                axes: aromaAxes,
                values: _note.retronasal,
                color: const Color(0xFF3F5E2E),
                onChanged: (i, v) => setState(() => _note.retronasal[i] = v),
              ),
            ),
            SheetSection(
              title: '개성',
              subtitle: 'Characters',
              child: Column(
                children: [
                  for (final s in characterScales)
                    CharacterSlider(
                      scale: s,
                      value: _note.characters[s.key]!,
                      onChanged: (v) =>
                          setState(() => _note.characters[s.key] = v),
                    ),
                ],
              ),
            ),
            SheetSection(
              title: '여운',
              subtitle: 'Finish',
              child: CharacterSlider(
                scale: finishScale,
                value: _note.finish,
                onChanged: (v) => setState(() => _note.finish = v),
              ),
            ),
            SheetSection(
              title: '총평',
              subtitle: 'Overall',
              child: TextField(
                controller: _overall,
                minLines: 4,
                maxLines: null,
                decoration: const InputDecoration(
                  hintText: '전체적인 인상, 같이 마신 사람, 다시 살지 …',
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save),
              label: const Text('저장'),
              style: FilledButton.styleFrom(
                backgroundColor: NoteColors.leather,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _basicInfo() {
    Widget field(
      TextEditingController c,
      String label, {
      String? suffix,
      bool number = false,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        decoration: InputDecoration(labelText: label, suffixText: suffix),
      ),
    );

    return SheetSection(
      title: 'Whiskey Tasting Note',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final t in WhiskyType.values)
                ChoiceChip(
                  label: Text(t.label),
                  selected: _note.type == t,
                  selectedColor: NoteColors.gold,
                  onSelected: (on) =>
                      setState(() => _note.type = on ? t : null),
                ),
            ],
          ),
          const SizedBox(height: 12),
          field(_name, '이름 / Name *'),
          if (_labelWords.isNotEmpty) _labelWordChips(),
          field(_region, '국가 / 지역'),
          field(_ageCask, '숙성연도 / 캐스크'),
          Row(
            children: [
              Expanded(child: field(_abv, '도수 ABV', suffix: '%', number: true)),
              const SizedBox(width: 8),
              Expanded(
                child: field(
                  _score,
                  '점수 / Score',
                  suffix: '/ 100',
                  number: true,
                ),
              ),
            ],
          ),
          field(_price, '가격 / Price (예: €65 / 70cl)'),
        ],
      ),
    );
  }

  Widget _labelWordChips() => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '라벨에서 읽은 글자 (누르면 이름에 덧붙여요)',
          style: TextStyle(fontSize: 12, color: NoteColors.hint),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final w in _labelWords)
              ActionChip(
                label: Text(w, style: const TextStyle(fontSize: 12)),
                visualDensity: VisualDensity.compact,
                onPressed: () => _addWord(w),
              ),
          ],
        ),
      ],
    ),
  );

  Widget _photoSection() {
    final photo = _photoImage;
    final cutout = _cutoutImage;
    final showCutout = _useCutout && cutout != null;
    return SheetSection(
      title: '병 사진',
      subtitle: 'Photo',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_processing)
            Container(
              height: 280,
              color: NoteColors.ink,
              alignment: Alignment.center,
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: NoteColors.gold),
                  SizedBox(height: 12),
                  Text(
                    '병만 오려내고 라벨을 읽는 중…',
                    style: TextStyle(color: NoteColors.gold),
                  ),
                ],
              ),
            )
          else if (photo != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 280,
                child: NotePhoto(
                  image: showCutout ? cutout : photo,
                  cutout: showCutout,
                ),
              ),
            ),
            if (cutout != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: true,
                      icon: Icon(Icons.auto_awesome),
                      label: Text('병만 (진열장용)'),
                    ),
                    ButtonSegment(
                      value: false,
                      icon: Icon(Icons.image_outlined),
                      label: Text('원본 사진'),
                    ),
                  ],
                  selected: {_useCutout},
                  onSelectionChanged: (v) =>
                      setState(() => _useCutout = v.first),
                ),
              ),
          ] else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '병을 찍으면 배경을 지워 진열장에 세우고,\n라벨을 읽어 이름과 숙성 연수를 채워 드려요.',
                textAlign: TextAlign.center,
                style: TextStyle(color: NoteColors.hint, height: 1.4),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _processing ? null : _takePhoto,
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('병 촬영'),
                  style: FilledButton.styleFrom(
                    backgroundColor: NoteColors.leather,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _processing ? null : _pickFromGallery,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('갤러리'),
                ),
              ),
              if (photo != null && !_processing) ...[
                const SizedBox(width: 4),
                IconButton(
                  tooltip: '사진 삭제',
                  onPressed: () => setState(() {
                    _pickedPhoto = null;
                    _pickedCutout = null;
                    _labelWords = const [];
                    _photoRemoved = true;
                  }),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
