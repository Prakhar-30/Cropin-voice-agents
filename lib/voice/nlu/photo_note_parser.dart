import 'lexicon.dart';
import 'utterance.dart';

/// Pulls quick tags out of a spoken photo note:
/// "Leaf curl on lower canopy, maybe 15% plants, near the bore well"
/// -> [Disease, 15% plants, Borewell].
class PhotoNoteParser {
  static const _percentWords = [
    'percent', 'per cent', 'प्रतिशत', 'फीसदी', 'ಶೇಕಡಾ', 'ಶೇ', 'பர்சென்ட்', 'சதவீதம்',
  ];

  static List<String> tags(String note) {
    final out = <String>[];
    final u = Utterance(note);
    final type = PhraseMatcher.best(u, Lexicon.alertType, minScore: 0.85);
    if (type != null) out.add(type.value);
    final crop = PhraseMatcher.best(u, Lexicon.crop);
    if (crop != null) out.add(crop.value);
    for (var i = 0; i < u.length; i++) {
      final v = u.tokens[i].numeric;
      if (v == null || i + 1 >= u.length) continue;
      final next = u.tokens[i + 1].raw;
      if (next == '%' || _percentWords.contains(next)) {
        out.add('${v == v.roundToDouble() ? v.toInt() : v}% affected');
        break;
      }
    }
    final landmark = PhraseMatcher.best(u, {
      'Near borewell': Lexicon.irrigation['Borewell']!,
      'Near canal': Lexicon.irrigation['Canal']!,
    }, minScore: 0.85);
    if (landmark != null) out.add(landmark.value);
    return out;
  }
}
