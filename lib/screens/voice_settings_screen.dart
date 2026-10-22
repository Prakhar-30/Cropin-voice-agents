import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../services/location_service.dart';
import '../services/speech_service.dart';
import '../services/tts_service.dart';
import '../theme/app_theme.dart';
import '../voice/agent_language.dart';
import '../voice/agent_strings.dart';
import '../widgets/top_bar.dart';

/// Language, offline mode, TTS and location settings for the voice agents,
/// plus a check of which offline speech packs the phone has.
class VoiceSettingsScreen extends StatefulWidget {
  const VoiceSettingsScreen({super.key});

  @override
  State<VoiceSettingsScreen> createState() => _VoiceSettingsScreenState();
}

class _VoiceSettingsScreenState extends State<VoiceSettingsScreen> {
  final store = AppStore.instance;
  final speech = SpeechService.instance;
  final tts = TtsService.instance;
  final ttsAvailable = <AgentLanguage, bool>{};

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    await speech.init();
    for (final l in AgentLanguage.values) {
      ttsAvailable[l] = await tts.isAvailable(l);
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: cropinTitleBar(context, 'Voice settings'),
      body: ListView(padding: const EdgeInsets.symmetric(vertical: 8), children: [
        const _Header('Agent language'),
        for (final l in AgentLanguage.values)
          ListTile(
            leading: Icon(
                store.language == l ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: CropinColors.primary),
            onTap: () => setState(() => store.language = l),
            title: Text('${l.nativeName}  ·  ${l.englishName}'),
            subtitle: Text(
              'Speech pack: ${!speech.isReady ? 'checking…' : speech.supports(l) ? 'recogniser supports ${speech.localeFor(l)}' : 'not listed — install offline pack'}'
              '   ·   Voice: ${ttsAvailable[l] == null ? '…' : ttsAvailable[l]! ? 'available' : 'not installed'}',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.volume_up_outlined),
              onPressed: () => tts.speak(AgentStrings(l).greeting, l),
            ),
          ),
        const Divider(),
        const _Header('Privacy & connectivity'),
        SwitchListTile(
          value: speech.offlineOnly,
          activeTrackColor: CropinColors.green,
          onChanged: (v) => setState(() => speech.offlineOnly = v),
          title: const Text('Offline only (on-device recognition)'),
          subtitle: const Text(
              'Audio never leaves the phone. Requires the offline speech pack for the language.'),
        ),
        SwitchListTile(
          value: tts.enabled,
          activeTrackColor: CropinColors.green,
          onChanged: (v) => setState(() => tts.enabled = v),
          title: const Text('Spoken replies'),
          subtitle: const Text('Agent confirms in the selected language using on-device TTS.'),
        ),
        const Divider(),
        const _Header('Location for "here" / nearest plot'),
        for (final m in const [
          ('auto', 'Device GPS, demo location when far from demo plots'),
          ('gps', 'Device GPS only'),
          ('demo', 'Demo location (BTM Layout, Bengaluru)'),
        ])
          ListTile(
            leading: Icon(
                LocationService.instance.mode == m.$1
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: CropinColors.primary),
            title: Text(m.$2),
            onTap: () => setState(() => LocationService.instance.mode = m.$1),
          ),
        const Divider(),
        const _Header('Install offline speech packs'),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text(
            '1. Open the Google app → Settings → Voice → Offline speech recognition.\n'
            '2. Under "All", download Kannada (ಕನ್ನಡ), Tamil (தமிழ்), Hindi and English (India).\n'
            '3. For spoken replies: Settings → System → Languages → Text-to-speech → '
            'Speech Services by Google → Install voice data for the same languages.\n\n'
            'Without a pack you can still use every agent by typing, or by tapping an example.',
            style: TextStyle(fontSize: 14, height: 1.4),
          ),
        ),
        if (speech.lastError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text('Last recogniser message: ${speech.lastError}',
                style: const TextStyle(color: CropinColors.attention, fontSize: 13)),
          ),
      ]),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: CropinColors.primary)),
      );
}
