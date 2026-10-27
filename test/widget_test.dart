import 'package:cropin_voice_agents/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('opens on Add Farmer with every section and Voice Assist', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const CropinVoiceApp());
    await tester.pump();

    expect(find.text('Add Farmer'), findsOneWidget);
    expect(find.text('Voice Assist'), findsOneWidget);
    expect(find.text('Auto Detect Data'), findsOneWidget);
    expect(find.text('Primary Information'), findsOneWidget);
    expect(find.text('Farmer Name:'), findsOneWidget);

    final list = find.byType(Scrollable).first;
    for (final t in ['Personal Information', 'Aadhar Number', 'Address', 'Pin Code', 'Additional Information', 'Ifsc Code']) {
      await tester.scrollUntilVisible(find.text(t), 300, scrollable: list);
      expect(find.text(t), findsOneWidget);
    }
    expect(find.text('Save Draft'), findsOneWidget);
    expect(find.text('Submit'), findsOneWidget);
  });
}
