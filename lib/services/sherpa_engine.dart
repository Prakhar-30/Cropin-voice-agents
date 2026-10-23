import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

/// Offline speech recognition with sherpa-onnx, run on a background isolate
/// so decoding never blocks the UI.
///
/// Microphone audio (16 kHz mono float) goes in with [feed]. Silero VAD cuts
/// it into utterances at short pauses; each finished utterance is decoded
/// straight away and reported through [onText], so when the command ends only
/// the last few words are left to decode. [speaking] follows the VAD.
class SherpaEngine {
  SherpaEngine._();
  static final SherpaEngine instance = SherpaEngine._();

  static const sampleRate = 16000;

  SendPort? _worker;
  final ReceivePort _inbox = ReceivePort();
  StreamSubscription? _inboxSub;
  Completer<SendPort>? _spawning;
  Completer<String?>? _loading;
  Completer<void>? _flushing;
  String? _loadedModel;

  /// Whether the VAD currently hears speech.
  bool speaking = false;
  void Function(String text)? onText;
  void Function(bool speaking)? onSpeech;

  Future<SendPort> _ensureWorker() async {
    if (_worker != null) return _worker!;
    if (_spawning != null) return _spawning!.future;
    final c = _spawning = Completer<SendPort>();
    _inboxSub = _inbox.listen(_onMessage);
    await Isolate.spawn(_workerMain, _inbox.sendPort, debugName: 'sherpa-asr');
    return c.future;
  }

  void _onMessage(dynamic msg) {
    if (msg is SendPort) {
      _worker = msg;
      _spawning?.complete(msg);
      _spawning = null;
      return;
    }
    final m = msg as Map;
    switch (m['evt']) {
      case 'loaded':
        _loading?.complete(null);
        _loading = null;
      case 'error':
        _loading?.complete(m['msg'] as String);
        _loading = null;
      case 'speech':
        speaking = m['on'] as bool;
        onSpeech?.call(speaking);
      case 'text':
        final t = (m['text'] as String).trim();
        if (t.isNotEmpty) onText?.call(t);
      case 'flushed':
        _flushing?.complete();
        _flushing = null;
    }
  }

  bool isLoaded(String modelPath) => _loadedModel == modelPath;

  /// Loads the model for a language (kept in memory until another language
  /// is loaded). Returns an error message, or null when ready.
  Future<String?> load({
    required String model,
    required String tokens,
    required String vad,
  }) async {
    if (_loadedModel == model) return null;
    if (_loading != null) await _loading!.future;
    if (_loadedModel == model) return null;
    final w = await _ensureWorker();
    final c = _loading = Completer<String?>();
    w.send({'cmd': 'load', 'model': model, 'tokens': tokens, 'vad': vad});
    final err = await c.future.timeout(const Duration(seconds: 60),
        onTimeout: () => 'Loading the speech model timed out');
    _loadedModel = err == null ? model : null;
    return err;
  }

  /// Starts a fresh command (forgets audio of the previous one).
  void reset() {
    speaking = false;
    _worker?.send({'cmd': 'reset'});
  }

  void feed(Float32List samples) => _worker?.send({'cmd': 'audio', 'samples': samples});

  /// Decodes whatever speech is still buffered; texts arrive via [onText]
  /// before this completes.
  Future<void> flush() async {
    final w = _worker;
    if (w == null) return;
    final c = _flushing ??= Completer<void>();
    w.send({'cmd': 'flush'});
    await c.future.timeout(const Duration(seconds: 10), onTimeout: () {});
    _flushing = null;
  }
}

/// Background isolate: owns the VAD and recogniser.
void _workerMain(SendPort main) {
  final inbox = ReceivePort();
  main.send(inbox.sendPort);

  var bindings = false;
  sherpa.OfflineRecognizer? recognizer;
  sherpa.VoiceActivityDetector? vad;
  var window = 512;
  var pending = Float32List(0);
  var speaking = false;

  void decodeReady() {
    final v = vad, r = recognizer;
    if (v == null || r == null) return;
    while (!v.isEmpty()) {
      final seg = v.front();
      v.pop();
      if (seg.samples.isEmpty) continue;
      final stream = r.createStream();
      stream.acceptWaveform(samples: seg.samples, sampleRate: SherpaEngine.sampleRate);
      r.decode(stream);
      final text = r.getResult(stream).text;
      stream.free();
      main.send({'evt': 'text', 'text': text});
    }
  }

  void setSpeaking(bool on) {
    if (on == speaking) return;
    speaking = on;
    main.send({'evt': 'speech', 'on': on});
  }

  inbox.listen((dynamic msg) {
    final m = msg as Map;
    switch (m['cmd']) {
      case 'load':
        try {
          if (!bindings) {
            try {
              sherpa.initBindings();
            } catch (_) {
              sherpa.initBindings('libsherpa-onnx-c-api.so');
            }
            bindings = true;
          }
          recognizer?.free();
          vad?.free();
          recognizer = null;
          vad = null;
          recognizer = sherpa.OfflineRecognizer(sherpa.OfflineRecognizerConfig(
            model: sherpa.OfflineModelConfig(
              nemoCtc: sherpa.OfflineNemoEncDecCtcModelConfig(model: m['model'] as String),
              tokens: m['tokens'] as String,
              numThreads: 4,
              debug: false,
            ),
          ));
          final silero = sherpa.SileroVadModelConfig(
            model: m['vad'] as String,
            threshold: 0.5,
            // Short pauses split the speech into pieces that are decoded while
            // the user is still talking; the command itself ends after 2.75 s.
            minSilenceDuration: 0.6,
            minSpeechDuration: 0.25,
            maxSpeechDuration: 20,
          );
          vad = sherpa.VoiceActivityDetector(
            config: sherpa.VadModelConfig(sileroVad: silero, numThreads: 1, debug: false),
            bufferSizeInSeconds: 120,
          );
          window = silero.windowSize;
          pending = Float32List(0);
          main.send({'evt': 'loaded'});
        } catch (e) {
          main.send({'evt': 'error', 'msg': 'Could not start offline speech: $e'});
        }
      case 'reset':
        vad?.reset();
        pending = Float32List(0);
        speaking = false;
      case 'audio':
        final v = vad;
        if (v == null) return;
        final s = m['samples'] as Float32List;
        final all = Float32List(pending.length + s.length)
          ..setAll(0, pending)
          ..setAll(pending.length, s);
        var i = 0;
        while (i + window <= all.length) {
          v.acceptWaveform(Float32List.sublistView(all, i, i + window));
          i += window;
          setSpeaking(v.isDetected());
          decodeReady();
        }
        pending = Float32List.fromList(Float32List.sublistView(all, i));
      case 'flush':
        final v = vad;
        if (v != null) {
          if (pending.isNotEmpty) v.acceptWaveform(pending);
          pending = Float32List(0);
          v.flush();
          decodeReady();
          v.reset();
        }
        setSpeaking(false);
        main.send({'evt': 'flushed'});
    }
  });
}
