/// Multilingual vocabulary (English, Hindi, Kannada, Tamil + common
/// romanised forms) used by the offline parsers. Every entry maps a canonical
/// app value to the phrases a field worker may say for it.
library;

class Lexicon {
  // ---------------------------------------------------------------- dropdowns
  static const Map<String, List<String>> soil = {
    'Red Soil': [
      'red soil', 'red', 'laal mitti', 'lal mitti', 'लाल मिट्टी', 'लाल',
      'ಕೆಂಪು ಮಣ್ಣು', 'ಕೆಂಪು', 'kempu mannu', 'செம்மண்', 'சிவப்பு மண்', 'சிவப்பு',
      'semman', 'sivappu',
    ],
    'Black Soil': [
      'black soil', 'black', 'black cotton soil', 'black cotton', 'kali mitti', 'काली मिट्टी', 'काली',
      'ಕಪ್ಪು ಮಣ್ಣು', 'ಕಪ್ಪು', 'ಎರೆ ಮಣ್ಣು', 'ಎರೆ', 'kappu mannu', 'கரிசல் மண்', 'கரிசல்',
      'கருப்பு மண்', 'கருப்பு', 'karisal',
    ],
    'Alluvial Soil': [
      'alluvial soil', 'alluvial', 'जलोढ़ मिट्टी', 'जलोढ़', 'ಮೆಕ್ಕಲು ಮಣ್ಣು', 'ಮೆಕ್ಕಲು',
      'வண்டல் மண்', 'வண்டல்',
    ],
    'Laterite Soil': [
      'laterite soil', 'laterite', 'लेटराइट', 'ಜಂಬಿಟ್ಟಿಗೆ ಮಣ್ಣು', 'ಜಂಬಿಟ್ಟಿಗೆ',
      'ಲ್ಯಾಟರೈಟ್', 'லேட்டரைட்', 'சரளை மண்',
    ],
    'Sandy Soil': [
      'sandy soil', 'sandy', 'sand', 'रेतीली मिट्टी', 'रेतीली', 'बलुई', 'ಮರಳು ಮಣ್ಣು',
      'ಮರಳು', 'மணல் மண்', 'மணல்',
    ],
    'Clay Soil': [
      'clay soil', 'clay', 'चिकनी मिट्टी', 'चिकनी', 'ಜೇಡಿ ಮಣ್ಣು', 'ಜೇಡಿ', 'களிமண்',
      'களி மண்',
    ],
    'Loamy Soil': [
      'loamy soil', 'loamy', 'loam', 'दोमट मिट्टी', 'दोमट', 'ಗೋಡು ಮಣ್ಣು', 'ಗೋಡು',
      'ಲೋಮಿ', 'லோமி', 'இருமண்',
    ],
  };

  static const Map<String, List<String>> irrigation = {
    'Drip': [
      'drip irrigation', 'drip', 'ड्रिप', 'टपक सिंचाई', 'टपक', 'ಹನಿ ನೀರಾವರಿ', 'ಹನಿ',
      'ಡ್ರಿಪ್', 'சொட்டு நீர் பாசனம்', 'சொட்டு நீர்', 'சொட்டு', 'டிரிப்', 'ட்ரிப்',
    ],
    'Sprinkler': [
      'sprinkler irrigation', 'sprinkler', 'स्प्रिंकलर', 'फव्वारा', 'ಸ್ಪ್ರಿಂಕ್ಲರ್',
      'ತುಂತುರು ನೀರಾವರಿ', 'ತುಂತುರು', 'ஸ்பிரிங்க்ளர்', 'தெளிப்பு நீர் பாசனம்', 'தெளிப்பு',
    ],
    'Flood': [
      'flood irrigation', 'flood', 'बाढ़ सिंचाई', 'फ्लड', 'ಕಾಲುವೆ ಹರಿವು', 'ಹರಿ ನೀರಾವರಿ',
      'ಫ್ಲಡ್', 'பாய்ச்சல்', 'வெள்ள பாசனம்',
    ],
    'Rainfed': [
      'rainfed', 'rain fed', 'rain', 'बारानी', 'वर्षा आधारित', 'ಮಳೆ ಆಶ್ರಿತ', 'ಮಳೆಯಾಶ್ರಿತ',
      'ಮಳೆ', 'மானாவாரி', 'மழை',
    ],
    'Canal': ['canal irrigation', 'canal', 'नहर', 'ಕಾಲುವೆ', 'கால்வாய்'],
    'Borewell': [
      'borewell', 'bore well', 'tube well', 'tubewell', 'बोरवेल', 'ट्यूबवेल',
      'ಬೋರ್ವೆಲ್', 'ಬೋರ್ ವೆಲ್', 'ಕೊಳವೆ ಬಾವಿ', 'போர்வெல்', 'ஆழ்துளை கிணறு', 'ஆழ்துளை',
    ],
  };

  static const Map<String, List<String>> areaUnit = {
    'acre': ['acre', 'acres', 'ekar', 'ekad', 'एकड़', 'एकड', 'ಎಕರೆ', 'ஏக்கர்'],
    'hectare': ['hectare', 'hectares', 'हेक्टेयर', 'ಹೆಕ್ಟೇರ್', 'ஹெக்டேர்'],
    'gunta': ['gunta', 'guntas', 'guntha', 'ಗುಂಟೆ', 'ಗುಂಟಾ', 'குண்டா'],
    'cent': ['cent', 'cents', 'सेंट', 'ಸೆಂಟ್', 'சென்ட்', 'செண்ட்'],
    'bigha': ['bigha', 'बीघा', 'ಬಿಘಾ', 'பிகா'],
  };

  static const Map<String, List<String>> crop = {
    'Chilli': [
      'chilli', 'chili', 'chillies', 'mirchi', 'मिर्च', 'मिर्ची', 'मिर्चों', 'चिली', 'चिल्ली', 'ಮೆಣಸಿನಕಾಯಿ',
      'ಮೆಣಸಿನ ಕಾಯಿ', 'ಮೆಣಸು', 'ಚಿಲ್ಲಿ', 'மிளகாய்', 'சில்லி',
    ],
    'Potato': [
      'potato', 'potatoes', 'aloo', 'alu', 'आलू', 'आलु', 'आलूओं', 'आलुओं', 'आलू के', 'पोटैटो',
      'पोटेटो', 'पटेटो', 'पोटाटो', 'ಆಲೂಗಡ್ಡೆ', 'ಆಲೂ', 'ಪೊಟಾಟೊ', 'ಪೊಟೇಟೊ',
      'உருளைக்கிழங்கு', 'உருளை', 'பொட்டேட்டோ',
    ],
    'Maize': [
      'maize', 'corn', 'makka', 'मक्का', 'मक्के', 'मेज़', 'मेज', 'कॉर्न', 'ಮೆಕ್ಕೆಜೋಳ', 'ಮೆಕ್ಕೆ ಜೋಳ', 'ಜೋಳ',
      'மக்காச்சோளம்', 'மக்காச் சோளம்', 'சோளம்',
    ],
    'Tomato': [
      'tomato', 'tomatoes', 'tamatar', 'टमाटर', 'टमाटरों', 'टोमैटो', 'टोमेटो', 'ಟೊಮೆಟೊ', 'ಟೊಮ್ಯಾಟೊ', 'ಟೊಮೇಟೊ',
      'தக்காளி', 'டொமேட்டோ',
    ],
    'Paddy': [
      'paddy', 'rice', 'dhan', 'धान', 'चावल', 'पैडी', 'राइस', 'ಭತ್ತ', 'ಅಕ್ಕಿ', 'நெல்', 'அரிசி',
    ],
    'Ragi': [
      'ragi', 'finger millet', 'मडुआ', 'रागी', 'ರಾಗಿ', 'ராகி', 'கேழ்வரகு',
    ],
    'Sugarcane': [
      'sugarcane', 'sugar cane', 'ganna', 'गन्ना', 'ಕಬ್ಬು', 'கரும்பு',
    ],
    'Groundnut': [
      'groundnut', 'ground nut', 'peanut', 'moongphali', 'मूंगफली', 'ಕಡಲೆಕಾಯಿ',
      'ನೆಲಗಡಲೆ', 'ಶೇಂಗಾ', 'நிலக்கடலை', 'கடலை', 'வேர்க்கடலை',
    ],
  };

  static const Map<String, List<String>> season = {
    'Kharif': ['kharif', 'khareef', 'खरीफ', 'ಖಾರಿಫ್', 'ಮುಂಗಾರು', 'காரீப்', 'கரீஃப்'],
    'Rabi': ['rabi', 'रबी', 'ರಬಿ', 'ಹಿಂಗಾರು', 'ரபி'],
  };

  // ---------------------------------------------------------------- alerts
  static const Map<String, List<String>> alertType = {
    'Pest': [
      'pest', 'pests', 'insect', 'insects', 'keet', 'पेस्ट', 'कीट', 'कीड़े', 'कीड़ा', 'ಕೀಟ',
      'ಕೀಟಗಳು', 'ಹುಳು', 'ಹುಳ', 'ಪೆಸ್ಟ್', 'பூச்சி', 'பூச்சிகள்', 'பெஸ்ட்',
      'aphid', 'thrips', 'whitefly', 'mites', 'borer',
    ],
    'Disease': [
      'disease', 'infection', 'fungus', 'blight', 'wilt', 'leaf curl', 'rot',
      'रोग', 'बीमारी', 'ರೋಗ', 'ಎಲೆ ಮುದುರು', 'ಡಿಸೀಸ್', 'நோய்', 'இலை சுருள்',
    ],
    'Weather damage': [
      'weather', 'flood', 'drought', 'hail', 'rain damage', 'storm', 'मौसम', 'सूखा',
      'बाढ़', 'ओले', 'ಹವಾಮಾನ', 'ಬರ', 'ಪ್ರವಾಹ', 'ಆಲಿಕಲ್ಲು', 'வானிலை', 'வறட்சி', 'வெள்ளம்',
      'புயல்',
    ],
    'Nutrient deficiency': [
      'nutrient', 'deficiency', 'yellowing', 'पोषक', 'पीलापन', 'ಪೋಷಕಾಂಶ', 'ಹಳದಿ',
      'ஊட்டச்சத்து', 'மஞ்சள்',
    ],
    'Water stress': [
      'water stress', 'wilting', 'dry', 'पानी की कमी', 'ಕಮ್ಮಿ ನೀರು', 'ನೀರಿನ ಕೊರತೆ',
      'நீர் பற்றாக்குறை', 'தண்ணீர் இல்லை',
    ],
    'Weed': ['weed', 'weeds', 'खरपतवार', 'ಕಳೆ', 'களை'],
  };

  static const Map<String, List<String>> severity = {
    'High': [
      'high', 'severe', 'serious', 'critical', 'urgent', 'ज्यादा', 'ज़्यादा', 'गंभीर',
      'अधिक', 'हाई', 'ಹೆಚ್ಚು', 'ಹೆಚ್ಚಿನ', 'ತೀವ್ರ', 'ಗಂಭೀರ', 'ಜಾಸ್ತಿ', 'ಹೈ', 'அதிக',
      'அதிகம்', 'கடுமையான', 'தீவிர', 'ஹை',
    ],
    'Medium': [
      'medium', 'moderate', 'मध्यम', 'मीडियम', 'ಮಧ್ಯಮ', 'ಮೀಡಿಯಂ', 'நடுத்தர', 'மிதமான',
      'மீடியம்',
    ],
    'Low': [
      'low', 'mild', 'minor', 'कम', 'हल्का', 'लो', 'ಕಡಿಮೆ', 'ಸ್ವಲ್ಪ', 'ಲೋ', 'குறைவு',
      'குறைந்த', 'லேசான', 'லோ',
    ],
  };

  static const List<String> here = [
    'here', 'nearby', 'nearest', 'near me', 'this plot', 'यहाँ', 'यहां', 'पास',
    'नजदीक', 'ಇಲ್ಲಿ', 'ಇಲ್ಲಿನ', 'ಹತ್ತಿರ', 'ಹತ್ತಿರದ', 'ಈ', 'இங்கே', 'இங்கு',
    'அருகில்', 'பக்கத்தில்', 'இந்த',
  ];

  /// "all chilli plots", "ಎಲ್ಲಾ ಜಮೀನು" -> act on every matching plot.
  static const List<String> all = [
    'all', 'every', 'each', 'both', 'सभी', 'सारे', 'सब', 'ಎಲ್ಲಾ', 'ಎಲ್ಲ', 'ಎರಡೂ', 'எல்லா',
    'அனைத்து', 'எல்லாம்',
  ];

  // ---------------------------------------------------------------- intents
  static const Map<String, List<String>> intent = {
    'add_farmer': [
      'add farmer', 'new farmer', 'register farmer', 'create farmer', 'farmer add',
      // recogniser homophones of "add"
      'at farmer', 'ad farmer', 'add a farmer', 'add a new farmer', 'add new farmer',
      'at a farmer', 'at new farmer', 'and farmer', 'enroll farmer', 'onboard farmer',
      'add the farmer', 'at the farmer', 'ऐड फार्मर', 'एड फार्मर', 'ಆಡ್ ಫಾರ್ಮರ್', 'ஆட் ஃபார்மர்',
      'किसान जोड़ो', 'किसान जोड़ें', 'नया किसान', 'ಹೊಸ ರೈತ', 'ರೈತ ಸೇರಿಸಿ', 'ರೈತರನ್ನು ಸೇರಿಸಿ',
      'புதிய விவசாயி', 'விவசாயி சேர்', 'விவசாயியை சேர்',
    ],
    'add_asset': [
      'add asset', 'add plot', 'new plot', 'new asset', 'create plot', 'add farm',
      'at asset', 'ad asset', 'at plot', 'add a plot', 'add a new plot', 'add land',
      'add field', 'at a plot',
      'नया खेत', 'खेत जोड़ो', 'प्लॉट जोड़ो', 'ಹೊಸ ಜಮೀನು', 'ಜಮೀನು ಸೇರಿಸಿ', 'ಪ್ಲಾಟ್ ಸೇರಿಸಿ',
      'ಹೊಸ ಪ್ಲಾಟ್', 'புதிய நிலம்', 'நிலம் சேர்', 'புதிய பிளாட்', 'பிளாட் சேர்',
    ],
    'raise_alert': [
      'raise alert', 'alert', 'raise', 'report', 'अलर्ट', 'चेतावनी', 'ಅಲರ್ಟ್', 'ಎಚ್ಚರಿಕೆ',
      'அலர்ட்', 'எச்சரிக்கை',
    ],
    'briefing': [
      "what's my day", 'what is my day', 'my day', 'today', 'pending', 'briefing',
      'plan for today', 'आज', 'बाकी', 'आज का काम', 'ಇಂದು', 'ಇವತ್ತು', 'ಇವತ್ತಿನ', 'ಬಾಕಿ',
      'ಇಂದಿನ', 'இன்று', 'இன்னைக்கு', 'இன்றைய', 'நிலுவை', 'பாக்கி',
    ],
    'search': [
      'show', 'find', 'search', 'list', 'filter', 'दिखाओ', 'दिखाइए', 'खोजो', 'ढूंढो',
      'ತೋರಿಸಿ', 'ತೋರಿಸು', 'ಹುಡುಕಿ', 'ಹುಡುಕು', 'ಪಟ್ಟಿ', 'காட்டு', 'காட்டவும்', 'காண்பி',
      'தேடு', 'தேடவும்', 'பட்டியல்',
      // open / go to + English words spoken inside Indian languages
      'open', 'go to', 'show me', 'display', 'look for', 'look up', 'खोलो', 'खोलें', 'खोलिए',
      'ओपन', 'सर्च', 'दिखा', 'दिखाना', 'ढूंढ', 'ತೆರೆ', 'ತೆರೆಯಿರಿ', 'ಓಪನ್', 'ಸರ್ಚ್', 'ಶೋ',
      'திற', 'திறக்கவும்', 'ஓபன்', 'சர்ச்', 'ஷோ', 'காட்டுங்கள்',
    ],
    'assign': [
      'assign', 'assigned', 'allot', 'allocate', 'transfer', 'reassign',
      'असाइन', 'अलॉट', 'आवंटित', 'सौंपो', 'सौंप', 'सौंपें', 'ट्रांसफर', 'ಅಸೈನ್', 'ನಿಯೋಜಿಸಿ',
      'ವರ್ಗಾಯಿಸಿ', 'ಟ್ರಾನ್ಸ್‌ಫರ್', 'அசைன்', 'ஒதுக்கு', 'ஒதுக்கவும்', 'ஒப்படை',
      'மாற்று', 'டிரான்ஸ்பர்',
    ],
  };

  static const Map<String, List<String>> entity = {
    'farmers': [
      'farmer', 'farmers', 'किसान', 'किसानों', 'फार्मर', 'फ़ार्मर', 'ರೈತ', 'ರೈತರು', 'ರೈತರ',
      'ಫಾರ್ಮರ್', 'விவசாயி', 'விவசாயிகள்', 'ஃபார்மர்', 'பார்மர்',
    ],
    'assets': [
      'plot', 'plots', 'asset', 'assets', 'farm', 'farms', 'field', 'fields', 'खेत',
      'प्लॉट', 'जमीन', 'ज़मीन', 'ಜಮೀನು', 'ಹೊಲ', 'ಪ್ಲಾಟ್', 'ತೋಟ', 'நிலம்', 'வயல்',
      'பிளாட்', 'தோட்டம்', 'நிலங்கள்', 'ಜಮೀನುಗಳು', 'ಪ್ಲಾಟ್‌ಗಳು', 'खेतों',
      'प्लॉट्स', 'प्लाट', 'असेट', 'फील्ड', 'ಅಸೆಟ್', 'ಫೀಲ್ಡ್', 'ಪ್ಲಾಟ್‌', 'அசெட்', 'ஃபீல்ட்',
      'பிளாட்டுகள்', 'ப்ளாட்',
    ],
    'tasks': [
      'task', 'tasks', 'work', 'visit', 'visits', 'activity', 'activities', 'job', 'jobs',
      'काम', 'टास्क', 'कार्य', 'एक्टिविटी', 'ಕೆಲಸ', 'ಕಾರ್ಯ', 'ಕೆಲಸಗಳು', 'ಟಾಸ್ಕ್', 'ಆಕ್ಟಿವಿಟಿ',
      'வேலை', 'பணி', 'பணிகள்', 'டாஸ்க்', 'வேலைகள்', 'ஆக்டிவிட்டி',
    ],
  };

  static const Map<String, List<String>> healthStatus = {
    'attention': [
      'need attention', 'needs attention', 'attention', 'problem', 'issue', 'unhealthy',
      'ध्यान', 'समस्या', 'ಗಮನ', 'ಸಮಸ್ಯೆ', 'கவனம்', 'பிரச்சனை',
    ],
    'good': ['healthy', 'good', 'अच्छा', 'स्वस्थ', 'ಉತ್ತಮ', 'ಆರೋಗ್ಯಕರ', 'நல்ல', 'ஆரோக்கியமான'],
  };

  static const Map<String, List<String>> taskStatus = {
    'overdue': [
      'overdue', 'late', 'delayed', 'missed', 'देर', 'ओवरड्यू', 'ಬಾಕಿ ಉಳಿದ', 'ತಡ', 'ಓವರ್‌ಡ್ಯೂ',
      'தாமதம்', 'ஓவர்டியூ',
    ],
    'today': ['today', 'due', 'आज', 'ड्यू', 'ಇಂದು', 'ಇವತ್ತು', 'ಡ್ಯೂ', 'இன்று', 'இன்னைக்கு', 'டியூ'],
    'upcoming': [
      'upcoming', 'future', 'next', 'later', 'tomorrow', 'आने वाले', 'कल', 'अपकमिंग',
      'ಮುಂದಿನ', 'ನಾಳೆ', 'ಅಪ್‌ಕಮಿಂಗ್', 'வரவிருக்கும்', 'நாளை', 'அடுத்த',
    ],
    'pending': [
      'pending', 'remaining', 'not done', 'बाकी', 'पेंडिंग', 'ಬಾಕಿ', 'ಪೆಂಡಿಂಗ್', 'நிலுவை',
      'பாக்கி', 'பெண்டிங்',
    ],
    'completed': [
      'completed', 'done', 'finished', 'complete', 'पूरा', 'पूरे', 'हो गए', 'कम्प्लीट', 'डन',
      'ಮುಗಿದ', 'ಮುಗಿದಿರುವ', 'ಕಂಪ್ಲೀಟ್', 'முடிந்த', 'முடிந்தவை', 'கம்ப்ளீட்',
    ],
  };

  static const Map<String, List<String>> comparator = {
    'gt': [
      'more than', 'above', 'greater than', 'over', 'से ज्यादा', 'से अधिक', 'ಕ್ಕಿಂತ ಹೆಚ್ಚು',
      'ಮೇಲ್ಪಟ್ಟ', 'மேல்', 'க்கு மேல்', 'அதிகமான', 'more', 'ಹೆಚ್ಚು', 'ಮೇಲೆ', 'ज्यादा',
      'अधिक',
    ],
    'lt': [
      'less than', 'below', 'under', 'smaller than', 'से कम', 'ಕ್ಕಿಂತ ಕಡಿಮೆ', 'ಒಳಗಿನ',
      'கீழ்', 'க்கு கீழ்', 'குறைவான', 'less', 'ಕಡಿಮೆ', 'कम',
    ],
  };

  // ---------------------------------------------------------------- labels
  /// Field label / filler words: consumed so they never end up in a name.
  static const List<String> fillers = [
    // English
    'and', 'the', 'is', 'of', 'with', 'in', 'a', 'an', 'at', 'on', 'for', 'to',
    'his', 'her', 'their', 'name', 'farmer', 'mobile', 'phone', 'number', 'no',
    'project', 'soil', 'irrigation', 'type', 'area', 'plot', 'please', 'add',
    'new', 'create', 'register', 'belongs', 'owner', 'crop', 'it', 'its', 'my',
    'called', 'details', 'contact', 'land', 'size', 'water', 'by', 'under',
    // natural sentences, disfluencies, honorifics, self-corrections
    'will', 'be', 'would', 'should', 'shall', 'has', 'have', 'having', 'had', 'he', 'she',
    'they', 'them', 'him', 'i', 'we', 'you', 'want', 'wants', 'need', 'are', 'was', 'were',
    'okay', 'ok', 'so', 'um', 'umm', 'uh', 'uhh', 'hmm', 'er', 'like', 'basically', 'just',
    'actually', 'sorry', 'mean', 'wait', 'not', 'change', 'instead', 'correction', 'also',
    'around', 'about', 'approximately', 'nearly', 'roughly', 'total', 'totally', 'using',
    'use', 'uses', 'through', 'via', 'there', 'that', 'this', 'which', 'who', 'whose',
    'mr', 'mrs', 'ms', 'shri', 'sri', 'smt', 'sir', 'madam', 'yes', 'yeah', 'do', 'does',
    'source', 'grows', 'growing', 'cultivates', 'cultivating', 'own', 'owns', 'acreage',
    'as', 'can', 'could', 'your', 'kindly', 'wanted', 'let', 'lets', "let's", 'us', 'make',
    'entry', 'record', 'person', 'guy', 'man', 'then', 'now', 'give', 'get', 'tell', 'see',
    'list', 'all', 'every', 'owned', 'belonging', 'belongs', 'from', 'whose', 'named',
    'plots', 'farmers', 'any', 'some', 'mine', 'our', 'these', 'those', 'what', 'where',
    'how', 'many', 'much', 'also', 'into', 'onto', 'inside',
    'ऐड', 'एड', 'रजिस्टर', 'ओपन', 'ಆಡ್', 'ರಿಜಿಸ್ಟರ್', 'ಓಪನ್', 'ஆட்', 'ரிஜிஸ்டர்', 'ஓபன்',
    'आप', 'कृपया', 'करें', 'कीजिए', 'नए', 'व्यक्ति', 'सारे', 'सभी', 'मेरे', 'मेरी', 'बताओ',
    'ನೀವು', 'ಒಬ್ಬ', 'ನನ್ನ', 'ಎಲ್ಲಾ', 'ಎಲ್ಲ', 'நீங்கள்', 'ஒரு', 'என்', 'எனது', 'எல்லா',
    // Hindi
    'होगा', 'होगी', 'रहेगा', 'रहेगी', 'था', 'थी', 'उनका', 'उनकी', 'उनके', 'उसका', 'उसकी',
    'उसके', 'इनका', 'इनकी', 'वो', 'वह', 'यह', 'जो', 'भी', 'लगभग', 'करीब', 'जमीन', 'ज़मीन',
    'पास', 'होती', 'होता', 'करते', 'करता', 'करती', 'मतलब', 'अच्छा', 'ठीक', 'माफ़', 'माफ',
    'नहीं', 'गलती', 'श्री', 'श्रीमती', 'साहब', 'जी', 'तो', 'एक', 'कुल', 'द्वारा', 'जोड़', 'जोड़',
    'दो', 'दीजिए', 'इन्हें', 'उन्हें', 'इसे', 'उसे', 'करो', 'कर', 'दें',
    // Kannada
    'ಆಗಿದೆ', 'ಇರುತ್ತೆ', 'ಇರುತ್ತದೆ', 'ಇದ್ದಾರೆ', 'ಅವರದು', 'ಅವನ', 'ಅವರಿಗೆ', 'ಅವರಲ್ಲಿ',
    'ಸುಮಾರು', 'ಒಟ್ಟು', 'ಸರ್', 'ಅಂದರೆ', 'ಅಂದ್ರೆ', 'ಆಗಿರುತ್ತದೆ', 'ಹಾಗೆ', 'ಬೇಕು', 'ಮಾಡ್ತಾರೆ',
    'ಮಾಡುತ್ತಾರೆ', 'ಹೊಂದಿದ್ದಾರೆ', 'ಅಲ್ಲ', 'ಇಲ್ಲ', 'ಕ್ಷಮಿಸಿ', 'ತಪ್ಪು', 'ಶ್ರೀ', 'ಶ್ರೀಮತಿ', 'ಓಕೆ',
    'ಸರಿ', 'ಅದೇ', 'ಈ', 'ಆ', 'ಮೂಲಕ', 'ಬಳಸುತ್ತಾರೆ', 'ರೈತನ', 'ರೈತರ', 'ಮಣ್ಣಿನ', 'ಅವರನ್ನು',
    'ಪ್ರಾಜೆಕ್ಟ್ಗೆ', 'ಪ್ರಾಜೆಕ್ಟ್‌ಗೆ', 'ಯೋಜನೆಗೆ',
    // Tamil
    'இருக்கு', 'இருக்கிறது', 'உள்ளது', 'அவருடைய', 'அவரிடம்', 'அவருக்கு', 'சுமார்', 'மொத்தம்',
    'சார்', 'அதாவது', 'வேண்டும்', 'என்பது', 'ஆனது', 'செய்கிறார்', 'செய்கிறார்கள்', 'இல்லை',
    'மன்னிக்கவும்', 'தப்பு', 'திரு', 'திருமதி', 'சரி', 'ஓகே', 'அந்த', 'மூலம்', 'பயன்படுத்துகிறார்',
    'விவசாயியின்', 'மண்ணு', 'அவரை', 'திட்டத்தில்', 'திட்டத்துக்கு',
    // Hindi
    'है', 'हैं', 'का', 'की', 'के', 'और', 'में', 'नाम', 'मोबाइल', 'नंबर', 'फोन', 'प्रोजेक्ट',
    'परियोजना', 'मिट्टी', 'सिंचाई', 'किसान', 'खेत', 'जोड़ो', 'जोड़ें', 'नया', 'फसल', 'वाला',
    'वाली', 'से', 'को', 'पर', 'हाँ', 'जी',
    // Kannada
    'ಮತ್ತು', 'ಅವರ', 'ಅವರು', 'ಇದೆ', 'ಹಾಗೂ', 'ಹೆಸರು', 'ಮೊಬೈಲ್', 'ನಂಬರ್', 'ಸಂಖ್ಯೆ',
    'ಫೋನ್', 'ಪ್ರಾಜೆಕ್ಟ್', 'ಯೋಜನೆ', 'ಮಣ್ಣು', 'ನೀರಾವರಿ', 'ರೈತ', 'ರೈತರು', 'ಸೇರಿಸಿ', 'ಹೊಸ',
    'ಬೆಳೆ', 'ಜಮೀನು', 'ಪ್ಲಾಟ್', 'ಬಾಧೆ', 'ದಯವಿಟ್ಟು', 'ಮಾಡಿ', 'ಅದು', 'ಇದು', 'ವಿಸ್ತೀರ್ಣ',
    // Tamil
    'மற்றும்', 'உள்ள', 'ஆகும்', 'அவர்', 'அவரது', 'பெயர்', 'மொபைல்', 'எண்', 'நம்பர்',
    'போன்', 'திட்டம்', 'ப்ராஜெக்ட்', 'மண்', 'பாசனம்', 'நீர்ப்பாசனம்', 'விவசாயி', 'சேர்',
    'சேர்க்கவும்', 'புதிய', 'பயிர்', 'நிலம்', 'பிளாட்', 'தயவுசெய்து', 'அது', 'இது', 'பரப்பளவு', 'தாக்குதல்',
  ];

  /// Labels that only appear when someone is dictating a farmer's details.
  static const List<String> farmerLabels = [
    'mobile', 'phone', 'number', 'contact', 'name', 'naam', 'नाम', 'मोबाइल', 'नंबर', 'फोन',
    'ಹೆಸರು', 'ಮೊಬೈಲ್', 'ನಂಬರ್', 'ಫೋನ್', 'பெயர்', 'மொபைல்', 'எண்', 'நம்பர்', 'போன்',
  ];

  /// Words that introduce a person's name ("name is …", "ಹೆಸರು …").
  static const List<String> nameMarkers = [
    'name', 'named', 'called', 'naam', 'नाम', 'ಹೆಸರು', 'ಹೆಸರಿನ', 'ಹೆಸರ', 'பெயர்', 'பேர்',
  ];

  /// Words that introduce a project name.
  static const List<String> projectMarkers = [
    'project', 'प्रोजेक्ट', 'परियोजना', 'ಪ್ರಾಜೆಕ್ಟ್', 'ಯೋಜನೆ', 'திட்டம்', 'ப்ராஜெக்ட்',
  ];

  // ---------------------------------------------------------------- numbers
  static const Map<String, double> numberWords = {
    // English
    'zero': 0, 'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5,
    'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10, 'eleven': 11,
    'twelve': 12, 'thirteen': 13, 'fourteen': 14, 'fifteen': 15, 'sixteen': 16,
    'seventeen': 17, 'eighteen': 18, 'nineteen': 19, 'twenty': 20, 'thirty': 30,
    'forty': 40, 'fifty': 50, 'sixty': 60, 'seventy': 70, 'eighty': 80, 'ninety': 90,
    'hundred': 100, 'half': 0.5,
    // Hindi
    'शून्य': 0, 'एक': 1, 'दो': 2, 'तीन': 3, 'चार': 4, 'पांच': 5, 'पाँच': 5, 'छह': 6,
    'छः': 6, 'सात': 7, 'आठ': 8, 'नौ': 9, 'दस': 10, 'ग्यारह': 11, 'बारह': 12,
    'पंद्रह': 15, 'बीस': 20, 'पच्चीस': 25, 'तीस': 30, 'चालीस': 40, 'पचास': 50, 'साठ': 60,
    'सत्तर': 70, 'अस्सी': 80, 'नब्बे': 90, 'सौ': 100,
    'आधा': 0.5, 'डेढ़': 1.5, 'ढाई': 2.5,
    'ek': 1, 'teen': 3, 'char': 4, 'paanch': 5, 'panch': 5, 'saat': 7,
    'aath': 8, 'nau': 9, 'das': 10,
    // Kannada
    'ಸೊನ್ನೆ': 0, 'ಒಂದು': 1, 'ಎರಡು': 2, 'ಮೂರು': 3, 'ನಾಲ್ಕು': 4, 'ಐದು': 5, 'ಆರು': 6,
    'ಏಳು': 7, 'ಎಂಟು': 8, 'ಒಂಬತ್ತು': 9, 'ಹತ್ತು': 10, 'ಹನ್ನೊಂದು': 11, 'ಹನ್ನೆರಡು': 12,
    'ಹದಿನೈದು': 15, 'ಇಪ್ಪತ್ತು': 20, 'ಇಪ್ಪತ್ತೈದು': 25, 'ಮೂವತ್ತು': 30, 'ನಲವತ್ತು': 40,
    'ಐವತ್ತು': 50, 'ಅರವತ್ತು': 60, 'ಎಪ್ಪತ್ತು': 70, 'ಎಂಬತ್ತು': 80, 'ತೊಂಬತ್ತು': 90,
    'ನೂರು': 100, 'ಅರ್ಧ': 0.5, 'ಒಂದೂವರೆ': 1.5, 'ಎರಡೂವರೆ': 2.5, 'ಮೂರೂವರೆ': 3.5,
    // Tamil
    'பூஜ்ஜியம்': 0, 'ஒன்று': 1, 'ஒன்னு': 1, 'இரண்டு': 2, 'ரெண்டு': 2, 'மூன்று': 3,
    'மூணு': 3, 'நான்கு': 4, 'நாலு': 4, 'ஐந்து': 5, 'அஞ்சு': 5, 'ஆறு': 6, 'ஏழு': 7,
    'எட்டு': 8, 'ஒன்பது': 9, 'பத்து': 10, 'பதினொன்று': 11, 'பன்னிரண்டு': 12,
    'பதினைந்து': 15, 'இருபது': 20, 'இருபத்தைந்து': 25, 'முப்பது': 30, 'நாற்பது': 40,
    'ஐம்பது': 50, 'அறுபது': 60, 'எழுபது': 70, 'எண்பது': 80, 'தொண்ணூறு': 90,
    'நூறு': 100, 'அரை': 0.5, 'ஒன்றரை': 1.5, 'இரண்டரை': 2.5, 'மூன்றரை': 3.5,
  };

  static const List<String> doubleWords = ['double', 'डबल', 'ಡಬಲ್', 'டபுள்'];
  static const List<String> tripleWords = ['triple', 'ट्रिपल', 'ಟ್ರಿಪಲ್', 'ட்ரிபிள்'];
}
