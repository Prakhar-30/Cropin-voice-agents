import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../voice/agent_language.dart';

/// Speaks agent replies with the phone's on-device TTS voices.
class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();
  bool enabled = true;
  bool _configured = false;
  final Map<AgentLanguage, bool> _available = {};

  Future<void> _configure() async {
    if (_configured) return;
    _configured = true;
    try {
      await _tts.setSpeechRate(0.48);
      await _tts.setPitch(1.0);
      await _tts.awaitSpeakCompletion(false);
    } catch (e) {
      debugPrint('TTS configure failed: $e');
    }
  }

  Future<bool> isAvailable(AgentLanguage lang) async {
    if (_available.containsKey(lang)) return _available[lang]!;
    try {
      final r = await _tts.isLanguageAvailable(lang.ttsLocale);
      _available[lang] = r == true || r == 1;
    } catch (_) {
      _available[lang] = false;
    }
    return _available[lang]!;
  }

  Future<void> speak(String text, AgentLanguage lang) async {
    if (!enabled || text.trim().isEmpty) return;
    await _configure();
    try {
      await _tts.stop();
      await _tts.setLanguage(lang.ttsLocale);
      await _tts.speak(text);
    } catch (e) {
      debugPrint('TTS failed: $e');
    }
  }

  /// Speaks [text] and returns when the voice has finished (or after a
  /// length-based timeout when the phone has no voice for the language), so
  /// the microphone never records the agent's own question.
  Future<void> speakAndWait(String text, AgentLanguage lang) async {
    if (!enabled || text.trim().isEmpty) return;
    await _configure();
    final cap = Duration(milliseconds: 1500 + 90 * text.length);
    try {
      await _tts.stop();
      await _tts.setLanguage(lang.ttsLocale);
      await _tts.awaitSpeakCompletion(true);
      await _tts.speak(text).timeout(cap > const Duration(seconds: 25) ? const Duration(seconds: 25) : cap);
    } catch (e) {
      debugPrint('TTS failed: $e');
    } finally {
      try {
        await _tts.awaitSpeakCompletion(false);
      } catch (_) {}
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
