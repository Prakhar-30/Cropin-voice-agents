import 'agent_language.dart';

/// Localised phrases the agents speak (TTS) and show. UI chrome stays in
/// English like the Cropin Grow app; the agent talks in the field language.
class AgentStrings {
  AgentStrings(this.lang);
  final AgentLanguage lang;

  String _pick(String en, String hi, String kn, String ta) => switch (lang) {
        AgentLanguage.english => en,
        AgentLanguage.hindi => hi,
        AgentLanguage.kannada => kn,
        AgentLanguage.tamil => ta,
      };

  String get listening => _pick('Listening…', 'सुन रहा हूँ…', 'ಕೇಳುತ್ತಿದ್ದೇನೆ…', 'கேட்கிறேன்…');

  String get tapToSpeak => _pick('Tap the mic and speak', 'माइक दबाएँ और बोलें',
      'ಮೈಕ್ ಒತ್ತಿ ಮಾತನಾಡಿ', 'மைக்கை அழுத்தி பேசுங்கள்');

  String get holdToSpeak => _pick('Hold the shutter and speak', 'शटर दबाकर रखें और बोलें',
      'ಶಟರ್ ಒತ್ತಿ ಹಿಡಿದು ಮಾತನಾಡಿ', 'ஷட்டரை அழுத்திப் பிடித்து பேசுங்கள்');

  String formFilled(int n, int check) => check == 0
      ? _pick('Filled $n fields. Please review and submit.',
          '$n फ़ील्ड भरे गए। जाँच कर सबमिट करें।',
          '$n ವಿವರಗಳನ್ನು ತುಂಬಲಾಗಿದೆ. ಪರಿಶೀಲಿಸಿ ಸಲ್ಲಿಸಿ.',
          '$n விவரங்கள் நிரப்பப்பட்டன. சரிபார்த்து சமர்ப்பிக்கவும்.')
      : _pick('Filled $n fields. $check need a check.',
          '$n फ़ील्ड भरे गए। $check की जाँच करें।',
          '$n ವಿವರಗಳನ್ನು ತುಂಬಲಾಗಿದೆ. $check ಪರಿಶೀಲಿಸಿ.',
          '$n விவரங்கள் நிரப்பப்பட்டன. $check சரிபார்க்கவும்.');

  String get notUnderstood => _pick("Sorry, I couldn't understand. Please try again.",
      'माफ़ कीजिए, समझ नहीं आया। फिर से बोलें।',
      'ಕ್ಷಮಿಸಿ, ಅರ್ಥವಾಗಲಿಲ್ಲ. ಮತ್ತೊಮ್ಮೆ ಹೇಳಿ.',
      'மன்னிக்கவும், புரியவில்லை. மீண்டும் சொல்லுங்கள்.');

  String alertReady(String type, String severity, String plot) => _pick(
      '$type alert, $severity severity, on $plot. Tap Raise alert to submit.',
      '$plot पर $type अलर्ट, गंभीरता $severity। सबमिट करने के लिए Raise alert दबाएँ।',
      '$plot ಮೇಲೆ $type ಎಚ್ಚರಿಕೆ, ತೀವ್ರತೆ $severity. ಸಲ್ಲಿಸಲು Raise alert ಒತ್ತಿ.',
      '$plot இல் $type எச்சரிக்கை, தீவிரம் $severity. சமர்ப்பிக்க Raise alert அழுத்தவும்.');

  String get alertSubmitted => _pick('Alert raised successfully.', 'अलर्ट सफलतापूर्वक भेजा गया।',
      'ಎಚ್ಚರಿಕೆ ಯಶಸ್ವಿಯಾಗಿ ಸಲ್ಲಿಸಲಾಗಿದೆ.', 'எச்சரிக்கை வெற்றிகரமாக அனுப்பப்பட்டது.');

  String searchResults(int n) => _pick('Found $n results.', '$n परिणाम मिले।',
      '$n ಫಲಿತಾಂಶಗಳು ಸಿಕ್ಕಿವೆ.', '$n முடிவுகள் கிடைத்தன.');

  String noteSaved(int n) => _pick('Note added to $n photos.', '$n फोटो में नोट जोड़ा गया।',
      '$n ಫೋಟೋಗಳಿಗೆ ಟಿಪ್ಪಣಿ ಸೇರಿಸಲಾಗಿದೆ.', '$n புகைப்படங்களுக்கு குறிப்பு சேர்க்கப்பட்டது.');

  String get saved => _pick('Saved.', 'सेव हो गया।', 'ಉಳಿಸಲಾಗಿದೆ.', 'சேமிக்கப்பட்டது.');

  // ------------------------------------------------------------- briefing
  String get greeting => _pick('Good morning. Here is your day.', 'नमस्ते। आज का आपका दिन ऐसा है।',
      'ನಮಸ್ಕಾರ. ಇಂದಿನ ನಿಮ್ಮ ಕೆಲಸಗಳು ಹೀಗಿವೆ.', 'வணக்கம். இன்றைய உங்கள் பணிகள் இதோ.');

  String overdue(int n) => _pick('$n tasks are overdue.', '$n काम की तारीख निकल चुकी है।',
      '$n ಕೆಲಸಗಳ ಗಡುವು ಮೀರಿದೆ.', '$n பணிகள் காலதாமதமாகியுள்ளன.');

  String dueToday(int n) => _pick('$n tasks are due today.', 'आज $n काम करने हैं।',
      'ಇಂದು $n ಕೆಲಸಗಳು ಮಾಡಬೇಕಿದೆ.', 'இன்று $n பணிகள் செய்ய வேண்டும்.');

  String nearby(int n, int km) => _pick('$n of them are within $km kilometres of you.',
      'इनमें से $n आपसे $km किलोमीटर के अंदर हैं।',
      'ಅವುಗಳಲ್ಲಿ $n ನಿಮ್ಮಿಂದ $km ಕಿಲೋಮೀಟರ್ ಒಳಗಿವೆ.',
      'அவற்றில் $n உங்களிடமிருந்து $km கிலோமீட்டருக்குள் உள்ளன.');

  String firstUp(String task, String farmer) => _pick('First up: $task for $farmer.',
      'पहला काम: $farmer के लिए $task।', 'ಮೊದಲ ಕೆಲಸ: $farmer ಅವರಿಗೆ $task.',
      'முதல் பணி: $farmer அவர்களுக்கு $task.');

  String cropHealth(int n) => _pick('$n plots need attention in crop health.',
      'फसल स्वास्थ्य में $n खेतों पर ध्यान देना है।', 'ಬೆಳೆ ಆರೋಗ್ಯದಲ್ಲಿ $n ಜಮೀನುಗಳಿಗೆ ಗಮನ ಬೇಕು.',
      'பயிர் ஆரோக்கியத்தில் $n நிலங்களுக்கு கவனம் தேவை.');

  String get allClear => _pick('No pending tasks. Have a good day!', 'कोई काम बाकी नहीं। आपका दिन शुभ हो!',
      'ಯಾವುದೇ ಕೆಲಸ ಬಾಕಿ ಇಲ್ಲ. ಶುಭ ದಿನ!', 'நிலுவையில் பணிகள் இல்லை. இனிய நாள்!');

  String get weatherPrefix => _pick('Weather advisory:', 'मौसम सलाह:', 'ಹವಾಮಾನ ಸಲಹೆ:', 'வானிலை ஆலோசனை:');

  // ------------------------------------------------------------- vocab
  String alertType(String v) => _vocab(v, const {
        'Pest': ['कीट', 'ಕೀಟ', 'பூச்சி'],
        'Disease': ['रोग', 'ರೋಗ', 'நோய்'],
        'Weather damage': ['मौसम क्षति', 'ಹವಾಮಾನ ಹಾನಿ', 'வானிலை சேதம்'],
        'Nutrient deficiency': ['पोषक तत्व की कमी', 'ಪೋಷಕಾಂಶ ಕೊರತೆ', 'ஊட்டச்சத்து குறைபாடு'],
        'Water stress': ['जल तनाव', 'ನೀರಿನ ಒತ್ತಡ', 'நீர் அழுத்தம்'],
        'Weed': ['खरपतवार', 'ಕಳೆ', 'களை'],
      });

  String severity(String v) => _vocab(v, const {
        'High': ['उच्च', 'ಹೆಚ್ಚು', 'அதிகம்'],
        'Medium': ['मध्यम', 'ಮಧ್ಯಮ', 'நடுத்தரம்'],
        'Low': ['कम', 'ಕಡಿಮೆ', 'குறைவு'],
      });

  String crop(String v) => _vocab(v, const {
        'Chilli': ['मिर्च', 'ಮೆಣಸಿನಕಾಯಿ', 'மிளகாய்'],
        'Potato': ['आलू', 'ಆಲೂಗಡ್ಡೆ', 'உருளைக்கிழங்கு'],
        'Maize': ['मक्का', 'ಮೆಕ್ಕೆಜೋಳ', 'மக்காச்சோளம்'],
        'Tomato': ['टमाटर', 'ಟೊಮೆಟೊ', 'தக்காளி'],
        'Paddy': ['धान', 'ಭತ್ತ', 'நெல்'],
        'Ragi': ['रागी', 'ರಾಗಿ', 'ராகி'],
        'Sugarcane': ['गन्ना', 'ಕಬ್ಬು', 'கரும்பு'],
        'Groundnut': ['मूंगफली', 'ಕಡಲೆಕಾಯಿ', 'நிலக்கடலை'],
      });

  String taskType(String v) => _vocab(v, const {
        'Crop scouting': ['फसल निरीक्षण', 'ಬೆಳೆ ಪರಿಶೀಲನೆ', 'பயிர் ஆய்வு'],
        'Irrigation check': ['सिंचाई जाँच', 'ನೀರಾವರಿ ಪರಿಶೀಲನೆ', 'பாசன சரிபார்ப்பு'],
        'Fertilizer application': ['खाद डालना', 'ಗೊಬ್ಬರ ಹಾಕುವುದು', 'உரமிடுதல்'],
        'Pest trap check': ['कीट जाल जाँच', 'ಕೀಟ ಬಲೆ ಪರಿಶೀಲನೆ', 'பூச்சி பொறி சரிபார்ப்பு'],
        'Yield estimation': ['उपज अनुमान', 'ಇಳುವರಿ ಅಂದಾಜು', 'மகசூல் மதிப்பீடு'],
        'Sowing verification': ['बुवाई सत्यापन', 'ಬಿತ್ತನೆ ಪರಿಶೀಲನೆ', 'விதைப்பு சரிபார்ப்பு'],
        'Geo-tag photos': ['जियो-टैग फोटो', 'ಜಿಯೋ-ಟ್ಯಾಗ್ ಫೋಟೋ', 'ஜியோ-டேக் புகைப்படம்'],
        'Farmer meeting': ['किसान बैठक', 'ರೈತ ಸಭೆ', 'விவசாயி சந்திப்பு'],
      });

  String _vocab(String v, Map<String, List<String>> table) {
    final row = table[v];
    if (row == null) return v;
    return switch (lang) {
      AgentLanguage.english => v,
      AgentLanguage.hindi => row[0],
      AgentLanguage.kannada => row[1],
      AgentLanguage.tamil => row[2],
    };
  }

  // ------------------------------------------------------------- examples
  /// Sample utterances shown as tappable chips (also handy for demos without
  /// an offline speech pack installed).
  static Map<AgentLanguage, List<String>> examples(String context) => switch (context) {
        'farmer' => const {
            AgentLanguage.english: [
              'Ramesh Gowda, 98450 12345, project Kharif Chilli, red soil, drip irrigation, 2 acres',
            ],
            AgentLanguage.hindi: [
              'किसान का नाम सुरेश यादव, मोबाइल 98765 43210, प्रोजेक्ट रबी आलू, काली मिट्टी, ड्रिप सिंचाई, 3 एकड़',
            ],
            AgentLanguage.kannada: [
              'ಹೆಸರು ರಮೇಶ್ ಗೌಡ, ಮೊಬೈಲ್ 98450 12345, ಖಾರಿಫ್ ಮೆಣಸಿನಕಾಯಿ ಪ್ರಾಜೆಕ್ಟ್, ಕೆಂಪು ಮಣ್ಣು, ಹನಿ ನೀರಾವರಿ, ಎರಡು ಎಕರೆ',
            ],
            AgentLanguage.tamil: [
              'பெயர் முருகன் செல்வம், மொபைல் 94430 56789, காரீப் மிளகாய் திட்டம், செம்மண், சொட்டு நீர் பாசனம், இரண்டு ஏக்கர்',
            ],
          },
        'asset' => const {
            AgentLanguage.english: [
              'Plot for Mahesh Hegde, project Rabi Potato, black soil, sprinkler, 4 acres',
            ],
            AgentLanguage.hindi: [
              'सुनीता देवी का खेत, प्रोजेक्ट मक्का, दोमट मिट्टी, स्प्रिंकलर, 5 एकड़',
            ],
            AgentLanguage.kannada: [
              'ಮಂಜುನಾಥ್ ಶೆಟ್ಟಿ ಅವರ ಜಮೀನು, ಕೆಂಪು ಮಣ್ಣು, ಹನಿ ನೀರಾವರಿ, ಎರಡೂವರೆ ಎಕರೆ, ಖಾರಿಫ್ ಮೆಣಸಿನಕಾಯಿ',
            ],
            AgentLanguage.tamil: [
              'செந்தில் குமார் நிலம், கரிசல் மண், சொட்டு நீர் பாசனம், மூன்று ஏக்கர், தக்காளி திட்டம்',
            ],
          },
        'alert' => const {
            AgentLanguage.english: ['Raise pest alert on the chilli plot here, high severity'],
            AgentLanguage.hindi: ['यहाँ टमाटर के खेत पर रोग का अलर्ट, गंभीरता ज्यादा'],
            AgentLanguage.kannada: ['ಇಲ್ಲಿನ ಮೆಣಸಿನಕಾಯಿ ಜಮೀನಿನಲ್ಲಿ ಕೀಟ ಬಾಧೆ, ತೀವ್ರತೆ ಹೆಚ್ಚು'],
            AgentLanguage.tamil: ['இங்கே உள்ள மிளகாய் வயலில் பூச்சி தாக்குதல், தீவிரம் அதிகம்'],
          },
        'search' => const {
            AgentLanguage.english: ['Show my 2-acre chilli plots in BTM that need attention'],
            AgentLanguage.hindi: ['बीटीएम में मिर्च के खेत दिखाओ जिन पर ध्यान देना है'],
            AgentLanguage.kannada: ['ಬಿಟಿಎಂ ನಲ್ಲಿ ಎರಡು ಎಕರೆ ಮೆಣಸಿನಕಾಯಿ ಜಮೀನು ತೋರಿಸಿ'],
            AgentLanguage.tamil: ['பிடிஎம் பகுதியில் கவனம் தேவையான மிளகாய் நிலங்களை காட்டு'],
          },
        'briefing' => const {
            AgentLanguage.english: ["What's pending today?"],
            AgentLanguage.hindi: ['आज क्या काम बाकी है?'],
            AgentLanguage.kannada: ['ಇವತ್ತು ಏನು ಕೆಲಸ ಬಾಕಿ ಇದೆ?'],
            AgentLanguage.tamil: ['இன்னைக்கு என்ன வேலை நிலுவையில் இருக்கு?'],
          },
        'photo' => const {
            AgentLanguage.english: ['Leaf curl on lower canopy, maybe 15% plants, near the bore well'],
            AgentLanguage.hindi: ['निचली पत्तियों पर पत्ती मोड़ रोग, लगभग 15% पौधे, बोरवेल के पास'],
            AgentLanguage.kannada: ['ಕೆಳಗಿನ ಎಲೆಗಳಲ್ಲಿ ಎಲೆ ಮುದುರು ರೋಗ, ಸುಮಾರು 15% ಗಿಡಗಳು, ಬೋರ್ವೆಲ್ ಹತ್ತಿರ'],
            AgentLanguage.tamil: ['கீழ் இலைகளில் இலை சுருள் நோய், சுமார் 15% செடிகள், போர்வெல் அருகில்'],
          },
        _ => const {
            AgentLanguage.english: [
              "What's pending today?",
              'Raise pest alert on the chilli plot here, high severity',
              'Show my 2-acre chilli plots in BTM that need attention',
            ],
            AgentLanguage.hindi: [
              'आज क्या काम बाकी है?',
              'यहाँ टमाटर के खेत पर रोग का अलर्ट, गंभीरता ज्यादा',
              'बीटीएम में मिर्च के खेत दिखाओ जिन पर ध्यान देना है',
            ],
            AgentLanguage.kannada: [
              'ಇವತ್ತು ಏನು ಕೆಲಸ ಬಾಕಿ ಇದೆ?',
              'ಇಲ್ಲಿನ ಮೆಣಸಿನಕಾಯಿ ಜಮೀನಿನಲ್ಲಿ ಕೀಟ ಬಾಧೆ, ತೀವ್ರತೆ ಹೆಚ್ಚು',
              'ಬಿಟಿಎಂ ನಲ್ಲಿ ಎರಡು ಎಕರೆ ಮೆಣಸಿನಕಾಯಿ ಜಮೀನು ತೋರಿಸಿ',
            ],
            AgentLanguage.tamil: [
              'இன்னைக்கு என்ன வேலை நிலுவையில் இருக்கு?',
              'இங்கே உள்ள மிளகாய் வயலில் பூச்சி தாக்குதல், தீவிரம் அதிகம்',
              'பிடிஎம் பகுதியில் கவனம் தேவையான மிளகாய் நிலங்களை காட்டு',
            ],
          },
      };
}
