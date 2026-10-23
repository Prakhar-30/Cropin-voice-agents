import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../voice/agent_language.dart';
import '../voice/nlu/dictation.dart';
import 'speech_pack_service.dart';

enum SpeechState { idle, initializing, listening, error }

/// Wraps Android's speech recogniser for field dictation.
///
/// Android ends a recognition session at the first short pause, so one
/// command ("name … mobile … (pause) … add him to the paddy project") is
/// recorded as several sessions that are joined into one [Dictation]. The
/// command ends after [endSilence] without new words, when the user taps
/// Done ([stop]) or says "done". With [offlineOnly] the on-device recogniser
/// is used when its language pack is installed.
class SpeechService extends ChangeNotifier {
  SpeechService._();
  static final SpeechService instance = SpeechService._();

  /// Silence after the last spoken word that ends the command.
  static const endSilence = Duration(milliseconds: 2750);

  /// Give up if nothing at all is said for this long after tapping the mic.
  static const noSpeechTimeout = Duration(seconds: 15);
  static const maxDictation = Duration(seconds: 120);

  /// Voice activity: microphone level (Android rms dB) this far above the
  /// running background-noise floor counts as speech. Adapting to the floor
  /// keeps field noise from holding the recording open and keeps quiet
  /// speakers from being cut off.
  static const voiceAboveNoise = 3.5;
  double? _noiseFloor;

  /// False from tapping the mic until the recogniser is actually listening
  /// (the UI shows a "Getting ready…" loader meanwhile).
  bool live = false;

  final SpeechToText _stt = SpeechToText();
  bool _ready = false;
  bool offlineOnly = true;

  SpeechState state = SpeechState.idle;

  /// Text recorded so far (shown only after recording ends).
  String partial = '';
  String? lastError;
  double soundLevel = 0;
  List<LocaleName> installedLocales = [];

  /// 'offline'  – Android's on-device model is used
  /// 'fallback' – offline wanted, but this language's on-device pack isn't
  ///              installed yet, so the standard recogniser is used meanwhile
  /// 'online'   – the user switched "Offline only" off
  String mode = 'offline';

  final Dictation _dict = Dictation();
  AgentLanguage? _lang;
  bool _onDevice = false;
  bool _fellBack = false;

  /// True between [start] and the end of the command.
  bool _active = false;
  bool _finishing = false;
  String _segPartial = '';
  DateTime _startedAt = DateTime.now();
  DateTime? _lastVoiceAt;
  DateTime _lastRestart = DateTime.fromMillisecondsSinceEpoch(0);
  int _errorRestarts = 0;
  bool _restartPending = false;

  /// Our own view of whether a recogniser session is running. The plugin's
  /// `isListening` flag lags behind `listen()` by a few hundred ms; trusting
  /// it made the watchdog restart (and so discard) sessions that had only
  /// just started.
  bool _sessionOpen = false;
  Timer? _ticker;
  void Function(String text, bool isFinal)? _onResult;
  bool _autoStop = true;

  /// Pack status is cached per language so starting is instant.
  final Map<AgentLanguage, (bool, DateTime)> _packCache = {};

  bool get isListening => state == SpeechState.listening;
  bool get isReady => _ready;

  Future<bool> init() async {
    if (_ready) return true;
    state = SpeechState.initializing;
    notifyListeners();
    try {
      _ready = await _stt.initialize(onError: _handleError, onStatus: _handleStatus);
      if (_ready) {
        installedLocales = await _stt.locales().timeout(const Duration(seconds: 3),
            onTimeout: () => <LocaleName>[]);
      }
    } catch (e) {
      _ready = false;
      lastError = 'Speech recogniser unavailable: $e';
    }
    state = _ready ? SpeechState.idle : SpeechState.error;
    if (!_ready) lastError ??= 'Microphone permission denied or no speech recogniser on this device.';
    notifyListeners();
    return _ready;
  }

  /// Picks the recogniser's own id for [lang] (e.g. "kn_IN" / "kn-IN").
  String localeFor(AgentLanguage lang) {
    for (final l in installedLocales) {
      if (l.localeId.toLowerCase().replaceAll('-', '_') == lang.sttLocale.toLowerCase()) {
        return l.localeId;
      }
    }
    return lang.ttsLocale;
  }

  bool supports(AgentLanguage lang) =>
      installedLocales.any((l) => l.localeId.toLowerCase().startsWith(lang.code));

  /// Whether to use the on-device recogniser for [lang] (installs the pack in
  /// the background when it's missing).
  Future<bool> _useOnDevice(AgentLanguage lang) async {
    if (!offlineOnly) return false;
    final cached = _packCache[lang];
    if (cached != null &&
        (cached.$1 || DateTime.now().difference(cached.$2) < const Duration(seconds: 30))) {
      return cached.$1;
    }
    final packs = SpeechPackService.instance;
    final st = await packs.status(lang).timeout(const Duration(seconds: 2), onTimeout: () => null);
    var ok = true;
    if (st != null && st.onDeviceAvailable && st.checked && !st.isInstalled(lang)) {
      ok = false;
      if (st.isSupported(lang)) unawaited(packs.download(lang));
    }
    _packCache[lang] = (ok, DateTime.now());
    return ok;
  }

  /// Starts a new dictation in [lang]. [onResult] is called once with
  /// `isFinal == true` when the command has ended.
  /// With [autoStopOnSilence] false (hold-to-talk) only [stop] ends it.
  Future<bool> start(AgentLanguage lang,
      {void Function(String text, bool isFinal)? onResult, bool autoStopOnSilence = true}) async {
    await _halt();
    _autoStop = autoStopOnSilence;
    if (!await init()) return false;
    _dict.clear();
    _segPartial = '';
    partial = '';
    lastError = null;
    _lang = lang;
    _onResult = onResult;
    _fellBack = false;
    _errorRestarts = 0;
    _finishing = false;
    _onDevice = await _useOnDevice(lang);
    mode = _onDevice ? 'offline' : (offlineOnly ? 'fallback' : 'online');
    _active = true;
    live = false;
    _noiseFloor = null;
    _startedAt = DateTime.now();
    _lastVoiceAt = null;
    state = SpeechState.listening;
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
    notifyListeners();
    final ok = await _listenSegment();
    if (!ok && _active) {
      _active = false;
      _ticker?.cancel();
      state = SpeechState.error;
      notifyListeners();
    }
    return ok;
  }

  Future<bool> _listenSegment() async {
    _restartPending = false;
    final lang = _lang;
    if (!_active || lang == null) return false;
    // A session that ended without a final result still counts.
    if (_segPartial.isNotEmpty) {
      _dict.add(_segPartial);
      _segPartial = '';
    }
    _lastRestart = DateTime.now();
    _sessionOpen = true;
    try {
      await _stt.listen(
        onResult: _handleResult,
        onSoundLevelChange: _onLevel,
        listenOptions: SpeechListenOptions(
          localeId: lang.ttsLocale,
          listenFor: const Duration(seconds: 60),
          pauseFor: const Duration(seconds: 3),
          partialResults: true,
          onDevice: _onDevice,
          listenMode: ListenMode.dictation,
          cancelOnError: true,
        ),
      );
      return true;
    } catch (e) {
      _sessionOpen = false;
      lastError = '$e';
      return false;
    }
  }

  void _onLevel(double level) {
    soundLevel = level;
    if (!live && _active) live = true;
    final floor = _noiseFloor;
    if (floor == null || level < floor) {
      _noiseFloor = level;
    } else {
      _noiseFloor = floor + (level - floor) * 0.01; // rises slowly with steady noise
    }
    final threshold = (_noiseFloor ?? 0) + voiceAboveNoise;
    if (_active && level > (threshold < 1 ? 1 : threshold)) _lastVoiceAt = DateTime.now();
    notifyListeners();
  }

  /// Initialises the recogniser and checks the language pack ahead of time so
  /// tapping the mic starts listening quickly.
  Future<void> prewarm(AgentLanguage lang) async {
    if (!await init()) return;
    await _useOnDevice(lang);
  }

  /// Silence / timeout watchdog. Uses the time of the last spoken word, so
  /// recogniser restarts at pauses never postpone the end of the command.
  void _tick() {
    if (!_active || _finishing) return;
    final now = DateTime.now();
    final hasText = !_dict.isEmpty || _segPartial.isNotEmpty;
    final heardVoice = _lastVoiceAt != null;
    if (_autoStop && heardVoice && hasText && now.difference(_lastVoiceAt!) >= endSilence) {
      _finish();
    } else if (_autoStop && heardVoice && !hasText &&
        now.difference(_lastVoiceAt!) >= endSilence + const Duration(seconds: 2)) {
      // spoke but the recogniser never returned words — don't hang forever
      _finish();
    } else if (_autoStop && !heardVoice && !hasText && now.difference(_startedAt) >= noSpeechTimeout) {
      _finish();
    } else if (now.difference(_startedAt) >= maxDictation) {
      _finish();
    } else if (!_sessionOpen &&
        !_restartPending &&
        now.difference(_lastRestart) > const Duration(milliseconds: 1500)) {
      // safety net in case a session ended without telling us
      _scheduleRestart();
    }
  }

  void _scheduleRestart() {
    if (!_active || _finishing || _restartPending) return;
    _restartPending = true;
    final since = DateTime.now().difference(_lastRestart);
    final minGap = Duration(milliseconds: _errorRestarts > 5 ? 800 : 400);
    final wait = since < minGap ? minGap - since : const Duration(milliseconds: 120);
    Future.delayed(wait, () {
      if (_active && !_finishing && !_sessionOpen) {
        _listenSegment();
      } else {
        _restartPending = false;
      }
    });
  }

  /// Ends the command because of silence or a "done" word.
  Future<void> _finish() async {
    if (_finishing || !_active) return;
    final text = await stop();
    _onResult?.call(text, true);
  }

  /// Ends recording (Done button / shutter released) and returns the text.
  /// Never waits on the recogniser for more than about a second.
  Future<String> stop() async {
    if (!_active) return _dict.withPartial(_segPartial);
    if (_finishing) {
      // already stopping (silence timeout raced with Done) — wait for it
      for (var i = 0; i < 20 && _active; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return partial;
    }
    _finishing = true;
    _ticker?.cancel();
    try {
      await _stt.stop().timeout(const Duration(milliseconds: 700));
    } catch (_) {}
    // The recogniser delivers the words of the current session after stop();
    // on-device models can take a second. Wait for the session to close.
    for (var i = 0; i < 15 && _sessionOpen; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    await Future.delayed(const Duration(milliseconds: 150));
    _sessionOpen = false;
    final text = _dict.withPartial(_segPartial);
    _segPartial = '';
    _active = false;
    _finishing = false;
    partial = text;
    state = SpeechState.idle;
    notifyListeners();
    return text;
  }

  /// Abandons the recording (sheet closed / language switched).
  Future<void> cancel() => _halt();

  Future<void> _halt() async {
    final wasActive = _active || _stt.isListening;
    _active = false;
    _finishing = false;
    _restartPending = false;
    _sessionOpen = false;
    _ticker?.cancel();
    if (wasActive) {
      try {
        await _stt.cancel().timeout(const Duration(milliseconds: 700));
      } catch (_) {}
    }
    if (state == SpeechState.listening) state = SpeechState.idle;
    notifyListeners();
  }

  /// Hypotheses to try for [chosen]: N-best variants of the dictated command
  /// when the text came straight from speech, otherwise just the typed text.
  List<String> hypothesesFor(String chosen) {
    final c = chosen.trim();
    if (_dict.isEmpty || _dict.text != c) return [c];
    return _dict.hypotheses();
  }

  void _handleResult(SpeechRecognitionResult r) {
    final words = r.recognizedWords.trim();
    if (words.isNotEmpty && words != _segPartial) {
      _lastVoiceAt = DateTime.now();
      _errorRestarts = 0;
      live = true;
    }
    if (r.finalResult) {
      final alts = <String>[];
      for (final a in r.alternates) {
        final w = a.recognizedWords.trim();
        if (w.isNotEmpty && !alts.contains(w)) alts.add(w);
      }
      // Only Done / silence end the recording; a trailing "done" is just dropped.
      final (clean, _) = Dictation.stripDone(words);
      _dict.add(clean, alts);
      _segPartial = '';
      // The session closes right after its final result; the "done" status
      // (or the watchdog) starts the next one.
    } else {
      _segPartial = words;
    }
  }

  void _handleStatus(String status) {
    if (status == SpeechToText.listeningStatus) {
      _sessionOpen = true;
      if (_active && !live) {
        live = true;
        notifyListeners();
      }
      return;
    }
    if (status != SpeechToText.doneStatus && status != SpeechToText.notListeningStatus) return;
    // Late "done" from the session we just replaced — ignore it.
    if (DateTime.now().difference(_lastRestart) < const Duration(milliseconds: 300)) return;
    _sessionOpen = false;
    // A session ended at a pause; keep listening while the command is active.
    if (_active && !_finishing) _scheduleRestart();
  }

  void _handleError(SpeechRecognitionError e) {
    _sessionOpen = false;
    final missingPack = e.errorMsg == 'error_language_unavailable' ||
        e.errorMsg == 'error_language_not_supported';
    if (_active && !_finishing && missingPack && _onDevice && !_fellBack) {
      // On-device model missing: download it, use the standard recogniser now.
      _fellBack = true;
      _onDevice = false;
      mode = 'fallback';
      final lang = _lang;
      if (lang != null) {
        _packCache[lang] = (false, DateTime.now());
        unawaited(SpeechPackService.instance.download(lang));
      }
      notifyListeners();
      _scheduleRestart();
      return;
    }
    if (_active && !_finishing && _errorRestarts < 200) {
      // Pauses and recogniser hiccups surface as errors; never stop because
      // of them — keep listening until Done or real silence.
      _errorRestarts++;
      _scheduleRestart();
      return;
    }
    if (_active && (!_dict.isEmpty || _segPartial.isNotEmpty)) {
      _finish();
      return;
    }
    if (_active) {
      _active = false;
      _ticker?.cancel();
      lastError = describeError(e.errorMsg);
      state = SpeechState.error;
      notifyListeners();
    }
  }

  static String describeError(String code) => switch (code) {
        'error_language_unavailable' || 'error_language_not_supported' =>
          'This language\'s speech pack isn\'t ready yet. It is downloading — tap the mic '
              'to try again, or type instead.',
        'error_network' || 'error_network_timeout' || 'error_server' || 'error_server_disconnected' =>
          'The recogniser needs its language pack or a connection. Tap the mic to retry, or type instead.',
        'error_no_match' || 'error_speech_timeout' => "Didn't catch that. Tap the mic and speak again.",
        'error_permission' || 'error_insufficient_permissions' => 'Microphone permission is required.',
        'error_busy' || 'error_recognizer_busy' => 'Recogniser is busy, tap the mic again.',
        _ => 'Speech error: $code. Tap the mic to retry.',
      };
}
