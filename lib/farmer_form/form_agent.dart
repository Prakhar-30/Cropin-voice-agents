import '../voice/agent_language.dart';
import '../voice/nlu/text_utils.dart';
import '../voice/nlu/utterance.dart';
import 'form_spec.dart';
import 'value_parsers.dart';

enum AgentMode { asking, offering, confirming, editing, done }

enum AgentAction { none, submit, saveDraft, useLocation, pause }

/// One turn of the agent: what to show and say, what changed on the form and
/// whether to listen again afterwards.
class AgentReply {
  AgentReply(
    this.text, {
    String? speech,
    this.chips = const [],
    this.asking,
    this.filled = const {},
    this.action = AgentAction.none,
    this.listen = true,
  }) : speech = speech ?? text;

  final String text;

  /// Same as [text] but with numbers spelled digit by digit for the TTS voice.
  final String speech;
  final List<String> chips;

  /// Field the agent is asking about (scrolled to and highlighted).
  final String? asking;
  final Map<String, FieldValue> filled;
  final AgentAction action;
  final bool listen;
}

enum _Cmd { stop, repeat, back, skip, skipAll, submit, draft, help }

/// Fills the Add Farmer form through a conversation.
///
/// Slot filling as in Alexa dialog management / Dialogflow forms: the first
/// answer may hold several details ("Ramesh Kumar, 98450 12345, paddy
/// project"); the agent then asks for each missing required field, one at a
/// time, offers the optional sections instead of reading out 20 more
/// questions, and confirms once before submitting. Any turn may volunteer
/// other fields by name ("village Hosakote, PIN 562114"), correct the last
/// one ("no, 98450 12346"), skip, go back, save a draft or submit.
class FarmerFormAgent {
  FarmerFormAgent({required this.values, this.lang = AgentLanguage.english});

  /// The form's values (shared with the screen): text, digits, option ids.
  final Map<String, String> values;
  AgentLanguage lang;

  AgentMode mode = AgentMode.asking;
  String? asking;
  final Set<String> skipped = {};
  final Set<FormSection> finished = {};
  FormSection? section;
  final List<FormSection> _queue = [];
  final List<String> _history = [];
  String? _lastFilled;
  bool _locationAsked = false;
  bool _offeredOnce = false;
  int _misses = 0;
  int _silences = 0;

  String _t(String en, String hi, String kn, String ta) => tr(lang, en, hi, kn, ta);

  static const _locationField = 'useLocation';

  bool filled(String id) => (values[id] ?? '').trim().isNotEmpty;

  List<FieldSpec> get _required => FarmerFormSpec.fields.where((f) => f.required).toList();

  // ------------------------------------------------------------------ turns

  AgentReply start() {
    mode = AgentMode.asking;
    if (_required.every((f) => !filled(f.id))) {
      asking = 'name';
      _history.add('name');
      return AgentReply(
        _t(
          "Let's add a farmer. Tell me their name, mobile number and project — all at once is fine.",
          'चलिए किसान जोड़ते हैं। उनका नाम, मोबाइल नंबर और प्रोजेक्ट बताइए — एक साथ भी बता सकते हैं।',
          'ರೈತರನ್ನು ಸೇರಿಸೋಣ. ಅವರ ಹೆಸರು, ಮೊಬೈಲ್ ಸಂಖ್ಯೆ ಮತ್ತು ಪ್ರಾಜೆಕ್ಟ್ ಹೇಳಿ — ಒಟ್ಟಿಗೆ ಹೇಳಿದರೂ ಸರಿ.',
          'விவசாயியைச் சேர்ப்போம். அவர்களின் பெயர், மொபைல் எண் மற்றும் திட்டத்தைச் சொல்லுங்கள் — ஒரே முறையில் சொன்னாலும் சரி.',
        ),
        asking: 'name',
      );
    }
    return _next(const []);
  }

  /// Repeats the current question (after a language switch or "repeat").
  AgentReply repeat() => _next(const [], again: true);

  /// The user said [text] (best recogniser hypothesis first in [alternatives]).
  AgentReply hear(String text, {List<String> alternatives = const []}) {
    final said = text.trim();
    if (said.isEmpty) return _noInput();
    _silences = 0;
    final norm = _norm(said);

    final cmd = _command(norm);
    switch (cmd) {
      case _Cmd.stop:
        return AgentReply(
          _t("Okay, I've paused. Tap the mic whenever you're ready.", 'ठीक है, मैं रुक गया हूँ। तैयार हों तो माइक दबाइए।',
              'ಸರಿ, ನಿಲ್ಲಿಸಿದ್ದೇನೆ. ಸಿದ್ಧವಾದಾಗ ಮೈಕ್ ಒತ್ತಿ.', 'சரி, நிறுத்திவிட்டேன். தயாரானதும் மைக்கை அழுத்துங்கள்.'),
          asking: asking,
          action: AgentAction.pause,
          listen: false,
        );
      case _Cmd.repeat:
        return repeat();
      case _Cmd.help:
        return _next([
          _t(
            "You can answer each question, or say several details at once like 'village Hosakote, PIN 562114'. "
                "Say 'skip' to leave a field, 'go back' to change the last one, or 'save draft' or 'submit' anytime.",
            "हर सवाल का जवाब दीजिए, या कई बातें एक साथ बोलिए — जैसे 'गाँव होसकोटे, पिन 562114'। "
                "किसी को छोड़ने के लिए 'छोड़ो', पिछला बदलने के लिए 'पीछे', और कभी भी 'ड्राफ्ट' या 'सबमिट' कहिए।",
            "ಪ್ರತಿ ಪ್ರಶ್ನೆಗೆ ಉತ್ತರಿಸಿ, ಅಥವಾ ಹಲವು ವಿವರಗಳನ್ನು ಒಟ್ಟಿಗೆ ಹೇಳಿ — ಉದಾ. 'ಗ್ರಾಮ ಹೊಸಕೋಟೆ, ಪಿನ್ 562114'. "
                "ಬಿಡಲು 'ಬಿಡಿ', ಹಿಂದಿನದನ್ನು ಬದಲಿಸಲು 'ಹಿಂದೆ', ಯಾವಾಗ ಬೇಕಾದರೂ 'ಡ್ರಾಫ್ಟ್' ಅಥವಾ 'ಸಬ್ಮಿಟ್' ಹೇಳಿ.",
            "ஒவ்வொரு கேள்விக்கும் பதில் சொல்லுங்கள், அல்லது பல விவரங்களை ஒன்றாகச் சொல்லுங்கள் — உதா. 'கிராமம் ஹோசகோட்டே, பின் 562114'. "
                "தவிர்க்க 'தவிர்', முந்தையதை மாற்ற 'முந்தைய', எப்போது வேண்டுமானாலும் 'டிராஃப்ட்' அல்லது 'சப்மிட்' சொல்லுங்கள்.",
          ),
        ], again: true);
      case _Cmd.draft:
        mode = AgentMode.done;
        return AgentReply(
          _t('Saving it as a draft.', 'ड्राफ्ट के रूप में सेव कर रहा हूँ।', 'ಡ್ರಾಫ್ಟ್ ಆಗಿ ಉಳಿಸುತ್ತಿದ್ದೇನೆ.', 'வரைவாகச் சேமிக்கிறேன்.'),
          action: AgentAction.saveDraft,
          listen: false,
        );
      case _Cmd.submit:
        return _submit();
      case _Cmd.back:
        return _back();
      default:
        break;
    }

    final yes = _isYes(norm), no = _isNo(norm);

    if (asking == _locationField && mode == AgentMode.asking) {
      if (yes) {
        _locationAsked = true;
        return AgentReply(
          _t('Getting your location…', 'आपकी लोकेशन ले रहा हूँ…', 'ನಿಮ್ಮ ಸ್ಥಳ ಪಡೆಯುತ್ತಿದ್ದೇನೆ…', 'உங்கள் இடத்தைப் பெறுகிறேன்…'),
          asking: _locationField,
          action: AgentAction.useLocation,
          listen: false,
        );
      }
      if (no || cmd == _Cmd.skip) {
        _locationAsked = true;
        return _next(const []);
      }
    }

    if (mode == AgentMode.offering) {
      if (cmd == _Cmd.skip || cmd == _Cmd.skipAll) return _confirm();
      final picked = _sections(norm);
      if (picked.isNotEmpty) {
        _queue
          ..clear()
          ..addAll(picked);
        section = _queue.removeAt(0);
        mode = AgentMode.asking;
        return _next(const []);
      }
      if (yes) {
        final open = _openSections();
        if (open.isNotEmpty) {
          section = open.first;
          mode = AgentMode.asking;
          return _next(const []);
        }
      }
      if (no) return _confirm();
    }

    if (mode == AgentMode.confirming) {
      if (yes) return _submit();
      if (no) {
        mode = AgentMode.editing;
        asking = null;
        return AgentReply(
          _t("Sure — what would you like to change? Say the field and the new value, like 'mobile number' and the number.",
              "ज़रूर — क्या बदलना है? फ़ील्ड का नाम और नई जानकारी बोलिए, जैसे 'मोबाइल नंबर' और नंबर।",
              "ಖಂಡಿತ — ಏನು ಬದಲಿಸಬೇಕು? ಫೀಲ್ಡ್ ಹೆಸರು ಮತ್ತು ಹೊಸ ಮಾಹಿತಿ ಹೇಳಿ, ಉದಾ. 'ಮೊಬೈಲ್ ಸಂಖ್ಯೆ' ಮತ್ತು ಸಂಖ್ಯೆ.",
              "சரி — எதை மாற்ற வேண்டும்? புலத்தின் பெயரையும் புதிய விவரத்தையும் சொல்லுங்கள், உதா. 'மொபைல் எண்' மற்றும் எண்."),
        );
      }
    }

    if (cmd == _Cmd.skip) return _skip();
    if (cmd == _Cmd.skipAll) return _skipSection();
    // A bare "no" to an optional question means "leave it".
    if (no &&
        mode == AgentMode.asking &&
        norm.split(' ').every((w) => _no.contains(w) || Utterance.isFiller(w) || _thanks.contains(w))) {
      return _skip();
    }

    // "no, it's …" right after a value: a correction of that value.
    var target = asking;
    var text0 = said;
    final words = norm.split(' ');
    if (words.length > 1 && _no.contains(words.first) && _lastFilled != null && mode != AgentMode.confirming) {
      target = _lastFilled;
      text0 = words.skip(1).join(' ');
    }

    // Try every recogniser hypothesis; keep the one that fills the most.
    final candidates = [text0, ...alternatives.where((a) => a.trim().isNotEmpty && a.trim() != said)];
    Extraction? best;
    for (final c in candidates) {
      final e = extract(c, expecting: target == _locationField ? null : target);
      if (best == null || e.score > best.score) best = e;
    }
    return _apply(best!);
  }

  /// After the screen filled the address from GPS ([filled] = field -> value).
  AgentReply locationDone(Map<String, String> filled) {
    _locationAsked = true;
    if (filled.isEmpty) {
      return _next([
        _t("I couldn't get the location, so let's fill the address by voice.",
            'लोकेशन नहीं मिल पाई, तो पता बोलकर भरते हैं।',
            'ಸ್ಥಳ ಸಿಗಲಿಲ್ಲ, ವಿಳಾಸವನ್ನು ಮಾತಿನಲ್ಲೇ ತುಂಬೋಣ.',
            'இடம் கிடைக்கவில்லை, முகவரியைப் பேசியே நிரப்புவோம்.'),
      ]);
    }
    values.addAll(filled);
    final place = [filled['city'], filled['district'], filled['state']].whereType<String>().join(', ');
    return _next([
      _t('Filled the address from your location — $place.', 'आपकी लोकेशन से पता भर दिया — $place।',
          'ನಿಮ್ಮ ಸ್ಥಳದಿಂದ ವಿಳಾಸ ತುಂಬಿದೆ — $place.', 'உங்கள் இடத்திலிருந்து முகவரி நிரப்பப்பட்டது — $place.'),
    ]);
  }

  // ------------------------------------------------------------- extraction

  /// Finds every field mentioned in [text]: values after (or, in Hindi /
  /// Kannada / Tamil word order, before) a field's name, unlabelled mobile
  /// numbers and crops, and the rest as the answer to [expecting].
  Extraction extract(String text, {String? expecting}) {
    final u = Utterance(text);
    final out = Extraction();
    final labelLex = {for (final f in FarmerFormSpec.fields) f.id: f.labels};
    final chosen = <PhraseMatch<String>>[];
    for (final m in PhraseMatcher.findAll(u, labelLex, minScore: 0.9)) {
      if (u.isFree(m.start, m.length)) {
        u.consume(m.start, m.length);
        chosen.add(m);
      }
    }
    chosen.sort((a, b) => a.start.compareTo(b.start));
    final claimed = List<bool>.filled(u.length, false);
    for (final m in chosen) {
      for (var i = m.start; i < m.start + m.length; i++) {
        claimed[i] = true;
      }
    }

    String spanText(int from, int to) =>
        [for (var i = from; i < to; i++) if (!claimed[i]) u.tokens[i].raw].join(' ');

    void claim(FieldSpec f, int from, int to, Parsed p) {
      final heard = (p.value?.heard ?? p.problem?.heard ?? '').split(' ').toSet();
      final digitsOnly = const {
        FieldKind.phone, FieldKind.aadhaar, FieldKind.pin, FieldKind.account,
      }.contains(f.kind);
      for (var i = from; i < to; i++) {
        if (claimed[i]) continue;
        final t = u.tokens[i];
        final take = switch (f.kind) {
          FieldKind.dropdown => heard.contains(t.raw),
          FieldKind.area => heard.contains(t.raw) || t.numeric != null,
          _ when digitsOnly => t.numeric != null || t.isDigits || heard.contains(t.raw),
          _ => true,
        };
        if (take) claimed[i] = true;
      }
    }

    // 1. Labelled values: the words after a field's name, else before it.
    final pending = <PhraseMatch<String>>[];
    for (var k = 0; k < chosen.length; k++) {
      final m = chosen[k];
      final f = FarmerFormSpec.byId[m.value]!;
      final from = m.start + m.length;
      final to = k + 1 < chosen.length ? chosen[k + 1].start : u.length;
      final p = ValueParsers.parse(f, spanText(from, to));
      if (p.isEmpty) {
        pending.add(m);
        continue;
      }
      claim(f, from, to, p);
      out.add(f.id, p);
    }
    for (final m in pending) {
      final f = FarmerFormSpec.byId[m.value]!;
      final k = chosen.indexOf(m);
      final from = k > 0 ? chosen[k - 1].start + chosen[k - 1].length : 0;
      var p = ValueParsers.parse(f, spanText(from, m.start));
      if (p.isEmpty && f.isDropdown) p = ValueParsers.choice(f, spanText(0, u.length));
      if (p.isEmpty) continue;
      claim(f, from, m.start, p);
      out.add(f.id, p);
    }

    // 2. Unlabelled details that can't be anything else.
    const digitFields = {'mobile', 'aadhaar', 'pin', 'bankAccount', 'area', 'dob'};
    if (!digitFields.contains(expecting) && !out.has('mobile') && !filled('mobile')) {
      final p = ValueParsers.parse(FarmerFormSpec.byId['mobile']!, spanText(0, u.length));
      if (p.value != null) {
        claim(FarmerFormSpec.byId['mobile']!, 0, u.length, p);
        out.add('mobile', p);
      }
    }
    if (expecting != 'project' && !out.has('project') && !filled('project')) {
      final f = FarmerFormSpec.byId['project']!;
      final rest = spanText(0, u.length);
      final p = ValueParsers.choice(f, rest);
      if (p.value != null && p.value!.confidence >= 0.9 && rest.split(' ').length > 1) {
        claim(f, 0, u.length, p);
        out.add('project', p);
      }
    }

    // 3. Whatever is left answers the question that was asked.
    if (expecting != null && !out.has(expecting)) {
      final f = FarmerFormSpec.byId[expecting];
      if (f != null) {
        final p = ValueParsers.parse(f, spanText(0, u.length));
        if (!p.isEmpty) out.add(f.id, p);
      }
    }
    return out;
  }

  // ---------------------------------------------------------------- replies

  AgentReply _apply(Extraction e) {
    final parts = <String>[];
    final speech = <String>[];
    final filledNow = <String, FieldValue>{};
    for (final entry in e.values.entries) {
      final f = FarmerFormSpec.byId[entry.key]!;
      final v = entry.value;
      values[f.id] = v.value;
      if (f.id == 'area' && v.unit != null) values['areaUnit'] = v.unit!;
      filledNow[f.id] = v;
      skipped.remove(f.id);
      _lastFilled = f.id;
    }
    if (filledNow.isNotEmpty) {
      _misses = 0;
      final (text, spoken) = _ack(filledNow);
      parts.add(text);
      speech.add(spoken);
      if (filledNow['dob']?.approximate == true) {
        final note = _t("I've set the birth year from the age — you can fix the exact date later.",
            'उम्र से जन्म का साल भर दिया है — सही तारीख बाद में ठीक कर सकते हैं।',
            'ವಯಸ್ಸಿನಿಂದ ಹುಟ್ಟಿದ ವರ್ಷ ತುಂಬಿದೆ — ನಿಖರ ದಿನಾಂಕವನ್ನು ನಂತರ ಸರಿಪಡಿಸಬಹುದು.',
            'வயதிலிருந்து பிறந்த ஆண்டை நிரப்பினேன் — சரியான தேதியைப் பிறகு திருத்தலாம்.');
        parts.add(note);
        speech.add(note);
      }
    }

    // A problem with what was said: explain and ask for that field again.
    if (e.problems.isNotEmpty) {
      final id = e.problems.keys.first;
      final f = FarmerFormSpec.byId[id]!;
      final (text, spoken, chips) = _problem(f, e.problems[id]!);
      asking = id;
      mode = AgentMode.asking;
      return AgentReply([...parts, text].join(' '),
          speech: [...speech, spoken].join(' '), chips: chips, asking: id, filled: filledNow);
    }

    if (filledNow.isEmpty) {
      _misses++;
      final sorry = _t("Sorry, I didn't get that.", 'माफ़ कीजिए, समझ नहीं आया।', 'ಕ್ಷಮಿಸಿ, ಅರ್ಥವಾಗಲಿಲ್ಲ.', 'மன்னிக்கவும், புரியவில்லை.');
      final f = asking == null ? null : FarmerFormSpec.byId[asking];
      if (_misses >= 2 && f != null && !f.required) {
        _misses = 0;
        skipped.add(f.id);
        return _next([
          sorry,
          _t("Let's leave ${f.spokenName(lang)} for now.", '${f.spokenName(lang)} अभी छोड़ देते हैं।',
              '${f.spokenName(lang)} ಈಗ ಬಿಡೋಣ.', '${f.spokenName(lang)} இப்போது விட்டுவிடுவோம்.'),
        ]);
      }
      if (_misses >= 2 && f != null) {
        return _next([
          sorry,
          _t('You can also type it in the field.', 'आप इसे फ़ील्ड में टाइप भी कर सकते हैं।',
              'ನೀವು ಇದನ್ನು ಫೀಲ್ಡ್‌ನಲ್ಲಿ ಟೈಪ್ ಕೂಡ ಮಾಡಬಹುದು.', 'இதைப் புலத்தில் தட்டச்சும் செய்யலாம்.'),
        ], again: true);
      }
      return _next([sorry], again: true);
    }
    if (mode == AgentMode.editing || mode == AgentMode.confirming) {
      return _confirm(prefix: parts, prefixSpeech: speech, filled: filledNow);
    }
    return _next(parts, speech: speech, filled: filledNow);
  }

  /// Moves on to the next question (or offer / confirmation).
  AgentReply _next(List<String> prefix,
      {List<String>? speech, Map<String, FieldValue> filled = const {}, bool again = false}) {
    if (mode == AgentMode.confirming && again) return _confirm(prefix: prefix, prefixSpeech: speech);
    if (mode == AgentMode.offering && again) return _offer(prefix: prefix, prefixSpeech: speech);
    if (mode == AgentMode.editing && again) {
      return AgentReply([...prefix, _t('What would you like to change?', 'क्या बदलना है?', 'ಏನು ಬದಲಿಸಬೇಕು?', 'எதை மாற்ற வேண்டும்?')].join(' '));
    }

    // Required fields first; they can't be skipped.
    for (final f in _required) {
      if (!filled_(f.id)) return _ask(f, prefix, speech, filled);
    }
    if (section != null) {
      if (section == FormSection.address && !_locationAsked && _addressEmpty) {
        asking = _locationField;
        mode = AgentMode.asking;
        final q = _t('Shall I fill the address from your current location?',
            'क्या पता आपकी मौजूदा लोकेशन से भर दूँ?',
            'ಪ್ರಸ್ತುತ ಸ್ಥಳದಿಂದ ವಿಳಾಸ ತುಂಬಲೇ?',
            'தற்போதைய இடத்திலிருந்து முகவரியை நிரப்பட்டுமா?');
        return AgentReply([...prefix, q].join(' '),
            speech: [...(speech ?? prefix), q].join(' '),
            chips: [_yesWord, _noWord],
            asking: _locationField,
            filled: filled);
      }
      for (final f in FarmerFormSpec.inSection(section!)) {
        if (f.askable && !filled_(f.id) && !skipped.contains(f.id)) return _ask(f, prefix, speech, filled);
      }
      finished.add(section!);
      final done = section!;
      section = _queue.isEmpty ? null : _queue.removeAt(0);
      if (section != null) return _next(prefix, speech: speech, filled: filled);
      return _offer(prefix: prefix, prefixSpeech: speech, filled: filled, justDone: done);
    }
    return _offer(prefix: prefix, prefixSpeech: speech, filled: filled);
  }

  bool filled_(String id) => filled(id);

  bool get _addressEmpty => FarmerFormSpec.inSection(FormSection.address).every((f) => !filled(f.id));

  AgentReply _ask(FieldSpec f, List<String> prefix, List<String>? speech, Map<String, FieldValue> filled) {
    mode = AgentMode.asking;
    if (asking != f.id) _history.add(f.id);
    asking = f.id;
    final q = f.ask(lang);
    return AgentReply(
      [...prefix, q].join(' '),
      speech: [...(speech ?? prefix), q].join(' '),
      chips: [
        if (f.isDropdown) ...f.choices.take(8).map((c) => c.label),
        if (!f.required) _skipWord,
      ],
      asking: f.id,
      filled: filled,
    );
  }

  List<FormSection> _openSections() => [
        for (final s in [FormSection.personal, FormSection.address, FormSection.additional])
          if (!finished.contains(s) &&
              FarmerFormSpec.inSection(s).any((f) => f.askable && !filled(f.id) && !skipped.contains(f.id)))
            s,
      ];

  String _list(List<String> items) {
    if (items.length == 1) return items.first;
    final and = _t('and', 'और', 'ಮತ್ತು', 'மற்றும்');
    return '${items.sublist(0, items.length - 1).join(', ')} $and ${items.last}';
  }

  AgentReply _offer(
      {List<String> prefix = const [],
      List<String>? prefixSpeech,
      Map<String, FieldValue> filled = const {},
      FormSection? justDone}) {
    final open = _openSections();
    if (open.isEmpty) return _confirm(prefix: prefix, prefixSpeech: prefixSpeech, filled: filled);
    mode = AgentMode.offering;
    asking = null;
    final names = _list([for (final s in open) FarmerFormSpec.sectionName(s, lang)]);
    final empty = [
      for (final s in open) ...FarmerFormSpec.inSection(s).where((f) => f.askable && !this.filled(f.id))
    ].length;
    final String q;
    if (!_offeredOnce) {
      _offeredOnce = true;
      q = _t(
        'Great, the required details are done. $empty optional fields are still empty — $names. Would you like to fill any of them, or shall I submit?',
        'बढ़िया, ज़रूरी जानकारी पूरी हो गई। अभी $empty वैकल्पिक फ़ील्ड खाली हैं — $names। क्या इनमें से कुछ भरना चाहेंगे, या सबमिट कर दूँ?',
        'ಚೆನ್ನಾಗಿದೆ, ಕಡ್ಡಾಯ ಮಾಹಿತಿ ಪೂರ್ಣವಾಯಿತು. ಇನ್ನೂ $empty ಐಚ್ಛಿಕ ಮಾಹಿತಿ ಖಾಲಿ ಇದೆ — $names. ಯಾವುದಾದರೂ ತುಂಬಬೇಕೆ, ಅಥವಾ ಸಬ್ಮಿಟ್ ಮಾಡಲೇ?',
        'நன்று, கட்டாய விவரங்கள் முடிந்தன. இன்னும் $empty விருப்ப விவரங்கள் காலியாக உள்ளன — $names. ஏதாவது நிரப்ப வேண்டுமா, அல்லது சமர்ப்பிக்கட்டுமா?',
      );
    } else {
      final done = justDone == null ? '' : '${_capital(FarmerFormSpec.sectionName(justDone, lang))} — ${_t('done.', 'पूरा।', 'ಮುಗಿಯಿತು.', 'முடிந்தது.')} ';
      q = done +
          _t('Would you like to add $names too, or shall I submit?', 'क्या $names भी भरना है, या सबमिट कर दूँ?',
              '$names ಕೂಡ ತುಂಬಬೇಕೆ, ಅಥವಾ ಸಬ್ಮಿಟ್ ಮಾಡಲೇ?', '$names கூட நிரப்ப வேண்டுமா, அல்லது சமர்ப்பிக்கட்டுமா?');
    }
    return AgentReply(
      [...prefix, q].join(' '),
      speech: [...(prefixSpeech ?? prefix), q].join(' '),
      chips: [
        for (final s in open) _capital(FarmerFormSpec.sectionName(s, lang)),
        _submitWord,
        _draftWord,
      ],
      filled: filled,
    );
  }

  String _capital(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  AgentReply _confirm(
      {List<String> prefix = const [], List<String>? prefixSpeech, Map<String, FieldValue> filled = const {}}) {
    for (final f in _required) {
      if (!this.filled(f.id)) return _ask(f, prefix, prefixSpeech, filled);
    }
    mode = AgentMode.confirming;
    asking = null;
    final project = FarmerFormSpec.byId['project']!.choice(values['project'])?.label ?? '';
    final phone = values['mobile'] ?? '';
    final extra = FarmerFormSpec.fields.where((f) => !f.required && f.askable && this.filled(f.id)).length;
    final more = extra == 0
        ? ''
        : _t(', and $extra more details', ', और $extra अन्य जानकारी', ', ಮತ್ತು ಇನ್ನೂ $extra ವಿವರಗಳು', ', மேலும் $extra விவரங்கள்');
    final summary = '${values['name']}, ${_groupDigits(phone)}, $project$more';
    final summarySpeech = '${values['name']}, ${_spaced(phone)}, $project$more';
    final q = _t('Shall I submit?', 'सबमिट कर दूँ?', 'ಸಬ್ಮಿಟ್ ಮಾಡಲೇ?', 'சமர்ப்பிக்கட்டுமா?');
    final head = _t('Here is the summary:', 'सारांश:', 'ಸಾರಾಂಶ:', 'சுருக்கம்:');
    return AgentReply(
      [...prefix, '$head $summary.', q].join(' '),
      speech: [...(prefixSpeech ?? prefix), '$head $summarySpeech.', q].join(' '),
      chips: [_yesWord, _changeWord, _draftWord],
      filled: filled,
    );
  }

  AgentReply _submit() {
    for (final f in _required) {
      if (!filled(f.id)) {
        return _ask(f, [
          _t('Before submitting I still need the ${f.spokenName(lang)}.',
              'सबमिट करने से पहले ${f.spokenName(lang)} चाहिए।',
              'ಸಬ್ಮಿಟ್ ಮಾಡುವ ಮೊದಲು ${f.spokenName(lang)} ಬೇಕು.',
              'சமர்ப்பிக்கும் முன் ${f.spokenName(lang)} தேவை.'),
        ], null, const {});
      }
    }
    mode = AgentMode.done;
    asking = null;
    return AgentReply(
      _t('Submitting.', 'सबमिट कर रहा हूँ।', 'ಸಬ್ಮಿಟ್ ಮಾಡುತ್ತಿದ್ದೇನೆ.', 'சமர்ப்பிக்கிறேன்.'),
      action: AgentAction.submit,
      listen: false,
    );
  }

  AgentReply _back() {
    if (_history.length < 2) return repeat();
    _history.removeLast();
    final id = _history.removeLast();
    final f = FarmerFormSpec.byId[id]!;
    final current = filled(id) ? _display(f, values[id]!) : null;
    final r = _ask(f, const [], null, const {});
    if (current == null) return r;
    final note = _t("${_capital(f.spokenName(lang))} is $current. Say the new value, or 'next' to keep it.",
        "${f.spokenName(lang)} अभी $current है। नई जानकारी बोलिए, या रखने के लिए 'आगे' कहिए।",
        "${f.spokenName(lang)} ಈಗ $current. ಹೊಸ ಮಾಹಿತಿ ಹೇಳಿ, ಅಥವಾ ಹಾಗೇ ಇಡಲು 'ಮುಂದೆ' ಹೇಳಿ.",
        "${f.spokenName(lang)} இப்போது $current. புதியதைச் சொல்லுங்கள், அல்லது வைத்துக்கொள்ள 'அடுத்து' சொல்லுங்கள்.");
    return AgentReply(note, chips: r.chips, asking: id);
  }

  AgentReply _skip() {
    final f = asking == null ? null : FarmerFormSpec.byId[asking];
    if (f == null) return _next(const []);
    if (f.required && !filled(f.id)) {
      return _ask(f, [
        _t('The ${f.spokenName(lang)} is required, so I need this one.',
            '${f.spokenName(lang)} ज़रूरी है, इसे भरना होगा।',
            '${f.spokenName(lang)} ಕಡ್ಡಾಯ, ಇದನ್ನು ತುಂಬಬೇಕು.',
            '${f.spokenName(lang)} கட்டாயம், இதை நிரப்ப வேண்டும்.'),
      ], null, const {});
    }
    skipped.add(f.id);
    return _next([
      _t('Okay, skipping that.', 'ठीक है, इसे छोड़ते हैं।', 'ಸರಿ, ಇದನ್ನು ಬಿಡೋಣ.', 'சரி, இதைத் தவிர்க்கிறேன்.'),
    ]);
  }

  AgentReply _skipSection() {
    if (section != null) {
      finished.add(section!);
      final done = section!;
      section = _queue.isEmpty ? null : _queue.removeAt(0);
      if (section != null) return _next(const []);
      return _offer(justDone: done);
    }
    return _confirm();
  }

  AgentReply _noInput() {
    _silences++;
    if (_silences >= 2) {
      _silences = 0;
      return AgentReply(
        _t("I'll wait. Tap the mic when you're ready.", 'मैं इंतज़ार करता हूँ। तैयार हों तो माइक दबाइए।',
            'ನಾನು ಕಾಯುತ್ತೇನೆ. ಸಿದ್ಧವಾದಾಗ ಮೈಕ್ ಒತ್ತಿ.', 'நான் காத்திருக்கிறேன். தயாரானதும் மைக்கை அழுத்துங்கள்.'),
        asking: asking,
        action: AgentAction.pause,
        listen: false,
      );
    }
    return _next([
      _t("I didn't hear anything.", 'मुझे कुछ सुनाई नहीं दिया।', 'ನನಗೆ ಏನೂ ಕೇಳಿಸಲಿಲ್ಲ.', 'எனக்கு எதுவும் கேட்கவில்லை.'),
    ], again: true);
  }

  // ------------------------------------------------------- spoken read-backs

  static String _groupDigits(String d) => d.length == 10 ? '${d.substring(0, 5)} ${d.substring(5)}' : d;

  static String _spaced(String d) {
    final s = d.split('').join(' ');
    return d.length == 10 ? '${d.substring(0, 5).split('').join(' ')}, ${d.substring(5).split('').join(' ')}' : s;
  }

  String _display(FieldSpec f, String v) {
    if (f.isDropdown) return f.choice(v)?.label ?? v;
    if (f.id == 'area') return '$v ${values['areaUnit'] ?? 'acre'}';
    return v;
  }

  (String, String) _readback(FieldSpec f, String v) => switch (f.kind) {
        FieldKind.phone => (_groupDigits(v), _spaced(v)),
        FieldKind.aadhaar || FieldKind.account => (
            _t('ending ${v.substring(v.length - 4)}', 'आख़िरी अंक ${v.substring(v.length - 4)}',
                'ಕೊನೆಯ ಅಂಕಿಗಳು ${v.substring(v.length - 4)}', 'கடைசி இலக்கங்கள் ${v.substring(v.length - 4)}'),
            _t('ending ${_spaced(v.substring(v.length - 4))}', 'आख़िरी अंक ${_spaced(v.substring(v.length - 4))}',
                'ಕೊನೆಯ ಅಂಕಿಗಳು ${_spaced(v.substring(v.length - 4))}',
                'கடைசி இலக்கங்கள் ${_spaced(v.substring(v.length - 4))}'),
          ),
        FieldKind.pin || FieldKind.pan || FieldKind.ifsc => (v, _spaced(v)),
        _ => (_display(f, v), _display(f, v)),
      };

  (String, String) _ack(Map<String, FieldValue> filled) {
    final ok = _t('Got it', 'ठीक है', 'ಸರಿ', 'சரி');
    if (filled.length == 1) {
      final f = FarmerFormSpec.byId[filled.keys.first]!;
      final (text, spoken) = _readback(f, filled.values.first.value);
      final name = f.spokenName(lang);
      return ('$ok — $name: $text.', '$ok — $name: $spoken.');
    }
    final names = _list([for (final id in filled.keys) FarmerFormSpec.byId[id]!.spokenName(lang)]);
    final s = '$ok — $names.';
    return (s, s);
  }

  (String, String, List<String>) _problem(FieldSpec f, ValueProblem p) {
    final name = f.spokenName(lang);
    switch (p.kind) {
      case ProblemKind.digits:
        final heard = _groupDigits(p.heard);
        String msg(String digits) => _t(
            'I heard ${p.got} digits — $digits. The $name needs ${p.need} digits. Please say it again.',
            'मैंने ${p.got} अंक सुने — $digits। $name में ${p.need} अंक होने चाहिए। कृपया फिर से बताइए।',
            'ನಾನು ${p.got} ಅಂಕಿಗಳು ಕೇಳಿದೆ — $digits. $name ಗೆ ${p.need} ಅಂಕಿಗಳು ಬೇಕು. ದಯವಿಟ್ಟು ಮತ್ತೆ ಹೇಳಿ.',
            'நான் ${p.got} இலக்கங்கள் கேட்டேன் — $digits. $name க்கு ${p.need} இலக்கங்கள் வேண்டும். மீண்டும் சொல்லுங்கள்.');
        return (msg(heard), msg(_spaced(p.heard)), const []);
      case ProblemKind.ambiguous:
        final opts = p.options.take(3).map((c) => c.label).toList();
        final or = _t('or', 'या', 'ಅಥವಾ', 'அல்லது');
        final which = opts.length == 2 ? '${opts[0]} $or ${opts[1]}' : opts.join(', ');
        final s = _t('Did you mean $which?', 'आपका मतलब $which है?', '$which — ಯಾವುದು?', '$which — எது?');
        return (s, s, opts);
      case ProblemKind.noMatch:
        final opts = f.choices.take(3).map((c) => c.label).toList();
        final s = _t(
            "I couldn't find that in the $name list. You can say ${_list(opts)}.",
            '$name की सूची में यह नहीं मिला। आप ${_list(opts)} बोल सकते हैं।',
            '$name ಪಟ್ಟಿಯಲ್ಲಿ ಇದು ಸಿಗಲಿಲ್ಲ. ${_list(opts)} ಹೇಳಬಹುದು.',
            '$name பட்டியலில் இது இல்லை. ${_list(opts)} என்று சொல்லலாம்.');
        return (s, s, [...f.choices.take(8).map((c) => c.label), if (!f.required) _skipWord]);
      case ProblemKind.invalid:
        final s = switch (f.kind) {
          FieldKind.date => _t("I couldn't read that date. Please say it like '15 August 1980', or just the age.",
              "तारीख समझ नहीं आई। ऐसे बोलिए — '15 अगस्त 1980', या सिर्फ़ उम्र।",
              "ದಿನಾಂಕ ಅರ್ಥವಾಗಲಿಲ್ಲ. ಹೀಗೆ ಹೇಳಿ — '15 ಆಗಸ್ಟ್ 1980', ಅಥವಾ ವಯಸ್ಸು ಮಾತ್ರ.",
              "தேதி புரியவில்லை. இப்படிச் சொல்லுங்கள் — '15 ஆகஸ்ட் 1980', அல்லது வயது மட்டும்."),
          FieldKind.email => _t("I heard ${p.heard} — that doesn't look like an email. Please say it like 'ramesh at gmail dot com'.",
              "मैंने ${p.heard} सुना — यह ईमेल जैसा नहीं लगता। ऐसे बोलिए — 'ramesh at gmail dot com'।",
              "ನಾನು ${p.heard} ಕೇಳಿದೆ — ಇದು ಇಮೇಲ್ ಅಲ್ಲ ಎನಿಸುತ್ತದೆ. ಹೀಗೆ ಹೇಳಿ — 'ramesh at gmail dot com'.",
              "நான் ${p.heard} கேட்டேன் — இது மின்னஞ்சல் போல இல்லை. இப்படிச் சொல்லுங்கள் — 'ramesh at gmail dot com'."),
          FieldKind.pan => _t('I heard ${p.heard}. A PAN has 5 letters, 4 numbers and then a letter — please say it again.',
              'मैंने ${p.heard} सुना। पैन में 5 अक्षर, 4 अंक और फिर एक अक्षर होता है — कृपया फिर से बोलिए।',
              'ನಾನು ${p.heard} ಕೇಳಿದೆ. ಪ್ಯಾನ್‌ನಲ್ಲಿ 5 ಅಕ್ಷರ, 4 ಅಂಕಿ, ನಂತರ ಒಂದು ಅಕ್ಷರ ಇರುತ್ತದೆ — ಮತ್ತೆ ಹೇಳಿ.',
              'நான் ${p.heard} கேட்டேன். பான் எண்ணில் 5 எழுத்துகள், 4 எண்கள், பின் ஒரு எழுத்து இருக்கும் — மீண்டும் சொல்லுங்கள்.'),
          FieldKind.ifsc => _t('I heard ${p.heard}. An IFSC has 4 letters, a zero, then 6 letters or numbers — please say it again.',
              'मैंने ${p.heard} सुना। आईएफएससी में 4 अक्षर, एक शून्य, फिर 6 अक्षर या अंक होते हैं — कृपया फिर से बोलिए।',
              'ನಾನು ${p.heard} ಕೇಳಿದೆ. ಐಎಫ್‌ಎಸ್‌ಸಿಯಲ್ಲಿ 4 ಅಕ್ಷರ, ಒಂದು ಸೊನ್ನೆ, ನಂತರ 6 ಅಕ್ಷರ ಅಥವಾ ಅಂಕಿ ಇರುತ್ತವೆ — ಮತ್ತೆ ಹೇಳಿ.',
              'நான் ${p.heard} கேட்டேன். ஐஎஃப்எஸ்சியில் 4 எழுத்துகள், ஒரு பூஜ்ஜியம், பின் 6 எழுத்துகள் அல்லது எண்கள் இருக்கும் — மீண்டும் சொல்லுங்கள்.'),
          _ => _t("Sorry, I couldn't use that for the $name. Please say it again.",
              'माफ़ कीजिए, $name के लिए यह समझ नहीं आया। कृपया फिर से बोलिए।',
              'ಕ್ಷಮಿಸಿ, $name ಗೆ ಇದು ಅರ್ಥವಾಗಲಿಲ್ಲ. ಮತ್ತೆ ಹೇಳಿ.',
              'மன்னிக்கவும், $name க்கு இது புரியவில்லை. மீண்டும் சொல்லுங்கள்.'),
        };
        return (s, s, [if (!f.required) _skipWord]);
    }
  }

  // ------------------------------------------------------------ vocabulary

  String get _yesWord => _t('Yes', 'हाँ', 'ಹೌದು', 'ஆம்');
  String get _noWord => _t('No', 'नहीं', 'ಇಲ್ಲ', 'இல்லை');
  String get _skipWord => _t('Skip', 'छोड़ें', 'ಬಿಡಿ', 'தவிர்');
  String get _submitWord => _t('Submit', 'सबमिट', 'ಸಬ್ಮಿಟ್', 'சப்மிட்');
  String get _draftWord => _t('Save draft', 'ड्राफ्ट सेव करें', 'ಡ್ರಾಫ್ಟ್ ಉಳಿಸಿ', 'டிராஃப்ட் சேமி');
  String get _changeWord => _t('No, change something', 'नहीं, कुछ बदलना है', 'ಇಲ್ಲ, ಬದಲಿಸಬೇಕು', 'இல்லை, மாற்ற வேண்டும்');

  static String _norm(String s) => TextUtils.normalize(s)
      .split(' ')
      .where((w) => !const {'please', 'कृपया', 'ದಯವಿಟ್ಟು', 'தயவுசெய்து', 'pls'}.contains(w))
      .join(' ');

  static const _yes = {
    'yes', 'yeah', 'yep', 'yup', 'sure', 'ok', 'okay', 'haan', 'han', 'हाँ', 'हां', 'हा', 'जी', 'ठीक',
    'चलो', 'ಹೌದು', 'ಸರಿ', 'ಹಾ', 'ಹೂಂ', 'ಓಕೆ', 'ஆமாம்', 'ஆம்', 'சரி', 'ஓகே', 'ஆமா',
  };
  static const _thanks = {'thanks', 'thank', 'you', 'धन्यवाद', 'शुक्रिया', 'ಧನ್ಯವಾದ', 'நன்றி'};
  static const _no = {
    'no', 'nope', 'nah', 'नहीं', 'नही', 'ना', 'ಇಲ್ಲ', 'ಬೇಡ', 'ಬೇಡಾ', 'இல்லை', 'வேண்டாம்', 'இல்ல',
  };

  static bool _isYes(String norm) {
    final w = norm.split(' ');
    return w.length <= 4 && w.any(_yes.contains) && !w.any(_no.contains);
  }

  static bool _isNo(String norm) {
    final w = norm.split(' ');
    return w.length <= 4 && w.any(_no.contains);
  }

  static const _commands = <_Cmd, List<String>>{
    _Cmd.stop: [
      'stop', 'pause', 'stop listening', 'रुको', 'रुकिए', 'बंद करो', 'ठहरो', 'स्टॉप', 'ನಿಲ್ಲಿಸಿ', 'ನಿಲ್ಲು', 'ಸ್ಟಾಪ್',
      'நிறுத்து', 'நிறுத்துங்கள்', 'ஸ்டாப்',
    ],
    _Cmd.repeat: [
      'repeat', 'say again', 'say that again', 'pardon', 'come again', 'what', 'दोबारा', 'फिर से', 'फिर से बोलो',
      'क्या', 'ಮತ್ತೆ ಹೇಳಿ', 'ಏನು', 'மறுபடி', 'மீண்டும் சொல்லுங்கள்', 'என்ன',
    ],
    _Cmd.back: ['go back', 'back', 'previous', 'पीछे', 'पिछला', 'वापस', 'ಹಿಂದೆ', 'ಹಿಂದಿನ', 'முந்தைய', 'பின்னால்'],
    _Cmd.skip: [
      'skip', 'next', 'skip it', 'skip this', 'later', 'leave it', 'not now', 'dont know', "don't know", 'no idea',
      'छोड़ो', 'छोड़ दो', 'छोड़ें', 'आगे', 'बाद में', 'पता नहीं', 'मालूम नहीं', 'स्किप', 'ಬಿಡಿ', 'ಬಿಟ್ಟುಬಿಡಿ',
      'ಮುಂದೆ', 'ಆಮೇಲೆ', 'ಗೊತ್ತಿಲ್ಲ', 'ಸ್ಕಿಪ್', 'விடு', 'விடுங்கள்', 'தவிர்', 'அடுத்து', 'பிறகு', 'தெரியாது', 'ஸ்கிப்',
    ],
    _Cmd.skipAll: [
      'skip all', 'skip section', 'skip the rest', 'that is all', 'thats all', "that's all", 'no more', 'enough',
      'बस इतना', 'और नहीं', 'ಸಾಕು', 'ಇಷ್ಟೇ', 'போதும்', 'அவ்வளவுதான்',
    ],
    _Cmd.submit: [
      'submit', 'submit it', 'सबमिट', 'सबमिट करो', 'सबमिट कर दो', 'जमा करो', 'ಸಬ್ಮಿಟ್', 'ಸಬ್ಮಿಟ್ ಮಾಡಿ', 'ಸಲ್ಲಿಸಿ',
      'சப்மிட்', 'சமர்ப்பி', 'சமர்ப்பிக்கவும்',
    ],
    _Cmd.draft: [
      'save draft', 'save as draft', 'draft', 'ड्राफ्ट', 'ड्राफ्ट सेव करें', 'ड्राफ्ट सेव करो', 'ड्राफ्ट सेव', 'ಡ್ರಾಫ್ಟ್',
      'ಡ್ರಾಫ್ಟ್ ಉಳಿಸಿ', 'டிராஃப்ட்', 'டிராஃப்ட் சேமி', 'வரைவு',
    ],
    _Cmd.help: ['help', 'what can i say', 'मदद', 'ಸಹಾಯ', 'உதவி'],
  };

  /// A command is the whole (short) utterance: "skip", "छोड़ दो", "ಸಬ್ಮಿಟ್ ಮಾಡಿ".
  static _Cmd? _command(String norm) {
    final words = norm.split(' ');
    if (words.length > 4) return null;
    for (final e in _commands.entries) {
      for (final p in e.value) {
        final phrase = TextUtils.normalize(p);
        if (norm == phrase) return e.key;
        // one-word command with a polite/carrier word around it ("skip it please")
        if (words.length <= 3 && phrase.split(' ').length >= 1 && ' $norm '.contains(' $phrase ') &&
            !(e.key == _Cmd.repeat && words.length > 1)) {
          return e.key;
        }
      }
    }
    return null;
  }

  static List<FormSection> _sections(String norm) {
    final allWords = {'all', 'everything', 'सब', 'सभी', 'सब कुछ', 'ಎಲ್ಲಾ', 'ಎಲ್ಲವೂ', 'எல்லாம்', 'அனைத்தும்'};
    final words = norm.split(' ');
    if (words.length <= 3 && words.any(allWords.contains)) {
      return [FormSection.personal, FormSection.address, FormSection.additional];
    }
    final out = <FormSection>[];
    final u = Utterance(norm);
    final found = PhraseMatcher.findAll(u, FarmerFormSpec.sectionWords, minScore: 0.9)
      ..sort((a, b) => a.start.compareTo(b.start));
    for (final m in found) {
      if (!out.contains(m.value)) out.add(m.value);
    }
    return out;
  }
}

class Extraction {
  final Map<String, FieldValue> values = {};
  final Map<String, ValueProblem> problems = {};

  bool has(String id) => values.containsKey(id) || problems.containsKey(id);

  void add(String id, Parsed p) {
    if (p.value != null) {
      values[id] = p.value!;
      problems.remove(id);
    } else if (p.problem != null && !values.containsKey(id)) {
      problems[id] = p.problem!;
    }
  }

  double get score => values.length - 0.5 * problems.length;
}
