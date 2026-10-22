import 'lexicon.dart';
import 'numbers.dart';
import 'slots.dart';
import 'transliterator.dart';
import 'utterance.dart';

class FormParseResult {
  Slot<String>? name;
  Slot<String>? phone;
  Slot<String>? projectId;
  Slot<String>? soil;
  Slot<String>? irrigation;
  Slot<double>? area;
  Slot<String>? areaUnit;
  Slot<String>? crop;
  Slot<String>? season;
  Slot<String>? ownerId;
  List<String> unmapped = [];

  List<Slot<Object>> get _all => [
        if (name != null) name!,
        if (phone != null) phone!,
        if (projectId != null) projectId!,
        if (soil != null) soil!,
        if (irrigation != null) irrigation!,
        if (area != null) area!,
        if (areaUnit != null) areaUnit!,
        if (crop != null) crop!,
        if (ownerId != null) ownerId!,
      ];

  int get filledCount => _all.length;

  /// Used to rank recogniser hypotheses: confident slots up, unknown words down.
  double get score =>
      _all.fold<double>(0, (s, slot) => s + slot.confidence) - 0.4 * unmapped.length;
  int get needsCheckCount => _all.where((s) => s.needsCheck).length;
  bool get isEmpty => filledCount == 0;

  /// True when the utterance also described a plot (used to offer "create plot").
  bool get hasAssetDetails => soil != null || irrigation != null || area != null;

  @override
  String toString() =>
      'FormParseResult(name: $name, phone: $phone, project: $projectId, soil: $soil, '
      'irrigation: $irrigation, area: $area $areaUnit, crop: $crop, owner: $ownerId, '
      'unmapped: $unmapped)';
}

/// Speak-to-fill parser for Add Farmer / Add Asset (and generic task forms).
///
/// "Ramesh Gowda, 98450 12345, project Kharif Chilli, red soil, drip
/// irrigation, 2 acres" -> name, mobile, project, soil, irrigation, area.
class FormParser {
  FormParser({required this.projects, required this.farmers});

  final List<ProjectRef> projects;
  final List<EntityRef> farmers;

  static const _extraFillers = {
    'from', 'village', 'gaon', 'गांव', 'गाँव', 'ಊರು', 'ಗ್ರಾಮ', 'கிராமம்', 'ஊர்',
    'seed', 'programme', 'program', 'season',
  };

  FormParseResult parse(String text, {bool extractName = true, bool extractOwner = false}) {
    final u = Utterance(text);
    final r = FormParseResult();

    // 1. Mobile number
    final phone = NumberExtractor.extractPhone(u);
    if (phone != null) {
      r.phone = Slot(phone.digits, phone.looksValid ? 0.97 : 0.7, phone.spoken);
    }

    // 2. Declared area + unit
    final area = NumberExtractor.extractArea(u);
    if (area != null) {
      r.area = Slot(area.value, area.score >= 0.9 ? 0.95 : 0.8, area.spoken);
      r.areaUnit = Slot(area.unit, area.score, area.spoken);
    }

    // 3. Soil & irrigation dropdowns (fuzzy, multilingual)
    final soil = PhraseMatcher.latest(u, Lexicon.soil);
    if (soil != null) r.soil = Slot(soil.value, soil.score, soil.spoken);
    final irr = PhraseMatcher.latest(u, Lexicon.irrigation);
    if (irr != null) r.irrigation = Slot(irr.value, irr.score, irr.spoken);

    // 4. Project: direct name match first, then crop + season.
    for (final m in PhraseMatcher.findAll(u, {'project': Lexicon.projectMarkers})) {
      u.consume(m.start, m.length);
    }
    final projectLex = {
      for (final p in projects)
        p.id: [p.name, p.name.replaceAll(RegExp(r'\d'), '').trim(), ...p.aliases],
    };
    final direct = PhraseMatcher.latest(u, projectLex, minScore: 0.85);
    final crop = PhraseMatcher.latest(u, Lexicon.crop);
    final season = PhraseMatcher.latest(u, Lexicon.season);
    if (crop != null) r.crop = Slot(crop.value, crop.score, crop.spoken);
    if (season != null) r.season = Slot(season.value, season.score, season.spoken);

    if (direct != null) {
      r.projectId = Slot(direct.value, direct.score, direct.spoken);
      r.crop ??= Slot(projects.firstWhere((p) => p.id == direct.value).crop, 0.9, direct.spoken);
    } else if (crop != null) {
      var candidates = projects.where((p) => p.crop == crop.value).toList();
      if (season != null) {
        final bySeason = candidates.where((p) => p.season == season.value).toList();
        if (bySeason.isNotEmpty) candidates = bySeason;
      }
      if (candidates.isNotEmpty) {
        final sure = candidates.length == 1 && crop.confident;
        final heard = [season?.spoken, crop.spoken].whereType<String>().join(' ');
        r.projectId = Slot(candidates.first.id, sure ? 0.93 : 0.75, heard);
      }
    }

    // 5. Owner ("Belongs To") — fuzzy match against existing farmers.
    if (extractOwner) {
      final owner = matchFarmer(u, farmers);
      if (owner != null) r.ownerId = owner;
    }

    // 6. Intent words such as "add farmer" / "ಹೊಸ ರೈತ" are not part of the name.
    PhraseMatcher.consumeAll(u, Lexicon.intent);
    PhraseMatcher.consumeAll(u, Lexicon.entity, minScore: 0.9);

    // 7. Person name
    if (extractName) r.name = _extractName(u);

    u.consumeFillers();
    r.unmapped = u.leftovers().where((w) => !_extraFillers.contains(w)).toList();
    return r;
  }

  /// Fuzzy match a farmer by full name, or by first name when it is unique.
  static Slot<String>? matchFarmer(Utterance u, List<EntityRef> farmers,
      {double minScore = 0.78}) {
    final firstNames = <String, int>{};
    for (final f in farmers) {
      final first = f.name.split(' ').first.toLowerCase();
      firstNames[first] = (firstNames[first] ?? 0) + 1;
    }
    final full = {
      for (final f in farmers) f.id: [f.name, ...f.aliases],
    };
    final m = PhraseMatcher.best(u, full, minScore: minScore);
    if (m != null && m.length > 1) return Slot(m.value, m.score, m.spoken);
    if (m != null) {
      // single-word match: only accept when the farmer's name is one word
      final f = farmers.firstWhere((f) => f.id == m.value);
      if (!f.name.contains(' ')) return Slot(m.value, m.score, m.spoken);
      u.tokens[m.start].used = false;
    }
    final firsts = {
      for (final f in farmers)
        if (firstNames[f.name.split(' ').first.toLowerCase()] == 1)
          f.id: [f.name.split(' ').first],
    };
    final fm = PhraseMatcher.best(u, firsts, minScore: 0.85);
    if (fm != null) return Slot(fm.value, fm.score * 0.85, fm.spoken);
    return null;
  }

  static bool _nameCandidate(Token t) =>
      !t.used &&
      !Utterance.isFiller(t.raw) &&
      !_extraFillers.contains(t.raw) &&
      t.numeric == null &&
      !RegExp(r'\d').hasMatch(t.raw) &&
      t.raw.length > 1;

  static Slot<String>? _extractName(Utterance u) {
    final markers = Lexicon.nameMarkers.toSet();
    final toks = u.tokens;
    // "name is Ramesh Gowda", "ಹೆಸರು ರಮೇಶ್ ಗೌಡ", "பெயர் ரமேஷ்"
    for (var i = 0; i < toks.length; i++) {
      if (toks[i].used || !markers.contains(toks[i].raw)) continue;
      toks[i].used = true;
      var j = i + 1;
      while (j < toks.length && !toks[j].used && Utterance.isFiller(toks[j].raw)) {
        toks[j].used = true;
        j++;
      }
      final run = _runFrom(u, j);
      if (run.isNotEmpty) return _nameSlot(u, run, marker: true);
      // SOV order: "ರಮೇಶ್ ಗೌಡ ಅವರ ಹೆಸರು"
      var k = i - 1;
      while (k >= 0 && !toks[k].used && Utterance.isFiller(toks[k].raw)) {
        k--;
      }
      final back = <int>[];
      while (k >= 0 && back.length < 3 && _nameCandidate(toks[k])) {
        back.insert(0, k);
        k--;
      }
      if (back.isNotEmpty) return _nameSlot(u, back, marker: true);
    }
    // Fallback: first run of free words ("Ramesh Gowda, 98450…").
    for (var i = 0; i < toks.length; i++) {
      if (_nameCandidate(toks[i])) {
        final run = _runFrom(u, i);
        if (run.isNotEmpty) return _nameSlot(u, run, marker: false);
      }
    }
    return null;
  }

  static List<int> _runFrom(Utterance u, int start) {
    final run = <int>[];
    var j = start;
    while (j < u.length && run.length < 3 && _nameCandidate(u.tokens[j])) {
      run.add(j);
      j++;
    }
    return run;
  }

  static Slot<String> _nameSlot(Utterance u, List<int> idx, {required bool marker}) {
    final spoken = idx.map((i) => u.tokens[i].raw).join(' ');
    for (final i in idx) {
      u.tokens[i].used = true;
    }
    final indic = Transliterator.hasIndic(spoken);
    final display = indic
        ? Transliterator.toDisplayName(spoken)
        : spoken.split(' ').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
    final conf = marker ? (indic ? 0.85 : 0.95) : (indic ? 0.8 : 0.88);
    return Slot(display, conf, spoken);
  }
}
