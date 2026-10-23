import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../services/location_service.dart';
import '../services/speech_models.dart';
import '../services/speech_service.dart';
import '../services/tts_service.dart';
import '../theme/app_theme.dart';
import '../voice/agent_language.dart';
import '../voice/agent_strings.dart';
import '../widgets/top_bar.dart';

/// Language, offline mode, TTS and location settings for the voice agents,
/// plus the offline voice models.
class VoiceSettingsScreen extends StatefulWidget {
  const VoiceSettingsScreen({super.key});

  @override
  State<VoiceSettingsScreen> createState() => _VoiceSettingsScreenState();
}

class _VoiceSettingsScreenState extends State<VoiceSettingsScreen> {
  final store = AppStore.instance;
  final speech = SpeechService.instance;
  final tts = TtsService.instance;
  final models = SpeechModels.instance;
  final ttsAvailable = <AgentLanguage, bool>{};

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    await speech.init();
    await models.refresh();
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
              'Voice reply: ${ttsAvailable[l] == null ? '…' : ttsAvailable[l]! ? 'available' : 'not installed'}',
              style: const TextStyle(fontSize: 10),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.volume_up_outlined),
              onPressed: () => tts.speak(AgentStrings(l).greeting, l),
            ),
          ),
        const Divider(),
        const _Header('Offline voice models (downloaded once per language)'),
        ListenableBuilder(
          listenable: models,
          builder: (context, _) => Column(children: [
            for (final l in AgentLanguage.values)
              ListTile(
                dense: true,
                leading: Icon(
                  switch (models.state[l]!) {
                    ModelState.ready => Icons.check_circle,
                    ModelState.downloading => Icons.downloading,
                    ModelState.failed => Icons.error_outline,
                    _ => Icons.download_for_offline_outlined,
                  },
                  color: models.isReady(l) ? CropinColors.voiceFilled : CropinColors.primary,
                ),
                title: Text('${l.nativeName}  ·  ${l.englishName}'),
                subtitle: models.state[l] == ModelState.downloading
                    ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(models.label(l), style: const TextStyle(fontSize: 11)),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(value: models.progress[l], minHeight: 3),
                      ])
                    : Text(models.label(l), style: const TextStyle(fontSize: 11)),
                trailing: switch (models.state[l]!) {
                  ModelState.ready => IconButton(
                      tooltip: 'Delete to free space',
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () => models.delete(l),
                    ),
                  ModelState.downloading || ModelState.checking => null,
                  _ => TextButton(
                      onPressed: () => models.download(l),
                      child: Text(models.state[l] == ModelState.failed ? 'Retry' : 'Download'),
                    ),
                },
              ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                'With a language\'s model downloaded, speech is recognised entirely on this phone '
                '(AI4Bharat IndicConformer for Hindi, Kannada and Tamil; NeMo for English). '
                'Until then the phone\'s own recogniser is used.',
                style: TextStyle(fontSize: 11, color: CropinColors.subText),
              ),
            ),
          ]),
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
        const _Header('If a pack can\'t be downloaded'),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text(
            'The app falls back to the standard recogniser automatically, so speaking still '
            'works (it may use the network until the pack is ready).\n'
            'Spoken replies use the phone\'s TTS voices: Settings → Text-to-speech → '
            'Speech Services by Google → Install voice data.\n'
            'You can always type, or tap an example sentence.',
            style: TextStyle(fontSize: 12, height: 1.4),
          ),
        ),
        if (speech.lastError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text('Last recogniser message: ${speech.lastError}',
                style: const TextStyle(color: CropinColors.attention, fontSize: 11)),
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
                fontSize: 13, fontWeight: FontWeight.w700, color: CropinColors.primary)),
      );
}
