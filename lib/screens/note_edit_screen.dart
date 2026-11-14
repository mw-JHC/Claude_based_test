import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../data/note_store.dart';
import '../models/tasting_note.dart';
import '../theme.dart';
import '../widgets/character_slider.dart';
import '../widgets/color_scale.dart';
import '../widgets/flavor_wheel.dart';
import '../widgets/note_photo.dart';
import '../widgets/sheet_section.dart';

/// 새 노트 작성 / 기존 노트 수정 화면. PDF 양식 순서를 따릅니다.
class NoteEditScreen extends StatefulWidget {
  const NoteEditScreen({super.key, required this.store, this.original});

  final NoteStore store;
  final TastingNote? original;

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
  bool _photoRemoved = false;
  bool _saving = false;

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

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final x = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (x != null) {
        setState(() {
          _pickedPhoto = x.path;
          _photoRemoved = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('사진을 가져오지 못했습니다: $e')));
    }
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
      if (_pickedPhoto != null) {
        _note.photo = await widget.store.storage.importPhoto(
          _pickedPhoto!,
          _note.id,
        );
      } else if (_photoRemoved) {
        _note.photo = null;
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

  File? get _photoFile {
    if (_pickedPhoto != null) return File(_pickedPhoto!);
    if (_photoRemoved) return null;
    return widget.store.storage.photoFile(_note.photo);
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
            _basicInfo(),
            SheetSection(
              title: '색상',
              subtitle: 'Color',
              child: ColorScalePicker(
                value: _note.color,
                onChanged: (v) => setState(() => _note.color = v),
              ),
            ),
            _photoSection(),
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

  Widget _photoSection() {
    final file = _photoFile;
    return SheetSection(
      title: '사진',
      subtitle: 'Photo',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (file != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(height: 240, child: NotePhoto(file: file)),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickPhoto(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('촬영'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickPhoto(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('갤러리'),
                ),
              ),
              if (file != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: '사진 삭제',
                  onPressed: () => setState(() {
                    _pickedPhoto = null;
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
