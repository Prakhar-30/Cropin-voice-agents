import 'form_parser.dart';
import 'lexicon.dart';
import 'search_parser.dart';
import 'slots.dart';
import 'utterance.dart';

class AssignParseResult {
  /// Farmer the plot(s) should go to.
  String? toFarmerId;

  /// Current owner, when the speaker names one ("Mahesh's potato plot").
  String? fromFarmerId;
  String? code;
  String? crop;
  String? location;
  bool all = false;
  List<String> unmapped = [];

  double get score =>
      (toFarmerId != null ? 1.5 : 0) +
      (code != null ? 1 : 0) +
      (crop != null ? 0.8 : 0) +
      (location != null ? 0.6 : 0) +
      (fromFarmerId != null ? 0.6 : 0) -
      0.4 * unmapped.length;
}

/// "Assign plot MH01 CA-1 to Sunita Devi", "Mahesh ka aloo plot Sunita Devi ko
/// assign karo", "ಮಹೇಶ್ ಅವರ ಆಲೂಗಡ್ಡೆ ಜಮೀನನ್ನು ಸುನೀತಾ ದೇವಿಗೆ ನಿಯೋಜಿಸಿ".
class AssignParser {
  AssignParser({required this.farmers, this.locations = const {}});
  final List<EntityRef> farmers;
  final Map<String, List<String>> locations;

  /// Words marking the receiving farmer: English "to" before the name,
  /// Hindi "को"/"ko" after it, Kannada "-ಗೆ"/"-ಗೆ", Tamil "-க்கு" suffixes.
  static const _toBefore = {'to', 'for', 'towards'};
  static const _toAfter = {'को', 'ko'};
  static const _toSuffixes = ['ಗೆ', 'ಿಗೆ', 'ಕ್ಕೆ', 'க்கு', 'ுக்கு'];

  AssignParseResult parse(String text) {
    final u = Utterance(text);
    final r = AssignParseResult();

    r.code = SearchParser.extractCode(u);
    final crop = PhraseMatcher.latest(u, Lexicon.crop);
    r.crop = crop?.value;
    if (locations.isNotEmpty) r.location = PhraseMatcher.best(u, locations, minScore: 0.88)?.value;
    r.all = PhraseMatcher.consumeAll(u, {'all': Lexicon.all}, minScore: 0.95).isNotEmpty;

    // Up to two farmers, remembering where each was said.
    final found = <(String, int, int)>[]; // id, first token, last token
    for (var k = 0; k < 2; k++) {
      final before = u.tokens.map((t) => t.used).toList();
      final m = FormParser.matchFarmer(u, farmers, minScore: 0.8);
      if (m == null) break;
      final idx = [
        for (var i = 0; i < u.length; i++)
          if (u.tokens[i].used && !before[i]) i,
      ];
      if (idx.isEmpty) break;
      found.add((m.value, idx.first, idx.last));
    }

    bool isTarget((String, int, int) f) {
      final (_, a, b) = f;
      if (a > 0 && _toBefore.contains(u.tokens[a - 1].raw)) return true;
      if (b + 1 < u.length && _toAfter.contains(u.tokens[b + 1].raw)) return true;
      return _toSuffixes.any((s) => u.tokens[b].raw.endsWith(s));
    }

    if (found.length == 1) {
      r.toFarmerId = found.first.$1;
    } else if (found.length == 2) {
      final target = found.firstWhere(isTarget, orElse: () => found.last);
      r.toFarmerId = target.$1;
      r.fromFarmerId = found.firstWhere((f) => f != target).$1;
    }

    PhraseMatcher.consumeAll(u, Lexicon.intent);
    PhraseMatcher.consumeAll(u, Lexicon.entity, minScore: 0.9);
    u.consumeFillers();
    r.unmapped = u.leftovers()
        .where((w) => !_toBefore.contains(w) && !_toAfter.contains(w))
        .where((w) => !const {
              'karo', 'kar', 'do', 'करो', 'कर', 'दो', 'का', 'की', 'ಮಾಡಿ', 'ಅವರ', 'ಅವರಿಗೆ', 'செய்',
              'செய்யவும்', 'அவரது', 'அவருக்கு', 'ಜಮೀನನ್ನು', 'நிலத்தை', 'plot', 'plots',
            }.contains(w))
        .toList();
    return r;
  }
}
