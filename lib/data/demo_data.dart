import '../services/location_service.dart';
import 'models.dart';

/// Demo dataset (28 farmers, 30 plots, 28 tasks, 8 projects) around
/// Bengaluru, Mysuru-Mandya, Hosur-Krishnagiri, Coimbatore and Patna.
class DemoData {
  static const projects = [
    Project('p1', 'Kharif Chilli 2026', 'Chilli', 'Kharif'),
    Project('p2', 'Rabi Potato 2026', 'Potato', 'Rabi'),
    Project('p3', 'Maize Seed Programme', 'Maize', 'Kharif'),
    Project('p4', 'Tomato Contract Farming', 'Tomato', 'Rabi'),
    Project('p5', 'Paddy Sustainability', 'Paddy', 'Kharif'),
    Project('p6', 'Ragi Millet Mission', 'Ragi', 'Kharif'),
    Project('p7', 'Sugarcane Yield Plus', 'Sugarcane', 'Rabi'),
    Project('p8', 'Groundnut Kharif 2026', 'Groundnut', 'Kharif'),
  ];

  static const soils = [
    'Red Soil', 'Black Soil', 'Alluvial Soil', 'Laterite Soil', 'Sandy Soil', 'Clay Soil',
    'Loamy Soil',
  ];
  static const irrigationTypes = ['Drip', 'Sprinkler', 'Flood', 'Rainfed', 'Canal', 'Borewell'];
  static const areaUnits = ['acre', 'hectare', 'gunta', 'cent', 'bigha'];
  static const crops = [
    'Chilli', 'Potato', 'Maize', 'Tomato', 'Paddy', 'Ragi', 'Sugarcane', 'Groundnut',
  ];
  static const alertTypes = [
    'Pest', 'Disease', 'Weather damage', 'Nutrient deficiency', 'Water stress', 'Weed',
  ];
  static const severities = ['High', 'Medium', 'Low'];

  /// locality -> (address suffix, centre)
  static const localities = <String, (String, GeoPoint)>{
    'BTM Layout': ('BTM Layout Stage 1, Bengaluru Urban, Karnataka', GeoPoint(12.9166, 77.6101)),
    'Bommanahalli': ('Bommanahalli, SBI Colony, Bangalore Division, Karnataka', GeoPoint(12.9081, 77.6245)),
    'Madivala': ('Madivala, Bengaluru Urban, Karnataka', GeoPoint(12.9226, 77.6174)),
    'HSR Layout': ('HSR Layout Sector 2, Bengaluru, Karnataka', GeoPoint(12.9121, 77.6446)),
    'Jayanagar': ('Jayanagar 4th Block, Bengaluru, Karnataka', GeoPoint(12.9299, 77.5826)),
    'Anekal': ('Anekal Taluk, Bengaluru Urban, Karnataka', GeoPoint(12.7105, 77.6954)),
    'Hosur': ('Hosur, Krishnagiri District, Tamil Nadu', GeoPoint(12.7409, 77.8253)),
    'Krishnagiri': ('Krishnagiri, Tamil Nadu', GeoPoint(12.5186, 78.2137)),
    'Mandya': ('Mandya, Karnataka', GeoPoint(12.5218, 76.8951)),
    'Mysuru': ('Nanjangud Road, Mysuru, Karnataka', GeoPoint(12.2958, 76.6394)),
    'Kolar': ('Kolar, Karnataka', GeoPoint(13.1367, 78.1292)),
    'Coimbatore': ('Pollachi Road, Coimbatore, Tamil Nadu', GeoPoint(11.0168, 76.9558)),
    'Patna': ('Kavi Raman Path, Kidwaipuri, Patna, Bihar', GeoPoint(25.5941, 85.1376)),
  };

  /// Spoken aliases for localities (voice search).
  static const localityAliases = <String, List<String>>{
    'BTM Layout': ['btm layout', 'btm', 'ಬಿಟಿಎಂ', 'ಬಿಟಿಎಂ ಲೇಔಟ್', 'பிடிஎம்', 'बीटीएम'],
    'Bommanahalli': ['bommanahalli', 'ಬೊಮ್ಮನಹಳ್ಳಿ', 'பொம்மனஹள்ளி', 'बोम्मनहल्ली'],
    'Madivala': ['madivala', 'ಮಡಿವಾಳ', 'மடிவாளா', 'मडिवाला'],
    'HSR Layout': ['hsr layout', 'hsr', 'ಎಚ್ಎಸ್ಆರ್', 'ஹெச்எஸ்ஆர்'],
    'Jayanagar': ['jayanagar', 'ಜಯನಗರ', 'ஜெயநகர்', 'जयनगर'],
    'Anekal': ['anekal', 'ಆನೇಕಲ್', 'ஆனேக்கல்'],
    'Hosur': ['hosur', 'ಹೊಸೂರು', 'ஓசூர்', 'होसुर'],
    'Krishnagiri': ['krishnagiri', 'ಕೃಷ್ಣಗಿರಿ', 'கிருஷ்ணகிரி'],
    'Mandya': ['mandya', 'ಮಂಡ್ಯ', 'மண்டியா', 'मांड्या'],
    'Mysuru': ['mysuru', 'mysore', 'ಮೈಸೂರು', 'மைசூர்', 'मैसूर'],
    'Kolar': ['kolar', 'ಕೋಲಾರ', 'கோலார்'],
    'Coimbatore': ['coimbatore', 'kovai', 'கோயம்புத்தூர்', 'கோவை', 'ಕೊಯಮತ್ತೂರು'],
    'Patna': ['patna', 'पटना'],
  };

  // name, code, phone, locality, projects
  static const _farmers = [
    ('Mahesh Hegde', 'MH-101', '9845011223', 'BTM Layout', ['p1', 'p2']),
    ('Manjunath Shetty', 'MS-102', '9886022334', 'Bommanahalli', ['p1']),
    ('Senthil Kumar', 'SK-103', '9443033445', 'Hosur', ['p4']),
    ('Sunita Devi', 'SD-104', '9934044556', 'Patna', ['p3']),
    ('Lakshmi Narayana', 'LN-105', '9900155667', 'Mandya', ['p5', 'p7']),
    ('Kavya Reddy', 'KR-106', '9741066778', 'HSR Layout', ['p4']),
    ('Basavaraj Patil', 'BP-107', '9845177889', 'Madivala', ['p1']),
    ('Anitha Kumari', 'AK-108', '9535088990', 'Jayanagar', ['p4']),
    ('Karthik Raja', 'KR-109', '9442199001', 'Krishnagiri', ['p8']),
    ('Meenakshi Sundaram', 'MS-110', '9842010112', 'Coimbatore', ['p7']),
    ('Prakash Naik', 'PN-111', '9632121223', 'Anekal', ['p6']),
    ('Shivakumar Swamy', 'SS-112', '9880132334', 'Mysuru', ['p6']),
    ('Venkatesh Murthy', 'VM-113', '9448143445', 'Kolar', ['p2']),
    ('Rajesh Kumar Singh', 'RS-114', '9835154556', 'Patna', ['p5']),
    ('Sowmya Rao', 'SR-115', '9741265667', 'BTM Layout', ['p1']),
    ('Nagaraj Gowda', 'NG-116', '9008276778', 'Mandya', ['p7']),
    ('Divya Bharathi', 'DB-117', '9787287889', 'Hosur', ['p1', 'p4']),
    ('Arjun Kannan', 'AK-118', '9894298990', 'Coimbatore', ['p3']),
    ('Geetha Ramesh', 'GR-119', '9845309001', 'Madivala', ['p4']),
    ('Siddappa Hosamani', 'SH-120', '9611310112', 'Mysuru', ['p5']),
    ('Pooja Sharma', 'PS-121', '9431321223', 'Patna', ['p2']),
    ('Muthu Pandian', 'MP-122', '9443332334', 'Krishnagiri', ['p8']),
    ('Chandrashekar Bhat', 'CB-123', '9886343445', 'Jayanagar', ['p3']),
    ('Revathi Subramani', 'RS-124', '9791354556', 'Hosur', ['p6']),
    ('Harish Kumar', 'HK-125', '9620365667', 'Bommanahalli', ['p2']),
    ('Yashodha Naidu', 'YN-126', '9480376778', 'Kolar', ['p8']),
    ('Dinesh Yadav', 'DY-127', '9939387889', 'Patna', ['p3']),
    ('Kumaraswamy Hiremath', 'KH-128', '9845398990', 'Anekal', ['p6']),
  ];

  // farmer#, project, variety, sub-variety, area, unit, soil, irrigation, health, status, dLat, dLng
  static const _assets = [
    (1, 'p1', 'Byadgi', 'Kaddi', 2.0, 'acre', 'Red Soil', 'Drip', 'attention', 'current', 0.0012, 0.0010),
    (1, 'p2', 'Kufri Jyoti', 'Table', 5.0, 'acre', 'Loamy Soil', 'Sprinkler', 'good', 'current', -0.0040, 0.0035),
    (2, 'p1', 'Guntur Sannam', 'S4', 2.0, 'acre', 'Red Soil', 'Drip', 'good', 'current', 0.0020, -0.0015),
    (3, 'p4', 'Arka Rakshak', 'Hybrid', 3.0, 'acre', 'Black Soil', 'Drip', 'attention', 'current', 0.0030, 0.0020),
    (4, 'p3', 'NK 6240', 'Seed', 4.0, 'bigha', 'Alluvial Soil', 'Canal', 'good', 'current', 0.0050, 0.0040),
    (5, 'p5', 'Sona Masuri', 'Fine', 6.0, 'acre', 'Clay Soil', 'Canal', 'good', 'current', 0.0045, -0.0030),
    (5, 'p7', 'Co 86032', 'Ratoon', 8.0, 'acre', 'Black Soil', 'Flood', 'attention', 'current', -0.0060, 0.0025),
    (6, 'p4', 'Arka Samrat', 'Hybrid', 1.5, 'acre', 'Red Soil', 'Drip', 'good', 'current', 0.0018, 0.0022),
    (7, 'p1', 'Teja', 'Hot', 3.0, 'acre', 'Red Soil', 'Borewell', 'good', 'current', -0.0015, 0.0012),
    (8, 'p4', 'Arka Rakshak', 'Hybrid', 2.0, 'acre', 'Loamy Soil', 'Drip', 'attention', 'current', 0.0010, -0.0020),
    (9, 'p8', 'TMV 2', 'Bunch', 5.0, 'acre', 'Sandy Soil', 'Rainfed', 'good', 'current', 0.0060, 0.0030),
    (10, 'p7', 'Co 86032', 'Plant', 10.0, 'acre', 'Black Soil', 'Drip', 'good', 'current', 0.0035, 0.0050),
    (11, 'p6', 'GPU 28', 'Finger', 2.5, 'acre', 'Red Soil', 'Rainfed', 'good', 'current', 0.0025, -0.0040),
    (12, 'p6', 'MR 6', 'Finger', 3.5, 'acre', 'Red Soil', 'Rainfed', 'attention', 'current', -0.0030, 0.0020),
    (13, 'p2', 'Kufri Pukhraj', 'Table', 4.0, 'acre', 'Red Soil', 'Sprinkler', 'good', 'upcoming', 0.0040, 0.0010),
    (14, 'p5', 'BPT 5204', 'Fine', 2.0, 'hectare', 'Alluvial Soil', 'Canal', 'good', 'current', -0.0025, 0.0035),
    (15, 'p1', 'Byadgi', 'Dabbi', 2.0, 'acre', 'Red Soil', 'Drip', 'attention', 'current', -0.0022, -0.0008),
    (15, 'p1', 'Guntur Sannam', 'S4', 3.0, 'acre', 'Red Soil', 'Sprinkler', 'good', 'current', 0.0030, -0.0025),
    (16, 'p7', 'Co 86032', 'Plant', 7.0, 'acre', 'Black Soil', 'Flood', 'good', 'current', 0.0030, 0.0060),
    (17, 'p1', 'Teja', 'Hot', 1.0, 'acre', 'Red Soil', 'Drip', 'good', 'current', -0.0040, -0.0030),
    (17, 'p4', 'Arka Samrat', 'Hybrid', 2.0, 'acre', 'Red Soil', 'Drip', 'attention', 'current', 0.0050, -0.0010),
    (18, 'p3', 'Pioneer 3396', 'Grain', 6.0, 'acre', 'Black Soil', 'Sprinkler', 'good', 'current', -0.0050, 0.0030),
    (19, 'p4', 'Arka Rakshak', 'Hybrid', 1.0, 'acre', 'Red Soil', 'Drip', 'good', 'current', 0.0008, 0.0015),
    (20, 'p5', 'Sona Masuri', 'Fine', 4.0, 'acre', 'Clay Soil', 'Canal', 'attention', 'current', 0.0020, 0.0045),
    (21, 'p2', 'Kufri Jyoti', 'Table', 3.0, 'bigha', 'Alluvial Soil', 'Borewell', 'good', 'upcoming', -0.0035, -0.0020),
    (22, 'p8', 'K 6', 'Spreading', 4.0, 'acre', 'Sandy Soil', 'Rainfed', 'attention', 'current', 0.0045, -0.0035),
    (23, 'p3', 'NK 6240', 'Seed', 2.0, 'acre', 'Red Soil', 'Drip', 'good', 'current', -0.0012, 0.0028),
    (24, 'p6', 'GPU 28', 'Finger', 2.0, 'acre', 'Red Soil', 'Rainfed', 'good', 'current', 0.0015, 0.0042),
    (25, 'p2', 'Kufri Pukhraj', 'Table', 2.0, 'acre', 'Loamy Soil', 'Sprinkler', 'good', 'current', 0.0028, 0.0018),
    (26, 'p8', 'TMV 2', 'Bunch', 30.0, 'gunta', 'Red Soil', 'Borewell', 'good', 'current', -0.0018, 0.0040),
  ];

  static const _taskTypes = [
    'Crop scouting', 'Irrigation check', 'Fertilizer application', 'Pest trap check',
    'Yield estimation', 'Sowing verification', 'Geo-tag photos', 'Farmer meeting',
  ];

  static List<Farmer> farmers() => [
        for (var i = 0; i < _farmers.length; i++)
          Farmer(
            id: 'f${i + 1}',
            name: _farmers[i].$1,
            code: _farmers[i].$2,
            phone: _farmers[i].$3,
            locality: _farmers[i].$4,
            address: localities[_farmers[i].$4]!.$1,
            projectIds: List.of(_farmers[i].$5),
          ),
      ];

  static List<Asset> assets() {
    final out = <Asset>[];
    for (var i = 0; i < _assets.length; i++) {
      final a = _assets[i];
      final f = _farmers[a.$1 - 1];
      final project = projects.firstWhere((p) => p.id == a.$2);
      final centre = localities[f.$4]!.$2;
      final code = f.$1.split(' ').map((w) => w[0].toLowerCase()).join();
      out.add(Asset(
        id: 'a${i + 1}',
        name: '$code${(i + 1).toString().padLeft(2, '0')}/CA-1',
        farmerId: 'f${a.$1}',
        projectId: a.$2,
        crop: project.crop,
        variety: a.$3,
        subVariety: a.$4,
        address: localities[f.$4]!.$1,
        locality: f.$4,
        area: a.$5,
        unit: a.$6,
        soil: a.$7,
        irrigation: a.$8,
        health: a.$9,
        status: a.$10,
        location: GeoPoint(centre.lat + a.$11, centre.lng + a.$12),
      ));
    }
    return out;
  }

  static List<FieldTask> tasks(List<Asset> assets) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 10);
    // day offsets relative to today: negatives are overdue
    const offsets = [
      0, -2, 0, 1, -1, 0, 2, 3, 0, -3, 1, 0, 4, 2, -1, 0, 5, 1, 0, 2, 3, -2, 1, 0, 6, 2, 0, 1,
    ];
    return [
      for (var i = 0; i < 28; i++)
        FieldTask(
          id: 't${i + 1}',
          type: _taskTypes[i % _taskTypes.length],
          assetId: assets[i % assets.length].id,
          farmerId: assets[i % assets.length].farmerId,
          due: today.add(Duration(days: offsets[i], hours: i % 5)),
          status: (i % 9 == 8) ? 'completed' : 'pending',
        ),
    ];
  }

  static List<FieldAlert> alerts() => [
        FieldAlert(
          id: 'al1',
          assetIds: const ['a4'],
          type: 'Disease',
          severity: 'Medium',
          note: 'Early blight spots on lower leaves',
          createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
        ),
        FieldAlert(
          id: 'al2',
          assetIds: const ['a7'],
          type: 'Water stress',
          severity: 'Low',
          note: 'Ratoon crop wilting at the tail end',
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
      ];

  static const advisories = [
    Advisory('weather', 'Weather & Climate Advisory', {
      'en': 'Heavy rain expected in the next 2 days around Bengaluru. Postpone spraying and clear field drains.',
      'hi': 'अगले दो दिनों में बेंगलुरु के आसपास भारी बारिश की संभावना। छिड़काव टालें और नालियाँ साफ़ रखें।',
      'kn': 'ಮುಂದಿನ ಎರಡು ದಿನಗಳಲ್ಲಿ ಬೆಂಗಳೂರು ಸುತ್ತಮುತ್ತ ಭಾರೀ ಮಳೆ ನಿರೀಕ್ಷೆ. ಸಿಂಪರಣೆ ಮುಂದೂಡಿ, ಹೊಲದ ಕಾಲುವೆಗಳನ್ನು ಸ್ವಚ್ಛಗೊಳಿಸಿ.',
      'ta': 'அடுத்த இரண்டு நாட்களில் பெங்களூரு சுற்றுவட்டாரத்தில் கனமழை எதிர்பார்க்கப்படுகிறது. தெளிப்பை ஒத்திவைத்து வடிகால்களை சுத்தம் செய்யவும்.',
    }),
    Advisory('indices', 'Indices Advisory', {
      'en': 'NDVI dropped by 12% on 3 chilli plots in BTM Layout this week.',
      'hi': 'इस हफ्ते बीटीएम लेआउट के 3 मिर्च खेतों में NDVI 12% घटा है।',
      'kn': 'ಈ ವಾರ ಬಿಟಿಎಂ ಲೇಔಟ್‌ನ 3 ಮೆಣಸಿನಕಾಯಿ ಜಮೀನುಗಳಲ್ಲಿ NDVI 12% ಕುಸಿದಿದೆ.',
      'ta': 'இந்த வாரம் பிடிஎம் லேஅவுட்டில் 3 மிளகாய் நிலங்களில் NDVI 12% குறைந்துள்ளது.',
    }),
    Advisory('pest', 'Pest & Disease Advisory', {
      'en': 'Thrips risk is high for chilli this week. Install blue sticky traps.',
      'hi': 'इस हफ्ते मिर्च में थ्रिप्स का खतरा ज्यादा है। नीले चिपचिपे ट्रैप लगाएँ।',
      'kn': 'ಈ ವಾರ ಮೆಣಸಿನಕಾಯಿಗೆ ಥ್ರಿಪ್ಸ್ ಅಪಾಯ ಹೆಚ್ಚು. ನೀಲಿ ಅಂಟು ಬಲೆಗಳನ್ನು ಅಳವಡಿಸಿ.',
      'ta': 'இந்த வாரம் மிளகாயில் இலைப்பேன் அபாயம் அதிகம். நீல ஒட்டும் பொறிகளை வையுங்கள்.',
    }),
  ];
}
