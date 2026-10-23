import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../voice/agent_language.dart';

enum ModelState { checking, missing, downloading, ready, failed }

class ModelFile {
  const ModelFile(this.name, this.bytes);
  final String name;
  final int bytes;
}

/// The app's own offline speech models (sherpa-onnx), downloaded once per
/// language from this repo's `speech-models-v1` release and kept in app
/// storage. Hindi, Kannada and Tamil are AI4Bharat IndicConformer (CTC, int8);
/// English is NeMo conformer-small; Silero VAD finds speech and pauses.
class SpeechModels extends ChangeNotifier {
  SpeechModels._();
  static final SpeechModels instance = SpeechModels._();

  static const baseUrl =
      'https://github.com/Prakhar-30/Cropin-voice-agents/releases/download/speech-models-v1';

  static const vad = ModelFile('silero_vad.onnx', 643854);
  static const _indicTokens = ModelFile('indic-tokens.txt', 67605);

  static ModelFile model(AgentLanguage l) => switch (l) {
        AgentLanguage.english => const ModelFile('en.int8.onnx', 46419854),
        AgentLanguage.hindi => const ModelFile('hi.int8.onnx', 197595593),
        AgentLanguage.kannada => const ModelFile('kn.int8.onnx', 197595728),
        AgentLanguage.tamil => const ModelFile('ta.int8.onnx', 197595513),
      };

  static ModelFile tokens(AgentLanguage l) =>
      l == AgentLanguage.english ? const ModelFile('en-tokens.txt', 11611) : _indicTokens;

  static List<ModelFile> filesFor(AgentLanguage l) => [model(l), tokens(l), vad];

  final Map<AgentLanguage, ModelState> state = {
    for (final l in AgentLanguage.values) l: ModelState.checking,
  };
  final Map<AgentLanguage, double> progress = {};
  final Map<AgentLanguage, String> error = {};

  Directory? _dir;

  Future<Directory> _folder() async {
    final d = _dir ??
        Directory('${(await getApplicationSupportDirectory()).path}/speech-models');
    if (!d.existsSync()) d.createSync(recursive: true);
    return _dir = d;
  }

  Future<String> pathOf(ModelFile f) async => '${(await _folder()).path}/${f.name}';

  bool isReady(AgentLanguage l) => state[l] == ModelState.ready;

  /// Download size still needed for [l], in MB.
  int sizeMb(AgentLanguage l) =>
      (filesFor(l).fold<int>(0, (s, f) => s + f.bytes) / (1024 * 1024)).round();

  bool _complete(Directory d, ModelFile f) {
    final file = File('${d.path}/${f.name}');
    return file.existsSync() && file.lengthSync() == f.bytes;
  }

  /// Checks which languages are already on the phone.
  Future<void> refresh() async {
    try {
      final d = await _folder();
      for (final l in AgentLanguage.values) {
        if (state[l] == ModelState.downloading) continue;
        state[l] = filesFor(l).every((f) => _complete(d, f)) ? ModelState.ready : ModelState.missing;
      }
    } catch (_) {
      for (final l in AgentLanguage.values) {
        if (state[l] == ModelState.checking) state[l] = ModelState.missing;
      }
    }
    notifyListeners();
  }

  /// Downloads everything [l] needs. Interrupted downloads resume.
  Future<bool> download(AgentLanguage l) async {
    if (state[l] == ModelState.downloading) return false;
    state[l] = ModelState.downloading;
    error.remove(l);
    progress[l] = 0;
    notifyListeners();
    try {
      final d = await _folder();
      final files = filesFor(l);
      final total = files.fold<int>(0, (s, f) => s + f.bytes);
      var done = 0;
      for (final f in files) {
        if (!_complete(d, f)) {
          await _fetch(d, f, (got) {
            final p = (done + got) / total;
            if (p - (progress[l] ?? 0) >= 0.005 || p >= 1) {
              progress[l] = p;
              notifyListeners();
            }
          });
        }
        done += f.bytes;
      }
      state[l] = ModelState.ready;
      progress[l] = 1;
      notifyListeners();
      return true;
    } catch (e) {
      state[l] = ModelState.failed;
      error[l] = e is SocketException || e is TimeoutException
          ? 'No internet connection. Connect to Wi-Fi and try again.'
          : 'Download failed: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> _fetch(Directory d, ModelFile f, void Function(int got) onBytes) async {
    final target = File('${d.path}/${f.name}');
    final part = File('${target.path}.part');
    var have = part.existsSync() ? part.lengthSync() : 0;
    if (have > f.bytes) {
      part.deleteSync();
      have = 0;
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
    try {
      final req = await client.getUrl(Uri.parse('$baseUrl/${f.name}'));
      if (have > 0) req.headers.set(HttpHeaders.rangeHeader, 'bytes=$have-');
      final res = await req.close();
      if (res.statusCode == HttpStatus.ok) {
        have = 0; // server sent the whole file
      } else if (res.statusCode != HttpStatus.partialContent) {
        throw HttpException('HTTP ${res.statusCode} for ${f.name}');
      }
      final sink = part.openWrite(mode: have > 0 ? FileMode.append : FileMode.write);
      try {
        await for (final chunk in res.timeout(const Duration(seconds: 30))) {
          sink.add(chunk);
          have += chunk.length;
          onBytes(have);
        }
      } finally {
        await sink.flush();
        await sink.close();
      }
      if (part.lengthSync() != f.bytes) {
        throw HttpException('${f.name} is incomplete (${part.lengthSync()} of ${f.bytes} bytes)');
      }
      part.renameSync(target.path);
    } finally {
      client.close(force: true);
    }
  }

  /// Frees space: removes [l]'s model (shared files stay).
  Future<void> delete(AgentLanguage l) async {
    final d = await _folder();
    for (final name in [model(l).name, '${model(l).name}.part']) {
      final f = File('${d.path}/$name');
      if (f.existsSync()) f.deleteSync();
    }
    state[l] = ModelState.missing;
    progress.remove(l);
    notifyListeners();
  }

  String label(AgentLanguage l) => switch (state[l]!) {
        ModelState.checking => 'Checking…',
        ModelState.missing => 'Not downloaded · ${sizeMb(l)} MB',
        ModelState.downloading => 'Downloading ${((progress[l] ?? 0) * 100).round()}% of ${sizeMb(l)} MB',
        ModelState.ready => 'Ready offline',
        ModelState.failed => error[l] ?? 'Download failed',
      };
}
