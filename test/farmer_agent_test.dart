import 'package:cropin_voice_agents/farmer_form/form_agent.dart';
import 'package:cropin_voice_agents/farmer_form/form_spec.dart';
import 'package:cropin_voice_agents/farmer_form/value_parsers.dart';
import 'package:cropin_voice_agents/voice/agent_language.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  FarmerFormAgent agentFor([AgentLanguage l = AgentLanguage.english]) =>
      FarmerFormAgent(values: {'areaUnit': 'acre'}, lang: l);

  FieldSpec f(String id) => FarmerFormSpec.byId[id]!;

  group('everything at once', () {
    test('English', () {
      final a = agentFor()..start();
      final r = a.hear('add farmer Ramesh Kumar mobile 98450 12345 paddy project');
      expect(a.values['name'], 'Ramesh Kumar');
      expect(a.values['mobile'], '9845012345');
      expect(a.values['project'], 'p5');
      expect(a.mode, AgentMode.offering);
      expect(r.chips, contains('Submit'));
    });

    test('unlabelled', () {
      final a = agentFor()..start();
      a.hear('Ramesh Kumar 9845012345 paddy');
      expect(a.values['name'], 'Ramesh Kumar');
      expect(a.values['mobile'], '9845012345');
      expect(a.values['project'], 'p5');
    });

    test('Hindi word order (value before the field name)', () {
      final a = agentFor(AgentLanguage.hindi)..start();
      a.hear('किसान का नाम रमेश कुमार, मोबाइल नंबर 9845012345, धान प्रोजेक्ट');
      expect(a.values['name'], 'Ramesh Kumar');
      expect(a.values['mobile'], '9845012345');
      expect(a.values['project'], 'p5');
    });

    test('Kannada', () {
      final a = agentFor(AgentLanguage.kannada)..start();
      a.hear('ರಮೇಶ್ ಕುಮಾರ್ ಮೊಬೈಲ್ ಸಂಖ್ಯೆ 9845012345 ಭತ್ತ ಪ್ರಾಜೆಕ್ಟ್');
      expect(a.values['name'], contains('Ramesh'));
      expect(a.values['mobile'], '9845012345');
      expect(a.values['project'], 'p5');
    });

    test('Tamil', () {
      final a = agentFor(AgentLanguage.tamil)..start();
      a.hear('விவசாயி பெயர் ரமேஷ் குமார் மொபைல் எண் 9845012345 நெல் திட்டம்');
      expect(a.values['name'], contains('Ramesh'));
      expect(a.values['mobile'], '9845012345');
      expect(a.values['project'], 'p5');
    });
  });

  group('open first turn', () {
    test('any field, in any order, is filled from the first answer', () {
      final a = agentFor()..start();
      final r = a.hear('Ramesh Kumar mobile 98450 12345 village Hosakote pin code 562114 '
          'gender male aadhaar 1234 5678 9012 bank name canara bank');
      expect(a.values['name'], 'Ramesh Kumar');
      expect(a.values['mobile'], '9845012345');
      expect(a.values['village'], 'Hosakote');
      expect(a.values['pin'], '562114');
      expect(a.values['gender'], 'male');
      expect(a.values['aadhaar'], '123456789012');
      expect(a.values['bankName'], 'Canara Bank');
      // then it guides through what's left: the missing required field first
      expect(r.asking, 'project');
      expect(r.chips, contains('Fill manually'));
    });

    test('details said without field names', () {
      final a = agentFor()..start();
      a.hear('Ramesh Kumar 98450 12345 male Canara Bank Aadhaar 1234 5678 9012');
      expect(a.values['name'], 'Ramesh Kumar');
      expect(a.values['mobile'], '9845012345');
      expect(a.values['gender'], 'male');
      expect(a.values['bankName'], 'Canara Bank');
      expect(a.values['aadhaar'], '123456789012');
      final b = agentFor()..start();
      b.hear('Sunita Devi 9845012345 female 2345 6789 0123');
      expect(b.values['name'], 'Sunita Devi');
      expect(b.values['gender'], 'female');
      expect(b.values['aadhaar'], '234567890123');
    });

    test('Hindi: everything at once, then guided', () {
      final a = agentFor(AgentLanguage.hindi)..start();
      final r = a.hear('रमेश कुमार, मोबाइल नंबर 9845012345, गाँव होसकोटे, पिन कोड 562114');
      expect(a.values['name'], 'Ramesh Kumar');
      expect(a.values['mobile'], '9845012345');
      expect(a.values['pin'], '562114');
      expect(r.asking, 'project');
    });

    test('fill manually hands over to the form, and Talk resumes', () {
      final a = agentFor()..start();
      a.hear('Ramesh Kumar 9845012345');
      final r = a.hear('fill manually');
      expect(r.action, AgentAction.manual);
      expect(r.listen, isFalse);
      a.values['project'] = 'p5'; // typed by hand
      final again = a.start();
      expect(again.openEnded, isFalse);
      expect(a.mode, AgentMode.offering);
      expect(again.chips, contains('Fill manually'));
      expect(agentFor(AgentLanguage.kannada).hear('ನಾನೇ ತುಂಬುತ್ತೇನೆ').action, AgentAction.manual);
    });
  });

  group('one question at a time', () {
    test('asks for each missing required field', () {
      final a = agentFor();
      final open = a.start();
      expect(open.asking, isNull);
      expect(open.openEnded, isTrue);
      expect(open.chips, contains('Fill manually'));
      expect(a.hear('Ramesh Kumar').asking, 'mobile');
      expect(a.hear('nine eight four five zero one two three four five').asking, 'project');
      expect(a.values['mobile'], '9845012345');
      final r = a.hear('the paddy one');
      expect(a.values['project'], 'p5');
      expect(a.mode, AgentMode.offering);
      expect(r.text, contains('optional'));
    });

    test('mobile with a missing digit is read back and asked again', () {
      final a = agentFor()..start();
      a.hear('Ramesh Kumar');
      final r = a.hear('98450 1234');
      expect(r.asking, 'mobile');
      expect(a.values['mobile'], isNull);
      expect(r.text, contains('9 digits'));
    });

    test('ambiguous project offers the close options', () {
      final a = agentFor()..start();
      a.hear('Ramesh Kumar 9845012345');
      final r = a.hear('kharif');
      expect(r.asking, 'project');
      expect(r.chips, containsAll(['Kharif Chilli 2026', 'Groundnut Kharif 2026']));
      a.hear('Groundnut Kharif 2026');
      expect(a.values['project'], 'p8');
    });

    test('a correction replaces the last value', () {
      final a = agentFor()..start();
      a.hear('Ramesh Kumar');
      a.hear('9845012345');
      a.hear('no 9845012346');
      expect(a.values['mobile'], '9845012346');
    });

    test('required fields cannot be skipped', () {
      final a = agentFor()..start();
      final r = a.hear('skip');
      expect(r.asking, 'name');
      expect(r.text, contains('required'));
    });

    test('Hindi digits and Kannada English digits', () {
      final h = agentFor(AgentLanguage.hindi)..start();
      h.hear('रमेश कुमार');
      h.hear('नौ आठ चार पाँच शून्य एक दो तीन चार पाँच');
      expect(h.values['mobile'], '9845012345');
      final k = agentFor(AgentLanguage.kannada)..start();
      k.hear('ರಮೇಶ್');
      k.hear('ನೈನ್ ಎಯ್ಟ್ ಫೋರ್ ಫೈವ್ ಜೀರೋ ವನ್ ಟು ತ್ರೀ ಫೋರ್ ಫೈವ್');
      expect(k.values['mobile'], '9845012345');
    });
  });

  group('optional sections', () {
    FarmerFormAgent ready([AgentLanguage l = AgentLanguage.english]) {
      final a = agentFor(l)..start();
      a.hear('Ramesh Kumar 9845012345 paddy project');
      return a;
    }

    test('personal details: ask, skip, volunteer other fields', () {
      final a = ready();
      expect(a.hear('personal details').asking, 'dob');
      a.hear('15 August 1980');
      expect(a.values['dob'], '15/08/1980');
      expect(a.asking, 'gender');
      a.hear('female');
      expect(a.values['gender'], 'female');
      expect(a.asking, 'guardian');
      expect(a.hear('skip').asking, 'aadhaar');
      // answering something else by name keeps the question open
      final r = a.hear('village Hosakote pin code 562114');
      expect(a.values['village'], 'Hosakote');
      expect(a.values['pin'], '562114');
      expect(r.asking, 'aadhaar');
      a.hear('1234 5678 9012');
      expect(a.values['aadhaar'], '123456789012');
      expect(a.asking, 'contractor');
      a.hear('the second one');
      expect(a.values['contractor'], 'c2');
      a.hear('3 acres');
      expect(a.values['area'], '3');
      expect(a.values['areaUnit'], 'acre');
      a.hear('Kannada');
      expect(a.values['language'], 'Kannada');
      a.hear('ramesh dot kumar at gmail dot com');
      expect(a.values['email'], 'ramesh.kumar@gmail.com');
      expect(a.mode, AgentMode.offering);
    });

    test('address from the current location, then the rest by voice', () {
      final a = ready();
      final r = a.hear('address');
      expect(r.asking, 'useLocation');
      expect(a.hear('yes').action, AgentAction.useLocation);
      final next = a.locationDone({
        'country': 'India', 'state': 'Karnataka', 'district': 'Bengaluru Urban', 'city': 'Bengaluru',
        'taluka': 'Bengaluru South', 'pin': '560076',
      });
      expect(next.asking, 'village');
      expect(next.text, contains('Bengaluru'));
    });

    test('no more sections -> summary -> submit', () {
      final a = ready();
      final r = a.hear('no');
      expect(a.mode, AgentMode.confirming);
      expect(r.text, contains('Ramesh Kumar'));
      expect(a.hear('yes').action, AgentAction.submit);
    });

    test('change something at the confirmation', () {
      final a = ready();
      a.hear('no');
      a.hear('No, change something');
      expect(a.mode, AgentMode.editing);
      final r = a.hear('mobile number 9845012399');
      expect(a.values['mobile'], '9845012399');
      expect(a.mode, AgentMode.confirming);
      expect(r.text, contains('98450 12399'));
    });

    test('submit and save draft any time', () {
      expect(ready().hear('submit').action, AgentAction.submit);
      expect(ready().hear('save draft').action, AgentAction.saveDraft);
      final early = agentFor()..start();
      final r = early.hear('submit');
      expect(r.action, AgentAction.none);
      expect(r.asking, 'name');
    });

    test('Hindi: section, gender, skip and bare no', () {
      final a = ready(AgentLanguage.hindi);
      expect(a.hear('निजी जानकारी').asking, 'dob');
      a.hear('उम्र पैंतालीस साल');
      expect(a.values['dob'], startsWith('01/01/'));
      a.hear('पुरुष');
      expect(a.values['gender'], 'male');
      expect(a.hear('छोड़ो').asking, 'aadhaar');
      expect(a.hear('नहीं').asking, 'contractor');
    });

    test('Kannada and Tamil sections', () {
      final k = ready(AgentLanguage.kannada);
      expect(k.hear('ವೈಯಕ್ತಿಕ ಮಾಹಿತಿ').asking, 'dob');
      k.hear('ನಲವತ್ತೈದು ವರ್ಷ');
      expect(k.values['dob'], startsWith('01/01/'));
      k.hear('ಮಹಿಳೆ');
      expect(k.values['gender'], 'female');
      final t = ready(AgentLanguage.tamil);
      expect(t.hear('முகவரி').asking, 'useLocation');
      expect(t.hear('இல்லை').asking, 'country');
      t.hear('இந்தியா');
      expect(t.values['country'], 'India');
      t.hear('தமிழ்நாடு');
      expect(t.values['state'], 'Tamil Nadu');
    });
  });

  group('value parsers', () {
    final now = DateTime(2026, 10, 27);

    test('dates and ages in four languages', () {
      expect(ValueParsers.date('15 August 1980', now: now).value!.value, '15/08/1980');
      expect(ValueParsers.date('पंद्रह अगस्त उन्नीस सौ अस्सी', now: now).value!.value, '15/08/1980');
      expect(ValueParsers.date('fifteen august nineteen eighty five', now: now).value!.value, '15/08/1985');
      expect(ValueParsers.date('15 08 1980', now: now).value!.value, '15/08/1980');
      expect(ValueParsers.date('45 years', now: now).value!.value, '01/01/1981');
      expect(ValueParsers.date('ನಲವತ್ತೈದು ವರ್ಷ', now: now).value!.value, '01/01/1981');
      expect(ValueParsers.date('இருபத்தைந்து வயது', now: now).value!.value, '01/01/2001');
      expect(ValueParsers.date('31 february 1980', now: now).problem, isNotNull);
    });

    test('PAN and IFSC spelled out', () {
      expect(ValueParsers.parse(f('pan'), 'a b c d e one two three four f').value!.value, 'ABCDE1234F');
      expect(ValueParsers.parse(f('pan'), 'ए बी सी डी ई 1 2 3 4 एफ').value!.value, 'ABCDE1234F');
      expect(ValueParsers.parse(f('ifsc'), 's b i n zero zero zero one two three four').value!.value, 'SBIN0001234');
      expect(ValueParsers.parse(f('pan'), 'a b c 1 2').problem, isNotNull);
    });

    test('dropdowns by alias, ordinal and in other scripts', () {
      expect(ValueParsers.choice(f('language'), 'कन्नड़').value!.value, 'Kannada');
      expect(ValueParsers.choice(f('gender'), 'ஆண்').value!.value, 'male');
      expect(ValueParsers.choice(f('contractor'), 'last one').value!.value, 'none');
      expect(ValueParsers.choice(f('project'), 'ಕಬ್ಬು').value!.value, 'p7');
      expect(ValueParsers.choice(f('project'), 'banana').problem!.kind, ProblemKind.noMatch);
    });

    test('area with units', () {
      final h = ValueParsers.parse(f('area'), 'दो हेक्टेयर').value!;
      expect(h.value, '2');
      expect(h.unit, 'hectare');
    });

    test('number words', () {
      expect(ValueParsers.readDigits('अट्ठानवे पैंतालीस शून्य एक दो तीन चार पाँच'), '9845012345');
      expect(ValueParsers.readDigits('double nine eight seven'), '9987');
      expect(ValueParsers.compose([19, 100, 85]), 1985);
      expect(ValueParsers.compose([2, 1000, 5]), 2005);
    });
  });
}
