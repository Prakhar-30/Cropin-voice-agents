import '../voice/nlu/lexicon.dart';
import '../voice/nlu/numbers.dart';
import '../voice/nlu/text_utils.dart';
import '../voice/nlu/transliterator.dart';
import '../voice/nlu/utterance.dart';
import 'form_spec.dart';

class FieldValue {
  const FieldValue(this.value, {this.confidence = 0.95, this.heard = '', this.unit, this.approximate = false});

  /// Value as stored in the form (display text, option id, digits, dd/MM/yyyy).
  final String value;
  final double confidence;
  final String heard;

  /// Area unit when the area was said with one ("3 acres").
  final String? unit;

  /// Date of birth estimated from an age.
  final bool approximate;
}

enum ProblemKind { digits, noMatch, ambiguous, invalid }

/// Something was said for the field, but it can't be used as is.
class ValueProblem {
  const ValueProblem(this.kind, {this.heard = '', this.got = 0, this.need = '', this.options = const []});
  final ProblemKind kind;
  final String heard;

  /// Digits heard / needed for number fields.
  final int got;
  final String need;

  /// Close options for an ambiguous dropdown answer.
  final List<Choice> options;
}

class Parsed {
  const Parsed.ok(FieldValue this.value) : problem = null;
  const Parsed.bad(ValueProblem this.problem) : value = null;
  const Parsed.none()
      : value = null,
        problem = null;
  final FieldValue? value;
  final ValueProblem? problem;
  bool get isEmpty => value == null && problem == null;
}

/// Turns what was said for one field into a form value.
class ValueParsers {
  static Parsed parse(FieldSpec f, String text) {
    if (text.trim().isEmpty) return const Parsed.none();
    return switch (f.kind) {
      FieldKind.name => _name(f, text, maxWords: 4),
      FieldKind.text => _name(f, text, maxWords: 8, titleCase: false),
      FieldKind.place => _place(f, text),
      FieldKind.phone => _phone(text),
      FieldKind.dropdown => choice(f, text),
      FieldKind.date => date(text),
      FieldKind.area => _area(text),
      FieldKind.aadhaar => _digitsField(text, 12, 12, '12'),
      FieldKind.pin => _digitsField(text, 6, 6, '6'),
      FieldKind.account => _digitsField(text, 9, 18, '9-18'),
      FieldKind.email => _email(text),
      FieldKind.pan => _spelled(text, RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$'), 10),
      FieldKind.ifsc => _spelled(text, RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$'), 11),
    };
  }

  // ------------------------------------------------------------ names & text

  /// Words that carry a sentence but are never part of a name or place.
  static const _carriers = {
    'its', "it's", 'is', 'called', 'named', 'the', 'name', 'was', 'are', 'mister', 'yes', 'no',
    'है', 'हैं', 'था', 'थी', 'का', 'की', 'के', 'नाम', 'उनका', 'उनकी', 'उनके', 'जी', 'श्री', 'श्रीमती', 'हाँ',
    'हां', 'नहीं', 'में', 'से', 'ಅವರ', 'ಅವರು', 'ಹೆಸರು', 'ಆಗಿದೆ', 'ಅಂತ', 'ಎಂದು', 'ಇದೆ', 'ಹೌದು', 'ಇಲ್ಲ',
    'ಶ್ರೀ', 'ಅವರದು', 'என்று', 'பெயர்', 'அவர்', 'அவரது', 'அவருடைய', 'ஆம்', 'இல்லை', 'திரு', 'திருமதி',
    'உள்ளது', 'ஆகும்',
  };

  static List<String> _words(FieldSpec f, String text) {
    final labelWords = <String>{
      for (final l in f.labels) ...TextUtils.normalize(l).split(' '),
    };
    return Utterance(text)
        .tokens
        .map((t) => t.raw)
        .where((w) =>
            !Utterance.isFiller(w) &&
            !_carriers.contains(w) &&
            !labelWords.contains(w) &&
            !RegExp(r'\d').hasMatch(w))
        .toList();
  }

  static String display(String spoken, {bool titleCase = true}) {
    if (Transliterator.hasIndic(spoken)) return Transliterator.toDisplayName(spoken);
    if (!titleCase) return spoken[0].toUpperCase() + spoken.substring(1);
    return spoken
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  static Parsed _name(FieldSpec f, String text, {required int maxWords, bool titleCase = true}) {
    final words = _words(f, text);
    if (words.isEmpty) return const Parsed.none();
    final kept = words.take(maxWords).join(' ');
    final conf = words.length > maxWords ? 0.75 : (Transliterator.hasIndic(kept) ? 0.85 : 0.92);
    return Parsed.ok(FieldValue(display(kept, titleCase: titleCase), confidence: conf, heard: kept));
  }

  static Parsed _place(FieldSpec f, String text) {
    if (f.choices.isNotEmpty) {
      final u = Utterance(text);
      final m = PhraseMatcher.best(u, {for (final c in f.choices) c.id: [c.label, ...c.aliases]},
          minScore: 0.86);
      if (m != null) {
        return Parsed.ok(FieldValue(f.choice(m.value)!.label, confidence: m.score, heard: m.spoken));
      }
    }
    return _name(f, text, maxWords: 4);
  }

  // ------------------------------------------------------------------ numbers

  static String? _digit(Token t) {
    if (t.isDigits) return t.raw;
    final v = Lexicon.numberWords[t.raw];
    if (v != null && v >= 0 && v <= 99 && v == v.roundToDouble()) return v.toInt().toString();
    return null;
  }

  /// Every digit said, in order: digit groups, number words ("nine eight"),
  /// pairs ("ninety eight"), "double 4". Other words are ignored.
  static String readDigits(String text) {
    final t = Utterance(text).tokens;
    final b = StringBuffer();
    for (var i = 0; i < t.length; i++) {
      final rep = Lexicon.doubleWords.contains(t[i].raw)
          ? 2
          : Lexicon.tripleWords.contains(t[i].raw)
              ? 3
              : 0;
      if (rep > 0 && i + 1 < t.length) {
        final d = _digit(t[i + 1]);
        if (d != null && d.length == 1) {
          b.write(d * rep);
          i++;
          continue;
        }
      }
      final v = Lexicon.numberWords[t[i].raw];
      if (v != null && v >= 20 && v < 100 && v % 10 == 0 && i + 1 < t.length) {
        final u = Lexicon.numberWords[t[i + 1].raw];
        if (u != null && u >= 1 && u <= 9 && u == u.roundToDouble()) {
          b.write((v + u).toInt());
          i++;
          continue;
        }
      }
      final d = _digit(t[i]);
      if (d != null) b.write(d);
    }
    return b.toString();
  }

  static Parsed _digitsField(String text, int min, int max, String need) {
    final d = readDigits(text);
    if (d.isEmpty) return const Parsed.none();
    if (d.length < min || d.length > max) {
      return Parsed.bad(ValueProblem(ProblemKind.digits, heard: d, got: d.length, need: need));
    }
    return Parsed.ok(FieldValue(d, heard: d));
  }

  static Parsed _phone(String text) {
    final p = NumberExtractor.extractPhone(Utterance(text));
    if (p == null) {
      final d = readDigits(text);
      if (d.isEmpty) return const Parsed.none();
      return Parsed.bad(ValueProblem(ProblemKind.digits, heard: d, got: d.length, need: '10'));
    }
    if (!p.looksValid) {
      return Parsed.bad(
          ValueProblem(ProblemKind.digits, heard: p.digits, got: p.digits.length, need: '10'));
    }
    return Parsed.ok(FieldValue(p.digits, confidence: 0.97, heard: p.spoken));
  }

  static String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  static Parsed _area(String text) {
    final u = Utterance(text);
    final a = NumberExtractor.extractArea(u);
    if (a != null) {
      return Parsed.ok(FieldValue(_fmt(a.value), unit: a.unit, confidence: a.score, heard: a.spoken));
    }
    for (final t in u.tokens) {
      final v = t.numeric;
      if (v != null && v > 0 && v < 100000) {
        return Parsed.ok(FieldValue(_fmt(v), confidence: 0.85, heard: t.raw));
      }
    }
    return const Parsed.none();
  }

  // -------------------------------------------------------------------- dates

  static const Map<int, List<String>> months = {
    1: ['january', 'jan', 'जनवरी', 'ಜನವರಿ', 'ஜனவரி'],
    2: ['february', 'feb', 'फरवरी', 'फ़रवरी', 'ಫೆಬ್ರವರಿ', 'பிப்ரவரி'],
    3: ['march', 'मार्च', 'ಮಾರ್ಚ್', 'மார்ச்'],
    4: ['april', 'अप्रैल', 'अप्रेल', 'ಏಪ್ರಿಲ್', 'ஏப்ரல்'],
    5: ['may', 'मई', 'ಮೇ', 'மே'],
    6: ['june', 'जून', 'ಜೂನ್', 'ஜூன்'],
    7: ['july', 'जुलाई', 'ಜುಲೈ', 'ஜூலை'],
    8: ['august', 'अगस्त', 'ಆಗಸ್ಟ್', 'ஆகஸ்ட்'],
    9: ['september', 'sept', 'सितंबर', 'सितम्बर', 'ಸೆಪ್ಟೆಂಬರ್', 'செப்டம்பர்'],
    10: ['october', 'अक्टूबर', 'अक्तूबर', 'ಅಕ್ಟೋಬರ್', 'அக்டோபர்'],
    11: ['november', 'नवंबर', 'नवम्बर', 'ನವೆಂಬರ್', 'நவம்பர்'],
    12: ['december', 'दिसंबर', 'दिसम्बर', 'ಡಿಸೆಂಬರ್', 'டிசம்பர்'],
  };

  static const _ageWords = {
    'age', 'aged', 'years', 'year', 'old', 'उम्र', 'आयु', 'साल', 'वर्ष', 'बरस', 'ವಯಸ್ಸು', 'ವರ್ಷ',
    'ವರ್ಷದ', 'ವಯಸ್ಸಿನ', 'வயது', 'வருடம்', 'வயசு',
  };

  /// Combines number words into one number: "nineteen eighty five" -> 1985,
  /// "उन्नीस सौ पचासी" -> 1985, "two thousand five" -> 2005.
  static int? compose(List<double> parts) {
    if (parts.isEmpty) return null;
    var total = 0;
    var current = 0;
    var pairedYear = false;
    for (final p in parts) {
      final v = p.toInt();
      if (v == 1000) {
        total += (current == 0 ? 1 : current) * 1000;
        current = 0;
      } else if (v == 100) {
        current = (current == 0 ? 1 : current) * 100;
      } else if (current >= 10 && current < 100 && v < 100 && !pairedYear && total == 0 && v >= 10) {
        // "nineteen eighty" -> 1980
        current = current * 100 + v;
        pairedYear = true;
      } else {
        current += v;
      }
    }
    return total + current;
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  static Parsed date(String text, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final u = Utterance(text);
    final t = u.tokens;

    // Runs of number tokens: [[15], [1980]] or [[15], [19, 80]].
    final runs = <(int, int, List<double>)>[]; // start, end (exclusive), values
    var i = 0;
    while (i < t.length) {
      final v = t[i].numeric;
      if (v == null || v != v.roundToDouble()) {
        i++;
        continue;
      }
      final start = i;
      final vals = <double>[];
      while (i < t.length && t[i].numeric != null && t[i].numeric == t[i].numeric!.roundToDouble()) {
        vals.add(t[i].numeric!);
        i++;
      }
      runs.add((start, i, vals));
    }

    bool validYear(int y) => y >= 1900 && y <= today.year;
    String out(int d, int m, int y) => '${_two(d)}/${_two(m)}/$y';
    bool validDay(int d, int m, int y) {
      if (d < 1 || m < 1 || m > 12) return false;
      return d <= DateTime(y, m + 1, 0).day;
    }

    final month = PhraseMatcher.best(u, months, minScore: 0.88);
    if (month != null) {
      final m = month.value;
      final before = runs.where((r) => r.$2 <= month.start).toList();
      final after = runs.where((r) => r.$1 >= month.start + month.length).toList();
      int? day;
      int? year;
      if (before.isNotEmpty) {
        day = compose(before.last.$3);
        if (after.isNotEmpty) year = compose(after.first.$3);
      } else if (after.isNotEmpty) {
        // "August 15 1980" or "August 15, nineteen eighty"
        final first = after.first.$3;
        if (first.length > 1 && first.first <= 31) {
          day = first.first.toInt();
          year = compose(first.sublist(1));
        } else {
          day = compose(first);
          if (after.length > 1) year = compose(after[1].$3);
        }
      }
      if (day != null && year != null && validYear(year) && validDay(day, m, year)) {
        return Parsed.ok(FieldValue(out(day, m, year), confidence: 0.9, heard: text));
      }
      return Parsed.bad(ValueProblem(ProblemKind.invalid, heard: text));
    }

    // "15 08 1980" / "15/8/1980"
    final digitsOnly = [for (final r in runs) ...r.$3];
    if (digitsOnly.length == 3 && t.every((x) => x.isDigits || Utterance.isFiller(x.raw))) {
      final d = digitsOnly[0].toInt(), m = digitsOnly[1].toInt(), y = digitsOnly[2].toInt();
      if (validYear(y) && validDay(d, m, y)) {
        return Parsed.ok(FieldValue(out(d, m, y), confidence: 0.9, heard: text));
      }
    }

    // An age: "45 years", "उम्र 45", "ವಯಸ್ಸು ನಲವತ್ತೈದು", or just a number.
    if (runs.length == 1) {
      final n = compose(runs.first.$3);
      final saysAge = t.any((x) => _ageWords.contains(x.raw));
      if (n != null && validYear(n) && !saysAge) {
        return Parsed.ok(FieldValue('01/01/$n', confidence: 0.7, heard: text, approximate: true));
      }
      if (n != null && n >= 10 && n <= 110) {
        return Parsed.ok(
            FieldValue('01/01/${today.year - n}', confidence: 0.7, heard: text, approximate: true));
      }
    }
    if (runs.isEmpty) return const Parsed.none();
    return Parsed.bad(ValueProblem(ProblemKind.invalid, heard: text));
  }

  // ------------------------------------------------------- email, PAN, IFSC

  static const _at = {'at', '@', 'एट', 'ऐट', 'ಅಟ್', 'ಆಟ್', 'அட்', 'ஆட்'};
  static const _dot = {'dot', '.', 'डॉट', 'डोट', 'ಡಾಟ್', 'ಡಾಟ', 'டாட்'};
  static const _underscore = {'underscore', 'अंडरस्कोर', 'ಅಂಡರ್‌ಸ್ಕೋರ್', 'ಅಂಡರ್ಸ್ಕೋರ್', 'அண்டர்ஸ்கோர்'};
  static const _emailWords = {
    'gmail': 'gmail', 'जीमेल': 'gmail', 'ಜಿಮೇಲ್': 'gmail', 'ஜிமெயில்': 'gmail', 'yahoo': 'yahoo',
    'याहू': 'yahoo', 'ಯಾಹೂ': 'yahoo', 'யாகூ': 'yahoo', 'com': 'com', 'कॉम': 'com', 'कोम': 'com',
    'ಕಾಮ್': 'com', 'ಕಾಂ': 'com', 'காம்': 'com', 'rediffmail': 'rediffmail', 'outlook': 'outlook',
    'hotmail': 'hotmail', 'in': 'in', 'इन': 'in', 'ಇನ್': 'in', 'இன்': 'in', 'co': 'co',
  };

  static Parsed _email(String text) {
    final raw = text
        .toLowerCase()
        .replaceAll('@', ' @ ')
        .replaceAll(RegExp(r'(?<=\S)\.(?=\S)'), ' . ')
        .replaceAll('at the rate of', ' @ ')
        .replaceAll('at the rate', ' @ ')
        .replaceAll('एट द रेट', ' @ ')
        .replaceAll('ऐट द रेट', ' @ ')
        .replaceAll('ಅಟ್ ದ ರೇಟ್', ' @ ')
        .replaceAll('அட் தி ரேட்', ' @ ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    final b = StringBuffer();
    var sawAt = false;
    for (final w in raw) {
      if (_at.contains(w) && !sawAt) {
        b.write('@');
        sawAt = true;
      } else if (_dot.contains(w)) {
        b.write('.');
      } else if (_underscore.contains(w)) {
        b.write('_');
      } else if (_emailWords.containsKey(w)) {
        b.write(_emailWords[w]);
      } else if (Utterance.isFiller(w) || _carriers.contains(w)) {
        continue;
      } else {
        final v = Lexicon.numberWords[w];
        if (v != null && v >= 0 && v <= 99 && v == v.roundToDouble()) {
          b.write(v.toInt());
        } else {
          final latin = Transliterator.hasIndic(w) ? Transliterator.toLatin(w) : w;
          b.write(latin.toLowerCase().replaceAll(RegExp(r'[^a-z0-9._-]'), ''));
        }
      }
    }
    final e = b.toString();
    if (e.isEmpty) return const Parsed.none();
    if (RegExp(r'^[a-z0-9._-]+@[a-z0-9-]+(\.[a-z0-9-]+)+$').hasMatch(e)) {
      return Parsed.ok(FieldValue(e, confidence: 0.85, heard: text));
    }
    return Parsed.bad(ValueProblem(ProblemKind.invalid, heard: e));
  }

  static const Map<String, String> _letterNames = {
    // English
    'ay': 'A', 'ae': 'A', 'bee': 'B', 'be': 'B', 'see': 'C', 'sea': 'C', 'dee': 'D', 'ee': 'E',
    'ef': 'F', 'eff': 'F', 'gee': 'G', 'ji': 'G', 'aitch': 'H', 'etch': 'H', 'edge': 'H',
    'eye': 'I', 'jay': 'J', 'kay': 'K', 'el': 'L', 'ell': 'L', 'em': 'M', 'en': 'N', 'oh': 'O',
    'pee': 'P', 'queue': 'Q', 'cue': 'Q', 'ar': 'R', 'are': 'R', 'es': 'S', 'ess': 'S',
    'tee': 'T', 'tea': 'T', 'you': 'U', 'vee': 'V', 'ex': 'X', 'why': 'Y', 'zed': 'Z', 'zee': 'Z',
    // Hindi
    'ए': 'A', 'बी': 'B', 'सी': 'C', 'डी': 'D', 'ई': 'E', 'एफ': 'F', 'एफ़': 'F', 'जी': 'G', 'एच': 'H',
    'आई': 'I', 'जे': 'J', 'के': 'K', 'एल': 'L', 'एम': 'M', 'एन': 'N', 'ओ': 'O', 'पी': 'P',
    'क्यू': 'Q', 'आर': 'R', 'एस': 'S', 'टी': 'T', 'यू': 'U', 'वी': 'V', 'डब्ल्यू': 'W', 'एक्स': 'X',
    'वाई': 'Y', 'जेड': 'Z', 'ज़ेड': 'Z',
    // Kannada
    'ಎ': 'A', 'ಬಿ': 'B', 'ಸಿ': 'C', 'ಡಿ': 'D', 'ಇ': 'E', 'ಈ': 'E', 'ಎಫ್': 'F', 'ಜಿ': 'G',
    'ಎಚ್': 'H', 'ಹೆಚ್': 'H', 'ಐ': 'I', 'ಜೆ': 'J', 'ಕೆ': 'K', 'ಎಲ್': 'L', 'ಎಂ': 'M', 'ಎನ್': 'N',
    'ಒ': 'O', 'ಓ': 'O', 'ಪಿ': 'P', 'ಕ್ಯೂ': 'Q', 'ಆರ್': 'R', 'ಎಸ್': 'S', 'ಟಿ': 'T', 'ಯು': 'U',
    'ಯೂ': 'U', 'ವಿ': 'V', 'ಡಬ್ಲ್ಯೂ': 'W', 'ಎಕ್ಸ್': 'X', 'ವೈ': 'Y', 'ಝಡ್': 'Z', 'ಜೆಡ್': 'Z',
    // Tamil (no b/p or d/t distinction in script: the long-vowel forms are P and T)
    'ஏ': 'A', 'பி': 'B', 'சி': 'C', 'டி': 'D', 'ஈ': 'E', 'இ': 'E', 'எஃப்': 'F', 'எப்': 'F',
    'ஜி': 'G', 'ஹெச்': 'H', 'எச்': 'H', 'ஐ': 'I', 'ஜே': 'J', 'கே': 'K', 'எல்': 'L', 'எம்': 'M',
    'என்': 'N', 'ஓ': 'O', 'பீ': 'P', 'க்யூ': 'Q', 'ஆர்': 'R', 'எஸ்': 'S', 'டீ': 'T', 'யூ': 'U',
    'வி': 'V', 'டபிள்யூ': 'W', 'எக்ஸ்': 'X', 'ஒய்': 'Y', 'வை': 'Y', 'இசட்': 'Z', 'ஜெட்': 'Z',
  };

  /// Letters and digits said one by one ("A B C D E 1 2 3 4 F").
  static String spell(String text) {
    final t = Utterance(text).tokens;
    final b = StringBuffer();
    for (var i = 0; i < t.length; i++) {
      final w = t[i].raw;
      if (w == 'double' && i + 1 < t.length && (t[i + 1].raw == 'you' || t[i + 1].raw == 'u')) {
        b.write('W');
        i++;
        continue;
      }
      final rep = Lexicon.doubleWords.contains(w) ? 2 : 0;
      if (rep > 0 && i + 1 < t.length) {
        final next = t[i + 1].raw;
        final letter = next.length == 1 && RegExp('[a-z]').hasMatch(next) ? next.toUpperCase() : _letterNames[next];
        final d = _digit(t[i + 1]);
        if (letter != null || (d != null && d.length == 1)) {
          b.write((letter ?? d)! * 2);
          i++;
          continue;
        }
      }
      if (RegExp(r'^[a-z0-9]+$').hasMatch(w) && !_letterNames.containsKey(w) && Lexicon.numberWords[w] == null) {
        // "sbin" / "abcde1234f" said or recognised as one word
        if (w.length <= 11) b.write(w.toUpperCase());
        continue;
      }
      final letter = _letterNames[w];
      if (letter != null) {
        b.write(letter);
        continue;
      }
      final d = _digit(t[i]);
      if (d != null) b.write(d);
    }
    return b.toString();
  }

  static Parsed _spelled(String text, RegExp pattern, int length) {
    final s = spell(text);
    if (s.isEmpty) return const Parsed.none();
    if (pattern.hasMatch(s)) return Parsed.ok(FieldValue(s, confidence: 0.85, heard: text));
    return Parsed.bad(ValueProblem(ProblemKind.invalid, heard: s, got: s.length, need: '$length'));
  }

  // ---------------------------------------------------------------- dropdowns

  static const _ordinals = <int, List<String>>{
    0: ['first', 'pehla', 'पहला', 'पहली', 'पहले', 'ಮೊದಲನೆಯದು', 'ಮೊದಲನೇ', 'ಮೊದಲ', 'ಮೊದಲನೆಯ', 'முதல்', 'முதலாவது', 'முதலாவதை'],
    1: ['second', 'dusra', 'दूसरा', 'दूसरी', 'दूसरे', 'ಎರಡನೆಯದು', 'ಎರಡನೇ', 'ಎರಡನೆಯ', 'இரண்டாவது', 'இரண்டாவதை'],
    2: ['third', 'teesra', 'तीसरा', 'तीसरी', 'तीसरे', 'ಮೂರನೆಯದು', 'ಮೂರನೇ', 'ಮೂರನೆಯ', 'மூன்றாவது', 'மூன்றாவதை'],
    3: ['fourth', 'चौथा', 'चौथी', 'चौथे', 'ನಾಲ್ಕನೆಯದು', 'ನಾಲ್ಕನೇ', 'நான்காவது'],
    4: ['fifth', 'पांचवां', 'पाँचवाँ', 'पांचवी', 'ಐದನೆಯದು', 'ಐದನೇ', 'ஐந்தாவது'],
    -1: ['last', 'आखिरी', 'आख़िरी', 'अंतिम', 'ಕೊನೆಯ', 'ಕೊನೆಯದು', 'கடைசி'],
  };

  static int? _ordinal(Utterance u, int count) {
    for (final t in u.tokens) {
      for (final e in _ordinals.entries) {
        if (e.value.contains(t.raw)) {
          final i = e.key < 0 ? count - 1 : e.key;
          return i < count ? i : null;
        }
      }
    }
    return null;
  }

  /// Matches what was said to one of [f]'s options: by name or alias in any
  /// language, by enough words of a long name ("paddy sustainability" /
  /// "groundnut"), or by position ("the second one").
  static Parsed choice(FieldSpec f, String text) {
    final u = Utterance(text);
    if (u.length == 0) return const Parsed.none();
    final lex = {for (final c in f.choices) c.id: [c.label, ...c.aliases]};
    final all = PhraseMatcher.findAll(u, lex, minScore: 0.82);
    if (all.isNotEmpty) {
      final best = all.first;
      final rival = all.where((m) => m.value != best.value && m.score >= best.score - 0.01).toList();
      if (rival.isEmpty || best.score >= 1.0 && rival.every((r) => r.score < 1.0)) {
        return Parsed.ok(
            FieldValue(best.value, confidence: best.score, heard: best.spoken));
      }
      final ids = {best.value, ...rival.map((r) => r.value)};
      return Parsed.bad(ValueProblem(ProblemKind.ambiguous,
          heard: best.spoken, options: [for (final id in ids) f.choice(id)!]));
    }
    final ord = _ordinal(u, f.choices.length);
    if (ord != null) {
      return Parsed.ok(FieldValue(f.choices[ord].id, confidence: 0.9, heard: text));
    }
    // Partial names: share of an option's words that were said.
    final said = u.tokens.where((t) => !Utterance.isFiller(t.raw)).toList();
    final scores = <Choice, double>{};
    for (final c in f.choices) {
      final words = TextUtils.normalize(c.label)
          .split(' ')
          .where((w) => w.length > 2 && !RegExp(r'^\d+$').hasMatch(w))
          .toList();
      if (words.isEmpty) continue;
      var hit = 0;
      for (final w in words) {
        final k = TextUtils.phoneticKey(w);
        if (said.any((t) => t.key == k || (k.length > 4 && TextUtils.similarity(t.key, k) >= 0.85))) {
          hit++;
        }
      }
      if (hit > 0) scores[c] = hit / words.length;
    }
    if (scores.isNotEmpty) {
      final top = scores.values.reduce((a, b) => a > b ? a : b);
      final best = scores.entries.where((e) => e.value == top).map((e) => e.key).toList();
      if (best.length == 1) {
        return Parsed.ok(FieldValue(best.first.id, confidence: top >= 0.99 ? 0.9 : 0.8, heard: text));
      }
      return Parsed.bad(ValueProblem(ProblemKind.ambiguous, heard: text, options: best));
    }
    return Parsed.bad(ValueProblem(ProblemKind.noMatch, heard: text));
  }
}
