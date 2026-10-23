import 'package:cropin_voice_agents/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('home renders Cropin Grow layout with voice agents', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const CropinVoiceApp());
    await tester.pump();

    expect(find.text('Add Farmer'), findsWidgets);
    expect(find.text('Raise alert'), findsOneWidget);
    expect(find.text('Talk to Cropin'), findsOneWidget);
    expect(find.text('Farm Intelligence & Advisory'), findsOneWidget);

    await tester.tap(find.text('Assets').last);
    await tester.pump();
    expect(find.textContaining('Assets ('), findsOneWidget);
  });
}
