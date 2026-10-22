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

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
