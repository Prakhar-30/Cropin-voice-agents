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
  String note = '';
  List<String> unmapped = [];

  @override
  String toString() =>
      'AlertParseResult(type: $type, severity: $severity, crop: $crop, farmer: $farmerId, '
      'nearMe: $nearMe, unmapped: $unmapped)';
}

/// "Raise pest alert on the chilli plot here, high severity"
/// -> type Pest, severity High, crop Chilli, use GPS for the nearest plot.
class AlertParser {
  AlertParser({required this.farmers});
  final List<EntityRef> farmers;

  AlertParseResult parse(String text) {
    final u = Utterance(text);
    final r = AlertParseResult()..note = text.trim();

    final sev = PhraseMatcher.best(u, Lexicon.severity, minScore: 0.85);
    if (sev != null) r.severity = Slot(sev.value, sev.score, sev.spoken);

    final type = PhraseMatcher.best(u, Lexicon.alertType, minScore: 0.82);
    if (type != null) r.type = Slot(type.value, type.score, type.spoken);

    final crop = PhraseMatcher.best(u, Lexicon.crop);
    if (crop != null) r.crop = Slot(crop.value, crop.score, crop.spoken);

    r.nearMe = PhraseMatcher.consumeAll(u, {'here': Lexicon.here}, minScore: 0.9).isNotEmpty;

    final farmer = FormParser.matchFarmer(u, farmers);
    if (farmer != null) r.farmerId = farmer;

    PhraseMatcher.consumeAll(u, Lexicon.intent);
    PhraseMatcher.consumeAll(u, Lexicon.entity, minScore: 0.9);
    u.consumeFillers();
    r.unmapped = u.leftovers()
        .where((w) => !const {'severity', 'level', 'ತೀವ್ರತೆ', 'தீவிரம்', 'गंभीरता'}.contains(w))
        .toList();
    return r;
  }
}
