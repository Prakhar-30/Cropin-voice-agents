import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../data/demo_data.dart';
import '../data/models.dart';
import '../services/location_service.dart';
import '../services/speech_service.dart';
import '../services/tts_service.dart';
import '../theme/app_theme.dart';
import '../voice/agent_strings.dart';
import '../voice/nlu/alert_parser.dart';
import '../voice/nlu/nbest.dart';
import '../widgets/common.dart';
import '../widgets/form_fields.dart';
import '../widgets/top_bar.dart';
import '../widgets/voice_sheet.dart';

/// Raise alert by voice: GPS pre-selects the nearest matching plot, alert
/// type and severity are filled from speech, the user just hits submit.
class RaiseAlertScreen extends StatefulWidget {
  const RaiseAlertScreen({super.key, this.initialUtterance});
  final String? initialUtterance;

  @override
  State<RaiseAlertScreen> createState() => _RaiseAlertScreenState();
}

class _RaiseAlertScreenState extends State<RaiseAlertScreen> {
  final store = AppStore.instance;
  final search = TextEditingController();
  final selected = <String>{};
  String? type;
  String? severity;
  String note = '';
  AlertParseResult? parsed;
  LocationFix? fix;
  bool locating = false;
  bool byVoice = false;

  @override
  void initState() {
    super.initState();
    _locate().then((_) {
      final u = widget.initialUtterance;
      if (u != null && mounted) _apply(u);
    });
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    setState(() => locating = true);
    final f = await LocationService.instance
        .current(nearTo: store.assets.map((a) => a.location).toList());
    if (!mounted) return;
    setState(() {
      fix = f;
      locating = false;
    });
  }

  double? _distance(Asset a) => fix?.point.distanceKm(a.location);

  Future<void> _speak() async {
    final text = await showVoiceSheet(context,
        exampleKey: 'alert', title: 'Raise alert by voice', subtitle: 'Type, crop / plot, severity');
    if (text != null) _apply(text);
  }

  // What has been said so far on this screen. Follow-up sentences ("make it
  // pest type") add to it instead of starting over.
  String? _ctxCrop;
  String? _ctxFarmer;
  String? _ctxLocation;
  bool _ctxAll = false;
  bool _ctxNear = false;

  void _apply(String text) {
    final parser = AlertParser(farmers: store.farmerRefs, locations: DemoData.localityAliases);
    final (_, r) = NBest.pick(
        SpeechService.instance.hypothesesFor(text), parser.parse, NBest.alertScore);
    final plotCue = r.crop != null ||
        r.farmerId != null ||
        r.location != null ||
        r.nearMe ||
        r.selectAll;
    _ctxCrop = r.crop?.value ?? _ctxCrop;
    _ctxFarmer = r.farmerId?.value ?? _ctxFarmer;
    _ctxLocation = r.location ?? _ctxLocation;
    _ctxAll = _ctxAll || r.selectAll;
    _ctxNear = _ctxNear || r.nearMe;
    // candidate plots: crop / farmer / locality filters, nearest first
    var candidates = store.assets.where((a) => a.status == 'current').toList();
    if (_ctxCrop != null) candidates = candidates.where((a) => a.crop == _ctxCrop).toList();
    if (_ctxFarmer != null) {
      candidates = candidates.where((a) => a.farmerId == _ctxFarmer).toList();
    }
    if (_ctxLocation != null) {
      candidates = candidates.where((a) => AppStore.inPlace(a.locality, _ctxLocation!)).toList();
    }
    if (fix != null) {
      candidates.sort((a, b) => _distance(a)!.compareTo(_distance(b)!));
    }
    // "all …" or a farmer / locality without "here" -> every matching plot
    final many =
        _ctxAll || (!_ctxNear && (_ctxFarmer != null || _ctxLocation != null));
    byVoice = true;
    setState(() {
      parsed = r;
      note = note.isEmpty ? r.note : '$note. ${r.note}';
      if (r.type != null) type = r.type!.value;
      if (r.severity != null) severity = r.severity!.value;
      // keep the current plot selection unless this sentence talks about plots
      if (candidates.isNotEmpty && (plotCue || selected.isEmpty)) {
        selected
          ..clear()
          ..addAll(many ? candidates.map((a) => a.id) : [candidates.first.id]);
      }
    });
    final strings = AgentStrings(store.language);
    if (selected.isEmpty && type == null) {
      TtsService.instance.speak(strings.notUnderstood, store.language);
      return;
    }
    final first = store.asset(selected.firstOrNull);
    final plot = selected.length > 1
        ? strings.plots(selected.length)
        : '${strings.crop(first?.crop ?? '')} ${first?.name.split('/').first ?? ''}'.trim();
    TtsService.instance.speak(
      strings.alertReady(
          strings.alertType(type ?? 'Pest'), strings.severity(severity ?? 'Medium'), plot),
      store.language,
    );
  }

  /// Select / clear every plot currently shown in the list (after search).
  void _toggleAll(List<Asset> shown) {
    setState(() {
      final allOn = shown.isNotEmpty && shown.every((a) => selected.contains(a.id));
      if (allOn) {
        selected.removeAll(shown.map((a) => a.id));
      } else {
        selected.addAll(shown.map((a) => a.id));
      }
    });
  }

  Future<void> _raise() async {
    if (type == null || severity == null) {
      final ok = await _detailsSheet();
      if (ok != true) return;
    }
    final al = store.raiseAlert(
      assetIds: selected.toList(),
      type: type!,
      severity: severity!,
      note: note,
      byVoice: byVoice,
    );
    TtsService.instance.speak(AgentStrings(store.language).alertSubmitted, store.language);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: CropinColors.goodGreen, size: 39),
        title: const Text('Alert raised'),
        content: Text('${al.type} · ${al.severity} severity\n'
            '${al.assetIds.map((id) => store.asset(id)?.name ?? id).join(', ')}'),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done'))],
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<bool?> _detailsSheet() => showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setSheet) => Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Alert details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              VoiceSelectField<String>(
                label: 'Alert Type',
                required: true,
                value: type,
                options: DemoData.alertTypes,
                display: (s) => s,
                onChanged: (s) {
                  setState(() => type = s);
                  setSheet(() {});
                },
              ),
              VoiceSelectField<String>(
                label: 'Severity',
                required: true,
                value: severity,
                options: DemoData.severities,
                display: (s) => s,
                onChanged: (s) {
                  setState(() => severity = s);
                  setSheet(() {});
                },
              ),
              PrimaryButton(
                label: 'Continue',
                onPressed: type != null && severity != null ? () => Navigator.pop(ctx, true) : null,
              ),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final q = search.text.trim().toLowerCase();
    final list = store.assets.where((a) {
      if (q.isEmpty) return true;
      return '${a.name} ${a.crop} ${a.variety} ${a.areaLabel} ${a.locality}'.toLowerCase().contains(q);
    }).toList();
    if (fix != null) list.sort((a, b) => _distance(a)!.compareTo(_distance(b)!));
    // selected plots on top, nearest first
    final ordered = [
      ...list.where((a) => selected.contains(a.id)),
      ...list.where((a) => !selected.contains(a.id)),
    ];

    return Scaffold(
      appBar: cropinTitleBar(context, 'Raise alert', actions: [
        IconButton(onPressed: _speak, icon: const Icon(Icons.mic, size: 23), tooltip: 'Speak'),
      ]),
      body: Column(children: [
        Expanded(
          child: ListView(children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 22, 18, 12),
              child: Text('SELECT PLOT', style: TextStyle(fontSize: 15, letterSpacing: 0.3)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Container(
                decoration: const BoxDecoration(
                  color: CropinColors.searchFill,
                  border: Border(bottom: BorderSide(color: CropinColors.subText, width: 1.4)),
                ),
                child: TextField(
                  controller: search,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(fontSize: 15),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    prefixIcon: const Icon(Icons.search, color: CropinColors.hint, size: 23),
                    hintText: 'Search Plot, Croppable area & Unit',
                    hintStyle: const TextStyle(color: CropinColors.hint, fontSize: 15),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.mic, color: CropinColors.primary),
                      onPressed: _speak,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _AgentCard(
              parsed: parsed,
              type: type,
              severity: severity,
              plot: store.asset(selected.firstOrNull),
              selectedCount: selected.length,
              distance: selected.isEmpty ? null : _distance(store.asset(selected.first)!),
              fix: fix,
              locating: locating,
              onSpeak: _speak,
              onType: (s) => setState(() => type = s),
              onSeverity: (s) => setState(() => severity = s),
            ),
            const SectionGap(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
              child: Row(children: [
                Expanded(
                  child: Text('Assets(${list.length})', style: const TextStyle(fontSize: 12)),
                ),
                Text(
                    list.isNotEmpty && list.every((a) => selected.contains(a.id))
                        ? 'Clear all'
                        : 'Select all',
                    style: const TextStyle(fontSize: 11, color: CropinColors.primary)),
                Checkbox(
                  key: const Key('select-all-plots'),
                  tristate: true,
                  value: list.isEmpty || !list.any((a) => selected.contains(a.id))
                      ? false
                      : list.every((a) => selected.contains(a.id))
                          ? true
                          : null,
                  onChanged: (_) => _toggleAll(list),
                ),
              ]),
            ),
            for (final a in ordered) _PlotRow(
              asset: a,
              distance: _distance(a),
              checked: selected.contains(a.id),
              onChanged: (v) => setState(() => v ? selected.add(a.id) : selected.remove(a.id)),
            ),
          ]),
        ),
        Container(
          padding: const EdgeInsets.only(top: 14),
          color: Colors.white,
          child: Text('${selected.length}assets has been selected',
              style: const TextStyle(fontSize: 14)),
        ),
        BottomActions(
          left: SecondaryButton(label: 'Cancel', onPressed: () => Navigator.of(context).pop()),
          right: PrimaryButton(label: 'Raise alert', onPressed: selected.isEmpty ? null : _raise),
        ),
      ]),
    );
  }
}

class _AgentCard extends StatelessWidget {
  const _AgentCard({
    required this.parsed,
    required this.type,
    required this.severity,
    required this.plot,
    required this.selectedCount,
    required this.distance,
    required this.fix,
    required this.locating,
    required this.onSpeak,
    required this.onType,
    required this.onSeverity,
  });

  final AlertParseResult? parsed;
  final String? type;
  final String? severity;
  final Asset? plot;
  final int selectedCount;
  final double? distance;
  final LocationFix? fix;
  final bool locating;
  final VoidCallback onSpeak;
  final ValueChanged<String> onType;
  final ValueChanged<String> onSeverity;

  @override
  Widget build(BuildContext context) {
    final gps = locating
        ? 'Getting GPS fix…'
        : fix == null
            ? 'Location unavailable'
            : fix!.isDemo
                ? 'Demo location · BTM Layout (no nearby GPS fix)'
                : 'GPS ${fix!.point.lat.toStringAsFixed(4)}, ${fix!.point.lng.toStringAsFixed(4)}';
    if (parsed == null) {
      return InkWell(
        onTap: onSpeak,
        child: Container(
          margin: const EdgeInsets.fromLTRB(18, 0, 18, 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF4FAEC),
            border: Border.all(color: CropinColors.green),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            const Icon(Icons.mic, color: CropinColors.green, size: 25),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Say "Raise pest alert on the chilli plot here, high severity"\n'
                'or "… on all chilli plots in BTM" for a common alert\n$gps',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ]),
        ),
      );
    }
    final p = parsed!;
    Widget row(String label, String? value, {double? conf, Widget? trailing}) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            SizedBox(
                width: 71,
                child: Text(label, style: const TextStyle(color: CropinColors.subText, fontSize: 12))),
            Expanded(
              child: Text(value ?? 'Not heard — tap to pick',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: value == null ? CropinColors.voiceCheck : CropinColors.text)),
            ),
            if (conf != null)
              Icon(conf >= 0.9 ? Icons.check_circle : Icons.help_outline,
                  size: 15, color: conf >= 0.9 ? CropinColors.voiceFilled : CropinColors.voiceCheck),
            if (trailing != null) trailing,
          ]),
        );
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FAF3),
        border: Border.all(color: CropinColors.voiceFilled),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.mic, color: CropinColors.voiceFilled, size: 15),
          const SizedBox(width: 6),
          Expanded(
            child: Text('"${p.note}"',
                style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
          ),
          IconButton(
            onPressed: onSpeak,
            icon: const Icon(Icons.refresh, color: CropinColors.primary),
            tooltip: 'Speak again',
          ),
        ]),
        const Divider(),
        _PickRow(label: 'Alert type', value: type, conf: p.type?.confidence,
            options: DemoData.alertTypes, onChanged: onType),
        _PickRow(label: 'Severity', value: severity, conf: p.severity?.confidence,
            options: DemoData.severities, onChanged: onSeverity),
        row(
            selectedCount > 1 ? 'Plots' : 'Plot',
            plot == null
                ? null
                : selectedCount > 1
                    ? '$selectedCount plots selected · common alert'
                    : '${plot!.name} · ${plot!.crop}',
            conf: plot == null ? null : (p.nearMe || p.crop != null || p.selectAll ? 0.95 : 0.8)),
        row('Location',
            distance == null || selectedCount > 1 ? gps : '${distance!.toStringAsFixed(2)} km away · $gps'),
        if (p.unmapped.isNotEmpty)
          Text('Not mapped: ${p.unmapped.join(', ')}',
              style: const TextStyle(fontSize: 10, color: CropinColors.voiceCheck)),
      ]),
    );
  }
}

class _PickRow extends StatelessWidget {
  const _PickRow({
    required this.label,
    required this.value,
    required this.conf,
    required this.options,
    required this.onChanged,
  });
  final String label;
  final String? value;
  final double? conf;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          SizedBox(
              width: 71,
              child: Text(label, style: const TextStyle(color: CropinColors.subText, fontSize: 12))),
          Expanded(
            child: PopupMenuButton<String>(
              onSelected: onChanged,
              itemBuilder: (_) => [for (final o in options) PopupMenuItem(value: o, child: Text(o))],
              child: Row(children: [
                Flexible(
                  child: Text(value ?? 'Not heard — tap to pick',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: value == null ? CropinColors.voiceCheck : CropinColors.text)),
                ),
                const Icon(Icons.arrow_drop_down, color: CropinColors.subText),
              ]),
            ),
          ),
          if (conf != null)
            Icon(conf! >= 0.9 ? Icons.check_circle : Icons.help_outline,
                size: 15, color: conf! >= 0.9 ? CropinColors.voiceFilled : CropinColors.voiceCheck),
        ]),
      );
}

class _PlotRow extends StatelessWidget {
  const _PlotRow({
    required this.asset,
    required this.distance,
    required this.checked,
    required this.onChanged,
  });
  final Asset asset;
  final double? distance;
  final bool checked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final f = AppStore.instance.farmer(asset.farmerId);
    return InkWell(
      onTap: () => onChanged(!checked),
      child: Container(
        color: checked ? const Color(0xFFF0FAF3) : Colors.white,
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Column(children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: 54,
              child: Column(children: [
                const PlotIcon(size: 21, filled: true),
                const SizedBox(height: 4),
                Text(asset.areaLabel,
                    textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                if (distance != null)
                  Text('${distance!.toStringAsFixed(1)} km',
                      style: const TextStyle(fontSize: 10, color: CropinColors.subText)),
              ]),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(asset.name,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600, color: CropinColors.primary)),
                Text('${asset.variety} (${asset.crop})',
                    style: const TextStyle(fontSize: 13, color: CropinColors.primary)),
                Text(f?.name ?? '', style: const TextStyle(fontSize: 13, color: CropinColors.primary)),
                Text(asset.address,
                    style: const TextStyle(fontSize: 12, color: CropinColors.primary)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: StatusDot(status: asset.status, size: 25),
            ),
            Checkbox(value: checked, onChanged: (v) => onChanged(v ?? false)),
          ]),
          const SizedBox(height: 6),
          const Divider(height: 1),
        ]),
      ),
    );
  }
}
