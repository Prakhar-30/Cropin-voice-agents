import 'form_parser.dart';
import 'lexicon.dart';
import 'slots.dart';
import 'utterance.dart';

class AlertParseResult {
  Slot<String>? type;
  Slot<String>? severity;
  Slot<String>? crop;
  Slot<String>? farmerId;
  bool nearMe = false;

  /// "all chilli plots" -> select every matching plot, not just the nearest.
  bool selectAll = false;
  String? location;
  String note = '';
  List<String> unmapped = [];

  double get score =>
      (type?.confidence ?? 0) +
      (severity?.confidence ?? 0) +
      (crop?.confidence ?? 0) +
      (farmerId?.confidence ?? 0) +
      (nearMe ? 0.5 : 0) +
      (location != null ? 0.8 : 0) -
      0.4 * unmapped.length;

  @override
  String toString() =>
      'AlertParseResult(type: $type, severity: $severity, crop: $crop, farmer: $farmerId, '
      'nearMe: $nearMe, unmapped: $unmapped)';
}

/// "Raise pest alert on the chilli plot here, high severity"
/// -> type Pest, severity High, crop Chilli, use GPS for the nearest plot.
class AlertParser {
  AlertParser({required this.farmers, this.locations = const {}});
  final List<EntityRef> farmers;

  /// canonical locality -> spoken aliases
  final Map<String, List<String>> locations;

  AlertParseResult parse(String text) {
    final u = Utterance(text);
    final r = AlertParseResult()..note = text.trim();

    final sev = PhraseMatcher.latest(u, Lexicon.severity, minScore: 0.85);
    if (sev != null) r.severity = Slot(sev.value, sev.score, sev.spoken);

    final type = PhraseMatcher.latest(u, Lexicon.alertType, minScore: 0.82);
    if (type != null) r.type = Slot(type.value, type.score, type.spoken);

    final crop = PhraseMatcher.best(u, Lexicon.crop);
    if (crop != null) r.crop = Slot(crop.value, crop.score, crop.spoken);

    r.nearMe = PhraseMatcher.consumeAll(u, {'here': Lexicon.here}, minScore: 0.9).isNotEmpty;
    r.selectAll = PhraseMatcher.consumeAll(u, {'all': Lexicon.all}, minScore: 0.95).isNotEmpty;
    if (locations.isNotEmpty) {
      final loc = PhraseMatcher.best(u, locations, minScore: 0.85);
      if (loc != null) r.location = loc.value;
    }

    final farmer = FormParser.matchFarmer(u, farmers);
    if (farmer != null) r.farmerId = farmer;

    PhraseMatcher.consumeAll(u, Lexicon.intent);
    PhraseMatcher.consumeAll(u, Lexicon.entity, minScore: 0.9);
    u.consumeFillers();
    r.unmapped = u.leftovers()
        .where((w) => !const {
              'severity', 'level', 'ತೀವ್ರತೆ', 'தீவிரம்', 'गंभीरता', 'ನಲ್ಲಿ', 'ಗಳು', 'பகுதியில்',
            }.contains(w))
        .toList();
    return r;
  }
}
