/// Offline Indic -> Latin transliteration used for fuzzy matching.
///
/// Devanagari (Hindi), Kannada and Tamil Unicode blocks share the same
/// ISCII-derived layout, so a single offset table covers all three scripts.
/// The output is a plain lowercase ASCII romanisation (no diacritics) that is
/// good enough to compare a spoken "ರಮೇಶ್ ಗೌಡ" with the stored "Ramesh Gowda".
library;

enum IndicScript { devanagari, kannada, tamil }

class Transliterator {
  static const int _devaBase = 0x0900;
  static const int _tamilBase = 0x0B80;
  static const int _kannadaBase = 0x0C80;

  // Consonants by offset inside the block (inherent vowel not included).
  static const Map<int, String> _consonants = {
    0x15: 'k', 0x16: 'kh', 0x17: 'g', 0x18: 'gh', 0x19: 'n',
    0x1A: 'ch', 0x1B: 'chh', 0x1C: 'j', 0x1D: 'jh', 0x1E: 'n',
    0x1F: 't', 0x20: 'th', 0x21: 'd', 0x22: 'dh', 0x23: 'n',
    0x24: 't', 0x25: 'th', 0x26: 'd', 0x27: 'dh', 0x28: 'n',
    0x29: 'n', 0x2A: 'p', 0x2B: 'ph', 0x2C: 'b', 0x2D: 'bh',
    0x2E: 'm', 0x2F: 'y', 0x30: 'r', 0x31: 'r', 0x32: 'l',
    0x33: 'l', 0x34: 'zh', 0x35: 'v', 0x36: 'sh', 0x37: 'sh',
    0x38: 's', 0x39: 'h',
    // Devanagari precomposed nukta letters
    0x58: 'q', 0x59: 'kh', 0x5A: 'g', 0x5B: 'z', 0x5C: 'r', 0x5D: 'rh',
    0x5E: 'f', 0x5F: 'y',
  };

  // Independent vowels.
  static const Map<int, String> _vowels = {
    0x05: 'a', 0x06: 'aa', 0x07: 'i', 0x08: 'ee', 0x09: 'u', 0x0A: 'oo',
    0x0B: 'ri', 0x0C: 'li', 0x0D: 'e', 0x0E: 'e', 0x0F: 'e', 0x10: 'ai',
    0x11: 'o', 0x12: 'o', 0x13: 'o', 0x14: 'au',
  };

  // Dependent vowel signs (matras).
  static const Map<int, String> _signs = {
    0x3E: 'aa', 0x3F: 'i', 0x40: 'ee', 0x41: 'u', 0x42: 'oo', 0x43: 'ri',
    0x44: 'ri', 0x45: 'e', 0x46: 'e', 0x47: 'e', 0x48: 'ai', 0x49: 'o',
    0x4A: 'o', 0x4B: 'o', 0x4C: 'au',
  };

  static const int _virama = 0x4D;
  static const int _nukta = 0x3C;
  static const int _candrabindu = 0x01;
  static const int _anusvara = 0x02;
  static const int _visarga = 0x03;

  static IndicScript? scriptOf(int cp) {
    if (cp >= _devaBase && cp < _devaBase + 0x80) return IndicScript.devanagari;
    if (cp >= _tamilBase && cp < _tamilBase + 0x80) return IndicScript.tamil;
    if (cp >= _kannadaBase && cp < _kannadaBase + 0x80) return IndicScript.kannada;
    return null;
  }

  static int _base(IndicScript s) => switch (s) {
        IndicScript.devanagari => _devaBase,
        IndicScript.tamil => _tamilBase,
        IndicScript.kannada => _kannadaBase,
      };

  /// True when [text] contains at least one Devanagari/Kannada/Tamil letter.
  static bool hasIndic(String text) =>
      text.runes.any((cp) => scriptOf(cp) != null);

  /// Romanises [text]. Latin characters and digits pass through unchanged.
  static String toLatin(String text) {
    final out = StringBuffer();
    final runes = text.runes.toList();
    var i = 0;
    while (i < runes.length) {
      final cp = runes[i];
      final script = scriptOf(cp);
      if (script == null) {
        out.writeCharCode(cp);
        i++;
        continue;
      }
      final off = cp - _base(script);
      if (off >= 0x66 && off <= 0x6F) {
        out.write(off - 0x66);
        i++;
        continue;
      }
      final consonant = _consonants[off];
      if (consonant != null) {
        var c = consonant;
        var j = i + 1;
        // nukta modifies the consonant (Devanagari ज़, फ़, ड़)
        if (j < runes.length && _offsetIn(runes[j], script) == _nukta) {
          c = switch (c) {
            'j' => 'z',
            'ph' => 'f',
            'd' => 'r',
            'dh' => 'rh',
            'k' => 'q',
            _ => c,
          };
          j++;
        }
        if (script == IndicScript.tamil) c = _tamilVoicing(off, c, out.toString());
        out.write(c);
        if (j < runes.length) {
          final nextOff = _offsetIn(runes[j], script);
          if (nextOff == _virama) {
            i = j + 1;
            continue;
          }
          final sign = nextOff == null ? null : _signs[nextOff];
          if (sign != null) {
            out.write(sign);
            i = j + 1;
            continue;
          }
        }
        // Inherent vowel. Hindi drops the final schwa ("राम" -> "ram").
        final atWordEnd = j >= runes.length || _offsetIn(runes[j], script) == null;
        if (!(script == IndicScript.devanagari && atWordEnd && out.length > 1)) {
          out.write('a');
        }
        i = j;
        continue;
      }
      final vowel = _vowels[off];
      if (vowel != null) {
        out.write(vowel);
      } else if (off == _anusvara || off == _candrabindu) {
        out.write('n');
      } else if (off == _visarga) {
        out.write('h');
      } else if (_signs.containsKey(off)) {
        // stray matra (shouldn't happen in well-formed text)
        out.write(_signs[off]);
      }
      // virama / nukta / length marks / others are dropped
      i++;
    }
    var s = out.toString();
    // Anusvara before labials reads as "m" (ಕೆಂಪು -> kempu, चंपा -> champa)
    s = s.replaceAllMapped(RegExp(r'n([pbm])'), (m) => 'm${m[1]}');
    return s;
  }

  /// Tamil script does not mark voicing; apply the usual pronunciation rules
  /// so names read naturally ("முருகன்" -> "murugan", "செல்வம்" -> "selvam").
  static String _tamilVoicing(int off, String c, String before) {
    final prev = before.isEmpty ? '' : before[before.length - 1];
    final wordStart = !RegExp('[a-z]').hasMatch(prev);
    final afterVowel = 'aeiou'.contains(prev) && prev.isNotEmpty;
    switch (off) {
      case 0x15: // க
        return (afterVowel || prev == 'n') ? 'g' : c;
      case 0x1F: // ட
        return (afterVowel || prev == 'n') ? 'd' : c;
      case 0x1A: // ச
        if (wordStart || afterVowel) return 's';
        if (prev == 'n') return 'j';
        return c;
      case 0x2A: // ப
        return prev == 'm' ? 'b' : c;
    }
    return c;
  }

  static int? _offsetIn(int cp, IndicScript script) {
    final s = scriptOf(cp);
    if (s != script) return null;
    return cp - _base(script);
  }

  /// Display-friendly romanisation of a spoken name: "ರಮೇಶ್ ಗೌಡ" -> "Ramesh Gowda".
  static String toDisplayName(String text) {
    var latin = toLatin(text);
    if (Transliterator.hasIndic(text) &&
        !text.runes.any((cp) => scriptOf(cp) == IndicScript.devanagari)) {
      latin = latin.replaceAll('au', 'ow');
    }
    latin = latin.replaceAll('aa', 'a');
    return latin
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }
}
