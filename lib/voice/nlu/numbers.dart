import 'lexicon.dart';
import 'utterance.dart';

class AreaValue {
  AreaValue(this.value, this.unit, this.score, this.spoken);
  final double value;
  final String unit;
  final double score;
  final String spoken;
}

class PhoneValue {
  PhoneValue(this.digits, this.spoken);
  final String digits;
  final String spoken;

  /// Indian mobile numbers start with 6-9.
  bool get looksValid => RegExp(r'^[6-9]\d{9}$').hasMatch(digits);
}

/// Extracts phone numbers and areas from spoken digits / number words.
class NumberExtractor {
  static final Set<String> _double = Lexicon.doubleWords.toSet();
  static final Set<String> _triple = Lexicon.tripleWords.toSet();
  static const _andWords = {'and', 'और', 'ಮತ್ತು', 'மற்றும்', 'ಕಾಲು'};

  static String? _digitString(Token t) {
    if (t.isDigits) return t.raw;
    final v = Lexicon.numberWords[t.raw];
    if (v != null && v == v.roundToDouble() && v >= 0 && v <= 9) {
      return v.toInt().toString();
    }
    return null;
  }

  /// Finds a 10-digit mobile number, which may be spoken as groups
  /// ("98450 12345"), single digits, number words or "double 4".
  static PhoneValue? extractPhone(Utterance u) {
    final tokens = u.tokens;
    var i = 0;
    while (i < tokens.length) {
      // Build a run of digit-like tokens.
      final parts = <MapEntry<int, String>>[];
      var j = i;
      while (j < tokens.length && !tokens[j].used) {
        final t = tokens[j];
        final repeat = _double.contains(t.raw) ? 2 : (_triple.contains(t.raw) ? 3 : 0);
        if (repeat > 0 && j + 1 < tokens.length) {
          final d = _digitString(tokens[j + 1]);
          if (d != null && d.length == 1) {
            parts.add(MapEntry(j, ''));
            parts.add(MapEntry(j + 1, d * repeat));
            j += 2;
            continue;
          }
        }
        final d = _digitString(t);
        if (d == null) break;
        parts.add(MapEntry(j, d));
        j++;
      }
      final all = parts.map((e) => e.value).join();
      if (all.length >= 10) {
        var skip = 0;
        if (all.startsWith('91') && all.length >= 12) {
          skip = 2;
        } else if (all.startsWith('0') && all.length >= 11) {
          skip = 1;
        }
        final phone = all.substring(skip, skip + 10);
        // consume the tokens that contributed to those digits
        var offset = 0;
        final usedIdx = <int>[];
        for (final p in parts) {
          if (offset < skip + 10) usedIdx.add(p.key);
          offset += p.value.length;
        }
        final spoken = usedIdx.map((k) => tokens[k].raw).join(' ');
        for (final k in usedIdx) {
          tokens[k].used = true;
        }
        return PhoneValue(phone, spoken);
      }
      i = j == i ? i + 1 : j;
    }
    return null;
  }

  /// Number spoken immediately before token [idx]; handles "2.5", "two and half",
  /// "twenty five". Returns the value and the index of its first token.
  static MapEntry<double, int>? numberBefore(Utterance u, int idx) {
    final t = u.tokens;
    final k = idx - 1;
    if (k < 0 || t[k].used) return null;
    final v = t[k].numeric;
    if (v == null) return null;
    var value = v;
    var first = k;
    // "two and half"
    if (v == 0.5 && k - 2 >= 0 && _andWords.contains(t[k - 1].raw)) {
      final w = t[k - 2].numeric;
      if (w != null && !t[k - 2].used) {
        value = w + 0.5;
        first = k - 2;
      }
    } else if (v < 10 && k - 1 >= 0 && !t[k - 1].used) {
      // "twenty five"
      final tens = t[k - 1].numeric;
      if (tens != null && tens >= 20 && tens < 100 && tens % 10 == 0) {
        value = tens + v;
        first = k - 1;
      }
    }
    return MapEntry(value, first);
  }

  /// Declared area: number + unit ("2 acres", "ಎರಡು ಎಕರೆ", "இரண்டரை ஏக்கர்").
  static AreaValue? extractArea(Utterance u) {
    final units = PhraseMatcher.findAll(u, Lexicon.areaUnit, minScore: 0.85);
    for (final m in units) {
      if (!u.isFree(m.start, m.length)) continue;
      final before = numberBefore(u, m.start);
      if (before != null) {
        final spoken = u.textOf(before.value, m.start + m.length - before.value);
        u.consume(before.value, m.start + m.length - before.value);
        return AreaValue(before.key, m.value, m.score, spoken);
      }
      // "acre 2" (less common)
      final after = m.start + m.length;
      if (after < u.length && !u.tokens[after].used) {
        final v = u.tokens[after].numeric;
        if (v != null) {
          final spoken = u.textOf(m.start, m.length + 1);
          u.consume(m.start, m.length + 1);
          return AreaValue(v, m.value, m.score * 0.95, spoken);
        }
      }
    }
    return null;
  }
}
