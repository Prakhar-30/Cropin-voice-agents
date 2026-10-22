import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../data/demo_data.dart';
import '../data/models.dart';
import '../services/location_service.dart';
import '../services/speech_service.dart';
import '../services/tts_service.dart';
import '../theme/app_theme.dart';
import '../voice/agent_strings.dart';
import '../voice/nlu/form_parser.dart';
import '../voice/nlu/nbest.dart';
import '../voice/nlu/slots.dart';
import '../widgets/common.dart';
import '../widgets/form_fields.dart';
import '../widgets/top_bar.dart';
import '../widgets/voice_sheet.dart';

/// Add Asset (plot) with speak-to-fill: owner, project, soil, irrigation,
/// declared area and unit from one utterance.
class AddAssetScreen extends StatefulWidget {
  const AddAssetScreen({super.key, this.initialUtterance, this.prefill, this.ownerId});
  final String? initialUtterance;
  final FormParseResult? prefill;
  final String? ownerId;

  @override
  State<AddAssetScreen> createState() => _AddAssetScreenState();
}

class _AddAssetScreenState extends State<AddAssetScreen> {
  final store = AppStore.instance;
  final assetName = TextEditingController(text: 'ASSET-${DateTime.now().millisecondsSinceEpoch}');
  final area = TextEditingController();
  String? ownerId;
  String? projectId;
  String? soil;
  String? irrigation;
  String unit = 'acre';
  String? crop;

  final marks = <String, VoiceMark>{};
  final heard = <String, String>{};
  List<String> unmapped = [];
  bool usedVoice = false;

  @override
  void initState() {
    super.initState();
    ownerId = widget.ownerId;
    if (ownerId != null) {
      final f = store.farmer(ownerId);
      if (f != null && f.projectIds.isNotEmpty) projectId = f.projectIds.first;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.prefill != null) _applyResult(widget.prefill!, speak: false);
      if (widget.initialUtterance != null) _apply(widget.initialUtterance!);
    });
  }

  @override
  void dispose() {
    assetName.dispose();
    area.dispose();
    super.dispose();
  }

  Future<void> _speak() async {
    final text = await showVoiceSheet(context,
        exampleKey: 'asset',
        title: 'Speak to fill',
        subtitle: 'Farmer, project, soil, irrigation, area');
    if (text != null) _apply(text);
  }

  void _apply(String text) {
    final parser = FormParser(projects: store.projectRefs, farmers: store.farmerRefs);
    final (_, r) = NBest.pick(SpeechService.instance.hypothesesFor(text),
        (h) => parser.parse(h, extractName: false, extractOwner: true), NBest.formScore);
    _applyResult(r);
  }

  void _mark(String key, Slot<Object>? s) {
    if (s == null) return;
    marks[key] = markFor(s.confidence);
    heard[key] = s.heard;
  }

  void _applyResult(FormParseResult r, {bool speak = true}) {
    usedVoice = true;
    setState(() {
      if (r.ownerId != null) {
        ownerId = r.ownerId!.value;
        _mark('owner', r.ownerId);
        final f = store.farmer(ownerId);
        if (r.projectId == null && f != null && f.projectIds.isNotEmpty) {
          projectId = f.projectIds.first;
          marks['project'] = VoiceMark.check;
          heard['project'] = "farmer's project";
        }
      }
      if (r.projectId != null) {
        projectId = r.projectId!.value;
        _mark('project', r.projectId);
      }
      if (r.soil != null) {
        soil = r.soil!.value;
        _mark('soil', r.soil);
      }
      if (r.irrigation != null) {
        irrigation = r.irrigation!.value;
        _mark('irrigation', r.irrigation);
      }
      if (r.area != null) {
        final v = r.area!.value;
        area.text = v == v.roundToDouble() ? v.toInt().toString() : v.toString();
        _mark('area', r.area);
      }
      if (r.areaUnit != null) {
        unit = r.areaUnit!.value;
        _mark('unit', r.areaUnit);
      }
      if (r.crop != null) crop = r.crop!.value;
      unmapped = r.unmapped;
    });
    if (!speak) return;
    final filled = [r.ownerId, r.projectId, r.soil, r.irrigation, r.area, r.areaUnit]
        .whereType<Slot<Object>>();
    final strings = AgentStrings(store.language);
    TtsService.instance.speak(
        filled.isEmpty
            ? strings.notUnderstood
            : strings.formFilled(filled.length, filled.where((s) => s.needsCheck).length),
        store.language);
  }

  Future<void> _submit() async {
    final a = double.tryParse(area.text.trim());
    final errors = <String>[
      if (ownerId == null) 'Belongs To',
      if (projectId == null) 'Project',
      if (soil == null) 'Soil Type',
      if (irrigation == null) 'Irrigation Type',
      if (a == null || a <= 0) 'Declared Area',
    ];
    if (errors.isNotEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Please fill: ${errors.join(', ')}')));
      return;
    }
    final fix = await LocationService.instance.current();
    if (!mounted) return;
    final asset = store.addAsset(
      name: assetName.text.trim(),
      farmerId: ownerId!,
      projectId: projectId!,
      soil: soil!,
      irrigation: irrigation!,
      area: a!,
      unit: unit,
      crop: crop,
      location: fix.point,
      byVoice: usedVoice,
    );
    TtsService.instance.speak(AgentStrings(store.language).saved, store.language);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Asset ${asset.name} added')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: cropinTitleBar(context, 'Add Asset', actions: [
        IconButton(onPressed: _speak, icon: const Icon(Icons.mic, size: 23), tooltip: 'Speak to fill'),
      ]),
      body: ListView(
        children: [
          InkWell(
            onTap: _speak,
            child: Container(
              color: const Color(0xFFF4FAEC),
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
              child: Row(children: [
                const Icon(Icons.record_voice_over_outlined, color: CropinColors.primary, size: 25),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Speak to fill · offline · ${store.language.nativeName}\n'
                    '"Plot for <farmer>, red soil, drip, 2 acres"',
                    style: const TextStyle(fontSize: 12, color: CropinColors.text),
                  ),
                ),
                const Icon(Icons.mic, color: CropinColors.green, size: 25),
              ]),
            ),
          ),
          const SizedBox(height: 22),
          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF2F4F5),
                border: Border.all(color: CropinColors.primary, width: 1.4),
              ),
              child: const Icon(Icons.add_a_photo_outlined, size: 33, color: CropinColors.primary),
            ),
          ),
          const SizedBox(height: 22),
          const SectionGap(),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Primary Information',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 22),
              UnmappedBanner(words: unmapped, onDismiss: () => setState(() => unmapped = [])),
              VoiceTextField(label: 'Asset Name', controller: assetName),
              VoiceSelectField<Farmer>(
                label: 'Belongs To',
                required: true,
                value: store.farmer(ownerId),
                options: store.farmers,
                display: (f) => f.name,
                subtitle: (f) => '${f.code} · ${f.locality}',
                mark: marks['owner'] ?? VoiceMark.none,
                heard: heard['owner'],
                onChanged: (f) => setState(() {
                  ownerId = f.id;
                  marks.remove('owner');
                }),
              ),
              VoiceSelectField<Project>(
                label: 'Project',
                required: true,
                value: store.project(projectId),
                options: store.projects,
                display: (p) => p.name,
                subtitle: (p) => '${p.crop} · ${p.season}',
                mark: marks['project'] ?? VoiceMark.none,
                heard: heard['project'],
                onChanged: (p) => setState(() {
                  projectId = p.id;
                  crop = p.crop;
                  marks.remove('project');
                }),
              ),
              VoiceSelectField<String>(
                label: 'Soil Type',
                required: true,
                value: soil,
                options: DemoData.soils,
                display: (s) => s,
                mark: marks['soil'] ?? VoiceMark.none,
                heard: heard['soil'],
                onChanged: (s) => setState(() {
                  soil = s;
                  marks.remove('soil');
                }),
              ),
              VoiceSelectField<String>(
                label: 'Irrigation Type',
                required: true,
                value: irrigation,
                options: DemoData.irrigationTypes,
                display: (s) => s,
                mark: marks['irrigation'] ?? VoiceMark.none,
                heard: heard['irrigation'],
                onChanged: (s) => setState(() {
                  irrigation = s;
                  marks.remove('irrigation');
                }),
              ),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: VoiceTextField(
                    label: 'Declared Area',
                    required: true,
                    controller: area,
                    hint: 'Area',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    mark: marks['area'] ?? VoiceMark.none,
                    onEdited: () => setState(() => marks.remove('area')),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: VoiceSelectField<String>(
                    label: 'Declared Area Unit ',
                    required: true,
                    compact: true,
                    value: unit,
                    options: DemoData.areaUnits,
                    display: (s) => s,
                    mark: marks['unit'] ?? VoiceMark.none,
                    onChanged: (s) => setState(() {
                      unit = s;
                      marks.remove('unit');
                    }),
                  ),
                ),
              ]),
              if (crop != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text('Crop: $crop',
                      style: const TextStyle(fontSize: 12, color: CropinColors.subText)),
                ),
            ]),
          ),
        ],
      ),
      bottomNavigationBar: BottomActions(
        left: SecondaryButton(label: 'Cancel', onPressed: () => Navigator.of(context).pop()),
        right: PrimaryButton(label: 'Submit', onPressed: _submit),
      ),
    );
  }
}
