import 'package:flutter/material.dart';

import 'screens/farmer_form_screen.dart';
import 'services/speech_models.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SpeechModels.instance.refresh();
  runApp(const CropinVoiceApp());
}

class CropinVoiceApp extends StatelessWidget {
  const CropinVoiceApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Cropin Voice',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        // This build is the Add Farmer voice assistant only.
        home: const FarmerFormScreen(),
      );
}
