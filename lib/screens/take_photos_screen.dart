import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../data/models.dart';
import '../services/location_service.dart';
import '../services/speech_service.dart';
import '../services/tts_service.dart';
import '../theme/app_theme.dart';
import '../voice/agent_strings.dart';
import '../voice/nlu/photo_note_parser.dart';
import '../widgets/form_fields.dart';
import '../widgets/top_bar.dart';

/// Take Photos with voice notes: hold the shutter and talk. The transcript
/// becomes the photo comment and can be applied to a whole batch.
class TakePhotosScreen extends StatefulWidget {
  const TakePhotosScreen({super.key});

  @override
  State<TakePhotosScreen> createState() => _TakePhotosScreenState();
}

class _TakePhotosScreenState extends State<TakePhotosScreen> with WidgetsBindingObserver {
  final store = AppStore.instance;
  final speech = SpeechService.instance;
  CameraController? camera;
  String? cameraError;
  final photos = <PhotoRecord>[];
  final selected = <String>{};
  String? assetId;
  String? recordingFor; // photo id or 'batch'
  String? focusId; // photo whose comment is shown / recorded
  bool capturing = false;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    speech.prewarm(store.language);
    _initCamera();
    _pickNearestPlot();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    camera?.dispose();
    if (speech.isListening) speech.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = camera;
    if (c == null || !c.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      c.dispose();
      camera = null;
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) throw CameraException('none', 'No camera found');
      final back = cams.firstWhere((c) => c.lensDirection == CameraLensDirection.back,
          orElse: () => cams.first);
      final c = CameraController(back, ResolutionPreset.medium, enableAudio: false);
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() {
        camera = c;
        cameraError = null;
      });
    } catch (e) {
      if (mounted) setState(() => cameraError = e is CameraException ? (e.description ?? e.code) : '$e');
    }
  }

  Future<void> _pickNearestPlot() async {
    final fix = await LocationService.instance
        .current(nearTo: store.assets.map((a) => a.location).toList());
    if (!mounted) return;
    final sorted = List.of(store.assets)
      ..sort((a, b) => fix.point.distanceKm(a.location).compareTo(fix.point.distanceKm(b.location)));
    setState(() => assetId = sorted.first.id);
  }

  Future<PhotoRecord?> _capture() async {
    if (capturing) return null;
    capturing = true;
    try {
      String path = '';
      final c = camera;
      if (c != null && c.value.isInitialized) {
        final file = await c.takePicture();
        path = file.path;
      }
      final p = PhotoRecord(
        id: 'ph${DateTime.now().millisecondsSinceEpoch}_${_seq++}',
        path: path,
        createdAt: DateTime.now(),
        assetId: assetId,
      );
      if (mounted) {
        setState(() {
          photos.insert(0, p);
          focusId = p.id;
        });
      }
      return p;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Capture failed: $e')));
      }
      return null;
    } finally {
      capturing = false;
    }
  }

  /// Tap "Record comment": records until Done or 2.75 s of silence, then the
  /// text becomes the comment of [target] (a photo id, or 'batch').
  Future<void> _recordFor(String target) async {
    if (recordingFor != null) {
      await _endNote();
      return;
    }
    setState(() => recordingFor = target);
    final ok = await speech.start(store.language, onResult: (text, isFinal) {
      if (!isFinal || !mounted || recordingFor != target) return;
      setState(() => recordingFor = null);
      _deliver(target, text);
    });
    if (!ok && mounted) {
      setState(() => recordingFor = null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(speech.lastError ?? 'Speech recogniser unavailable. Use the keyboard icon.')));
    }
  }

  /// Done tapped while recording.
  Future<void> _endNote() async {
    final target = recordingFor;
    if (target == null) return;
    setState(() => recordingFor = null);
    final text = await speech.stop();
    if (mounted) _deliver(target, text);
  }

  void _deliver(String target, String text) {
    final t = text.trim();
    if (t.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Didn't catch anything — tap Record comment and speak again.")));
      return;
    }
    _applyNote(target, t);
  }

  void _applyNote(String target, String text) {
    final targets = target == 'batch'
        ? (selected.isEmpty ? photos : photos.where((p) => selected.contains(p.id))).toList()
        : photos.where((p) => p.id == target).toList();
    final tags = PhotoNoteParser.tags(text);
    setState(() {
      for (final p in targets) {
        p.note = text;
        p.tags = tags;
      }
    });
    TtsService.instance.speak(AgentStrings(store.language).noteSaved(targets.length), store.language);
  }

  /// Keyboard fallback for a comment.
  Future<void> _typeNote(String target) async {
    final ctrl = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Photo comment'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Type the observation'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Save')),
        ],
      ),
    );
    ctrl.dispose();
    if (text != null && text.trim().isNotEmpty && mounted) _applyNote(target, text.trim());
  }


  void _save() {
    if (photos.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    for (final p in photos) {
      p.assetId ??= assetId;
    }
    store.addPhotos(List.of(photos));
    TtsService.instance.speak(AgentStrings(store.language).saved, store.language);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('${photos.length} photos saved with notes')));
  }

  @override
  Widget build(BuildContext context) {
    final plot = store.asset(assetId);
    final strings = AgentStrings(store.language);
    final focus = photos.isEmpty
        ? null
        : photos.firstWhere((p) => p.id == focusId,
            orElse: () => photos.firstWhere((p) => selected.contains(p.id),
                orElse: () => photos.first));
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: cropinTitleBar(context, 'Take Photos', actions: [
        TextButton(
          onPressed: _save,
          child: Text('Save (${photos.length})',
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      ]),
      body: Column(children: [
        Container(
          color: Colors.white,
          child: VoiceSelectField<Asset>(
            label: '  Plot (nearest by GPS)',
            value: plot,
            options: store.assets,
            display: (a) => '${a.name} · ${a.crop} · ${a.areaLabel}',
            subtitle: (a) => store.farmer(a.farmerId)?.name ?? '',
            onChanged: (a) => setState(() => assetId = a.id),
          ),
        ),
        Expanded(
          child: Stack(fit: StackFit.expand, children: [
            _preview(),
            if (recordingFor != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: ListenableBuilder(
                  listenable: speech,
                  builder: (context, _) => Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(children: [
                      speech.live
                          ? const Icon(Icons.mic, color: CropinColors.green)
                          : const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  color: CropinColors.green, strokeWidth: 2.5),
                            ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          speech.live
                              ? '${strings.speakNow}\n${strings.pauseHint}'
                              : strings.getReady,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: CropinColors.green),
                        onPressed: _endNote,
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Done'),
                      ),
                    ]),
                  ),
                ),
              )
            else
              Positioned(
                left: 0,
                right: 0,
                bottom: 14,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text('Tap the shutter to take a photo, then ${strings.recordComment}',
                        style: const TextStyle(color: Colors.white, fontSize: 11)),
                  ),
                ),
              ),
          ]),
        ),
        if (photos.isNotEmpty) _strip(),
        if (focus != null) _noteEditor(focus),
        _controls(),
      ]),
    );
  }

  Widget _preview() {
    final c = camera;
    if (c != null && c.value.isInitialized) {
      return ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: c.value.previewSize?.height ?? 300,
            height: c.value.previewSize?.width ?? 400,
            child: CameraPreview(c),
          ),
        ),
      );
    }
    return Container(
      color: const Color(0xFF1E2A30),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Text(
        cameraError == null
            ? 'Starting camera…'
            : 'Camera unavailable ($cameraError).\nYou can still capture placeholder photos and add voice notes.',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white70),
      ),
    );
  }

  Widget _strip() => Container(
        height: 78,
        color: const Color(0xFF111111),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(8),
          itemCount: photos.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final p = photos[i];
            final sel = selected.contains(p.id);
            return GestureDetector(
              onTap: () => setState(() {
                sel ? selected.remove(p.id) : selected.add(p.id);
                focusId = p.id;
              }),
              child: Stack(children: [
                Container(
                  width: 65,
                  height: 65,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2B3A40),
                    border: Border.all(color: sel ? CropinColors.green : Colors.white24, width: sel ? 3 : 1),
                    borderRadius: BorderRadius.circular(6),
                    image: p.path.isEmpty
                        ? null
                        : DecorationImage(image: FileImage(File(p.path)), fit: BoxFit.cover),
                  ),
                  child: p.path.isEmpty
                      ? const Icon(Icons.image_outlined, color: Colors.white54)
                      : null,
                ),
                if (p.note.isNotEmpty)
                  const Positioned(
                    right: 4,
                    bottom: 4,
                    child: CircleAvatar(
                      radius: 8,
                      backgroundColor: CropinColors.green,
                      child: Icon(Icons.mic, size: 11, color: Colors.white),
                    ),
                  ),
                if (sel)
                  const Positioned(
                    left: 4,
                    top: 4,
                    child: Icon(Icons.check_circle, size: 15, color: CropinColors.green),
                  ),
              ]),
            );
          },
        ),
      );

  Widget _noteEditor(PhotoRecord p) => Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                p.note.isEmpty ? 'No comment yet' : p.note,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12, color: p.note.isEmpty ? CropinColors.hint : CropinColors.text),
              ),
              if (p.tags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Wrap(spacing: 4, runSpacing: 4, children: [
                    for (final t in p.tags)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: CropinColors.voiceFilled.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(t, style: const TextStyle(fontSize: 10)),
                      ),
                  ]),
                ),
            ]),
          ),
          const SizedBox(width: 6),
          FilledButton.icon(
            key: const Key('record-comment'),
            style: FilledButton.styleFrom(
              backgroundColor:
                  recordingFor == null ? CropinColors.primary : CropinColors.green,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            onPressed: () => _recordFor(selected.length > 1 ? 'batch' : p.id),
            icon: Icon(recordingFor == null ? Icons.mic : Icons.check, size: 16),
            label: Text(
                recordingFor == null
                    ? (selected.length > 1
                        ? '${AgentStrings(store.language).recordComment} (${selected.length})'
                        : AgentStrings(store.language).recordComment)
                    : 'Done',
                style: const TextStyle(fontSize: 12)),
          ),
          IconButton(
            tooltip: 'Type or pick an example note',
            icon: const Icon(Icons.keyboard_outlined, color: CropinColors.primary),
            onPressed: recordingFor == null ? () => _typeNote(p.id) : null,
          ),
        ]),
      );

  Widget _controls() => Container(
        color: Colors.black,
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
        child: SafeArea(
          top: false,
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            // Batch note: one spoken comment for all selected (or all) photos
            GestureDetector(
              onTap: photos.isEmpty ? null : () => _recordFor('batch'),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircleAvatar(
                  radius: 21,
                  backgroundColor: recordingFor == 'batch' ? CropinColors.green : Colors.white24,
                  child: const Icon(Icons.playlist_add, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(selected.isEmpty ? 'Note all' : 'Note ${selected.length}',
                    style: const TextStyle(color: Colors.white70, fontSize: 10)),
              ]),
            ),
            GestureDetector(
              key: const Key('shutter'),
              onTap: recordingFor == null ? _capture : null,
              child: Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                ),
                padding: const EdgeInsets.all(5),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: recordingFor != null ? Colors.white38 : Colors.white,
                  ),
                ),
              ),
            ),
            Column(mainAxisSize: MainAxisSize.min, children: [
              GestureDetector(
                onTap: () => setState(() {
                  if (selected.length == photos.length) {
                    selected.clear();
                  } else {
                    selected
                      ..clear()
                      ..addAll(photos.map((p) => p.id));
                  }
                }),
                child: const CircleAvatar(
                  radius: 21,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.select_all, color: Colors.white),
                ),
              ),
              const SizedBox(height: 4),
              Text('${photos.length} photos',
                  style: const TextStyle(color: Colors.white70, fontSize: 10)),
            ]),
          ]),
        ),
      );
}
