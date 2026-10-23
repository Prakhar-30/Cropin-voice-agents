import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../voice/agent_language.dart';

/// What Android's on-device recogniser reports for the phone.
class SpeechPackStatus {
  SpeechPackStatus(Map<Object?, Object?> m)
      : sdk = (m['sdk'] as int?) ?? 0,
        onDeviceAvailable = m['onDeviceAvailable'] == true,
        installed = _list(m['installed']),
        pending = _list(m['pending']),
        supported = _list(m['supported']),
        online = _list(m['online']),
        checked = m.containsKey('installed');

  final int sdk;
  final bool onDeviceAvailable;
  final List<String> installed;
  final List<String> pending;
  final List<String> supported;
  final List<String> online;

  /// False when the phone couldn't tell us (Android < 13 or service error).
  final bool checked;

  static List<String> _list(Object? v) =>
      v is List ? v.map((e) => '$e'.toLowerCase().replaceAll('_', '-')).toList() : const [];

  static bool _has(List<String> list, AgentLanguage l) =>
      list.any((x) => x == l.ttsLocale.toLowerCase() || x == l.code || x.startsWith('${l.code}-'));

  bool isInstalled(AgentLanguage l) => _has(installed, l);
  bool isPending(AgentLanguage l) => _has(pending, l);
  bool isSupported(AgentLanguage l) => _has(supported, l) || _has(installed, l) || _has(pending, l);
}

enum PackState { unknown, installed, downloading, scheduled, notInstalled, unsupported, error }

/// Downloads Android's on-device speech models from inside the app (no trip to
/// system settings): `SpeechRecognizer.checkRecognitionSupport` +
/// `triggerModelDownload` via the native channel in MainActivity.kt.
class SpeechPackService extends ChangeNotifier {
  SpeechPackService._() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'progress') {
        final args = Map<Object?, Object?>.from(call.arguments as Map);
        final l = _langFor('${args['locale']}');
        if (l != null) {
          progress[l] = (args['percent'] as int?) ?? 0;
          state[l] = progress[l]! >= 100 ? PackState.installed : PackState.downloading;
          notifyListeners();
        }
      }
    });
  }
  static final SpeechPackService instance = SpeechPackService._();

  static const _channel = MethodChannel('cropin/speech_packs');

  final Map<AgentLanguage, PackState> state = {};
  final Map<AgentLanguage, int> progress = {};
  SpeechPackStatus? last;

  static AgentLanguage? _langFor(String locale) {
    for (final l in AgentLanguage.values) {
      if (locale.toLowerCase().startsWith(l.code)) return l;
    }
    return null;
  }

  /// Queries the phone; null when not on Android or the channel is missing.
  Future<SpeechPackStatus?> status(AgentLanguage l) async {
    try {
      final m = await _channel.invokeMethod<Map<Object?, Object?>>('status', {'locale': l.ttsLocale});
      if (m == null) return null;
      final s = SpeechPackStatus(m);
      last = s;
      if (s.checked) {
        for (final lang in AgentLanguage.values) {
          if (state[lang] == PackState.downloading && !s.isInstalled(lang)) continue;
          state[lang] = s.isInstalled(lang)
              ? PackState.installed
              : s.isPending(lang)
                  ? PackState.downloading
                  : s.isSupported(lang)
                      ? PackState.notInstalled
                      : PackState.unsupported;
        }
        notifyListeners();
      }
      return s;
    } on MissingPluginException {
      return null;
    } catch (e) {
      debugPrint('speech pack status failed: $e');
      return null;
    }
  }

  /// Starts downloading the on-device model for [l]. Safe to call repeatedly.
  Future<PackState> download(AgentLanguage l) async {
    if (state[l] == PackState.downloading || state[l] == PackState.installed) return state[l]!;
    state[l] = PackState.downloading;
    progress[l] = progress[l] ?? 0;
    notifyListeners();
    try {
      final r = await _channel.invokeMethod<String>('download', {'locale': l.ttsLocale}) ?? '';
      state[l] = switch (r) {
        'success' => PackState.installed,
        'scheduled' => PackState.scheduled,
        'triggered' => PackState.downloading,
        'unsupported' => PackState.unsupported,
        _ => PackState.error,
      };
    } on MissingPluginException {
      state[l] = PackState.unsupported;
    } catch (e) {
      debugPrint('speech pack download failed: $e');
      state[l] = PackState.error;
    }
    notifyListeners();
    return state[l]!;
  }

  String label(AgentLanguage l) {
    final p = progress[l];
    return switch (state[l] ?? PackState.unknown) {
      PackState.installed => 'Offline pack installed',
      PackState.downloading => p == null || p == 0 ? 'Downloading offline pack…' : 'Downloading offline pack $p%',
      PackState.scheduled => 'Download scheduled (waits for Wi-Fi)',
      PackState.notInstalled => 'Offline pack not installed',
      PackState.unsupported => 'No on-device model on this phone',
      PackState.error => 'Download failed — tap to retry',
      PackState.unknown => 'Checking…',
    };
  }
}
