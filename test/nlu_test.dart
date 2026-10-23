import 'package:cropin_voice_agents/data/app_store.dart';
import 'package:cropin_voice_agents/data/demo_data.dart';
import 'package:cropin_voice_agents/voice/agent_language.dart';
import 'package:cropin_voice_agents/voice/agent_strings.dart';
import 'package:cropin_voice_agents/voice/nlu/alert_parser.dart';
import 'package:cropin_voice_agents/voice/nlu/assign_parser.dart';
import 'package:cropin_voice_agents/voice/nlu/dictation.dart';
import 'package:cropin_voice_agents/voice/nlu/form_parser.dart';
import 'package:cropin_voice_agents/voice/nlu/intent_router.dart';
import 'package:cropin_voice_agents/voice/nlu/nbest.dart';
import 'package:cropin_voice_agents/voice/nlu/numbers.dart';
import 'package:cropin_voice_agents/voice/nlu/photo_note_parser.dart';
import 'package:cropin_voice_agents/voice/nlu/search_parser.dart';
import 'package:cropin_voice_agents/voice/nlu/text_utils.dart';
import 'package:cropin_voice_agents/voice/nlu/transliterator.dart';
import 'package:cropin_voice_agents/voice/nlu/utterance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final store = AppStore.instance;
  FormParser formParser() => FormParser(projects: store.projectRefs, farmers: store.farmerRefs);
  String ex(String key, AgentLanguage l) => AgentStrings.examples(key)[l]!.first;

  group('transliteration & phonetics', () {
    test('names read naturally', () {
      expect(Transliterator.toDisplayName('ರಮೇಶ್ ಗೌಡ'), 'Ramesh Gowda');
      expect(Transliterator.toDisplayName('முருகன் செல்வம்'), 'Murugan Selvam');
      expect(Transliterator.toDisplayName('सुरेश यादव'), 'Suresh Yadav');
    });

    test('same word in three scripts shares a key', () {
      final k = TextUtils.phoneticKey('chilli');
      expect(TextUtils.phoneticKey('ಚಿಲ್ಲಿ'), k);
      expect(TextUtils.phoneticKey('சில்லி'), k);
      expect(TextUtils.phoneticKey('Manjunath Shetty'.replaceAll(' ', '')),
          TextUtils.phoneticKey('ಮಂಜುನಾಥ್ಶೆಟ್ಟಿ'));
    });

    test('native digits become ASCII', () {
      expect(TextUtils.asciiDigits('೯೮೪೫೦'), '98450');
      expect(TextUtils.asciiDigits('௧௨௩'), '123');
      expect(TextUtils.asciiDigits('४५'), '45');
    });
  });

  group('numbers', () {
    test('phone from digit groups, words and "double"', () {
      expect(NumberExtractor.extractPhone(Utterance('98450 12345'))!.digits, '9845012345');
      expect(NumberExtractor.extractPhone(Utterance('+91 98450 12345'))!.digits, '9845012345');
      expect(
          NumberExtractor.extractPhone(
                  Utterance('nine eight four five zero one two three four five'))!
              .digits,
          '9845012345');
      expect(NumberExtractor.extractPhone(Utterance('double nine 8 4 5 0 1 2 3 4'))!.digits,
          '9984501234');
      expect(
          NumberExtractor.extractPhone(
                  Utterance('ಒಂಬತ್ತು ಎಂಟು ನಾಲ್ಕು ಐದು ಸೊನ್ನೆ ಒಂದು ಎರಡು ಮೂರು ನಾಲ್ಕು ಐದು'))!
              .digits,
          '9845012345');
    });

    test('phone does not swallow the area that follows', () {
      final u = Utterance('9845012345 2 acres');
      expect(NumberExtractor.extractPhone(u)!.digits, '9845012345');
      final a = NumberExtractor.extractArea(u)!;
      expect(a.value, 2);
      expect(a.unit, 'acre');
    });

    test('areas in four languages', () {
      expect(NumberExtractor.extractArea(Utterance('two and half acres'))!.value, 2.5);
      expect(NumberExtractor.extractArea(Utterance('ಎರಡೂವರೆ ಎಕರೆ'))!.value, 2.5);
      expect(NumberExtractor.extractArea(Utterance('இரண்டு ஏக்கர்'))!.value, 2);
      expect(NumberExtractor.extractArea(Utterance('3 एकड़'))!.value, 3);
      expect(NumberExtractor.extractArea(Utterance('30 guntas'))!.unit, 'gunta');
    });
  });

  group('speak-to-fill: Add Farmer', () {
    test('English', () {
      final r = formParser().parse(ex('farmer', AgentLanguage.english));
      expect(r.name!.value, 'Ramesh Gowda');
      expect(r.phone!.value, '9845012345');
      expect(r.projectId!.value, 'p1');
      expect(r.soil!.value, 'Red Soil');
      expect(r.irrigation!.value, 'Drip');
      expect(r.area!.value, 2);
      expect(r.areaUnit!.value, 'acre');
      expect(r.unmapped, isEmpty);
    });

    test('Kannada', () {
      final r = formParser().parse(ex('farmer', AgentLanguage.kannada));
      expect(r.name!.value, 'Ramesh Gowda');
      expect(r.phone!.value, '9845012345');
      expect(r.projectId!.value, 'p1');
      expect(r.soil!.value, 'Red Soil');
      expect(r.irrigation!.value, 'Drip');
      expect(r.area!.value, 2);
      expect(r.unmapped, isEmpty);
    });

    test('Tamil', () {
      final r = formParser().parse(ex('farmer', AgentLanguage.tamil));
      expect(r.name!.value, 'Murugan Selvam');
      expect(r.phone!.value, '9443056789');
      expect(r.projectId!.value, 'p1');
      expect(r.soil!.value, 'Red Soil');
      expect(r.irrigation!.value, 'Drip');
      expect(r.area!.value, 2);
      expect(r.unmapped, isEmpty);
    });

    test('Hindi', () {
      final r = formParser().parse(ex('farmer', AgentLanguage.hindi));
      expect(r.name!.value, 'Suresh Yadav');
      expect(r.phone!.value, '9876543210');
      expect(r.projectId!.value, 'p2');
      expect(r.soil!.value, 'Black Soil');
      expect(r.irrigation!.value, 'Drip');
      expect(r.area!.value, 3);
      expect(r.unmapped, isEmpty);
    });

    test('fuzzy dropdown values: laal mitti -> Red Soil', () {
      final r = formParser().parse('laal mitti, sprinkler');
      expect(r.soil!.value, 'Red Soil');
      expect(r.irrigation!.value, 'Sprinkler');
    });

    test('unknown words are reported, not dropped', () {
      final r = formParser().parse('Ramesh Gowda 9845012345 xylophone');
      expect(r.unmapped, contains('xylophone'));
    });
  });

  group('speak-to-fill: Add Asset', () {
    FormParseResult parse(AgentLanguage l) =>
        formParser().parse(ex('asset', l), extractName: false, extractOwner: true);

    test('English', () {
      final r = parse(AgentLanguage.english);
      expect(r.ownerId!.value, 'f1');
      expect(r.projectId!.value, 'p2');
      expect(r.soil!.value, 'Black Soil');
      expect(r.irrigation!.value, 'Sprinkler');
      expect(r.area!.value, 4);
      expect(r.unmapped, isEmpty);
    });

    test('Kannada', () {
      final r = parse(AgentLanguage.kannada);
      expect(r.ownerId!.value, 'f2');
      expect(r.projectId!.value, 'p1');
      expect(r.soil!.value, 'Red Soil');
      expect(r.irrigation!.value, 'Drip');
      expect(r.area!.value, 2.5);
      expect(r.unmapped, isEmpty);
    });

    test('Tamil', () {
      final r = parse(AgentLanguage.tamil);
      expect(r.ownerId!.value, 'f3');
      expect(r.projectId!.value, 'p4');
      expect(r.soil!.value, 'Black Soil');
      expect(r.irrigation!.value, 'Drip');
      expect(r.area!.value, 3);
      expect(r.unmapped, isEmpty);
    });

    test('Hindi', () {
      final r = parse(AgentLanguage.hindi);
      expect(r.ownerId!.value, 'f4');
      expect(r.projectId!.value, 'p3');
      expect(r.soil!.value, 'Loamy Soil');
      expect(r.irrigation!.value, 'Sprinkler');
      expect(r.area!.value, 5);
      expect(r.unmapped, isEmpty);
    });
  });

  group('raise alert', () {
    final parser = AlertParser(farmers: store.farmerRefs);
    final expected = {
      AgentLanguage.english: ('Pest', 'High', 'Chilli'),
      AgentLanguage.hindi: ('Disease', 'High', 'Tomato'),
      AgentLanguage.kannada: ('Pest', 'High', 'Chilli'),
      AgentLanguage.tamil: ('Pest', 'High', 'Chilli'),
    };
    for (final e in expected.entries) {
      test(e.key.englishName, () {
        final r = parser.parse(ex('alert', e.key));
        expect(r.type!.value, e.value.$1);
        expect(r.severity!.value, e.value.$2);
        expect(r.crop!.value, e.value.$3);
        expect(r.nearMe, isTrue);
        expect(r.unmapped, isEmpty);
      });
    }
  });

  group('voice search', () {
    final parser = SearchParser(farmers: store.farmerRefs, locations: DemoData.localityAliases);

    test('English: 2-acre chilli plots in BTM that need attention', () {
      final q = parser.parse(ex('search', AgentLanguage.english));
      expect(q.entity, SearchEntity.assets);
      expect(q.crop, 'Chilli');
      expect(q.area, 2);
      expect(q.areaUnit, 'acre');
      expect(q.location, 'BTM Layout');
      expect(q.health, 'attention');
      expect(q.unmapped, isEmpty);
      expect(store.searchAssets(q, '').length, 2);
    });

    for (final l in [AgentLanguage.hindi, AgentLanguage.kannada, AgentLanguage.tamil]) {
      test(l.englishName, () {
        final q = parser.parse(ex('search', l));
        expect(q.entity, SearchEntity.assets);
        expect(q.crop, 'Chilli');
        expect(q.location, 'BTM Layout');
        expect(q.unmapped, isEmpty);
        expect(store.searchAssets(q, '').length, 2);
      });
    }

    test('task status', () {
      final q = parser.parse('show overdue tasks');
      expect(q.entity, SearchEntity.tasks);
      expect(q.taskStatus, 'overdue');
    });
  });

  group('intent routing', () {
    final cases = {
      'farmer': AgentIntent.addFarmer,
      'asset': AgentIntent.addAsset,
      'alert': AgentIntent.raiseAlert,
      'search': AgentIntent.search,
      'briefing': AgentIntent.briefing,
    };
    for (final l in AgentLanguage.values) {
      for (final c in cases.entries) {
        test('${l.englishName} ${c.key}', () {
          expect(IntentRouter.detect(ex(c.key, l)), c.value);
        });
      }
    }

    test('commands', () {
      expect(IntentRouter.detect('add new farmer'), AgentIntent.addFarmer);
      expect(IntentRouter.detect('ಹೊಸ ರೈತ ಸೇರಿಸಿ'), AgentIntent.addFarmer);
      expect(IntentRouter.detect('புதிய நிலம் சேர்'), AgentIntent.addAsset);
      expect(IntentRouter.detect('take photo'), AgentIntent.takePhoto);
      expect(IntentRouter.detect('ಫೋಟೋ'), AgentIntent.takePhoto);
    });
  });

  group('photo notes', () {
    test('English tags', () {
      final tags = PhotoNoteParser.tags(ex('photo', AgentLanguage.english));
      expect(tags, containsAll(['Disease', '15% affected', 'Near borewell']));
    });

    test('Kannada and Tamil tags', () {
      for (final l in [AgentLanguage.kannada, AgentLanguage.tamil]) {
        final tags = PhotoNoteParser.tags(ex('photo', l));
        expect(tags, containsAll(['Disease', '15% affected', 'Near borewell']), reason: l.name);
      }
    });
  });

  group('accuracy upgrades', () {
    test('phone read in pairs: "ninety eight forty five …"', () {
      expect(
          NumberExtractor.extractPhone(
                  Utterance('ninety eight forty five zero one two three four five'))!
              .digits,
          '9845012345');
    });

    test('phonetic distance: vowel / close-consonant edits are cheap', () {
      expect(TextUtils.similarity('tirip', 'trip'), greaterThanOrEqualTo(0.8));
      expect(TextUtils.similarity('kota', 'tote'), lessThan(0.8));
    });

    test('N-best: a lower-ranked hypothesis with better slots wins', () {
      final parser = formParser();
      final (text, r) = NBest.pick(
        ['ramesh gowda 98450 12345 red oil drip', 'ramesh gowda 98450 12345 red soil drip'],
        parser.parse,
        NBest.formScore,
      );
      expect(text, contains('red soil'));
      expect(r.soil!.value, 'Red Soil');
      expect(r.unmapped, isEmpty);
    });

    test('N-best intent: falls through to a hypothesis that has an intent', () {
      final (_, i) = NBest.intent(['hmm', 'show chilli plots in btm']);
      expect(i, AgentIntent.search);
    });

    test('common alert for all plots of a crop in a locality', () {
      final parser =
          AlertParser(farmers: store.farmerRefs, locations: DemoData.localityAliases);
      final r = parser.parse('raise pest alert on all chilli plots in BTM, medium severity');
      expect(r.selectAll, isTrue);
      expect(r.location, 'BTM Layout');
      expect(r.crop!.value, 'Chilli');
      expect(r.severity!.value, 'Medium');
      expect(r.unmapped, isEmpty);
      final kn = parser.parse('ಬಿಟಿಎಂ ನಲ್ಲಿ ಎಲ್ಲಾ ಮೆಣಸಿನಕಾಯಿ ಜಮೀನುಗಳಿಗೆ ಕೀಟ ಎಚ್ಚರಿಕೆ');
      expect(kn.selectAll, isTrue);
      expect(kn.location, 'BTM Layout');
      expect(kn.type!.value, 'Pest');
    });
  });

  group('natural sentences', () {
    void expectFarmer(FormParseResult r, String name, String phone, String project, String soil,
        String irrigation, double area) {
      expect(r.name!.value, name);
      expect(r.phone!.value, phone);
      expect(r.projectId!.value, project);
      expect(r.soil!.value, soil);
      expect(r.irrigation!.value, irrigation);
      expect(r.area!.value, area);
      expect(r.unmapped, isEmpty);
    }

    test('English', () {
      expectFarmer(
          formParser().parse('Okay so the farmer name is Ramesh Gowda and his mobile number is '
              '98450 12345. The project will be Kharif Chilli. He has around 2 acres of red soil '
              'and they use drip irrigation.'),
          'Ramesh Gowda', '9845012345', 'p1', 'Red Soil', 'Drip', 2);
    });

    test('Hindi', () {
      expectFarmer(
          formParser().parse('किसान का नाम सुरेश यादव है, उनका मोबाइल नंबर 98765 43210 है, '
              'प्रोजेक्ट रबी आलू रहेगा, उनके पास 3 एकड़ काली मिट्टी की जमीन है और ड्रिप से सिंचाई होती है'),
          'Suresh Yadav', '9876543210', 'p2', 'Black Soil', 'Drip', 3);
    });

    test('Kannada', () {
      expectFarmer(
          formParser().parse('ರೈತನ ಹೆಸರು ರಮೇಶ್ ಗೌಡ, ಅವರ ಮೊಬೈಲ್ ನಂಬರ್ 98450 12345, ಪ್ರಾಜೆಕ್ಟ್ ಖಾರಿಫ್ '
              'ಮೆಣಸಿನಕಾಯಿ, ಅವರಿಗೆ ಎರಡು ಎಕರೆ ಕೆಂಪು ಮಣ್ಣಿನ ಜಮೀನು ಇದೆ, ಹನಿ ನೀರಾವರಿ ಮಾಡ್ತಾರೆ'),
          'Ramesh Gowda', '9845012345', 'p1', 'Red Soil', 'Drip', 2);
    });

    test('Tamil', () {
      expectFarmer(
          formParser().parse('விவசாயி பெயர் முருகன் செல்வம், அவருடைய மொபைல் எண் 94430 56789, '
              'திட்டம் காரீப் மிளகாய், அவரிடம் இரண்டு ஏக்கர் செம்மண் நிலம் உள்ளது, சொட்டு நீர் '
              'பாசனம் செய்கிறார்'),
          'Murugan Selvam', '9443056789', 'p1', 'Red Soil', 'Drip', 2);
    });

    test('self-corrections: the last value said wins', () {
      final r = formParser().parse('name Ramesh Gowda, mobile 98450 12344 sorry 98450 12345, '
          'red soil no actually black soil, 2 acres sorry 3 acres, drip');
      expect(r.name!.value, 'Ramesh Gowda');
      expect(r.phone!.value, '9845012345');
      expect(r.soil!.value, 'Black Soil');
      expect(r.irrigation!.value, 'Drip');
      expect(r.area!.value, 3);
      expect(r.unmapped, isEmpty);
    });

    test('routes a natural farmer sentence to Add Farmer', () {
      expect(
          IntentRouter.detect('farmer name is Ramesh Gowda and his mobile number is 98450 12345'),
          AgentIntent.addFarmer);
    });
  });

  group('home routing with context', () {
    const said = 'add farmer Ramesh Kumar, his mobile number is 6867116104, and add him to '
        'the paddy project, and the plot area is 7 acres';
    test('goes to Add Farmer, not plot search', () {
      expect(IntentRouter.detect(said), AgentIntent.addFarmer);
      expect(IntentRouter.detect(said.replaceFirst('add farmer', 'at farmer')),
          AgentIntent.addFarmer);
      expect(IntentRouter.detect('farmer Ramesh Kumar mobile number 6867116104 plot 7 acres'),
          AgentIntent.addFarmer);
    });

    test('fills every field from it', () {
      final r = formParser().parse(said.replaceFirst('add farmer', 'at farmer'));
      expect(r.name!.value, 'Ramesh Kumar');
      expect(r.phone!.value, '6867116104');
      expect(r.projectId!.value, 'p5');
      expect(r.area!.value, 7);
      expect(r.hasAssetDetails, isTrue);
    });

    test('a missed digit still fills the mobile field (flagged)', () {
      final r = formParser().parse('farmer Ramesh Kumar mobile number 686711610');
      expect(r.phone!.value, '686711610');
      expect(r.phone!.needsCheck, isTrue);
    });

    test('explicit search still searches', () {
      expect(IntentRouter.detect('show plots with 7 acres'), AgentIntent.search);
    });
  });

  group('dictation across pauses', () {
    Dictation said(List<String> segments) {
      final d = Dictation();
      for (final s in segments) {
        d.add(s);
      }
      return d;
    }

    final cases = {
      'English': (
        ['farmer name is Ramesh Kumar, his mobile number is 6867116104', 'add him to the paddy project'],
        'Ramesh Kumar', '6867116104',
      ),
      'Hindi': (
        ['किसान का नाम सुरेश यादव मोबाइल 98765 43210', 'इन्हें धान प्रोजेक्ट में जोड़ दो'],
        'Suresh Yadav', '9876543210',
      ),
      'Kannada': (
        ['ರೈತನ ಹೆಸರು ರಮೇಶ್ ಗೌಡ ಮೊಬೈಲ್ 98450 12345', 'ಅವರನ್ನು ಭತ್ತ ಪ್ರಾಜೆಕ್ಟ್‌ಗೆ ಸೇರಿಸಿ'],
        'Ramesh Gowda', '9845012345',
      ),
      'Tamil': (
        ['விவசாயி பெயர் முருகன் செல்வம் மொபைல் 94430 56789', 'அவரை நெல் திட்டத்தில் சேர்க்கவும்'],
        'Murugan Selvam', '9443056789',
      ),
    };
    for (final c in cases.entries) {
      test('${c.key}: both halves are kept and routed to Add Farmer', () {
        final d = said(c.value.$1);
        expect(IntentRouter.detect(d.text), AgentIntent.addFarmer);
        final r = formParser().parse(d.text);
        expect(r.name!.value, c.value.$2);
        expect(r.phone!.value, c.value.$3);
        expect(r.projectId!.value, 'p5');
        expect(r.unmapped, isEmpty);
      });
    }

    test('silence adds nothing; "done" words finish and are stripped', () {
      final d = Dictation()
        ..add('   ')
        ..add('name Ramesh Kumar');
      expect(d.text, 'name Ramesh Kumar');
      expect(Dictation.stripDone('paddy project done'), ('paddy project', true));
      expect(Dictation.stripDone('ಭತ್ತ ಪ್ರಾಜೆಕ್ಟ್ ಮುಗಿತು'), ('ಭತ್ತ ಪ್ರಾಜೆಕ್ಟ್', true));
      expect(Dictation.stripDone('நெல் திட்டம் முடிந்தது'), ('நெல் திட்டம்', true));
      expect(Dictation.stripDone('धान प्रोजेक्ट बस'), ('धान प्रोजेक्ट', true));
      expect(Dictation.stripDone('paddy project').$2, isFalse);
    });

    test('N-best variants per segment', () {
      final d = Dictation()
        ..add('name Ramesh Kumar', ['name Ramesh Kumar', 'name Rakesh Kumar'])
        ..add('red oil', ['red oil', 'red soil']);
      expect(d.hypotheses(), containsAll(['name Ramesh Kumar red oil', 'name Ramesh Kumar red soil']));
    });
  });

  group('search refinements', () {
    final parser = SearchParser(farmers: store.farmerRefs, locations: DemoData.localityAliases);

    test('city covers its localities; "give" is not Kovai', () {
      final q = parser.parse('give me a list of all the plots in Bengaluru');
      expect(q.location, 'Bengaluru');
      final list = store.searchAssets(q, '');
      expect(list, isNotEmpty);
      expect(list.every((a) => DemoData.localityGroups['Bengaluru']!.contains(a.locality)), isTrue);
      expect(parser.parse('ಬೆಂಗಳೂರಿನ ಎಲ್ಲಾ ಜಮೀನು ತೋರಿಸಿ').location, 'Bengaluru');
      expect(parser.parse('தமிழ்நாடு நிலங்களை காட்டு').location, 'Tamil Nadu');
    });

    test('plot code CA-1 returns every CA-1 plot', () {
      for (final said in ['search for all the CA-1 plots', 'show CA 1 plots', 'find ca1 plots']) {
        final q = parser.parse(said);
        expect(q.code, 'ca1', reason: said);
        expect(store.searchAssets(q, '').length, store.assets.length, reason: said);
      }
    });

    test('all maize / potato plots', () {
      final m = parser.parse('show me all my maize plots');
      expect(m.crop, 'Maize');
      expect(m.entity, SearchEntity.assets);
      expect(store.searchAssets(m, '').every((a) => a.crop == 'Maize'), isTrue);
      expect(parser.parse('show me all the potato plots').crop, 'Potato');
      expect(parser.parse('मक्का के सभी खेत दिखाओ').crop, 'Maize');
      expect(parser.parse('ಎಲ್ಲಾ ಆಲೂಗಡ್ಡೆ ಜಮೀನು ತೋರಿಸಿ').crop, 'Potato');
      expect(parser.parse('எல்லா மக்காச்சோளம் நிலங்களை காட்டு').crop, 'Maize');
    });

    test('plots owned by a farmer', () {
      final q = parser.parse('search for plots owned by Mahesh Hegde');
      expect(q.farmerId, 'f1');
      expect(q.unmapped, isEmpty);
    });
  });

  group('add farmer from free sentences', () {
    final sentences = [
      'Please register Ramesh Kumar as a new farmer, his phone is 98450 12345 and he grows paddy',
      'Can you add Ramesh Kumar, mobile 9845012345, to the paddy project',
      'I want to add a farmer named Ramesh Kumar whose number is 98450 12345 under paddy',
      'add Ramesh Kumar to the paddy project his number is 98450 12345',
    ];
    for (final said in sentences) {
      test(said, () {
        expect(IntentRouter.detect(said), AgentIntent.addFarmer);
        final r = formParser().parse(said);
        expect(r.name!.value, 'Ramesh Kumar');
        expect(r.phone!.value, '9845012345');
        expect(r.projectId!.value, 'p5');
      });
    }

    test('add without a number still goes to Add Farmer', () {
      expect(IntentRouter.detect('add Ramesh Kumar to the paddy project'), AgentIntent.addFarmer);
    });
  });

  group('Hindi alert phrasing', () {
    final parser = AlertParser(farmers: store.farmerRefs, locations: DemoData.localityAliases);
    for (final said in [
      'एक अलर्ट रेज करो आलू टाइप प्लॉट में और सेवेरिटी मीडियम होगी',
      'एक अलर्ट रेज करो आलु के प्लॉट में और गंभीरता मध्यम होगी',
      'एक अलर्ट रेज करो पोटैटो टाइप प्लॉट में और सेवेरिटी मीडियम होगी',
      'ek alert raise karo potato type plot mein aur severity medium hogi',
      'ek alert raise karo aloo plot mein severity medium',
    ]) {
      test(said, () {
        final r = parser.parse(said);
        expect(r.crop!.value, 'Potato');
        expect(r.severity!.value, 'Medium');
        expect(IntentRouter.detect(said), AgentIntent.raiseAlert);
      });
    }

    test('follow-up sentence gives the type', () {
      expect(parser.parse('पेस्ट टाइप रेज करनी है').type!.value, 'Pest');
      expect(parser.parse('pest type raise karni hai').type!.value, 'Pest');
    });
  });

  group('home assistant behaviours', () {
    final search = SearchParser(farmers: store.farmerRefs, locations: DemoData.localityAliases);
    final assign = AssignParser(farmers: store.farmerRefs, locations: DemoData.localityAliases);

    test('task questions', () {
      for (final (said, status) in [
        ('which tasks are done', 'completed'),
        ('show upcoming tasks', 'upcoming'),
        ('show overdue visits', 'overdue'),
        ('पूरे हो गए काम दिखाओ', 'completed'),
        ('ಮುಗಿದಿರುವ ಕೆಲಸಗಳನ್ನು ತೋರಿಸಿ', 'completed'),
        ('வரவிருக்கும் பணிகள் காட்டு', 'upcoming'),
      ]) {
        expect(IntentRouter.detect(said), AgentIntent.search, reason: said);
        final q = search.parse(said);
        expect(q.entity, SearchEntity.tasks, reason: said);
        expect(q.taskStatus, status, reason: said);
      }
      // the daily briefing still works
      expect(IntentRouter.detect("What's pending today?"), AgentIntent.briefing);
    });

    test('open a farmer (English words inside other languages too)', () {
      for (final said in [
        'open farmer Sunita Devi',
        'सुनीता देवी फार्मर ओपन करो',
        'ಸುನೀತಾ ದೇವಿ ಫಾರ್ಮರ್ ಓಪನ್ ಮಾಡಿ',
        'சுனிதா தேவி ஃபார்மர் ஓபன் செய்',
      ]) {
        expect(IntentRouter.detect(said), AgentIntent.search, reason: said);
        expect(search.parse(said).farmerId, 'f4', reason: said);
      }
    });

    test('code-mixed search', () {
      expect(search.parse('एल्ला पोटैटो प्लॉट्स दिखाओ').crop, 'Potato');
      expect(search.parse('ಎಲ್ಲಾ ಪೊಟಾಟೊ ಪ್ಲಾಟ್ ತೋರಿಸಿ').crop, 'Potato');
      expect(search.parse('எல்லா பொட்டேட்டோ பிளாட் காட்டு').crop, 'Potato');
    });

    test('assign a plot to a farmer', () {
      final cases = [
        ('assign plot CA 1 of Mahesh Hegde to Sunita Devi', 'f4', 'f1'),
        ('सुनीता देवी को आलू का प्लॉट असाइन करो', 'f4', null),
        ('ಆಲೂಗಡ್ಡೆ ಜಮೀನನ್ನು ಸುನೀತಾ ದೇವಿಗೆ ನಿಯೋಜಿಸಿ', 'f4', null),
      ];
      for (final (said, to, from) in cases) {
        expect(IntentRouter.detect(said), AgentIntent.assignPlot, reason: said);
        final r = assign.parse(said);
        expect(r.toFarmerId, to, reason: said);
        expect(r.fromFarmerId, from, reason: said);
      }
      expect(assign.parse('assign plot CA 1 of Mahesh Hegde to Sunita Devi').code, 'ca1');
      expect(assign.parse('सुनीता देवी को आलू का प्लॉट असाइन करो').crop, 'Potato');
    });

    test('code-mixed add farmer', () {
      const said = 'ऐड फार्मर रमेश कुमार मोबाइल 9845012345 धान प्रोजेक्ट';
      expect(IntentRouter.detect(said), AgentIntent.addFarmer);
      final r = formParser().parse(said);
      expect(r.name!.value, 'Ramesh Kumar');
      expect(r.phone!.value, '9845012345');
      expect(r.projectId!.value, 'p5');
    });

    test('alert on a specific plot by code', () {
      final r = AlertParser(farmers: store.farmerRefs, locations: DemoData.localityAliases)
          .parse('raise disease alert on plot mh01 CA 1, high severity');
      expect(r.code, isNotNull);
      expect(r.type!.value, 'Disease');
      expect(r.severity!.value, 'High');
    });
  });
}
