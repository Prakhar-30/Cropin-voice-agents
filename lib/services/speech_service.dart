import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../voice/agent_language.dart';
import '../voice/nlu/dictation.dart';
import 'speech_pack_service.dart';

enum SpeechState { idle, initializing, listening, error }

/// Wraps Android's on-device speech recogniser.
///
/// With [offlineOnly] the recogniser is asked to run on-device
/// (`EXTRA_PREFER_OFFLINE`), so no audio leaves the phone. That needs the
/// offline speech pack for the language (Google app > Settings > Voice >
/// Offline speech recognition), which is available for English, Hindi,
/// Kannada, Tamil and other Indian languages.
class SpeechService extends ChangeNotifier {
  SpeechService._();
  static final SpeechService instance = SpeechService._();

  final SpeechToText _stt = SpeechToText();
  bool _ready = false;
  bool offlineOnly = true;

  SpeechState state = SpeechState.idle;
  String partial = '';

  String? lastError;
  double soundLevel = 0;
  List<LocaleName> installedLocales = [];

  /// 'offline'  – Android's on-device model is used
  /// 'fallback' – offline wanted, but this language's on-device pack is still
  ///              downloading, so the standard recogniser is used meanwhile
  /// 'online'   – the user switched "Offline only" off
  String mode = 'offline';
  AgentLanguage? _lang;
  bool _retried = false;

  void Function(String text, bool isFinal)? _onResult;
  Completer<String>? _finalCompleter;

  bool get isListening => state == SpeechState.listening;
  bool get isReady => _ready;

  Future<bool> init() async {
    if (_ready) return true;
    state = SpeechState.initializing;
    notifyListeners();
    try {
      _ready = await _stt.initialize(
        onError: _handleError,
        onStatus: _handleStatus,
      );
      if (_ready) installedLocales = await _stt.locales();
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
      final id = l.localeId.toLowerCase().replaceAll('-', '_');
      if (id == lang.sttLocale.toLowerCase()) return l.localeId;
    }
    for (final l in installedLocales) {
      if (l.localeId.toLowerCase().startsWith(lang.code)) return l.localeId;
    }
    return lang.sttLocale;
  }

  bool supports(AgentLanguage lang) => installedLocales
      .any((l) => l.localeId.toLowerCase().startsWith(lang.code));

  // ------------------------------------------------------------ dictation
  /// How long the speaker may stay silent before the command is considered
  /// finished. Android stops each session after ~1 s of silence; we restart
  /// it and keep collecting until this much silence has passed.
  static const endSilence = Duration(milliseconds: 3500);
  static const noSpeechTimeout = Duration(seconds: 10);
  static const maxDictation = Duration(seconds: 90);

  final Dictation _dict = Dictation();
  bool _continuous = false;
  bool _onDeviceNow = false;
  bool _restartPending = false;
  String _segPartial = '';
  Timer? _silenceTimer;
  Timer? _maxTimer;

  /// Listens continuously: pauses are fine, segments are joined, and the
  /// result is delivered with `isFinal == true` once the speaker has been
  /// silent for [endSilence], says "done", or [stop] is called.
  Future<bool> start(AgentLanguage lang,
      {void Function(String text, bool isFinal)? onResult, bool forceFallback = false}) async {
    if (!await init()) return false;
    _continuous = false; // so the cancel below doesn't trigger a restart
    if (_stt.isListening) await _stt.cancel();
    if (!forceFallback) {
      _retried = false;
      _dict.clear();
      _finalCompleter = Completer<String>();
      _maxTimer?.cancel();
      _maxTimer = Timer(maxDictation, _finish);
    }
    var onDevice = offlineOnly && !forceFallback;
    if (onDevice) {
      // Make sure the on-device model exists; if not, fetch it in the
      // background and use the standard recogniser until it's ready.
      final packs = SpeechPackService.instance;
      final st = await packs.status(lang);
      if (st != null && st.onDeviceAvailable && st.checked && !st.isInstalled(lang)) {
        onDevice = false;
        if (st.isSupported(lang)) unawaited(packs.download(lang));
      }
    }
    if (forceFallback) unawaited(SpeechPackService.instance.download(lang));
    mode = onDevice ? 'offline' : (offlineOnly ? 'fallback' : 'online');
    _lang = lang;
    _onDeviceNow = onDevice;
    partial = _dict.text;
    lastError = null;
    _onResult = onResult;
    _continuous = true;
    state = SpeechState.listening;
    _armSilence(noSpeech: _dict.isEmpty);
    notifyListeners();
    return _listenSegment();
  }

  Future<bool> _listenSegment() async {
    _restartPending = false;
    // A session that ended without a final result still counts.
    if (_segPartial.isNotEmpty) {
      _dict.add(_segPartial);
      _segPartial = '';
    }
    final lang = _lang;
    if (lang == null || !_continuous) return false;
    try {
      await _stt.listen(
        onResult: _handleResult,
        onSoundLevelChange: (level) {
          soundLevel = level;
          notifyListeners();
        },
        listenOptions: SpeechListenOptions(
          localeId: lang.ttsLocale,
          listenFor: const Duration(seconds: 60),
          pauseFor: const Duration(seconds: 3),
          partialResults: true,
          onDevice: _onDeviceNow,
          listenMode: ListenMode.dictation,
          cancelOnError: true,
        ),
      );
      return true;
    } catch (e) {
      if (!_dict.isEmpty) {
        _finish();
        return true;
      }
      _continuous = false;
      state = SpeechState.error;
      lastError = '$e';
      notifyListeners();
      return false;
    }
  }

  void _armSilence({bool noSpeech = false}) {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(noSpeech ? noSpeechTimeout : endSilence, _finish);
  }

  void _scheduleRestart() {
    if (_restartPending || !_continuous) return;
    _restartPending = true;
    Future.delayed(const Duration(milliseconds: 250), () {
      if (_continuous && !_stt.isListening) {
        _listenSegment();
      } else {
        _restartPending = false;
      }
    });
  }

  /// Ends the dictation and delivers the joined text.
  void _finish() {
    if (!_continuous) return;
    _continuous = false;
    _silenceTimer?.cancel();
    _maxTimer?.cancel();
    if (_stt.isListening) _stt.stop();
    final text = _dict.withPartial(_segPartial);
    _segPartial = '';
    partial = text;
    state = SpeechState.idle;
    _onResult?.call(text, true);
    _complete(text);
    notifyListeners();
  }

  /// Stops listening (user tapped Done / released the shutter) and returns
  /// everything said so far.
  Future<String> stop() async {
    _continuous = false;
    _silenceTimer?.cancel();
    _maxTimer?.cancel();
    if (_stt.isListening) await _stt.stop();
    final c = _finalCompleter;
    var text = _dict.withPartial(_segPartial);
    if (c != null && !c.isCompleted) {
      // the last segment's final result usually arrives right after stop()
      text = await c.future
          .timeout(const Duration(milliseconds: 1200), onTimeout: () => _dict.withPartial(_segPartial));
    } else if (c != null) {
      text = await c.future;
    }
    _segPartial = '';
    _complete(text);
    partial = text;
    state = SpeechState.idle;
    notifyListeners();
    return text;
  }

  /// Hypotheses to try for [chosen]: N-best variants of the dictated command
  /// when the text came straight from speech, otherwise just the typed text.
  List<String> hypothesesFor(String chosen) {
    final c = chosen.trim();
    if (_dict.isEmpty || _dict.text != c) return [c];
    return _dict.hypotheses();
  }

  Future<void> cancel() async {
    _continuous = false;
    _silenceTimer?.cancel();
    _maxTimer?.cancel();
    await _stt.cancel();
    _complete(_dict.withPartial(_segPartial));
    state = SpeechState.idle;
    notifyListeners();
  }

  void _handleResult(SpeechRecognitionResult r) {
    final words = r.recognizedWords.trim();
    final alts = <String>[];
    for (final a in r.alternates) {
      final w = a.recognizedWords.trim();
      if (w.isNotEmpty && !alts.contains(w)) alts.add(w);
    }
    if (words.isNotEmpty) _silenceTimer?.cancel();
    if (r.finalResult) {
      final (clean, done) = Dictation.stripDone(words);
      _dict.add(clean, alts);
      _segPartial = '';
      partial = _dict.text;
      notifyListeners();
      if (done) {
        _finish();
      } else if (_continuous) {
        _onResult?.call(partial, false);
        _armSilence(noSpeech: _dict.isEmpty);
        _scheduleRestart();
      } else {
        _complete(_dict.text);
      }
      return;
    }
    _segPartial = words;
    partial = _dict.withPartial(words);
    _onResult?.call(partial, false);
    notifyListeners();
  }

  void _handleStatus(String status) {
    if (status != SpeechToText.doneStatus && status != SpeechToText.notListeningStatus) return;
    if (_continuous) {
      // Session ended at a pause: keep listening, the silence timer decides
      // when the command is over.
      _armSilence(noSpeech: _dict.isEmpty && _segPartial.isEmpty);
      _scheduleRestart();
    } else if (state == SpeechState.listening) {
      state = SpeechState.idle;
      Future.delayed(const Duration(milliseconds: 600),
          () => _complete(_dict.withPartial(_segPartial)));
    }
    notifyListeners();
  }

  void _handleError(SpeechRecognitionError e) {
    final missingPack = e.errorMsg == 'error_language_unavailable' ||
        e.errorMsg == 'error_language_not_supported';
    if (missingPack && _onDeviceNow && !_retried && _lang != null) {
      // On-device model missing: download it and carry on with the
      // standard recogniser so the user isn't blocked.
      _retried = true;
      final lang = _lang!;
      final cb = _onResult;
      Future.microtask(() => start(lang, onResult: cb, forceFallback: true));
      return;
    }
    const silence = {
      'error_no_match', 'error_speech_timeout', 'error_client', 'error_busy',
      'error_recognizer_busy',
    };
    if (_continuous && silence.contains(e.errorMsg)) {
      // Just a pause (or a restart race) — keep the dictation going.
      _armSilence(noSpeech: _dict.isEmpty && _segPartial.isEmpty);
      _scheduleRestart();
      return;
    }
    if (_continuous && !_dict.isEmpty) {
      _finish();
      return;
    }
    _continuous = false;
    lastError = describeError(e.errorMsg);
    state = SpeechState.error;
    _complete(_dict.withPartial(_segPartial));
    notifyListeners();
  }

  void _complete(String text) {
    final c = _finalCompleter;
    if (c != null && !c.isCompleted) c.complete(text);
  }

  static String describeError(String code) => switch (code) {
        'error_language_unavailable' || 'error_language_not_supported' =>
          'This language\'s on-device speech pack isn\'t ready yet. The app is downloading '
              'it — tap the mic again to use standard recognition meanwhile, or type instead.',
        'error_network' || 'error_network_timeout' || 'error_server' || 'error_server_disconnected' =>
          'Recogniser needs its offline language pack (device is offline). Download the pack '
              'in Google app → Settings → Voice → Offline speech recognition, or type instead.',
        'error_no_match' || 'error_speech_timeout' => "Didn't catch that. Please speak again.",
        'error_permission' || 'error_insufficient_permissions' => 'Microphone permission is required.',
        'error_busy' || 'error_recognizer_busy' => 'Recogniser is busy, try again in a moment.',
        _ => 'Speech error: $code',
      };
}
