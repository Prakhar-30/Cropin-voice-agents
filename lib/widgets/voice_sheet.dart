import 'dart:async';

import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../services/speech_models.dart';
import '../services/speech_service.dart';
import '../theme/app_theme.dart';
import '../voice/agent_language.dart';
import '../voice/agent_strings.dart';

/// Opens the voice assistant sheet. Recording starts as soon as the sheet is
/// up (a loader shows until the microphone is live) and ends after 2.75 s of
/// silence or when the user taps Done. Returns the recognised text, or null.
Future<String?> showVoiceSheet(
  BuildContext context, {
  String exampleKey = 'home',
  String title = 'Cropin Voice',
  String? subtitle,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => VoiceSheet(title: title, subtitle: subtitle),
  );
}

class VoiceSheet extends StatefulWidget {
  const VoiceSheet({super.key, required this.title, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  State<VoiceSheet> createState() => _VoiceSheetState();
}

enum _Phase { starting, listening, processing, captured, empty, error }

class _VoiceSheetState extends State<VoiceSheet> with SingleTickerProviderStateMixin {
  final speech = SpeechService.instance;
  final store = AppStore.instance;
  late final AnimationController pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
        ..repeat(reverse: true);

  _Phase phase = _Phase.starting;
  String captured = '';
  bool closed = false;

  /// Each recording gets a number so results of a cancelled one are ignored.
  int _run = 0;

  @override
  void initState() {
    super.initState();
    // Recording starts as soon as the sheet is on screen.
    WidgetsBinding.instance.addPostFrameCallback((_) => _record());
  }

  @override
  void dispose() {
    closed = true;
    _run++;
    pulse.dispose();
    speech.cancel();
    super.dispose();
  }

  Future<void> _record() async {
    if (closed) return;
    final run = ++_run;
    setState(() {
      phase = _Phase.starting;
      captured = '';
    });
    final ok = await speech.start(store.language, onResult: (text, isFinal) {
      if (isFinal && run == _run) _onText(text);
    });
    if (closed || run != _run) return;
    if (!ok) setState(() => phase = _Phase.error);
  }

  void _onText(String text) {
    if (closed) return;
    final t = text.trim();
    if (t.isEmpty) {
      setState(() => phase = _Phase.empty);
      return;
    }
    setState(() {
      captured = t;
      phase = _Phase.captured;
    });
    Timer(const Duration(milliseconds: 650), () {
      if (!closed && mounted) Navigator.of(context).pop(t);
    });
  }

  /// Done: stop now and use what was said.
  Future<void> _done() async {
    if (phase != _Phase.listening && phase != _Phase.starting) return;
    final run = _run;
    setState(() => phase = _Phase.processing);
    final text = await speech.stop();
    if (closed || run != _run) return;
    _onText(text);
  }

  /// Switching language restarts the recording in that language.
  Future<void> _setLanguage(AgentLanguage l) async {
    if (l == store.language) return;
    store.language = l;
    _run++;
    await speech.cancel();
    if (!closed) _record();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AgentStrings(store.language);
    return SafeArea(
      child: ListenableBuilder(
        listenable: speech,
        builder: (context, _) {
          // Move from "starting" to "listening" once the recogniser is live.
          if (phase == _Phase.starting && speech.isListening && speech.live) {
            phase = _Phase.listening;
          }
          if ((phase == _Phase.starting || phase == _Phase.listening) &&
              speech.state == SpeechState.error) {
            phase = _Phase.error;
          }
          final live = phase == _Phase.listening;
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: CropinColors.border, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 14),
              Text(widget.title,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              if (widget.subtitle != null) ...[
                const SizedBox(height: 2),
                Text(widget.subtitle!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: CropinColors.subText)),
              ],
              const SizedBox(height: 14),
              _LanguageTabs(value: store.language, onChanged: _setLanguage),
              ModelPrompt(lang: store.language),
              const SizedBox(height: 24),
              // Mic: loader while starting, pulsing while listening, tap to finish.
              GestureDetector(
                onTap: switch (phase) {
                  _Phase.listening || _Phase.starting => _done,
                  _Phase.empty || _Phase.error => _record,
                  _ => null,
                },
                child: AnimatedBuilder(
                  animation: pulse,
                  builder: (context, child) {
                    final level = ((speech.soundLevel.clamp(-2, 10) + 2) / 12).toDouble();
                    final grow = live ? 8 + 10 * pulse.value + 16 * level : 0.0;
                    return Container(
                      width: 84 + grow,
                      height: 84 + grow,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (live ? CropinColors.green : CropinColors.primary)
                            .withValues(alpha: 0.14),
                      ),
                      child: child,
                    );
                  },
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: live ? CropinColors.green : CropinColors.primary,
                    ),
                    child: switch (phase) {
                      _Phase.starting || _Phase.processing => const Padding(
                          padding: EdgeInsets.all(22),
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                        ),
                      _Phase.captured => const Icon(Icons.check, color: Colors.white, size: 34),
                      _Phase.empty || _Phase.error =>
                        const Icon(Icons.refresh, color: Colors.white, size: 32),
                      _ => const Icon(Icons.mic, color: Colors.white, size: 34),
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                switch (phase) {
                  _Phase.starting => strings.getReady,
                  _Phase.listening => strings.speakNow,
                  _Phase.processing => '…',
                  _Phase.captured => '',
                  _Phase.empty => strings.notHeard,
                  _Phase.error => speech.lastError ?? strings.notHeard,
                },
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: phase == _Phase.listening ? 16 : 13,
                  fontWeight: phase == _Phase.listening ? FontWeight.w600 : FontWeight.w400,
                  color: phase == _Phase.error ? CropinColors.attention : CropinColors.text,
                ),
              ),
              if (phase == _Phase.listening) ...[
                const SizedBox(height: 4),
                Text(strings.pauseHint,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: CropinColors.subText)),
              ],
              if (phase == _Phase.captured) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CropinColors.searchFill,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(captured, style: const TextStyle(fontSize: 15)),
                ),
              ],
              const SizedBox(height: 18),
              if (phase == _Phase.listening || phase == _Phase.starting)
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: FilledButton.icon(
                    key: const Key('dictation-done'),
                    style: FilledButton.styleFrom(
                      backgroundColor: CropinColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
                    ),
                    onPressed: _done,
                    icon: const Icon(Icons.check),
                    label: const Text('Done', style: TextStyle(fontSize: 15)),
                  ),
                ),
              if (phase == _Phase.empty || phase == _Phase.error)
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
                    ),
                    onPressed: _record,
                    icon: const Icon(Icons.mic),
                    label: Text(strings.tryAgain, style: const TextStyle(fontSize: 15)),
                  ),
                ),
            ]),
          );
        },
      ),
    );
  }
}

/// Segmented language switcher (English / हिन्दी / ಕನ್ನಡ / தமிழ்).
class _LanguageTabs extends StatelessWidget {
  const _LanguageTabs({required this.value, required this.onChanged});
  final AgentLanguage value;
  final ValueChanged<AgentLanguage> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: CropinColors.searchFill,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(children: [
          for (final l in AgentLanguage.values)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(l),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: l == value ? CropinColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(19),
                  ),
                  child: Text(l.nativeName,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: l == value ? Colors.white : CropinColors.text)),
                ),
              ),
            ),
        ]),
      );
}

/// Offers the language's offline voice model while it isn't on the phone
/// (recording meanwhile uses the phone's own recogniser). Shows nothing once
/// the model is ready.
class ModelPrompt extends StatelessWidget {
  const ModelPrompt({super.key, required this.lang});
  final AgentLanguage lang;

  @override
  Widget build(BuildContext context) {
    final models = SpeechModels.instance;
    return ListenableBuilder(
      listenable: models,
      builder: (context, _) {
        final st = models.state[lang]!;
        if (st == ModelState.ready || st == ModelState.checking) return const SizedBox.shrink();
        final downloading = st == ModelState.downloading;
        return Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
          decoration: BoxDecoration(
            color: CropinColors.searchFill,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(
                  switch (st) {
                    ModelState.downloading =>
                      'Downloading ${lang.englishName} voice model… ${((models.progress[lang] ?? 0) * 100).round()}%',
                    ModelState.failed => models.error[lang] ?? 'Download failed',
                    _ => 'Get the ${lang.englishName} voice model for the best accuracy '
                        '(${models.sizeMb(lang)} MB, once, Wi-Fi recommended)',
                  },
                  style: TextStyle(
                      fontSize: 11,
                      color: st == ModelState.failed ? CropinColors.attention : CropinColors.subText),
                ),
              ),
              if (!downloading)
                TextButton(
                  key: const Key('download-voice-model'),
                  style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8)),
                  onPressed: () => models.download(lang),
                  child: Text(st == ModelState.failed ? 'Retry' : 'Download',
                      style: const TextStyle(fontSize: 12)),
                ),
            ]),
            if (downloading) ...[
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: models.progress[lang],
                minHeight: 3,
                color: CropinColors.green,
                backgroundColor: CropinColors.border,
              ),
            ],
          ]),
        );
      },
    );
  }
}

/// Round mic button used next to search bars and on forms.
class MicButton extends StatelessWidget {
  const MicButton({super.key, required this.onPressed, this.size = 40, this.color});
  final VoidCallback onPressed;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => InkResponse(
        onTap: onPressed,
        radius: size * 0.7,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(Icons.mic, color: color ?? CropinColors.primary, size: size * 0.62),
        ),
      );
}
