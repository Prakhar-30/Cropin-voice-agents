import 'form_parser.dart';
import 'lexicon.dart';
import 'numbers.dart';
import 'slots.dart';
import 'utterance.dart';

enum SearchEntity { farmers, assets, tasks }

class SearchQuery {
  SearchEntity? entity;
  String? crop;
  double? area;
  String? areaUnit;

  /// 'eq', 'gt' or 'lt'
  String comparator = 'eq';
  String? location;
  String? health; // 'attention' | 'good'
  String? taskStatus; // 'overdue' | 'today' | 'pending' | 'completed'
  String? farmerId;
  String? farmerName;

  /// Plot code such as "ca1" (from "CA-1" / "CA 1"), matched against names.
  String? code;
  List<String> unmapped = [];
  String heard = '';

  bool get hasFilters =>
      code != null ||
      crop != null ||
      area != null ||
      location != null ||
      health != null ||
      taskStatus != null ||
      farmerId != null;

  double get score => describe().length + (entity != null ? 0.3 : 0) - 0.4 * unmapped.length;

  /// Human-readable filter chips.
  List<String> describe() => [
        if (code != null) 'Plot code ${code!.toUpperCase()}',
        if (crop != null) crop!,
        if (area != null)
          '${comparator == 'gt' ? '> ' : comparator == 'lt' ? '< ' : ''}'
              '${_fmt(area!)} ${areaUnit ?? 'acre'}',
        if (location != null) location!,
        if (health == 'attention') 'Needs attention',
        if (health == 'good') 'Healthy',
        if (taskStatus != null) taskStatus![0].toUpperCase() + taskStatus!.substring(1),
        if (farmerName != null) farmerName!,
      ];

  static String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  String toString() => 'SearchQuery($entity, ${describe()}, unmapped: $unmapped)';
}

/// "Show my 2-acre chilli plots in BTM that need attention"
class SearchParser {
  SearchParser({required this.farmers, required this.locations});

  final List<EntityRef> farmers;

  /// canonical locality -> spoken aliases
  final Map<String, List<String>> locations;

  SearchQuery parse(String text, {SearchEntity? defaultEntity}) {
    final u = Utterance(text);
    final q = SearchQuery()..heard = text.trim();

    // Plot codes: "CA-1" / "CA 1" / "ca1" -> "ca1"
    for (var i = 0; i < u.length; i++) {
      final t = u.tokens[i];
      final m = RegExp(r'^([a-z]{1,4})(\d{1,3})$').firstMatch(t.raw);
      if (m != null && !Utterance.isFiller(t.raw)) {
        q.code = t.raw;
        t.used = true;
        break;
      }
      if (RegExp(r'^[a-z]{2,4}$').hasMatch(t.raw) && !Utterance.isFiller(t.raw) &&
          i + 1 < u.length && RegExp(r'^\d{1,3}$').hasMatch(u.tokens[i + 1].raw) &&
          !(i + 2 < u.length && Lexicon.areaUnit.values.any((v) => v.contains(u.tokens[i + 2].raw)))) {
        final words = {'ca', 'pa', 'cp', 'plot', 'plt', 'ast', 'asset', 'mh', 'ms', 'sk', 'sd'};
        const notCodes = {'me', 'top', 'first', 'last', 'only', 'about', 'than', 'over', 'get'};
        if (!notCodes.contains(t.raw) && (words.contains(t.raw) || t.raw.length <= 3)) {
          q.code = '${t.raw}${u.tokens[i + 1].raw}';
          t.used = true;
          u.tokens[i + 1].used = true;
          break;
        }
      }
    }
    if (q.code != null) q.entity ??= SearchEntity.assets;

    final cmp = PhraseMatcher.best(u, Lexicon.comparator, minScore: 0.9);
    if (cmp != null) q.comparator = cmp.value;

    final area = NumberExtractor.extractArea(u);
    if (area != null) {
      q.area = area.value;
      q.areaUnit = area.unit;
    }

    final crop = PhraseMatcher.best(u, Lexicon.crop);
    if (crop != null) q.crop = crop.value;

    final health = PhraseMatcher.best(u, Lexicon.healthStatus, minScore: 0.85);
    if (health != null) q.health = health.value;

    final loc = PhraseMatcher.best(u, locations, minScore: 0.88);
    if (loc != null) q.location = loc.value;

    final ent = PhraseMatcher.best(u, Lexicon.entity, minScore: 0.85);
    q.entity = ent != null
        ? SearchEntity.values.byName(ent.value)
        : defaultEntity;

    final status = PhraseMatcher.best(u, Lexicon.taskStatus, minScore: 0.85);
    if (status != null) {
      q.taskStatus = status.value;
      // "what's pending today" is about tasks unless something else was named
      q.entity ??= SearchEntity.tasks;
    }

    final farmer = FormParser.matchFarmer(u, farmers);
    if (farmer != null) {
      q.farmerId = farmer.value;
      q.farmerName = farmers.firstWhere((f) => f.id == farmer.value).name;
    }

    // Plots are implied by crop / area / health filters.
    if (q.entity == null &&
        (q.crop != null || q.area != null || q.health != null || q.location != null)) {
      q.entity = SearchEntity.assets;
    }

    PhraseMatcher.consumeAll(u, Lexicon.intent);
    u.consumeFillers();
    q.unmapped = u.leftovers()
        .where((w) => !const {
              'that', 'which', 'need', 'needs', 'all', 'me', 'show', 'only', 'are', 'there',
              'जो', 'जिन', 'जिनमें', 'देना', 'वाले', 'सभी', 'ಎಲ್ಲಾ', 'ಇರುವ', 'ಬೇಕಾದ', 'ನಲ್ಲಿ',
              'ಅಗತ್ಯ', 'எல்லா', 'உள்ள', 'தேவையான', 'பகுதியில்', 'my',
            }.contains(w))
        .toList();
    return q;
  }
}
