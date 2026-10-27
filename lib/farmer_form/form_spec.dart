import '../data/demo_data.dart';
import '../voice/agent_language.dart';
import '../voice/nlu/lexicon.dart';

/// What kind of value a field holds; decides how speech is parsed.
enum FieldKind { name, text, place, phone, dropdown, date, area, aadhaar, email, pin, ifsc, pan, account }

enum FormSection { primary, personal, address, additional }

/// One option of a dropdown, with spoken aliases in all four languages.
class Choice {
  const Choice(this.id, this.label, [this.aliases = const []]);
  final String id;
  final String label;
  final List<String> aliases;
}

/// Picks the phrase for [lang] from English / Hindi / Kannada / Tamil.
String tr(AgentLanguage lang, String en, String hi, String kn, String ta) => switch (lang) {
      AgentLanguage.english => en,
      AgentLanguage.hindi => hi,
      AgentLanguage.kannada => kn,
      AgentLanguage.tamil => ta,
    };

class FieldSpec {
  const FieldSpec({
    required this.id,
    required this.label,
    required this.kind,
    required this.section,
    required this.spoken,
    required this.question,
    this.required = false,
    this.labels = const [],
    this.choices = const [],
    this.askable = true,
  });

  final String id;

  /// Label shown on the form.
  final String label;
  final FieldKind kind;
  final FormSection section;
  final bool required;

  /// Spoken phrases that introduce this field ("mobile number", "ಆಧಾರ್"…).
  final List<String> labels;
  final List<Choice> choices;

  /// The field's name in each language (en, hi, kn, ta) for spoken replies.
  final List<String> spoken;

  /// The question the agent asks (en, hi, kn, ta). `{a}` / `{b}` are
  /// replaced with example options for dropdowns.
  final List<String> question;

  /// False for fields the agent never asks about on its own.
  final bool askable;

  bool get isDropdown => kind == FieldKind.dropdown;

  String spokenName(AgentLanguage l) => tr(l, spoken[0], spoken[1], spoken[2], spoken[3]);

  String ask(AgentLanguage l) {
    var q = tr(l, question[0], question[1], question[2], question[3]);
    if (choices.isNotEmpty) {
      q = q.replaceAll('{a}', choices[0].label);
      q = q.replaceAll('{b}', choices.length > 1 ? choices[1].label : choices[0].label);
    }
    return q;
  }

  Choice? choice(String? id) {
    for (final c in choices) {
      if (c.id == id) return c;
    }
    return null;
  }
}

/// The Add Farmer form, field for field as in Cropin Grow.
class FarmerFormSpec {
  static String sectionName(FormSection s, AgentLanguage l) => switch (s) {
        FormSection.primary => tr(l, 'primary details', 'मुख्य जानकारी', 'ಮುಖ್ಯ ಮಾಹಿತಿ', 'முதன்மை விவரங்கள்'),
        FormSection.personal =>
          tr(l, 'personal details', 'निजी जानकारी', 'ವೈಯಕ್ತಿಕ ಮಾಹಿತಿ', 'தனிப்பட்ட விவரங்கள்'),
        FormSection.address => tr(l, 'address', 'पता', 'ವಿಳಾಸ', 'முகவரி'),
        FormSection.additional =>
          tr(l, 'bank and ID details', 'बैंक और पहचान विवरण', 'ಬ್ಯಾಂಕ್ ಮತ್ತು ಗುರುತಿನ ವಿವರ',
              'வங்கி மற்றும் அடையாள விவரங்கள்'),
      };

  /// Words that pick a section when the agent offers them.
  static const sectionWords = <FormSection, List<String>>{
    FormSection.personal: [
      'personal', 'personal details', 'personal information', 'निजी', 'निजी जानकारी', 'व्यक्तिगत',
      'पर्सनल', 'ವೈಯಕ್ತಿಕ', 'ವೈಯಕ್ತಿಕ ಮಾಹಿತಿ', 'ಪರ್ಸನಲ್', 'தனிப்பட்ட', 'தனிப்பட்ட விவரங்கள்', 'பர்சனல்',
    ],
    FormSection.address: [
      'address', 'एड्रेस', 'पता', 'ಅಡ್ರೆಸ್', 'ವಿಳಾಸ', 'முகவரி', 'அட்ரஸ்',
    ],
    FormSection.additional: [
      'bank', 'bank details', 'bank and id details', 'additional', 'id details', 'बैंक',
      'बैंक विवरण', 'बैंक और पहचान विवरण', 'अतिरिक्त', 'ಬ್ಯಾಂಕ್', 'ಬ್ಯಾಂಕ್ ವಿವರ',
      'ಬ್ಯಾಂಕ್ ಮತ್ತು ಗುರುತಿನ ವಿವರ', 'ಹೆಚ್ಚುವರಿ', 'வங்கி', 'வங்கி விவரங்கள்',
      'வங்கி மற்றும் அடையாள விவரங்கள்', 'கூடுதல்', 'பேங்க்',
    ],
  };

  static final List<Choice> projects = [
    for (final p in DemoData.projects)
      Choice(p.id, p.name, [
        p.name.replaceAll(RegExp(r'\d'), '').trim(),
        ...Lexicon.crop[p.crop] ?? const <String>[],
      ]),
  ];

  static const genders = [
    Choice('male', 'Male', [
      'male', 'man', 'gents', 'purush', 'पुरुष', 'आदमी', 'मेल', 'ಪುರುಷ', 'ಗಂಡು', 'ಮೇಲ್', 'ஆண்', 'மேல்',
    ]),
    Choice('female', 'Female', [
      'female', 'woman', 'lady', 'ladies', 'mahila', 'महिला', 'औरत', 'स्त्री', 'फीमेल', 'ಮಹಿಳೆ', 'ಹೆಣ್ಣು',
      'ಸ್ತ್ರೀ', 'ಫೀಮೇಲ್', 'பெண்', 'ஃபீமேல்', 'பீமேல்',
    ]),
    Choice('other', 'Other', ['other', 'others', 'अन्य', 'ಇತರೆ', 'ಇತರ', 'மற்றவை', 'மற்ற']),
  ];

  static const contractors = [
    Choice('c1', 'Sri Sai Agro Services', ['sai agro', 'sai', 'साई', 'साईं', 'ಸಾಯಿ', 'சாய்']),
    Choice('c2', 'Green Field Contractors', [
      'green field', 'greenfield', 'ग्रीन फील्ड', 'ಗ್ರೀನ್ ಫೀಲ್ಡ್', 'கிரீன் ஃபீல்ட்', 'கிரீன் பீல்டு',
    ]),
    Choice('c3', 'Kaveri Farm Services', ['kaveri', 'cauvery', 'कावेरी', 'ಕಾವೇರಿ', 'காவேரி']),
    Choice('c4', 'Annapurna Agri Contractors', ['annapurna', 'अन्नपूर्णा', 'ಅನ್ನಪೂರ್ಣ', 'அன்னபூர்ணா']),
    Choice('none', 'No contractor', [
      'none', 'no contractor', 'self', 'nobody', 'कोई नहीं', 'खुद', 'ಯಾರೂ ಇಲ್ಲ', 'ಸ್ವಂತ',
      'யாரும் இல்லை', 'சொந்தம்',
    ]),
  ];

  static final List<Choice> areaUnits = [
    for (final e in Lexicon.areaUnit.entries) Choice(e.key, e.key, e.value),
  ];

  static const languages = [
    Choice('English', 'English', ['english', 'इंग्लिश', 'अंग्रेज़ी', 'अंग्रेजी', 'ಇಂಗ್ಲಿಷ್', 'ಆಂಗ್ಲ', 'ஆங்கிலம்', 'இங்கிலீஷ்']),
    Choice('Hindi', 'Hindi', ['hindi', 'हिंदी', 'हिन्दी', 'ಹಿಂದಿ', 'இந்தி', 'ஹிந்தி']),
    Choice('Kannada', 'Kannada', ['kannada', 'कन्नड़', 'कन्नड', 'ಕನ್ನಡ', 'கன்னடம்']),
    Choice('Tamil', 'Tamil', ['tamil', 'तमिल', 'ತಮಿಳು', 'தமிழ்']),
    Choice('Telugu', 'Telugu', ['telugu', 'तेलुगु', 'ತೆಲುಗು', 'தெலுங்கு']),
    Choice('Marathi', 'Marathi', ['marathi', 'मराठी', 'ಮರಾಠಿ', 'மராத்தி']),
    Choice('Malayalam', 'Malayalam', ['malayalam', 'मलयालम', 'ಮಲಯಾಳಂ', 'மலையாளம்']),
    Choice('Bengali', 'Bengali', ['bengali', 'bangla', 'बंगाली', 'बांग्ला', 'ಬಂಗಾಳಿ', 'வங்காளம்']),
  ];

  static const countries = [
    Choice('India', 'India', [
      'india', 'bharat', 'भारत', 'इंडिया', 'हिंदुस्तान', 'ಭಾರತ', 'ಇಂಡಿಯಾ', 'இந்தியா', 'பாரதம்',
    ]),
    Choice('Nepal', 'Nepal', ['nepal', 'नेपाल', 'ನೇಪಾಳ', 'நேபாளம்']),
    Choice('Bangladesh', 'Bangladesh', ['bangladesh', 'बांग्लादेश', 'ಬಾಂಗ್ಲಾದೇಶ', 'வங்காளதேசம்']),
    Choice('Sri Lanka', 'Sri Lanka', ['sri lanka', 'srilanka', 'श्रीलंका', 'ಶ್ರೀಲಂಕಾ', 'இலங்கை']),
  ];

  static final List<Choice> locations = [
    for (final l in DemoData.localities.keys)
      Choice(l, l, DemoData.localityAliases[l] ?? [l.toLowerCase()]),
  ];

  /// States are a free-text field; known names are normalised.
  static const states = [
    Choice('Karnataka', 'Karnataka', ['karnataka', 'कर्नाटक', 'ಕರ್ನಾಟಕ', 'கர்நாடகா', 'கர்நாடகம்']),
    Choice('Tamil Nadu', 'Tamil Nadu', ['tamil nadu', 'tamilnadu', 'तमिलनाडु', 'तमिल नाडु', 'ತಮಿಳುನಾಡು', 'தமிழ்நாடு']),
    Choice('Bihar', 'Bihar', ['bihar', 'बिहार', 'ಬಿಹಾರ', 'பீகார்']),
    Choice('Andhra Pradesh', 'Andhra Pradesh', ['andhra pradesh', 'andhra', 'आंध्र प्रदेश', 'ಆಂಧ್ರ ಪ್ರದೇಶ', 'ஆந்திரப் பிரதேசம்', 'ஆந்திரா']),
    Choice('Telangana', 'Telangana', ['telangana', 'तेलंगाना', 'ತೆಲಂಗಾಣ', 'தெலுங்கானா']),
    Choice('Kerala', 'Kerala', ['kerala', 'केरल', 'ಕೇರಳ', 'கேரளா']),
    Choice('Maharashtra', 'Maharashtra', ['maharashtra', 'महाराष्ट्र', 'ಮಹಾರಾಷ್ಟ್ರ', 'மகாராஷ்டிரா']),
    Choice('Uttar Pradesh', 'Uttar Pradesh', ['uttar pradesh', 'up', 'उत्तर प्रदेश', 'ಉತ್ತರ ಪ್ರದೇಶ', 'உத்தரப் பிரதேசம்']),
    Choice('Madhya Pradesh', 'Madhya Pradesh', ['madhya pradesh', 'mp', 'मध्य प्रदेश', 'ಮಧ್ಯ ಪ್ರದೇಶ', 'மத்தியப் பிரதேசம்']),
    Choice('Gujarat', 'Gujarat', ['gujarat', 'गुजरात', 'ಗುಜರಾತ್', 'குஜராத்']),
    Choice('Rajasthan', 'Rajasthan', ['rajasthan', 'राजस्थान', 'ರಾಜಸ್ಥಾನ', 'ராஜஸ்தான்']),
    Choice('Punjab', 'Punjab', ['punjab', 'पंजाब', 'ಪಂಜಾಬ್', 'பஞ்சாப்']),
    Choice('West Bengal', 'West Bengal', ['west bengal', 'bengal', 'पश्चिम बंगाल', 'ಪಶ್ಚಿಮ ಬಂಗಾಳ', 'மேற்கு வங்காளம்']),
    Choice('Odisha', 'Odisha', ['odisha', 'orissa', 'ओडिशा', 'ಒಡಿಶಾ', 'ஒடிசா']),
  ];

  static const banks = [
    Choice('State Bank of India', 'State Bank of India', [
      'sbi', 'state bank', 'state bank of india', 'एसबीआई', 'स्टेट बैंक', 'ಎಸ್‌ಬಿಐ', 'ಎಸ್ಬಿಐ', 'ಸ್ಟೇಟ್ ಬ್ಯಾಂಕ್',
      'எஸ்பிஐ', 'ஸ்டேட் பேங்க்',
    ]),
    Choice('Canara Bank', 'Canara Bank', ['canara', 'canara bank', 'केनरा', 'ಕೆನರಾ', 'கனரா']),
    Choice('Bank of Baroda', 'Bank of Baroda', ['bank of baroda', 'baroda', 'बड़ौदा', 'ಬರೋಡಾ', 'பரோடா']),
    Choice('Union Bank of India', 'Union Bank of India', ['union bank', 'union', 'यूनियन', 'ಯೂನಿಯನ್', 'யூனியன்']),
    Choice('Punjab National Bank', 'Punjab National Bank', ['pnb', 'punjab national', 'पंजाब नेशनल', 'पीएनबी']),
    Choice('HDFC Bank', 'HDFC Bank', ['hdfc', 'एचडीएफसी', 'ಎಚ್‌ಡಿಎಫ್‌ಸಿ', 'ಎಚ್ಡಿಎಫ್ಸಿ', 'ஹெச்டிஎஃப்சி']),
    Choice('ICICI Bank', 'ICICI Bank', ['icici', 'आईसीआईसीआई', 'ಐಸಿಐಸಿಐ', 'ஐசிஐசிஐ']),
    Choice('Axis Bank', 'Axis Bank', ['axis', 'एक्सिस', 'ಆಕ್ಸಿಸ್', 'ஆக்சிஸ்']),
    Choice('Karnataka Bank', 'Karnataka Bank', ['karnataka bank', 'ಕರ್ನಾಟಕ ಬ್ಯಾಂಕ್']),
    Choice('Indian Bank', 'Indian Bank', ['indian bank', 'इंडियन बैंक', 'ಇಂಡಿಯನ್ ಬ್ಯಾಂಕ್', 'இந்தியன் வங்கி', 'இந்தியன் பேங்க்']),
    Choice('Indian Overseas Bank', 'Indian Overseas Bank', ['indian overseas', 'iob', 'இந்தியன் ஓவர்சீஸ்']),
    Choice('Kotak Mahindra Bank', 'Kotak Mahindra Bank', ['kotak', 'कोटक', 'ಕೋಟಕ್', 'கோடக்']),
    Choice('Gramin Bank', 'Gramin Bank', ['gramin', 'grameen', 'ग्रामीण', 'ಗ್ರಾಮೀಣ', 'கிராமின்']),
  ];

  static final List<FieldSpec> fields = [
    // ------------------------------------------------------------ primary
    const FieldSpec(
      id: 'name',
      label: 'Farmer Name',
      kind: FieldKind.name,
      section: FormSection.primary,
      required: true,
      labels: [
        'farmer name', 'farmers name', "farmer's name", 'name', 'naam', 'नाम', 'किसान का नाम', 'ಹೆಸರು',
        'ರೈತರ ಹೆಸರು', 'ರೈತನ ಹೆಸರು', 'பெயர்', 'விவசாயி பெயர்', 'விவசாயியின் பெயர்',
      ],
      spoken: ['name', 'नाम', 'ಹೆಸರು', 'பெயர்'],
      question: [
        "What is the farmer's full name?",
        'किसान का पूरा नाम बताइए।',
        'ರೈತರ ಪೂರ್ಣ ಹೆಸರು ಹೇಳಿ.',
        'விவசாயியின் முழு பெயரைச் சொல்லுங்கள்.',
      ],
    ),
    const FieldSpec(
      id: 'mobile',
      label: 'Mobile Number',
      kind: FieldKind.phone,
      section: FormSection.primary,
      required: true,
      labels: [
        'mobile number', 'mobile no', 'mobile', 'phone number', 'phone', 'contact number', 'cell number',
        'मोबाइल नंबर', 'मोबाइल', 'फोन नंबर', 'फ़ोन नंबर', 'फोन', 'फ़ोन', 'ಮೊಬೈಲ್ ನಂಬರ್', 'ಮೊಬೈಲ್ ಸಂಖ್ಯೆ',
        'ಮೊಬೈಲ್', 'ಫೋನ್ ನಂಬರ್', 'ಫೋನ್', 'மொபைல் எண்', 'மொபைல் நம்பர்', 'மொபைல்', 'போன் நம்பர்', 'போன்',
        'தொலைபேசி எண்',
      ],
      spoken: ['mobile number', 'मोबाइल नंबर', 'ಮೊಬೈಲ್ ಸಂಖ್ಯೆ', 'மொபைல் எண்'],
      question: [
        "What's their 10-digit mobile number?",
        'उनका दस अंकों का मोबाइल नंबर बताइए।',
        'ಅವರ ಹತ್ತು ಅಂಕಿಯ ಮೊಬೈಲ್ ಸಂಖ್ಯೆ ಹೇಳಿ.',
        'அவர்களின் பத்து இலக்க மொபைல் எண்ணைச் சொல்லுங்கள்.',
      ],
    ),
    FieldSpec(
      id: 'project',
      label: 'Project',
      kind: FieldKind.dropdown,
      section: FormSection.primary,
      required: true,
      choices: projects,
      labels: const [
        'project', 'programme', 'program', 'प्रोजेक्ट', 'परियोजना', 'ಪ್ರಾಜೆಕ್ಟ್', 'ಯೋಜನೆ', 'திட்டம்',
        'ப்ராஜெக்ட்', 'புராஜெக்ட்',
      ],
      spoken: const ['project', 'प्रोजेक्ट', 'ಪ್ರಾಜೆಕ್ಟ್', 'திட்டம்'],
      question: const [
        'Which project should they join? For example {a} or {b}.',
        'उन्हें किस प्रोजेक्ट में जोड़ें? जैसे {a} या {b}।',
        'ಯಾವ ಪ್ರಾಜೆಕ್ಟ್‌ಗೆ ಸೇರಿಸಬೇಕು? ಉದಾಹರಣೆಗೆ {a} ಅಥವಾ {b}.',
        'எந்தத் திட்டத்தில் சேர்க்க வேண்டும்? உதாரணமாக {a} அல்லது {b}.',
      ],
    ),
    // ----------------------------------------------------------- personal
    const FieldSpec(
      id: 'dob',
      label: 'Date Of Birth',
      kind: FieldKind.date,
      section: FormSection.personal,
      labels: [
        'date of birth', 'birth date', 'birthday', 'dob', 'born on', 'born', 'age', 'जन्म तिथि',
        'जन्मतिथि', 'जन्म दिनांक', 'जन्म', 'डेट ऑफ बर्थ', 'उम्र', 'आयु', 'ಜನ್ಮ ದಿನಾಂಕ', 'ಹುಟ್ಟಿದ ದಿನಾಂಕ',
        'ಹುಟ್ಟಿದ ದಿನ', 'ಜನ್ಮ', 'ವಯಸ್ಸು', 'பிறந்த தேதி', 'பிறந்த நாள்', 'பிறந்தது', 'வயது',
      ],
      spoken: ['date of birth', 'जन्म तिथि', 'ಜನ್ಮ ದಿನಾಂಕ', 'பிறந்த தேதி'],
      question: [
        "What's their date of birth? You can also just tell me their age.",
        'उनकी जन्म तिथि क्या है? चाहें तो सिर्फ़ उम्र बता दीजिए।',
        'ಅವರ ಜನ್ಮ ದಿನಾಂಕ ಏನು? ಬೇಕಿದ್ದರೆ ವಯಸ್ಸು ಮಾತ್ರ ಹೇಳಿ.',
        'அவர்களின் பிறந்த தேதி என்ன? வயதை மட்டும் சொன்னாலும் போதும்.',
      ],
    ),
    const FieldSpec(
      id: 'gender',
      label: 'Gender',
      kind: FieldKind.dropdown,
      section: FormSection.personal,
      choices: genders,
      labels: ['gender', 'sex', 'लिंग', 'जेंडर', 'ಲಿಂಗ', 'ಜೆಂಡರ್', 'பாலினம்', 'ஜெண்டர்'],
      spoken: ['gender', 'लिंग', 'ಲಿಂಗ', 'பாலினம்'],
      question: [
        'Gender — male, female or other?',
        'लिंग — पुरुष, महिला या अन्य?',
        'ಲಿಂಗ — ಪುರುಷ, ಮಹಿಳೆ ಅಥವಾ ಇತರೆ?',
        'பாலினம் — ஆண், பெண் அல்லது மற்றவை?',
      ],
    ),
    const FieldSpec(
      id: 'guardian',
      label: 'Father/husband Name',
      kind: FieldKind.name,
      section: FormSection.personal,
      labels: [
        "father's name", 'fathers name', 'father name', 'father', "husband's name", 'husband name',
        'husband', 'पिता का नाम', 'पिताजी का नाम', 'पिता', 'पिताजी', 'पति का नाम', 'पति', 'ತಂದೆಯ ಹೆಸರು',
        'ತಂದೆ ಹೆಸರು', 'ತಂದೆ', 'ಪತಿಯ ಹೆಸರು', 'ಗಂಡನ ಹೆಸರು', 'ಪತಿ', 'ಗಂಡ', 'தந்தை பெயர்', 'தந்தையின் பெயர்',
        'தந்தை', 'அப்பா', 'கணவர் பெயர்', 'கணவரின் பெயர்', 'கணவர்',
      ],
      spoken: ["father's or husband's name", 'पिता या पति का नाम', 'ತಂದೆ ಅಥವಾ ಪತಿಯ ಹೆಸರು', 'தந்தை அல்லது கணவர் பெயர்'],
      question: [
        "What is their father's or husband's name?",
        'उनके पिता या पति का नाम क्या है?',
        'ಅವರ ತಂದೆ ಅಥವಾ ಪತಿಯ ಹೆಸರು ಏನು?',
        'அவர்களின் தந்தை அல்லது கணவர் பெயர் என்ன?',
      ],
    ),
    const FieldSpec(
      id: 'aadhaar',
      label: 'Aadhar Number',
      kind: FieldKind.aadhaar,
      section: FormSection.personal,
      labels: [
        'aadhaar number', 'aadhar number', 'adhar number', 'aadhaar', 'aadhar', 'adhar', 'आधार नंबर',
        'आधार संख्या', 'आधार', 'ಆಧಾರ್ ಸಂಖ್ಯೆ', 'ಆಧಾರ್ ನಂಬರ್', 'ಆಧಾರ್', 'ஆதார் எண்', 'ஆதார் நம்பர்', 'ஆதார்',
      ],
      spoken: ['Aadhaar number', 'आधार नंबर', 'ಆಧಾರ್ ಸಂಖ್ಯೆ', 'ஆதார் எண்'],
      question: [
        "What's their 12-digit Aadhaar number?",
        'उनका बारह अंकों का आधार नंबर बताइए।',
        'ಅವರ ಹನ್ನೆರಡು ಅಂಕಿಯ ಆಧಾರ್ ಸಂಖ್ಯೆ ಹೇಳಿ.',
        'அவர்களின் பன்னிரண்டு இலக்க ஆதார் எண்ணைச் சொல்லுங்கள்.',
      ],
    ),
    const FieldSpec(
      id: 'contractor',
      label: 'Contractor',
      kind: FieldKind.dropdown,
      section: FormSection.personal,
      choices: contractors,
      labels: [
        'contractor', 'ठेकेदार', 'कॉन्ट्रैक्टर', 'कांट्रेक्टर', 'ಗುತ್ತಿಗೆದಾರ', 'ಕಾಂಟ್ರಾಕ್ಟರ್', 'ஒப்பந்ததாரர்',
        'கான்ட்ராக்டர்', 'காண்ட்ராக்டர்',
      ],
      spoken: ['contractor', 'ठेकेदार', 'ಗುತ್ತಿಗೆದಾರ', 'ஒப்பந்ததாரர்'],
      question: [
        'Which contractor do they work with? For example {a} or {b}.',
        'वे किस ठेकेदार के साथ काम करते हैं? जैसे {a} या {b}।',
        'ಅವರು ಯಾವ ಗುತ್ತಿಗೆದಾರರೊಂದಿಗೆ ಕೆಲಸ ಮಾಡುತ್ತಾರೆ? ಉದಾಹರಣೆಗೆ {a} ಅಥವಾ {b}.',
        'அவர்கள் எந்த ஒப்பந்ததாரருடன் வேலை செய்கிறார்கள்? உதாரணமாக {a} அல்லது {b}.',
      ],
    ),
    const FieldSpec(
      id: 'area',
      label: 'Declared Area',
      kind: FieldKind.area,
      section: FormSection.personal,
      labels: [
        'declared area', 'land area', 'total land', 'area', 'land', 'क्षेत्रफल', 'एरिया', 'जमीन', 'ज़मीन',
        'खेत', 'ಜಮೀನು', 'ವಿಸ್ತೀರ್ಣ', 'ಏರಿಯಾ', 'ಭೂಮಿ', 'பரப்பளவு', 'நிலம்', 'ஏரியா',
      ],
      spoken: ['declared area', 'ज़मीन का क्षेत्रफल', 'ಜಮೀನಿನ ವಿಸ್ತೀರ್ಣ', 'நிலப் பரப்பளவு'],
      question: [
        'How much land do they have? Say it like "3 acres".',
        'उनके पास कितनी ज़मीन है? जैसे "तीन एकड़"।',
        'ಅವರ ಬಳಿ ಎಷ್ಟು ಜಮೀನು ಇದೆ? ಉದಾಹರಣೆಗೆ "ಮೂರು ಎಕರೆ".',
        'அவர்களிடம் எவ்வளவு நிலம் உள்ளது? உதாரணமாக "மூன்று ஏக்கர்".',
      ],
    ),
    FieldSpec(
      id: 'areaUnit',
      label: 'Declared Area Unit',
      kind: FieldKind.dropdown,
      section: FormSection.personal,
      choices: areaUnits,
      askable: false,
      labels: const ['area unit', 'unit', 'इकाई', 'यूनिट', 'ಘಟಕ', 'ಯೂನಿಟ್', 'அலகு', 'யூனிட்'],
      spoken: const ['area unit', 'इकाई', 'ಘಟಕ', 'அலகு'],
      question: const ['Which unit — {a} or {b}?', 'कौन सी इकाई — {a} या {b}?', 'ಯಾವ ಘಟಕ — {a} ಅಥವಾ {b}?', 'எந்த அலகு — {a} அல்லது {b}?'],
    ),
    const FieldSpec(
      id: 'language',
      label: 'Language Preference',
      kind: FieldKind.dropdown,
      section: FormSection.personal,
      choices: languages,
      labels: [
        'language preference', 'preferred language', 'language', 'भाषा', 'पसंदीदा भाषा', 'ಭಾಷೆ', 'ಆದ್ಯತೆಯ ಭಾಷೆ',
        'மொழி', 'விருப்ப மொழி',
      ],
      spoken: ['language', 'भाषा', 'ಭಾಷೆ', 'மொழி'],
      question: [
        'Which language do they prefer — for example Kannada or Hindi?',
        'वे कौन सी भाषा पसंद करते हैं — जैसे हिंदी या कन्नड़?',
        'ಅವರು ಯಾವ ಭಾಷೆ ಇಷ್ಟಪಡುತ್ತಾರೆ — ಉದಾಹರಣೆಗೆ ಕನ್ನಡ ಅಥವಾ ಹಿಂದಿ?',
        'அவர்கள் விரும்பும் மொழி எது — உதாரணமாக தமிழ் அல்லது ஆங்கிலம்?',
      ],
    ),
    const FieldSpec(
      id: 'email',
      label: 'Email',
      kind: FieldKind.email,
      section: FormSection.personal,
      labels: [
        'email id', 'email address', 'email', 'e mail', 'mail id', 'ईमेल', 'ई मेल', 'मेल आईडी', 'ಇಮೇಲ್',
        'ಈಮೇಲ್', 'ಇ ಮೇಲ್', 'இமெயில்', 'ஈமெயில்', 'மின்னஞ்சல்',
      ],
      spoken: ['email', 'ईमेल', 'ಇಮೇಲ್', 'மின்னஞ்சல்'],
      question: [
        'Their email address? Say it like "ramesh at gmail dot com".',
        'उनका ईमेल पता? ऐसे बोलिए — "ramesh at gmail dot com"।',
        'ಅವರ ಇಮೇಲ್ ವಿಳಾಸ? ಹೀಗೆ ಹೇಳಿ — "ramesh at gmail dot com".',
        'அவர்களின் மின்னஞ்சல் முகவரி? இப்படிச் சொல்லுங்கள் — "ramesh at gmail dot com".',
      ],
    ),
    // ------------------------------------------------------------ address
    const FieldSpec(
      id: 'country',
      label: 'Country',
      kind: FieldKind.dropdown,
      section: FormSection.address,
      choices: countries,
      labels: ['country', 'देश', 'ದೇಶ', 'நாடு'],
      spoken: ['country', 'देश', 'ದೇಶ', 'நாடு'],
      question: ['Which country?', 'कौन सा देश?', 'ಯಾವ ದೇಶ?', 'எந்த நாடு?'],
    ),
    const FieldSpec(
      id: 'state',
      label: 'State',
      kind: FieldKind.place,
      section: FormSection.address,
      choices: states,
      labels: ['state', 'राज्य', 'स्टेट', 'ರಾಜ್ಯ', 'ಸ್ಟೇಟ್', 'மாநிலம்', 'ஸ்டேட்'],
      spoken: ['state', 'राज्य', 'ರಾಜ್ಯ', 'மாநிலம்'],
      question: ['Which state?', 'कौन सा राज्य?', 'ಯಾವ ರಾಜ್ಯ?', 'எந்த மாநிலம்?'],
    ),
    const FieldSpec(
      id: 'city',
      label: 'City',
      kind: FieldKind.place,
      section: FormSection.address,
      labels: ['city', 'town', 'शहर', 'नगर', 'सिटी', 'ನಗರ', 'ಪಟ್ಟಣ', 'ಸಿಟಿ', 'நகரம்', 'சிட்டி'],
      spoken: ['city', 'शहर', 'ನಗರ', 'நகரம்'],
      question: ['Which city or town?', 'कौन सा शहर या कस्बा?', 'ಯಾವ ನಗರ ಅಥವಾ ಪಟ್ಟಣ?', 'எந்த நகரம் அல்லது ஊர்?'],
    ),
    const FieldSpec(
      id: 'district',
      label: 'District',
      kind: FieldKind.place,
      section: FormSection.address,
      labels: ['district', 'जिला', 'ज़िला', 'डिस्ट्रिक्ट', 'ಜಿಲ್ಲೆ', 'ಡಿಸ್ಟ್ರಿಕ್ಟ್', 'மாவட்டம்', 'டிஸ்ட்ரிக்ட்'],
      spoken: ['district', 'ज़िला', 'ಜಿಲ್ಲೆ', 'மாவட்டம்'],
      question: ['Which district?', 'कौन सा ज़िला?', 'ಯಾವ ಜಿಲ್ಲೆ?', 'எந்த மாவட்டம்?'],
    ),
    const FieldSpec(
      id: 'taluka',
      label: 'Taluka',
      kind: FieldKind.place,
      section: FormSection.address,
      labels: [
        'taluka', 'taluk', 'tehsil', 'tahsil', 'block', 'तहसील', 'तालुका', 'ब्लॉक', 'ತಾಲೂಕು', 'ತಾಲ್ಲೂಕು',
        'தாலுகா', 'வட்டம்',
      ],
      spoken: ['taluka', 'तहसील', 'ತಾಲೂಕು', 'தாலுகா'],
      question: ['Which taluka?', 'कौन सी तहसील या तालुका?', 'ಯಾವ ತಾಲೂಕು?', 'எந்த தாலுகா?'],
    ),
    const FieldSpec(
      id: 'village',
      label: 'Village',
      kind: FieldKind.place,
      section: FormSection.address,
      labels: ['village', 'gaon', 'गांव', 'गाँव', 'ग्राम', 'ಗ್ರಾಮ', 'ಹಳ್ಳಿ', 'ಊರು', 'கிராமம்', 'ஊர்'],
      spoken: ['village', 'गाँव', 'ಗ್ರಾಮ', 'கிராமம்'],
      question: ['Which village?', 'कौन सा गाँव?', 'ಯಾವ ಗ್ರಾಮ?', 'எந்த கிராமம்?'],
    ),
    const FieldSpec(
      id: 'landmark',
      label: 'Landmark',
      kind: FieldKind.text,
      section: FormSection.address,
      labels: ['landmark', 'near to', 'nearby', 'लैंडमार्क', 'के पास', 'पास में', 'ಲ್ಯಾಂಡ್‌ಮಾರ್ಕ್', 'ಹತ್ತಿರ', 'அருகில்', 'லேண்ட்மார்க்'],
      spoken: ['landmark', 'लैंडमार्क', 'ಲ್ಯಾಂಡ್‌ಮಾರ್ಕ್', 'அடையாளம்'],
      question: [
        'Any landmark near their home?',
        'घर के पास कोई पहचान की जगह?',
        'ಮನೆಯ ಹತ್ತಿರ ಯಾವುದಾದರೂ ಗುರುತು?',
        'வீட்டின் அருகில் ஏதாவது அடையாளம்?',
      ],
    ),
    const FieldSpec(
      id: 'pin',
      label: 'Pin Code',
      kind: FieldKind.pin,
      section: FormSection.address,
      labels: [
        'pin code', 'pincode', 'postal code', 'pin', 'पिन कोड', 'पिनकोड', 'पिन', 'ಪಿನ್ ಕೋಡ್', 'ಪಿನ್‌ಕೋಡ್',
        'ಪಿನ್', 'பின் கோடு', 'பின்கோடு', 'அஞ்சல் குறியீடு',
      ],
      spoken: ['PIN code', 'पिन कोड', 'ಪಿನ್ ಕೋಡ್', 'பின் கோடு'],
      question: ["What's the 6-digit PIN code?", 'छह अंकों का पिन कोड बताइए।', 'ಆರು ಅಂಕಿಯ ಪಿನ್ ಕೋಡ್ ಹೇಳಿ.', 'ஆறு இலக்க பின் கோடைச் சொல்லுங்கள்.'],
    ),
    // --------------------------------------------------------- additional
    const FieldSpec(
      id: 'bankAccount',
      label: 'Bank A/c Number',
      kind: FieldKind.account,
      section: FormSection.additional,
      labels: [
        'bank account number', 'account number', 'bank account', 'account', 'a c number', 'खाता संख्या',
        'खाता नंबर', 'खाता', 'अकाउंट नंबर', 'अकाउंट', 'ಖಾತೆ ಸಂಖ್ಯೆ', 'ಖಾತೆ', 'ಅಕೌಂಟ್ ನಂಬರ್', 'ಅಕೌಂಟ್',
        'கணக்கு எண்', 'கணக்கு', 'அக்கவுண்ட் நம்பர்', 'அக்கவுண்ட்',
      ],
      spoken: ['bank account number', 'बैंक खाता नंबर', 'ಬ್ಯಾಂಕ್ ಖಾತೆ ಸಂಖ್ಯೆ', 'வங்கிக் கணக்கு எண்'],
      question: [
        "What's their bank account number?",
        'उनका बैंक खाता नंबर बताइए।',
        'ಅವರ ಬ್ಯಾಂಕ್ ಖಾತೆ ಸಂಖ್ಯೆ ಹೇಳಿ.',
        'அவர்களின் வங்கிக் கணக்கு எண்ணைச் சொல்லுங்கள்.',
      ],
    ),
    const FieldSpec(
      id: 'bankName',
      label: 'Bank Name',
      kind: FieldKind.place,
      section: FormSection.additional,
      choices: banks,
      labels: ['bank name', 'bank', 'बैंक का नाम', 'बैंक', 'ಬ್ಯಾಂಕ್ ಹೆಸರು', 'ಬ್ಯಾಂಕ್', 'வங்கி பெயர்', 'வங்கி', 'பேங்க்'],
      spoken: ['bank name', 'बैंक का नाम', 'ಬ್ಯಾಂಕ್ ಹೆಸರು', 'வங்கி பெயர்'],
      question: ['Which bank?', 'कौन सा बैंक?', 'ಯಾವ ಬ್ಯಾಂಕ್?', 'எந்த வங்கி?'],
    ),
    const FieldSpec(
      id: 'branch',
      label: 'Branch Name',
      kind: FieldKind.place,
      section: FormSection.additional,
      labels: ['branch name', 'branch', 'शाखा', 'ब्रांच', 'ಶಾಖೆ', 'ಬ್ರಾಂಚ್', 'கிளை', 'பிராஞ்ச்'],
      spoken: ['branch', 'शाखा', 'ಶಾಖೆ', 'கிளை'],
      question: ['Which branch?', 'कौन सी शाखा?', 'ಯಾವ ಶಾಖೆ?', 'எந்தக் கிளை?'],
    ),
    const FieldSpec(
      id: 'ifsc',
      label: 'Ifsc Code',
      kind: FieldKind.ifsc,
      section: FormSection.additional,
      labels: [
        'ifsc code', 'ifsc', 'i f s c', 'आईएफएससी कोड', 'आईएफएससी', 'आई एफ एस सी', 'ಐಎಫ್‌ಎಸ್‌ಸಿ', 'ಐಎಫ್ಎಸ್ಸಿ',
        'ஐஎஃப்எஸ்சி', 'ஐஎப்எஸ்சி',
      ],
      spoken: ['IFSC code', 'आईएफएससी कोड', 'ಐಎಫ್‌ಎಸ್‌ಸಿ ಕೋಡ್', 'ஐஎஃப்எஸ்சி கோடு'],
      question: [
        'The IFSC code? Say the letters and numbers one by one.',
        'आईएफएससी कोड? अक्षर और अंक एक-एक करके बोलिए।',
        'ಐಎಫ್‌ಎಸ್‌ಸಿ ಕೋಡ್? ಅಕ್ಷರ ಮತ್ತು ಅಂಕಿಗಳನ್ನು ಒಂದೊಂದಾಗಿ ಹೇಳಿ.',
        'ஐஎஃப்எஸ்சி கோடு? எழுத்துகளையும் எண்களையும் ஒவ்வொன்றாகச் சொல்லுங்கள்.',
      ],
    ),
    const FieldSpec(
      id: 'pan',
      label: 'Pan Number',
      kind: FieldKind.pan,
      section: FormSection.additional,
      labels: ['pan number', 'pan card', 'pan', 'पैन नंबर', 'पैन कार्ड', 'पैन', 'ಪ್ಯಾನ್ ಸಂಖ್ಯೆ', 'ಪ್ಯಾನ್ ಕಾರ್ಡ್', 'ಪ್ಯಾನ್', 'பான் எண்', 'பான் கார்டு', 'பான்'],
      spoken: ['PAN number', 'पैन नंबर', 'ಪ್ಯಾನ್ ಸಂಖ್ಯೆ', 'பான் எண்'],
      question: [
        'Their PAN number? Say the letters and numbers one by one.',
        'उनका पैन नंबर? अक्षर और अंक एक-एक करके बोलिए।',
        'ಅವರ ಪ್ಯಾನ್ ಸಂಖ್ಯೆ? ಅಕ್ಷರ ಮತ್ತು ಅಂಕಿಗಳನ್ನು ಒಂದೊಂದಾಗಿ ಹೇಳಿ.',
        'அவர்களின் பான் எண்? எழுத்துகளையும் எண்களையும் ஒவ்வொன்றாகச் சொல்லுங்கள்.',
      ],
    ),
    FieldSpec(
      id: 'location',
      label: 'Location',
      kind: FieldKind.dropdown,
      section: FormSection.additional,
      choices: locations,
      labels: const ['location', 'लोकेशन', 'स्थान', 'ಲೊಕೇಶನ್', 'ಸ್ಥಳ', 'லொகேஷன்', 'இடம்'],
      spoken: const ['location', 'लोकेशन', 'ಸ್ಥಳ', 'இடம்'],
      question: const [
        'Which location? For example {a} or {b}.',
        'कौन सी लोकेशन? जैसे {a} या {b}।',
        'ಯಾವ ಸ್ಥಳ? ಉದಾಹರಣೆಗೆ {a} ಅಥವಾ {b}.',
        'எந்த இடம்? உதாரணமாக {a} அல்லது {b}.',
      ],
    ),
  ];

  static final Map<String, FieldSpec> byId = {for (final f in fields) f.id: f};

  static List<FieldSpec> inSection(FormSection s) => fields.where((f) => f.section == s).toList();
}
