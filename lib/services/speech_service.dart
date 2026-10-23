import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../voice/agent_language.dart';
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

  /// Alternative transcripts of the last utterance, best first (N-best).
  List<String> alternates = [];
  String? lastError;
  double soundLevel = 0;
  List<LocaleName> installedLocales = [];

  /// 'offline'  – Android's on-device model is used
  /// 'fallback' – offline wanted, but this language's on-device pack is still
  ///              downloading, so the standard recogniser is used meanwhile
  /// 'online'   – the user switched "Offline only" off
  String mode = 'offline';
  AgentLanguage? _lang;
  bool _usedOnDevice = false;
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

  Future<bool> start(AgentLanguage lang,
      {void Function(String text, bool isFinal)? onResult, bool forceFallback = false}) async {
    if (!await init()) return false;
    if (_stt.isListening) await _stt.cancel();
    if (!forceFallback) _retried = false;
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
    _usedOnDevice = onDevice;
    partial = '';
    alternates = [];
    lastError = null;
    _onResult = onResult;
    _finalCompleter = Completer<String>();
    state = SpeechState.listening;
    notifyListeners();
    try {
      await _stt.listen(
        onResult: _handleResult,
        onSoundLevelChange: (level) {
          soundLevel = level;
          notifyListeners();
        },
        listenOptions: SpeechListenOptions(
          localeId: lang.ttsLocale,
          listenFor: const Duration(seconds: 45),
          pauseFor: const Duration(seconds: 4),
          partialResults: true,
          onDevice: onDevice,
          listenMode: ListenMode.dictation,
          cancelOnError: true,
        ),
      );
      return true;
    } catch (e) {
      state = SpeechState.error;
      lastError = '$e';
      notifyListeners();
      return false;
    }
  }

  /// Stops listening and returns the final transcript (or the last partial).
  Future<String> stop() async {
    if (_stt.isListening) await _stt.stop();
    final c = _finalCompleter;
    if (c == null) return partial;
    try {
      return await c.future.timeout(const Duration(milliseconds: 1800), onTimeout: () => partial);
    } finally {
      state = SpeechState.idle;
      notifyListeners();
    }
  }

  /// Hypotheses to try for [chosen]: the recogniser's N-best list when the
  /// text came straight from speech, otherwise just the (typed/edited) text.
  List<String> hypothesesFor(String chosen) {
    final c = chosen.trim();
    if (alternates.isEmpty || !alternates.any((a) => a.trim() == c)) return [c];
    return [c, ...alternates.where((a) => a.trim() != c)];
  }

  Future<void> cancel() async {
    await _stt.cancel();
    _complete(partial);
    state = SpeechState.idle;
    notifyListeners();
  }

  void _handleResult(SpeechRecognitionResult r) {
    partial = r.recognizedWords;
    final alts = <String>[];
    for (final a in r.alternates) {
      final w = a.recognizedWords.trim();
      if (w.isNotEmpty && !alts.contains(w)) alts.add(w);
    }
    if (alts.isNotEmpty) alternates = alts;
    _onResult?.call(partial, r.finalResult);
    if (r.finalResult) {
      _complete(partial);
      state = SpeechState.idle;
    }
    notifyListeners();
  }

  void _handleStatus(String status) {
    if (status == SpeechToText.doneStatus || status == SpeechToText.notListeningStatus) {
      if (state == SpeechState.listening) {
        state = SpeechState.idle;
        // final result normally arrives just before "done"; give it a moment
        Future.delayed(const Duration(milliseconds: 600), () => _complete(partial));
      }
      notifyListeners();
    }
  }

  void _handleError(SpeechRecognitionError e) {
    final missingPack = e.errorMsg == 'error_language_unavailable' ||
        e.errorMsg == 'error_language_not_supported';
    if (missingPack && _usedOnDevice && !_retried && _lang != null) {
      // On-device model missing: download it and carry on with the
      // standard recogniser so the user isn't blocked.
      _retried = true;
      final lang = _lang!;
      final cb = _onResult;
      Future.microtask(() => start(lang, onResult: cb, forceFallback: true));
      return;
    }
    lastError = describeError(e.errorMsg);
    state = SpeechState.error;
    _complete(partial);
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
