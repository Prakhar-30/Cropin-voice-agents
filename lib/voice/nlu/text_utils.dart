import 'dart:math' as math;

import 'transliterator.dart';

/// Text normalisation and fuzzy-matching helpers shared by all parsers.
class TextUtils {
  static const _nativeDigitBases = [0x0966, 0x0BE6, 0x0CE6]; // deva, tamil, kannada

  /// Converts Devanagari / Tamil / Kannada digits to ASCII digits.
  static String asciiDigits(String s) {
    final b = StringBuffer();
    for (final cp in s.runes) {
      var written = false;
      for (final base in _nativeDigitBases) {
        if (cp >= base && cp <= base + 9) {
          b.write(cp - base);
          written = true;
          break;
        }
      }
      if (!written) b.writeCharCode(cp);
    }
    return b.toString();
  }

  /// Lowercase, ASCII digits, punctuation turned into spaces (decimal points kept).
  static String normalize(String s) {
    var t = asciiDigits(s).toLowerCase();
    t = t.replaceAll(RegExp(r'(?<!\d)\.|\.(?!\d)'), ' ');
    t = t.replaceAll(RegExp(r'[,;:!?।॥|/()\[\]{}"“”‘’`~_*#@&=+\-]'), ' ');
    // separate numbers glued to words: "2acre" -> "2 acre", "15%" -> "15 %"
    t = t.replaceAllMapped(RegExp(r'(\d)([^\d\s.])'), (m) => '${m[1]} ${m[2]}');
    t = t.replaceAllMapped(RegExp(r'([a-z])(\d)'), (m) => '${m[1]} ${m[2]}');
    return t.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Phonetic key used for script-independent fuzzy comparison.
  ///
  /// Collapses aspiration, voicing (Tamil script doesn't mark it), vowel
  /// length and doubled letters so that "Chilli", "ಚಿಲ್ಲಿ" and "சில்லி"
  /// all reduce to the same key.
  static String phoneticKey(String s) {
    var t = Transliterator.toLatin(s.toLowerCase());
    t = t.replaceAll(RegExp(r'[^a-z0-9]'), '');
    const pairs = [
      ['chh', 's'], ['ch', 's'], ['sh', 's'], ['zh', 'l'], ['ph', 'p'],
      ['bh', 'p'], ['dh', 't'], ['th', 't'], ['kh', 'k'], ['gh', 'k'],
      ['jh', 's'], ['ck', 'k'], ['ow', 'o'], ['ou', 'o'], ['au', 'o'],
      ['aa', 'a'], ['ee', 'i'], ['ii', 'i'], ['oo', 'u'], ['uu', 'u'],
      ['ai', 'e'], ['ay', 'e'], ['ei', 'e'], ['ey', 'e'],
    ];
    for (final p in pairs) {
      t = t.replaceAll(p[0], p[1]);
    }
    const single = {
      'g': 'k', 'q': 'k', 'd': 't', 'b': 'p', 'f': 'p', 'j': 's', 'c': 's',
      'z': 's', 'w': 'v', 'x': 'ks', 'y': 'i',
    };
    final b = StringBuffer();
    for (final ch in t.split('')) {
      b.write(single[ch] ?? ch);
    }
    t = b.toString();
    // collapse doubled letters
    t = t.replaceAllMapped(RegExp(r'(.)\1+'), (m) => m[1]!);
    return t;
  }

  static int levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    var prev = List<int>.generate(b.length + 1, (i) => i);
    var cur = List<int>.filled(b.length + 1, 0);
    for (var i = 1; i <= a.length; i++) {
      cur[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        cur[j] = math.min(math.min(cur[j - 1] + 1, prev[j] + 1), prev[j - 1] + cost);
      }
      final tmp = prev;
      prev = cur;
      cur = tmp;
    }
    return prev[b.length];
  }

  static const _vowels = 'aeiou';
  static const _closePairs = {'rl', 'lr', 'nm', 'mn', 'vp', 'pv', 'ie', 'ei', 'uo', 'ou'};

  /// Phonetically weighted edit distance (after Raghuvanshi et al., "Entity
  /// resolution for noisy ASR transcripts", EMNLP 2019): recognisers and
  /// transliteration mostly confuse vowels and close consonants, and add or
  /// drop vowels (Tamil "டிரிப்" -> "tirip" for "drip"), so those edits are
  /// cheaper than an arbitrary consonant swap.
  static double weightedDistance(String a, String b) {
    if (a == b) return 0;
    double indel(int c) => _vowels.contains(String.fromCharCode(c)) ? 0.5 : 1.0;
    double sub(int x, int y) {
      if (x == y) return 0;
      final sx = String.fromCharCode(x), sy = String.fromCharCode(y);
      if (_vowels.contains(sx) && _vowels.contains(sy)) return 0.4;
      if (_closePairs.contains('$sx$sy')) return 0.5;
      return 1;
    }

    var prev = List<double>.filled(b.length + 1, 0);
    for (var j = 1; j <= b.length; j++) {
      prev[j] = prev[j - 1] + indel(b.codeUnitAt(j - 1));
    }
    for (var i = 1; i <= a.length; i++) {
      final cur = List<double>.filled(b.length + 1, 0);
      cur[0] = prev[0] + indel(a.codeUnitAt(i - 1));
      for (var j = 1; j <= b.length; j++) {
        cur[j] = math.min(
          math.min(cur[j - 1] + indel(b.codeUnitAt(j - 1)), prev[j] + indel(a.codeUnitAt(i - 1))),
          prev[j - 1] + sub(a.codeUnitAt(i - 1), b.codeUnitAt(j - 1)),
        );
      }
      prev = cur;
    }
    return prev[b.length];
  }

  /// 0..1 similarity between two phonetic keys (phonetically weighted).
  static double similarity(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0;
    if (a == b) return 1;
    final d = weightedDistance(a, b);
    return (1 - d / math.max(a.length, b.length)).clamp(0.0, 1.0);
  }
}
