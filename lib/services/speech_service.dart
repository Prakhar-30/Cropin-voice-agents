import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../voice/agent_language.dart';

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

  Future<bool> start(AgentLanguage lang, {void Function(String text, bool isFinal)? onResult}) async {
    if (!await init()) return false;
    if (_stt.isListening) await _stt.cancel();
    partial = '';
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
          localeId: localeFor(lang),
          listenFor: const Duration(seconds: 45),
          pauseFor: const Duration(seconds: 4),
          partialResults: true,
          onDevice: offlineOnly,
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

  Future<void> cancel() async {
    await _stt.cancel();
    _complete(partial);
    state = SpeechState.idle;
    notifyListeners();
  }

  void _handleResult(SpeechRecognitionResult r) {
    partial = r.recognizedWords;
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
          'Offline speech pack for this language is not installed. Install it from '
              'Google app → Settings → Voice → Offline speech recognition, or type instead.',
        'error_network' || 'error_network_timeout' || 'error_server' || 'error_server_disconnected' =>
          'Recogniser needs its offline language pack (device is offline). Download the pack '
              'in Google app → Settings → Voice → Offline speech recognition, or type instead.',
        'error_no_match' || 'error_speech_timeout' => "Didn't catch that. Please speak again.",
        'error_permission' || 'error_insufficient_permissions' => 'Microphone permission is required.',
        'error_busy' || 'error_recognizer_busy' => 'Recogniser is busy, try again in a moment.',
        _ => 'Speech error: $code',
      };
}
