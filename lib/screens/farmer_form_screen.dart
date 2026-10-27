import 'dart:async';

import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../data/demo_data.dart';
import '../farmer_form/form_agent.dart';
import '../farmer_form/form_spec.dart';
import '../farmer_form/value_parsers.dart';
import '../services/location_service.dart';
import '../services/speech_service.dart';
import '../services/tts_service.dart';
import '../theme/app_theme.dart';
import '../voice/agent_language.dart';
import '../widgets/common.dart';
import '../widgets/form_fields.dart';
import '../widgets/top_bar.dart';
import '../widgets/voice_sheet.dart' show ModelPrompt;
import 'voice_settings_screen.dart';

enum _Phase { speaking, starting, listening, processing, idle }

/// Add Farmer, as in Cropin Grow, with a voice assistant that fills the form
/// in a conversation: it asks for what's missing, offers the optional
/// sections, reads options for dropdowns and confirms before submitting.
class FarmerFormScreen extends StatefulWidget {
  const FarmerFormScreen({super.key});

  @override
  State<FarmerFormScreen> createState() => _FarmerFormScreenState();
}

class _FarmerFormScreenState extends State<FarmerFormScreen> {
  final store = AppStore.instance;
  final speech = SpeechService.instance;
  final tts = TtsService.instance;
  final scroll = ScrollController();

  final values = <String, String>{'areaUnit': 'acre'};
  final controllers = <String, TextEditingController>{};
  final keys = <String, GlobalKey>{};
  final marks = <String, VoiceMark>{};
  final heardFor = <String, String>{};
  String code = _newCode();

  late FarmerFormAgent agent = FarmerFormAgent(values: values, lang: store.language);

  bool personalOpen = true;
  bool additionalOpen = true;
  bool documentsOpen = false;

  // voice panel
  bool active = false;
  _Phase phase = _Phase.idle;
  String bubble = '';
  String heard = '';
  List<String> chips = const [];
  String? asking;
  int _turn = 0;
  int _listenId = 0;

  static String _newCode() => 'FC-${DateTime.now().millisecondsSinceEpoch}';

  static const _textFields = [
    'name', 'mobile', 'dob', 'guardian', 'aadhaar', 'area', 'email', 'state', 'city', 'district',
    'taluka', 'village', 'landmark', 'pin', 'bankAccount', 'bankName', 'branch', 'ifsc', 'pan',
  ];

  @override
  void initState() {
    super.initState();
    for (final id in _textFields) {
      controllers[id] = TextEditingController();
    }
    for (final f in FarmerFormSpec.fields) {
      keys[f.id] = GlobalKey();
    }
  }

  @override
  void dispose() {
    _turn++;
    speech.cancel();
    tts.stop();
    for (final c in controllers.values) {
      c.dispose();
    }
    scroll.dispose();
    super.dispose();
  }

  AgentLanguage get lang => store.language;

  // ------------------------------------------------------------ form state

  void _set(String id, String? v) {
    setState(() {
      if (v == null || v.isEmpty) {
        values.remove(id);
      } else {
        values[id] = v;
      }
      marks.remove(id);
    });
  }

  /// Copies agent-filled values into the text boxes and marks them.
  void _syncFromValues(Map<String, FieldValue> filled) {
    for (final id in _textFields) {
      final c = controllers[id]!;
      final v = values[id] ?? '';
      if (c.text != v) c.text = v;
    }
    for (final e in filled.entries) {
      marks[e.key] = markFor(e.value.confidence);
      heardFor[e.key] = e.value.heard;
      if (e.key == 'area' && e.value.unit != null) marks['areaUnit'] = VoiceMark.filled;
    }
    final sections = filled.keys.map((id) => FarmerFormSpec.byId[id]?.section).toSet();
    if (sections.contains(FormSection.personal)) personalOpen = true;
    if (sections.contains(FormSection.additional)) additionalOpen = true;
  }

  void _scrollTo(String? id) {
    if (id == null) return;
    final f = FarmerFormSpec.byId[id];
    if (f?.section == FormSection.personal && !personalOpen) setState(() => personalOpen = true);
    if (f?.section == FormSection.additional && !additionalOpen) setState(() => additionalOpen = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = (keys[id == 'useLocation' ? 'country' : id])?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx,
            alignment: 0.25, duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
      }
    });
  }

  // ------------------------------------------------------------ voice turns

  Future<void> _startAgent() async {
    if (active) return;
    setState(() {
      active = true;
      heard = '';
    });
    agent.lang = lang;
    unawaited(speech.prewarm(lang));
    await _play(agent.start());
  }

  void _closeAgent() {
    _turn++;
    _listenId++;
    speech.cancel();
    tts.stop();
    setState(() {
      active = false;
      phase = _Phase.idle;
      asking = null;
    });
  }

  Future<void> _play(AgentReply r) async {
    final turn = ++_turn;
    setState(() {
      _syncFromValues(r.filled);
      bubble = r.text;
      chips = r.chips;
      asking = r.asking;
      phase = _Phase.speaking;
    });
    _scrollTo(r.asking ?? (r.filled.isEmpty ? null : r.filled.keys.last));

    switch (r.action) {
      case AgentAction.useLocation:
        final filled = await _locationAddress();
        if (!mounted || turn != _turn) return;
        return _play(agent.locationDone(filled));
      case AgentAction.submit:
        await tts.speakAndWait(r.speech, lang);
        if (!mounted || turn != _turn) return;
        _submit();
        return;
      case AgentAction.saveDraft:
        await tts.speakAndWait(r.speech, lang);
        if (!mounted || turn != _turn) return;
        _saveDraft();
        return;
      default:
        break;
    }
    await tts.speakAndWait(r.speech, lang);
    if (!mounted || turn != _turn || !active) return;
    if (r.listen) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted || turn != _turn || !active) return;
      await _listen();
    } else {
      setState(() => phase = _Phase.idle);
    }
  }

  Future<void> _listen() async {
    final id = ++_listenId;
    setState(() => phase = _Phase.starting);
    final ok = await speech.start(lang, onResult: (text, isFinal) {
      if (isFinal) _heard(id, text);
    });
    if (!mounted || id != _listenId) return;
    if (!ok) {
      setState(() {
        phase = _Phase.idle;
        bubble = speech.lastError ?? bubble;
      });
    }
  }

  void _heard(int id, String text) {
    if (id != _listenId || !mounted || !active) return;
    _listenId++;
    setState(() {
      heard = text.trim();
      phase = _Phase.processing;
    });
    final reply = agent.hear(text, alternatives: speech.hypothesesFor(text));
    _play(reply);
  }

  Future<void> _micTap() async {
    switch (phase) {
      case _Phase.speaking:
        await tts.stop(); // skip the question, listen now
      case _Phase.starting:
      case _Phase.listening:
        final id = _listenId;
        setState(() => phase = _Phase.processing);
        final text = await speech.stop();
        _heard(id, text);
      case _Phase.processing:
        break;
      case _Phase.idle:
        await _listen();
    }
  }

  Future<void> _chip(String label) async {
    _listenId++;
    _turn++;
    await speech.cancel();
    await tts.stop();
    setState(() {
      heard = label;
      phase = _Phase.processing;
    });
    _play(agent.hear(label));
  }

  Future<void> _setLanguage(AgentLanguage l) async {
    if (l == lang) return;
    store.language = l;
    agent.lang = l;
    _listenId++;
    _turn++;
    await speech.cancel();
    await tts.stop();
    unawaited(speech.prewarm(l));
    if (active) _play(agent.repeat());
    setState(() {});
  }

  // -------------------------------------------------------------- location

  static const _addresses = <String, Map<String, String>>{
    'BTM Layout': {'state': 'Karnataka', 'district': 'Bengaluru Urban', 'city': 'Bengaluru', 'taluka': 'Bengaluru South', 'pin': '560076'},
    'Bommanahalli': {'state': 'Karnataka', 'district': 'Bengaluru Urban', 'city': 'Bengaluru', 'taluka': 'Bengaluru South', 'pin': '560068'},
    'Madivala': {'state': 'Karnataka', 'district': 'Bengaluru Urban', 'city': 'Bengaluru', 'taluka': 'Bengaluru South', 'pin': '560068'},
    'HSR Layout': {'state': 'Karnataka', 'district': 'Bengaluru Urban', 'city': 'Bengaluru', 'taluka': 'Bengaluru South', 'pin': '560102'},
    'Jayanagar': {'state': 'Karnataka', 'district': 'Bengaluru Urban', 'city': 'Bengaluru', 'taluka': 'Bengaluru South', 'pin': '560011'},
    'Anekal': {'state': 'Karnataka', 'district': 'Bengaluru Urban', 'city': 'Anekal', 'taluka': 'Anekal', 'pin': '562106'},
    'Hosur': {'state': 'Tamil Nadu', 'district': 'Krishnagiri', 'city': 'Hosur', 'taluka': 'Hosur', 'pin': '635109'},
    'Krishnagiri': {'state': 'Tamil Nadu', 'district': 'Krishnagiri', 'city': 'Krishnagiri', 'taluka': 'Krishnagiri', 'pin': '635001'},
    'Mandya': {'state': 'Karnataka', 'district': 'Mandya', 'city': 'Mandya', 'taluka': 'Mandya', 'pin': '571401'},
    'Mysuru': {'state': 'Karnataka', 'district': 'Mysuru', 'city': 'Mysuru', 'taluka': 'Mysuru', 'pin': '570001'},
    'Kolar': {'state': 'Karnataka', 'district': 'Kolar', 'city': 'Kolar', 'taluka': 'Kolar', 'pin': '563101'},
    'Coimbatore': {'state': 'Tamil Nadu', 'district': 'Coimbatore', 'city': 'Coimbatore', 'taluka': 'Coimbatore South', 'pin': '641001'},
    'Patna': {'state': 'Bihar', 'district': 'Patna', 'city': 'Patna', 'taluka': 'Patna Sadar', 'pin': '800001'},
  };

  /// Address fields for the phone's position (nearest known place; offline).
  Future<Map<String, String>> _locationAddress() async {
    try {
      final points = DemoData.localities.values.map((e) => e.$2).toList();
      final fix = await LocationService.instance.current(nearTo: points);
      var best = DemoData.localities.keys.first;
      var bestKm = double.infinity;
      DemoData.localities.forEach((name, v) {
        final km = fix.point.distanceKm(v.$2);
        if (km < bestKm) {
          bestKm = km;
          best = name;
        }
      });
      final filled = <String, String>{'country': 'India', ...?_addresses[best]};
      filled.removeWhere((k, _) => (values[k] ?? '').isNotEmpty);
      setState(() {
        values.addAll(filled);
        _syncFromValues({for (final e in filled.entries) e.key: FieldValue(e.value, heard: 'GPS')});
      });
      return filled;
    } catch (_) {
      return {};
    }
  }

  Future<void> _useLocationTap() async {
    final filled = await _locationAddress();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(filled.isEmpty
            ? 'Could not get the location'
            : 'Address filled: ${[filled['city'], filled['district'], filled['state']].whereType<String>().join(', ')}')));
  }

  // ----------------------------------------------------------- submit/draft

  List<String> _missing() => [
        if ((values['name'] ?? '').trim().isEmpty) 'Farmer Name',
        if (!RegExp(r'^[6-9]\d{9}$').hasMatch(values['mobile'] ?? '')) 'Mobile Number (10 digits)',
        if ((values['project'] ?? '').isEmpty) 'Project',
      ];

  void _submit() {
    final missing = _missing();
    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Please fill: ${missing.join(', ')}')));
      if (active) _play(agent.repeat());
      return;
    }
    final f = store.addFarmer(
      name: values['name']!.trim(),
      code: code,
      phone: values['mobile']!,
      projectId: values['project']!,
      byVoice: marks.isNotEmpty,
    );
    final said = tr(lang, 'Farmer ${f.name} added.', 'किसान ${f.name} जोड़ दिए गए।',
        'ರೈತ ${f.name} ಅವರನ್ನು ಸೇರಿಸಲಾಗಿದೆ.', 'விவசாயி ${f.name} சேர்க்கப்பட்டார்.');
    if (active) tts.speak(said, lang);
    _closeAgent();
    _reset();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: CropinColors.voiceFilled, size: 40),
        title: Text('Farmer ${f.name} added'),
        content: Text('Code ${f.code} · ${store.project(f.projectIds.first)?.name ?? ''}'),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Add another farmer')),
        ],
      ),
    );
  }

  void _saveDraft() {
    _closeAgent();
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved as draft — you can finish it later')));
  }

  void _reset() {
    setState(() {
      values
        ..clear()
        ..['areaUnit'] = 'acre';
      for (final c in controllers.values) {
        c.clear();
      }
      marks.clear();
      heardFor.clear();
      code = _newCode();
      agent = FarmerFormAgent(values: values, lang: lang);
      bubble = '';
      heard = '';
    });
  }

  // -------------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: cropinTitleBar(context, 'Add Farmer', actions: [
        IconButton(
          tooltip: 'Voice settings',
          icon: const Icon(Icons.settings_voice_outlined),
          onPressed: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const VoiceSettingsScreen())),
        ),
      ]),
      body: ListView(
        controller: scroll,
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
            key: const Key('voice-assist'),
            icon: Icons.record_voice_over_outlined,
            title: 'Voice Assist',
            subtitle: "Speak the details — I'll ask for the rest",
            pill: 'Talk',
            pillIcon: Icons.mic,
            highlight: true,
            onTap: _startAgent,
          ),
          const Divider(height: 1),
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
          _section('Primary Information', null, null, [
            _text('name'),
            _plain('Farmer Code:', code),
            _text('mobile', keyboard: TextInputType.phone, prefix: const _CountryCode(), hint: 'Mobile Number'),
            _select('project'),
          ]),
          const SectionGap(),
          _section('Personal Information', personalOpen, () => setState(() => personalOpen = !personalOpen), [
            _date(),
            _select('gender'),
            _text('guardian'),
            _text('aadhaar', keyboard: TextInputType.number, secret: true),
            _select('contractor'),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: _text('area', keyboard: const TextInputType.numberWithOptions(decimal: true))),
              const SizedBox(width: 16),
              Expanded(child: _select('areaUnit', filledGrey: true)),
            ]),
            _select('language'),
            _text('email', keyboard: TextInputType.emailAddress),
          ]),
          const SectionGap(),
          _section('Address', null, null, [
            InkWell(
              key: const Key('use-current-location'),
              onTap: _useLocationTap,
              child: Container(
                decoration: _frame(asking == 'useLocation'),
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: const Row(children: [
                  Icon(Icons.my_location, color: CropinColors.green, size: 26),
                  SizedBox(width: 14),
                  Text('Use Current Location', style: TextStyle(fontSize: 16)),
                ]),
              ),
            ),
            const SizedBox(height: 18),
            _select('country'),
            _text('state'),
            _text('city'),
            _text('district'),
            _text('taluka'),
            _text('village'),
            _text('landmark'),
            _text('pin', keyboard: TextInputType.number),
          ]),
          const SectionGap(),
          _section('Additional Information', additionalOpen, () => setState(() => additionalOpen = !additionalOpen), [
            _text('bankAccount', keyboard: TextInputType.number, secret: true),
            _text('bankName'),
            _text('branch'),
            _text('ifsc'),
            _text('pan', secret: true),
            _select('location'),
          ]),
          const SectionGap(),
          _section('Captured Documents(0)', documentsOpen, () => setState(() => documentsOpen = !documentsOpen), [
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('No documents captured yet.', style: TextStyle(color: CropinColors.subText)),
            ),
          ]),
          const SizedBox(height: 24),
        ],
      ),
      bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
        if (active) _voicePanel(),
        BottomActions(
          left: SecondaryButton(label: 'Save Draft', onPressed: _saveDraft),
          right: PrimaryButton(label: 'Submit', onPressed: _submit),
        ),
      ]),
    );
  }

  BoxDecoration _frame(bool on) => BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: on
            ? [BoxShadow(color: CropinColors.green.withValues(alpha: 0.35), blurRadius: 0, spreadRadius: 3)]
            : const [],
      );

  Widget _section(String title, bool? open, VoidCallback? toggle, List<Widget> children) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          InkWell(
            onTap: toggle,
            child: Row(children: [
              Expanded(
                  child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
              if (open != null) Icon(open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 26),
            ]),
          ),
          const SizedBox(height: 18),
          if (open ?? true) ...children,
        ]),
      );

  Widget _plain(String label, String value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        FieldLabel(label),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            border: Border.all(color: CropinColors.border, width: 1.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(value, style: const TextStyle(fontSize: 15)),
        ),
        const SizedBox(height: 20),
      ]);

  Widget _text(String id,
      {TextInputType? keyboard, Widget? prefix, String hint = 'Please Enter Value', bool secret = false}) {
    final f = FarmerFormSpec.byId[id]!;
    return Container(
      key: keys[id],
      decoration: _frame(asking == id),
      child: _TextInput(
        label: id == 'name' ? '${f.label}:' : f.label,
        required: f.required,
        controller: controllers[id]!,
        keyboard: keyboard,
        prefix: prefix,
        hint: hint,
        secret: secret,
        mark: marks[id] ?? VoiceMark.none,
        heard: heardFor[id],
        onChanged: (v) => _set(id, v.trim()),
      ),
    );
  }

  Widget _date() {
    const id = 'dob';
    final f = FarmerFormSpec.byId[id]!;
    return Container(
      key: keys[id],
      decoration: _frame(asking == id),
      child: _TextInput(
        label: f.label,
        controller: controllers[id]!,
        hint: 'DD/MM/YYYY',
        readOnly: true,
        suffix: const Icon(Icons.calendar_month_outlined, color: CropinColors.primary),
        mark: marks[id] ?? VoiceMark.none,
        heard: heardFor[id],
        onTap: () async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: context,
            firstDate: DateTime(1920),
            lastDate: now,
            initialDate: DateTime(now.year - 35),
          );
          if (picked == null) return;
          final v = '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
          controllers[id]!.text = v;
          _set(id, v);
        },
      ),
    );
  }

  Widget _select(String id, {bool filledGrey = false}) {
    final f = FarmerFormSpec.byId[id]!;
    return Container(
      key: keys[id],
      decoration: _frame(asking == id),
      child: VoiceSelectField<Choice>(
        label: f.label,
        required: f.required,
        value: f.choice(values[id]),
        options: f.choices,
        display: (c) => c.label,
        mark: marks[id] ?? VoiceMark.none,
        heard: heardFor[id],
        compact: filledGrey,
        onChanged: (c) => _set(id, c.id),
      ),
    );
  }

  Widget _voicePanel() {
    return Material(
      elevation: 12,
      color: Colors.white,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 10, 8),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: Color(0xFFF4FAEC), shape: BoxShape.circle),
                child: const Icon(Icons.support_agent, size: 18, color: CropinColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 92),
                  child: SingleChildScrollView(
                    reverse: true,
                    child: Text(bubble,
                        key: const Key('agent-bubble'),
                        style: const TextStyle(fontSize: 14, height: 1.3, color: CropinColors.text)),
                  ),
                ),
              ),
              PopupMenuButton<AgentLanguage>(
                tooltip: 'Language',
                initialValue: lang,
                onSelected: _setLanguage,
                itemBuilder: (_) => [
                  for (final l in AgentLanguage.values) PopupMenuItem(value: l, child: Text(l.nativeName)),
                ],
                child: Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: CropinColors.searchFill,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(lang.nativeName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
              IconButton(
                tooltip: 'Close voice assist',
                visualDensity: VisualDensity.compact,
                onPressed: _closeAgent,
                icon: const Icon(Icons.close, size: 20),
              ),
            ]),
            if (heard.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 40, top: 4, right: 8),
                child: Text('“$heard”',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, fontStyle: FontStyle.italic, color: CropinColors.subText)),
              ),
            ModelPrompt(lang: lang),
            if (chips.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: chips.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (_, i) => ActionChip(
                      label: Text(chips[i], style: const TextStyle(fontSize: 12)),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: CropinColors.border),
                      onPressed: () => _chip(chips[i]),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 6),
            ListenableBuilder(
              listenable: speech,
              builder: (context, _) {
                var p = phase;
                if (p == _Phase.starting && speech.live) p = _Phase.listening;
                return Row(children: [
                  Expanded(
                    child: Text(
                      switch (p) {
                        _Phase.speaking => tr(lang, 'Speaking… tap the mic to answer now',
                            'बोल रहा हूँ… अभी जवाब देने के लिए माइक दबाएँ', 'ಮಾತನಾಡುತ್ತಿದ್ದೇನೆ… ಈಗ ಉತ್ತರಿಸಲು ಮೈಕ್ ಒತ್ತಿ',
                            'பேசுகிறேன்… இப்போதே பதிலளிக்க மைக்கை அழுத்துங்கள்'),
                        _Phase.starting => tr(lang, 'Getting ready…', 'तैयार हो रहा हूँ…', 'ಸಿದ್ಧವಾಗುತ್ತಿದೆ…', 'தயாராகிறது…'),
                        _Phase.listening => tr(lang, 'Listening — tap the mic when done', 'सुन रहा हूँ — पूरा होने पर माइक दबाएँ',
                            'ಕೇಳುತ್ತಿದ್ದೇನೆ — ಮುಗಿದಾಗ ಮೈಕ್ ಒತ್ತಿ', 'கேட்கிறேன் — முடிந்ததும் மைக்கை அழுத்துங்கள்'),
                        _Phase.processing => '…',
                        _Phase.idle => tr(lang, 'Tap the mic to talk', 'बोलने के लिए माइक दबाएँ', 'ಮಾತನಾಡಲು ಮೈಕ್ ಒತ್ತಿ',
                            'பேச மைக்கை அழுத்துங்கள்'),
                      },
                      style: const TextStyle(fontSize: 11, color: CropinColors.subText),
                    ),
                  ),
                  _MicButton(phase: p, level: speech.soundLevel, onTap: _micTap),
                ]);
              },
            ),
          ]),
        ),
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  const _MicButton({required this.phase, required this.level, required this.onTap});
  final _Phase phase;
  final double level;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final listening = phase == _Phase.listening;
    final ring = listening ? 4 + 10 * ((level.clamp(-2, 10) + 2) / 12) : 0.0;
    // Fixed outer box: the ring grows inside it, so the panel never moves.
    return SizedBox(
      width: 66,
      height: 66,
      child: Center(
        child: GestureDetector(
          key: const Key('agent-mic'),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 50 + ring,
            height: 50 + ring,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: CropinColors.green.withValues(alpha: listening ? 0.18 : 0),
            ),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: switch (phase) {
                  _Phase.listening => CropinColors.green,
                  _Phase.idle => Colors.white,
                  _ => CropinColors.primary,
                },
                border: phase == _Phase.idle ? Border.all(color: CropinColors.primary, width: 1.5) : null,
              ),
              child: switch (phase) {
                _Phase.starting || _Phase.processing => const Padding(
                    padding: EdgeInsets.all(14),
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4),
                  ),
                _Phase.speaking => const Icon(Icons.volume_up, color: Colors.white, size: 24),
                _Phase.idle => const Icon(Icons.mic_none, color: CropinColors.primary, size: 26),
                _Phase.listening => const Icon(Icons.mic, color: Colors.white, size: 26),
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Text input in Cropin Grow style, with the voice-filled highlight.
class _TextInput extends StatefulWidget {
  const _TextInput({
    required this.label,
    required this.controller,
    this.required = false,
    this.keyboard,
    this.prefix,
    this.suffix,
    this.hint = 'Please Enter Value',
    this.secret = false,
    this.readOnly = false,
    this.mark = VoiceMark.none,
    this.heard,
    this.onChanged,
    this.onTap,
  });

  final String label;
  final TextEditingController controller;
  final bool required;
  final TextInputType? keyboard;
  final Widget? prefix;
  final Widget? suffix;
  final String hint;
  final bool secret;
  final bool readOnly;
  final VoiceMark mark;
  final String? heard;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;

  @override
  State<_TextInput> createState() => _TextInputState();
}

class _TextInputState extends State<_TextInput> {
  late bool hidden = widget.secret;

  @override
  Widget build(BuildContext context) {
    final mark = widget.mark;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      FieldLabel(widget.label, required: widget.required, mark: mark, heard: widget.heard),
      AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: switch (mark) {
            VoiceMark.filled => const Color(0xFFF0FAF3),
            VoiceMark.check => const Color(0xFFFFF8E6),
            VoiceMark.none => Colors.white,
          },
          border: Border.all(
            color: switch (mark) {
              VoiceMark.filled => CropinColors.voiceFilled,
              VoiceMark.check => CropinColors.voiceCheck,
              VoiceMark.none => CropinColors.border,
            },
            width: mark == VoiceMark.none ? 1.2 : 1.8,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(children: [
          if (widget.prefix != null) widget.prefix!,
          Expanded(
            child: TextField(
              controller: widget.controller,
              keyboardType: widget.keyboard,
              obscureText: hidden,
              readOnly: widget.readOnly,
              onTap: widget.onTap,
              onChanged: widget.onChanged,
              style: const TextStyle(fontSize: 15, color: CropinColors.text),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: const TextStyle(color: CropinColors.hint, fontSize: 15),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              ),
            ),
          ),
          if (widget.secret)
            IconButton(
              onPressed: () => setState(() => hidden = !hidden),
              icon: Icon(hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: CropinColors.subText),
            ),
          if (widget.suffix != null)
            Padding(padding: const EdgeInsets.only(right: 12), child: widget.suffix!),
        ]),
      ),
      const SizedBox(height: 20),
    ]);
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    super.key,
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
                    style: TextStyle(fontSize: 13, color: CropinColors.primary, fontWeight: FontWeight.w600)),
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
        decoration: const BoxDecoration(border: Border(right: BorderSide(color: CropinColors.border))),
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
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF000080)),
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
