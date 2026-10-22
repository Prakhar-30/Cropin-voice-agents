import 'lexicon.dart';
import 'text_utils.dart';
import 'transliterator.dart';

class Token {
  Token(this.raw)
      : key = TextUtils.phoneticKey(raw),
        isIndic = Transliterator.hasIndic(raw);

  final String raw;
  final String key;
  final bool isIndic;
  bool used = false;

  bool get isDigits => RegExp(r'^\d+$').hasMatch(raw);
  double? get numeric =>
      RegExp(r'^\d+(\.\d+)?$').hasMatch(raw) ? double.parse(raw) : Lexicon.numberWords[raw];

  @override
  String toString() => used ? '[$raw]' : raw;
}

/// A tokenised utterance that tracks which words have been consumed by a slot.
class Utterance {
  Utterance(this.original)
      : tokens = TextUtils.normalize(original)
            .split(' ')
            .where((t) => t.isNotEmpty)
            .map(Token.new)
            .toList();

  final String original;
  final List<Token> tokens;

  int get length => tokens.length;

  String textOf(int start, int len) =>
      tokens.sublist(start, start + len).map((t) => t.raw).join(' ');

  void consume(int start, int len) {
    for (var i = start; i < start + len; i++) {
      tokens[i].used = true;
    }
  }

  bool isFree(int start, int len) {
    for (var i = start; i < start + len; i++) {
      if (tokens[i].used) return false;
    }
    return true;
  }

  /// Unconsumed words that are not fillers, in order.
  List<String> leftovers() => tokens
      .where((t) => !t.used && !_fillerSet.contains(t.raw))
      .map((t) => t.raw)
      .toList();

  void consumeFillers() {
    for (final t in tokens) {
      if (_fillerSet.contains(t.raw)) t.used = true;
    }
  }

  static final Set<String> _fillerSet = Lexicon.fillers.toSet();
  static bool isFiller(String raw) => _fillerSet.contains(raw);
}

class PhraseMatch<T> {
  PhraseMatch(this.value, this.start, this.length, this.score, this.spoken);
  final T value;
  final int start;
  final int length;
  final double score;
  final String spoken;

  bool get confident => score >= 0.9;

  @override
  String toString() => 'PhraseMatch($value, "$spoken", ${score.toStringAsFixed(2)})';
}

class _Phrase {
  _Phrase(this.text)
      : words = TextUtils.normalize(text).split(' '),
        key = TextUtils.phoneticKey(TextUtils.normalize(text).replaceAll(' ', '')),
        isIndic = Transliterator.hasIndic(text);
  final String text;
  final List<String> words;
  final String key;
  final bool isIndic;
}

/// Fuzzy, script-independent phrase matcher.
class PhraseMatcher {
  /// Drops a trailing vowel sign / virama so suffixed forms still match.
  static String _stem(String word) {
    final r = word.runes.toList();
    if (r.length < 4) return word;
    final cp = r.last;
    final script = Transliterator.scriptOf(cp);
    if (script == null) return word;
    final base = switch (script) {
      IndicScript.devanagari => 0x0900,
      IndicScript.tamil => 0x0B80,
      IndicScript.kannada => 0x0C80,
    };
    final off = cp - base;
    if (off >= 0x3E && off <= 0x4D) return String.fromCharCodes(r.sublist(0, r.length - 1));
    return word;
  }

  /// Number of words in a lexicon phrase.
  static int wordCount(String phrase) => _phrase(phrase).words.length;

  static final Map<String, _Phrase> _cache = {};

  static _Phrase _phrase(String p) => _cache.putIfAbsent(p, () => _Phrase(p));

  /// Scores [phrase] against the window starting at [start] (0 when no match).
  static double scoreAt(Utterance u, String phrase, int start) {
    final p = _phrase(phrase);
    final n = p.words.length;
    if (start + n > u.length || !u.isFree(start, n)) return 0;
    final window = u.tokens.sublist(start, start + n);
    final windowRaw = window.map((t) => t.raw).join(' ');
    if (windowRaw == p.words.join(' ')) return 1.0;

    final windowIndic = window.any((t) => t.isIndic);
    // Agglutinative suffixes: "ಮೆಣಸಿನಕಾಯಿ" ~ "ಮೆಣಸು", "ಎಕರೆಯಲ್ಲಿ" ~ "ಎಕರೆ".
    if (windowIndic && p.isIndic) {
      var prefixOk = true;
      for (var i = 0; i < n - 1; i++) {
        if (window[i].raw != p.words[i]) prefixOk = false;
      }
      final last = p.words.last;
      if (prefixOk && last.runes.length >= 3 && window.last.raw.startsWith(last)) {
        return 0.92;
      }
      // Inflected stem: "ಜಮೀನು" -> "ಜಮೀನಿನಲ್ಲಿ", "வயல்" -> "வயலில்"
      final stem = _stem(last);
      if (prefixOk && stem.runes.length >= 3 && window.last.raw.startsWith(stem)) {
        return 0.9;
      }
      // same-script fuzzy only for long words (avoid कम ~ काम)
      if (p.key.length >= 5) {
        final s = TextUtils.similarity(window.map((t) => t.key).join(), p.key);
        return s >= 0.85 ? s : 0;
      }
      return 0;
    }

    final wKey = window.map((t) => t.key).join();
    if (wKey == p.key) return p.key.length <= 3 ? 0.95 : 1.0;
    // English plural: "acres", "plots"
    if (!windowIndic && wKey == '${p.key}s') return 0.93;
    if (p.key.length <= 3 || wKey.length <= 3) return 0;
    final s = TextUtils.similarity(wKey, p.key);
    // Short words need a near-exact sound match ("gowda" must not become "ಗೋಡು").
    final minLen = wKey.length < p.key.length ? wKey.length : p.key.length;
    if (s >= (minLen <= 5 ? 0.9 : 0.8) && !(minLen <= 5 && s < 1 && windowIndic != p.isIndic)) {
      return s;
    }
    // Transliterated word with a native suffix: "ಡ್ರಿಪ್ಪಿನ" ~ "drip"
    if (windowIndic && wKey.startsWith(p.key) && p.key.length >= 4) return 0.85;
    return 0;
  }

  /// All matches of every phrase of every value in [lexicon].
  static List<PhraseMatch<T>> findAll<T>(Utterance u, Map<T, List<String>> lexicon,
      {double minScore = 0.8}) {
    final out = <PhraseMatch<T>>[];
    lexicon.forEach((value, phrases) {
      for (final ph in phrases) {
        final n = _phrase(ph).words.length;
        for (var s = 0; s + n <= u.length; s++) {
          final score = scoreAt(u, ph, s);
          if (score >= minScore) {
            out.add(PhraseMatch(value, s, n, score, u.textOf(s, n)));
          }
        }
      }
    });
    // Prefer higher scores, with a bonus for covering more words
    // ("ಕೆಂಪು ಮಣ್ಣಿನ" as one soil phrase beats the bare "ಕೆಂಪು").
    double rank(PhraseMatch<T> m) => m.score + 0.1 * (m.length - 1);
    out.sort((a, b) {
      final c = rank(b).compareTo(rank(a));
      return c != 0 ? c : b.length.compareTo(a.length);
    });
    return out;
  }

  /// Best match; consumes its words when [consume] is true.
  static PhraseMatch<T>? best<T>(Utterance u, Map<T, List<String>> lexicon,
      {double minScore = 0.8, bool consume = true}) {
    final all = findAll(u, lexicon, minScore: minScore);
    if (all.isEmpty) return null;
    // Among top-scoring matches, prefer the longest phrase.
    final top = all.first;
    if (consume) u.consume(top.start, top.length);
    return top;
  }

  /// Last mention wins ("red soil… sorry, black soil" -> Black Soil). Every
  /// mention is consumed so corrected words don't show up as unmapped.
  static PhraseMatch<T>? latest<T>(Utterance u, Map<T, List<String>> lexicon,
      {double minScore = 0.8}) {
    final all = findAll(u, lexicon, minScore: minScore);
    if (all.isEmpty) return null;
    final top = all.first.score;
    // Only strong mentions count as (re)statements; weak fuzzy hits stay free.
    final taken = <PhraseMatch<T>>[];
    for (final m in all) {
      if (m.score >= top - 0.08 && u.isFree(m.start, m.length)) {
        u.consume(m.start, m.length);
        taken.add(m);
      }
    }
    taken.sort((a, b) => b.start.compareTo(a.start));
    return taken.first;
  }

  /// Consumes every match (used for markers / multiple mentions).
  static List<PhraseMatch<T>> consumeAll<T>(Utterance u, Map<T, List<String>> lexicon,
      {double minScore = 0.8}) {
    final taken = <PhraseMatch<T>>[];
    for (final m in findAll(u, lexicon, minScore: minScore)) {
      if (u.isFree(m.start, m.length)) {
        u.consume(m.start, m.length);
        taken.add(m);
      }
    }
    return taken;
  }

  static bool containsAny(Utterance u, List<String> phrases, {double minScore = 0.85}) {
    for (final ph in phrases) {
      final n = _phrase(ph).words.length;
      for (var s = 0; s + n <= u.length; s++) {
        if (scoreAt(u, ph, s) >= minScore) return true;
      }
    }
    return false;
  }
}
