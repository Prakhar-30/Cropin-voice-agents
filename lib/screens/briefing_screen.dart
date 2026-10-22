import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../data/demo_data.dart';
import '../data/models.dart';
import '../services/location_service.dart';
import '../services/tts_service.dart';
import '../theme/app_theme.dart';
import '../voice/agent_language.dart';
import '../voice/agent_strings.dart';
import '../widgets/list_cards.dart';
import '../widgets/top_bar.dart';

/// "What's my day?" — reads out overdue tasks, nearby visits and the Crop
/// Health / Weather advisories, all computed on the device.
class BriefingScreen extends StatefulWidget {
  const BriefingScreen({super.key, this.autoSpeak = false});
  final bool autoSpeak;

  @override
  State<BriefingScreen> createState() => _BriefingScreenState();
}

class Briefing {
  Briefing(this.overdue, this.today, this.nearby, this.attention, this.order, this.fix);
  final List<FieldTask> overdue;
  final List<FieldTask> today;
  final List<FieldTask> nearby;
  final int attention;
  final List<FieldTask> order;
  final LocationFix fix;

  static const nearbyKm = 10;

  static Future<Briefing> build() async {
    final store = AppStore.instance;
    final fix = await LocationService.instance
        .current(nearTo: store.assets.map((a) => a.location).toList());
    final now = DateTime.now();
    final overdue = store.tasks.where((t) => t.isOverdue(now)).toList();
    final today = store.tasks.where((t) => t.isDueToday(now)).toList();
    double dist(FieldTask t) => fix.point.distanceKm(store.asset(t.assetId)!.location);
    final order = [...overdue, ...today]..sort((a, b) => dist(a).compareTo(dist(b)));
    final nearby = order.where((t) => dist(t) <= nearbyKm).toList();
    return Briefing(overdue, today, nearby, store.attentionCount, order, fix);
  }

  String speech(AgentLanguage lang) {
    final s = AgentStrings(lang);
    final store = AppStore.instance;
    final parts = <String>[s.greeting];
    if (order.isEmpty) {
      parts.add(s.allClear);
    } else {
      if (overdue.isNotEmpty) parts.add(s.overdue(overdue.length));
      if (today.isNotEmpty) parts.add(s.dueToday(today.length));
      if (nearby.isNotEmpty) parts.add(s.nearby(nearby.length, nearbyKm));
      final first = order.first;
      parts.add(s.firstUp(s.taskType(first.type), store.farmer(first.farmerId)?.name ?? ''));
    }
    if (attention > 0) parts.add(s.cropHealth(attention));
    final weather = DemoData.advisories.firstWhere((a) => a.kind == 'weather');
    parts.add('${s.weatherPrefix} ${weather.text[lang.code] ?? weather.text['en']}');
    return parts.join(' ');
  }
}

class _BriefingScreenState extends State<BriefingScreen> {
  final store = AppStore.instance;
  Briefing? briefing;
  bool speaking = false;

  @override
  void initState() {
    super.initState();
    Briefing.build().then((b) {
      if (!mounted) return;
      setState(() => briefing = b);
      if (widget.autoSpeak) _play();
    });
  }

  @override
  void dispose() {
    TtsService.instance.stop();
    super.dispose();
  }

  Future<void> _play() async {
    final b = briefing;
    if (b == null) return;
    setState(() => speaking = true);
    await TtsService.instance.speak(b.speech(store.language), store.language);
  }

  Future<void> _stop() async {
    await TtsService.instance.stop();
    if (mounted) setState(() => speaking = false);
  }

  @override
  Widget build(BuildContext context) {
    final b = briefing;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: cropinTitleBar(context, "What's my day"),
      body: b == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.only(bottom: 24), children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Wrap(spacing: 8, children: [
                    for (final l in AgentLanguage.values)
                      ChoiceChip(
                        label: Text(l.nativeName),
                        selected: store.language == l,
                        showCheckmark: false,
                        selectedColor: CropinColors.primary,
                        labelStyle:
                            TextStyle(color: store.language == l ? Colors.white : CropinColors.text),
                        onSelected: (_) {
                          setState(() => store.language = l);
                          _play();
                        },
                      ),
                  ]),
                  const SizedBox(height: 12),
                  Text(b.speech(store.language),
                      style: const TextStyle(fontSize: 16, height: 1.4, color: CropinColors.text)),
                  const SizedBox(height: 12),
                  Row(children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: CropinColors.green),
                      onPressed: _play,
                      icon: const Icon(Icons.volume_up),
                      label: Text(speaking ? 'Play again' : 'Read aloud'),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: _stop,
                      icon: const Icon(Icons.stop),
                      label: const Text('Stop'),
                    ),
                    const Spacer(),
                    Icon(b.fix.isDemo ? Icons.location_searching : Icons.my_location,
                        size: 16, color: CropinColors.subText),
                    const SizedBox(width: 4),
                    Text(b.fix.isDemo ? 'Demo GPS' : 'GPS',
                        style: const TextStyle(fontSize: 12, color: CropinColors.subText)),
                  ]),
                ]),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  _Stat('Overdue', b.overdue.length, CropinColors.attention),
                  _Stat('Due today', b.today.length, CropinColors.voiceCheck),
                  _Stat('Nearby', b.nearby.length, CropinColors.primary),
                  _Stat('Attention', b.attention, CropinColors.cropHealth),
                ]),
              ),
              const SizedBox(height: 10),
              for (final a in DemoData.advisories)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: CropinColors.border),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(
                        switch (a.kind) {
                          'weather' => Icons.thermostat,
                          'indices' => Icons.satellite_alt,
                          _ => Icons.bug_report_outlined,
                        },
                        color: CropinColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(a.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 3),
                        Text(a.text[store.language.code] ?? a.text['en']!,
                            style: const TextStyle(fontSize: 14, color: CropinColors.subText)),
                      ]),
                    ),
                  ]),
                ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: Text('Visit order (nearest first)',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              ),
              for (final t in b.order)
                TaskCard(
                  task: t,
                  distanceKm: b.fix.point.distanceKm(store.asset(t.assetId)!.location),
                ),
            ]),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.color);
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: CropinColors.border),
          ),
          child: Column(children: [
            Text(value.toString().padLeft(2, '0'),
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: color)),
            Text(label, style: const TextStyle(fontSize: 12, color: CropinColors.subText)),
          ]),
        ),
      );
}
