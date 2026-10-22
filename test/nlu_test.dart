import 'package:cropin_voice_agents/data/app_store.dart';
import 'package:cropin_voice_agents/data/demo_data.dart';
import 'package:cropin_voice_agents/voice/agent_language.dart';
import 'package:cropin_voice_agents/voice/agent_strings.dart';
import 'package:cropin_voice_agents/voice/nlu/alert_parser.dart';
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
}
