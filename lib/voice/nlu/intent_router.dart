import 'lexicon.dart';
import 'numbers.dart';
import 'utterance.dart';

enum AgentIntent { addFarmer, addAsset, assignPlot, raiseAlert, takePhoto, briefing, search, unknown }

/// Routes a free-form utterance from the home-screen mic to one of the agents.
class IntentRouter {
  static const _addWords = [
    'add', 'new', 'create', 'register', 'enroll', 'onboard', 'जोड़ो', 'जोड़ें', 'जोड़', 'नया',
    'नए', 'ऐड', 'एड', 'रजिस्टर', 'ಸೇರಿಸಿ', 'ಸೇರಿಸು', 'ಹೊಸ', 'ಆಡ್', 'ರಿಜಿಸ್ಟರ್', 'சேர்',
    'சேர்க்கவும்', 'புதிய', 'ஆட்', 'ரிஜிஸ்டர்',
  ];

  static double _score(Utterance u, List<String> phrases) {
    var best = 0.0;
    for (final ph in phrases) {
      final n = PhraseMatcher.wordCount(ph);
      for (var s = 0; s + n <= u.length; s++) {
        final v = PhraseMatcher.scoreAt(u, ph, s);
        if (v > best) best = v;
      }
    }
    return best;
  }

  static AgentIntent detect(String text) {
    final u = Utterance(text);
    if (u.length == 0) return AgentIntent.unknown;
    double s(String intent) => _score(u, Lexicon.intent[intent]!);

    final add = _score(u, _addWords) >= 0.9;
    final farmerWord = _score(u, Lexicon.entity['farmers']!) >= 0.9;
    final plotWord = _score(u, Lexicon.entity['assets']!) >= 0.9;

    // Dictating a farmer's details ("farmer Ramesh Kumar, his mobile number
    // is …, paddy project, plot area 7 acres") is Add Farmer even when plot
    // words appear — unless the user explicitly asked to show / search.
    final searchVerb = s('search') >= 0.9;

    final alertWord = s('raise_alert') >= 0.9;
    final alertType = _score(u, Lexicon.alertType.values.expand((e) => e).toList()) >= 0.85;
    final severity = _score(u, Lexicon.severity.values.expand((e) => e).toList()) >= 0.9;
    final alertLike = alertWord || (alertType && severity);

    // "Assign plot CA-1 to Sunita Devi" / "… Sunita Devi ko assign karo"
    if (!alertLike && s('assign') >= 0.9 && (farmerWord || plotWord || _mentionsFarmer(u))) {
      return AgentIntent.assignPlot;
    }
    final labels = _score(u, Lexicon.farmerLabels) >= 0.9;
    final phone = NumberExtractor.extractPhone(Utterance(text)) != null;
    if (s('add_farmer') >= 0.9 ||
        (add && farmerWord && !plotWord) ||
        (!searchVerb && (phone || (labels && (farmerWord || add))))) {
      return AgentIntent.addFarmer;
    }
    if (s('add_asset') >= 0.9 || (add && plotWord)) return AgentIntent.addAsset;

    if (alertLike) return AgentIntent.raiseAlert;

    // "add Ramesh Kumar to the paddy project": adding without a plot word is a farmer.
    if (add && !plotWord && !searchVerb) return AgentIntent.addFarmer;

    if (s('take_photo') >= 0.9) return AgentIntent.takePhoto;

    // Questions about tasks with a specific status ("which tasks are done",
    // "overdue visits", "upcoming work") are a task search; plain "what's
    // pending today" stays the spoken daily briefing.
    final taskWord = _score(u, Lexicon.entity['tasks']!) >= 0.9;
    final status = Lexicon.taskStatus;
    final specificStatus = _score(u, [
          ...status['completed']!,
          ...status['overdue']!,
          ...status['upcoming']!,
        ]) >=
        0.9;
    if (taskWord && (specificStatus || searchVerb)) return AgentIntent.search;

    if (searchVerb) return AgentIntent.search;
    if (s('briefing') >= 0.9) return AgentIntent.briefing;
    if (taskWord) return AgentIntent.search;

    final crop = _score(u, Lexicon.crop.values.expand((e) => e).toList()) >= 0.9;
    final hasArea = NumberExtractor.extractArea(Utterance(text)) != null;
    final hasPhone = NumberExtractor.extractPhone(Utterance(text)) != null;
    final formSlots = _score(u, Lexicon.soil.values.expand((e) => e).toList()) >= 0.9 ||
        _score(u, Lexicon.irrigation.values.expand((e) => e).toList()) >= 0.9;
    if (hasPhone) return AgentIntent.addFarmer;
    if (formSlots) return AgentIntent.addAsset;
    if (farmerWord || plotWord || crop || hasArea) return AgentIntent.search;
    if (alertType) return AgentIntent.raiseAlert;
    return AgentIntent.unknown;
  }

  static bool _mentionsFarmer(Utterance u) => u.tokens.any((t) => t.raw.length > 2) &&
      knownFarmerNames.any((n) => _score(u, [n]) >= 0.85);

  /// Farmer names known to the app (kept up to date by the store), so
  /// "assign … to Sunita Devi" is recognised even without the word "farmer".
  static List<String> knownFarmerNames = const [];
}
