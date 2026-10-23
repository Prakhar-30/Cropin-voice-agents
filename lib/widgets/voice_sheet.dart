import 'dart:async';

import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../services/speech_pack_service.dart';
import '../services/speech_service.dart';
import '../theme/app_theme.dart';
import '../voice/agent_language.dart';
import '../voice/agent_strings.dart';

/// Opens the offline voice agent sheet and returns the final utterance
/// (spoken or typed), or null when dismissed.
Future<String?> showVoiceSheet(
  BuildContext context, {
  required String exampleKey,
  String title = 'Voice assistant',
  String? subtitle,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
    builder: (_) => VoiceSheet(exampleKey: exampleKey, title: title, subtitle: subtitle),
  );
}

class VoiceSheet extends StatefulWidget {
  const VoiceSheet({super.key, required this.exampleKey, required this.title, this.subtitle});
  final String exampleKey;
  final String title;
  final String? subtitle;

  @override
  State<VoiceSheet> createState() => _VoiceSheetState();
}

class _VoiceSheetState extends State<VoiceSheet> with SingleTickerProviderStateMixin {
  final speech = SpeechService.instance;
  final store = AppStore.instance;
  final typed = TextEditingController();
  late final AnimationController pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
        ..repeat(reverse: true);
  bool typing = false;
  bool done = false;

  /// A start / stop is in flight — ignore extra taps.
  bool busy = false;

  /// Transcript shown briefly once recording has ended.
  String? captured;
  String? notice;

  @override
  void initState() {
    super.initState();
    // Warm up the recogniser so the first tap starts listening quickly.
    speech.prewarm(store.language);
  }

  @override
  void dispose() {
    pulse.dispose();
    typed.dispose();
    if (speech.isListening) speech.cancel();
    super.dispose();
  }

  Future<void> _listen() async {
    if (!mounted || busy || done) return;
    setState(() {
      busy = true;
      typing = false;
      captured = null;
      notice = null;
    });
    final ok = await speech.start(store.language, onResult: (text, isFinal) {
      if (isFinal) _onCaptured(text);
    });
    if (!mounted) return;
    setState(() {
      busy = false;
      if (!ok) notice = speech.lastError ?? 'Microphone unavailable — type instead.';
    });
  }

  void _onCaptured(String text) {
    if (!mounted || done) return;
    final t = text.trim();
    if (t.isEmpty) {
      setState(() => notice = "Didn't catch anything — tap the mic and speak again.");
      return;
    }
    setState(() => captured = t);
    Timer(const Duration(milliseconds: 700), () => _submit(t));
  }

  /// Mic / Done: stop and use what was said, or start a new recording.
  Future<void> _toggle() async {
    if (busy || done) return;
    if (speech.isListening) {
      setState(() => busy = true);
      final text = await speech.stop();
      if (!mounted) return;
      setState(() => busy = false);
      _onCaptured(text);
    } else {
      await _listen();
    }
  }

  void _submit(String text) {
    if (done || !mounted || text.trim().isEmpty) return;
    done = true;
    if (speech.isListening) speech.cancel();
    Navigator.of(context).pop(text.trim());
  }

  /// Switching language never auto-starts; the user taps the mic.
  Future<void> _setLanguage(AgentLanguage l) async {
    if (busy) return;
    store.language = l;
    if (speech.isListening) await speech.cancel();
    speech.prewarm(l);
    if (!mounted) return;
    setState(() {
      captured = null;
      notice = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AgentStrings(store.language);
    final examples = AgentStrings.examples(widget.exampleKey)[store.language] ?? const [];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: speech,
          builder: (context, _) {
            final listening = speech.isListening;
            final err = speech.state == SpeechState.error ? speech.lastError : null;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 34,
                      height: 4,
                      decoration: BoxDecoration(
                          color: CropinColors.border, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(widget.title,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        if (widget.subtitle != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(widget.subtitle!,
                                style: const TextStyle(fontSize: 11, color: CropinColors.subText)),
                          ),
                      ]),
                    ),
                    const _OfflineBadge(),
                  ]),
                  const SizedBox(height: 12),
                  _LanguagePicker(value: store.language, onChanged: _setLanguage),
                  const SizedBox(height: 18),
                  Center(
                    child: GestureDetector(
                      onTap: _toggle,
                      child: AnimatedBuilder(
                        animation: pulse,
                        builder: (context, child) {
                          final level = (speech.soundLevel.clamp(-2, 10) + 2) / 12;
                          final grow = listening ? 10 + 14 * pulse.value + 18 * level : 0.0;
                          return Container(
                            width: 71 + grow,
                            height: 71 + grow,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: (listening && speech.live ? CropinColors.green : CropinColors.primary)
                                  .withValues(alpha: 0.15),
                            ),
                            child: child,
                          );
                        },
                        child: Container(
                          width: 65,
                          height: 65,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: listening && speech.live ? CropinColors.green : CropinColors.primary,
                          ),
                          child: listening && !speech.live
                              ? const Padding(
                                  padding: EdgeInsets.all(18),
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 3),
                                )
                              : Icon(listening ? Icons.mic : Icons.mic_none,
                                  color: Colors.white, size: 31),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    listening
                        ? speech.live
                            ? '${strings.speakNow}\n${strings.pauseHint}'
                            : strings.getReady
                        : captured != null
                            ? '✓'
                            : busy || speech.state == SpeechState.initializing
                                ? '…'
                                : strings.tapToSpeak,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: CropinColors.subText),
                  ),
                  if (listening)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: FilledButton.icon(
                          key: const Key('dictation-done'),
                          style: FilledButton.styleFrom(backgroundColor: CropinColors.green),
                          onPressed: busy ? null : _toggle,
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Done'),
                        ),
                      ),
                    ),
                  if (captured != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: CropinColors.searchFill,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(captured!,
                          style: const TextStyle(fontSize: 15, color: CropinColors.text)),
                    ),
                  ],
                  if (notice != null && err == null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF4E0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(notice!, style: const TextStyle(fontSize: 11)),
                    ),
                  ],
                  if (err != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF4E0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Icon(Icons.info_outline, color: CropinColors.voiceCheck, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(err, style: const TextStyle(fontSize: 11))),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (typing)
                    TextField(
                      controller: typed,
                      autofocus: true,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.done,
                      onSubmitted: _submit,
                      decoration: InputDecoration(
                        hintText: 'Type what you would say…',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.send, color: CropinColors.primary),
                          onPressed: () => _submit(typed.text),
                        ),
                      ),
                    )
                  else
                    Align(
                      child: TextButton.icon(
                        onPressed: () async {
                          if (speech.isListening) await speech.cancel();
                          setState(() => typing = true);
                        },
                        icon: const Icon(Icons.keyboard_outlined),
                        label: const Text('Type instead'),
                      ),
                    ),
                  if (examples.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('Try saying',
                        style: TextStyle(fontWeight: FontWeight.w600, color: CropinColors.subText)),
                    const SizedBox(height: 6),
                    for (final e in examples)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => _submit(e),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                            decoration: BoxDecoration(
                              border: Border.all(color: CropinColors.border),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(children: [
                              const Icon(Icons.format_quote, size: 15, color: CropinColors.hint),
                              const SizedBox(width: 6),
                              Expanded(child: Text(e, style: const TextStyle(fontSize: 12))),
                            ]),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OfflineBadge extends StatelessWidget {
  const _OfflineBadge();

  @override
  Widget build(BuildContext context) {
    final packs = SpeechPackService.instance;
    return ListenableBuilder(
      listenable: packs,
      builder: (context, _) {
        final speech = SpeechService.instance;
        final lang = AppStore.instance.language;
        final (label, icon, color) = switch (speech.mode) {
          'fallback' => (
              packs.state[lang] == PackState.downloading
                  ? 'Pack ${packs.progress[lang] ?? 0}% · standard mode'
                  : 'Standard mode',
              Icons.downloading,
              CropinColors.voiceCheck,
            ),
          'online' => ('Online allowed', Icons.cloud_queue, CropinColors.voiceCheck),
          _ => ('Offline · on-device', Icons.cloud_off, CropinColors.voiceFilled),
        };
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
          ]),
        );
      },
    );
  }
}

class _LanguagePicker extends StatelessWidget {
  const _LanguagePicker({required this.value, required this.onChanged});
  final AgentLanguage value;
  final ValueChanged<AgentLanguage> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          for (final l in AgentLanguage.values)
            ChoiceChip(
              label: Text(l.nativeName),
              selected: l == value,
              onSelected: (_) => onChanged(l),
              selectedColor: CropinColors.primary,
              labelStyle: TextStyle(color: l == value ? Colors.white : CropinColors.text),
              showCheckmark: false,
            ),
        ],
      );
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
