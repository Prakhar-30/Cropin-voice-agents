import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../data/models.dart';
import '../services/speech_service.dart';
import '../services/tts_service.dart';
import '../theme/app_theme.dart';
import '../voice/agent_strings.dart';
import '../voice/nlu/form_parser.dart';
import '../voice/nlu/nbest.dart';
import '../voice/nlu/slots.dart';
import '../voice/nlu/utterance.dart';
import '../widgets/common.dart';
import '../widgets/form_fields.dart';
import '../widgets/top_bar.dart';
import '../widgets/voice_sheet.dart';
import 'add_asset_screen.dart';

/// Add Farmer with speak-to-fill: one utterance fills name, mobile and
/// project; anything that couldn't be mapped is highlighted.
class AddFarmerScreen extends StatefulWidget {
  const AddFarmerScreen({super.key, this.initialUtterance});
  final String? initialUtterance;

  @override
  State<AddFarmerScreen> createState() => _AddFarmerScreenState();
}

class _AddFarmerScreenState extends State<AddFarmerScreen> {
  final store = AppStore.instance;
  final name = TextEditingController();
  final code = TextEditingController(text: 'FC-${DateTime.now().millisecondsSinceEpoch}');
  final phone = TextEditingController();
  String? projectId;

  final marks = <String, VoiceMark>{};
  final heard = <String, String>{};
  List<String> unmapped = [];
  FormParseResult? lastResult;
  Farmer? duplicate;
  bool usedVoice = false;

  @override
  void initState() {
    super.initState();
    final u = widget.initialUtterance;
    if (u != null) WidgetsBinding.instance.addPostFrameCallback((_) => _apply(u));
  }

  @override
  void dispose() {
    name.dispose();
    code.dispose();
    phone.dispose();
    super.dispose();
  }

  Future<void> _speak() async {
    final text = await showVoiceSheet(context,
        exampleKey: 'farmer',
        title: 'Speak to fill',
        subtitle: 'Name, mobile number, project — plot details too');
    if (text != null) _apply(text);
  }

  void _mark(String key, Slot<Object>? s) {
    if (s == null) return;
    marks[key] = markFor(s.confidence);
    heard[key] = s.heard;
  }

  void _apply(String text) {
    final parser = FormParser(projects: store.projectRefs, farmers: store.farmerRefs);
    final (_, r) = NBest.pick(
        SpeechService.instance.hypothesesFor(text), parser.parse, NBest.formScore);
    usedVoice = true;
    setState(() {
      lastResult = r;
      if (r.name != null) {
        name.text = r.name!.value;
        _mark('name', r.name);
        final m = FormParser.matchFarmer(Utterance(r.name!.value), store.farmerRefs, minScore: 0.85);
        duplicate = m == null ? null : store.farmer(m.value);
      }
      if (r.phone != null) {
        phone.text = r.phone!.value;
        _mark('phone', r.phone);
      }
      if (r.projectId != null) {
        projectId = r.projectId!.value;
        _mark('project', r.projectId);
      }
      unmapped = r.unmapped;
    });
    final filled = [r.name, r.phone, r.projectId].whereType<Slot<Object>>();
    final strings = AgentStrings(store.language);
    if (filled.isEmpty) {
      TtsService.instance.speak(strings.notUnderstood, store.language);
    } else {
      TtsService.instance.speak(
          strings.formFilled(filled.length, filled.where((s) => s.needsCheck).length),
          store.language);
    }
  }

  void _submit() {
    final errors = <String>[
      if (name.text.trim().isEmpty) 'Farmer name',
      if (!RegExp(r'^\d{10}$').hasMatch(phone.text.trim())) 'Mobile number (10 digits)',
      if (projectId == null) 'Project',
    ];
    if (errors.isNotEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Please fill: ${errors.join(', ')}')));
      return;
    }
    final f = store.addFarmer(
      name: name.text.trim(),
      code: code.text.trim(),
      phone: phone.text.trim(),
      projectId: projectId!,
      byVoice: usedVoice,
    );
    TtsService.instance.speak(AgentStrings(store.language).saved, store.language);
    final r = lastResult;
    if (r != null && r.hasAssetDetails) {
      _offerPlot(f, r);
    } else {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Farmer ${f.name} added')));
    }
  }

  Future<void> _offerPlot(Farmer f, FormParseResult r) async {
    final details = [
      r.soil?.value,
      r.irrigation?.value,
      if (r.area != null) '${_fmt(r.area!.value)} ${r.areaUnit?.value ?? 'acre'}',
    ].whereType<String>().join(' · ');
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create plot too?'),
        content: Text('Farmer ${f.name} added.\n\nYou also said: $details.\n'
            'Create the plot for this farmer with these details?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create plot')),
        ],
      ),
    );
    if (!mounted) return;
    if (yes == true) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => AddAssetScreen(prefill: r, ownerId: f.id),
      ));
    } else {
      Navigator.of(context).pop();
    }
  }

  static String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: cropinTitleBar(context, 'Add Farmer'),
      body: ListView(
        children: [
          _ActionRow(
            icon: Icons.document_scanner_outlined,
            title: 'Auto Detect Data',
            subtitle: 'Fetch details from documents',
            pill: 'Auto',
            pillIcon: Icons.auto_awesome,
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Document scan is outside this voice demo'))),
          ),
          const Divider(height: 1),
          _ActionRow(
            icon: Icons.record_voice_over_outlined,
            title: 'Speak to fill',
            subtitle: 'Say name, mobile, project — ${store.language.nativeName}',
            pill: 'Speak',
            pillIcon: Icons.mic,
            highlight: true,
            onTap: _speak,
          ),
          const Divider(height: 1),
          const SizedBox(height: 26),
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
          const SizedBox(height: 26),
          const SectionGap(),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Primary Information',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 22),
              UnmappedBanner(words: unmapped, onDismiss: () => setState(() => unmapped = [])),
              VoiceTextField(
                label: 'Farmer Name:',
                required: true,
                controller: name,
                mark: marks['name'] ?? VoiceMark.none,
                heard: heard['name'],
                onEdited: () => setState(() => marks.remove('name')),
              ),
              if (duplicate != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                      'A farmer named ${duplicate!.name} (${duplicate!.code}) already exists.',
                      style: const TextStyle(color: CropinColors.attention, fontSize: 11)),
                ),
              VoiceTextField(label: 'Farmer Code:', controller: code),
              VoiceTextField(
                label: 'Mobile Number',
                required: true,
                controller: phone,
                keyboardType: TextInputType.phone,
                hint: 'Mobile Number',
                mark: marks['phone'] ?? VoiceMark.none,
                heard: heard['phone'],
                onEdited: () => setState(() => marks.remove('phone')),
                prefix: const _CountryCode(),
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
                  marks.remove('project');
                }),
              ),
            ]),
          ),
          const SectionGap(height: 14),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: CropinColors.green,
        foregroundColor: Colors.white,
        onPressed: _speak,
        tooltip: 'Speak to fill',
        child: const Icon(Icons.mic, size: 25),
      ),
      bottomNavigationBar: BottomActions(
        left: SecondaryButton(
          label: 'Save Draft',
          onPressed: () => ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Draft saved on device'))),
        ),
        right: PrimaryButton(label: 'Submit', onPressed: _submit),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.pill,
    required this.pillIcon,
    required this.onTap,
    this.highlight = false,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final String pill;
  final IconData pillIcon;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          color: highlight ? const Color(0xFFF4FAEC) : Colors.white,
          padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
          child: Row(children: [
            Icon(icon, size: 28, color: CropinColors.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const Text('Offline first',
                    style: TextStyle(
                        fontSize: 13, color: CropinColors.primary, fontWeight: FontWeight.w600)),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: CropinColors.subText)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: highlight ? CropinColors.green : CropinColors.primary,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(pillIcon, color: Colors.white, size: 13),
                const SizedBox(width: 5),
                Text(pill, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ]),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_forward, color: CropinColors.primary),
          ]),
        ),
      );
}

class _CountryCode extends StatelessWidget {
  const _CountryCode();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.only(left: 12, right: 10),
        decoration: const BoxDecoration(
          border: Border(right: BorderSide(color: CropinColors.border)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: 24,
            height: 18,
            child: Column(children: [
              Expanded(child: Container(color: const Color(0xFFFF9933))),
              Expanded(
                child: Container(
                  color: Colors.white,
                  alignment: Alignment.center,
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle, color: Color(0xFF000080)),
                  ),
                ),
              ),
              Expanded(child: Container(color: const Color(0xFF138808))),
            ]),
          ),
          const SizedBox(width: 8),
          const Text('+91', style: TextStyle(fontSize: 15)),
          const Icon(Icons.keyboard_arrow_down, size: 16),
        ]),
      );
}
