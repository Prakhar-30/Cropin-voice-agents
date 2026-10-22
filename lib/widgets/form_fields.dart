import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// How a field was filled: by hand, confidently by voice, or by voice but
/// needing a human check (fuzzy match).
enum VoiceMark { none, filled, check }

VoiceMark markFor(double? confidence) => confidence == null
    ? VoiceMark.none
    : confidence >= 0.9
        ? VoiceMark.filled
        : VoiceMark.check;

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.label, {super.key, this.required = false, this.mark = VoiceMark.none, this.heard});
  final String label;
  final bool required;
  final VoiceMark mark;
  final String? heard;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Text(label, style: const TextStyle(fontSize: 15, color: CropinColors.text)),
          if (required) const Text('*', style: TextStyle(color: CropinColors.required, fontSize: 15)),
          const Spacer(),
          if (mark != VoiceMark.none)
            Flexible(
              flex: 3,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(mark == VoiceMark.filled ? Icons.mic : Icons.help_outline,
                    size: 14,
                    color: mark == VoiceMark.filled ? CropinColors.voiceFilled : CropinColors.voiceCheck),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    mark == VoiceMark.filled
                        ? 'by voice'
                        : heard == null
                            ? 'please check'
                            : 'check · heard "$heard"',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: mark == VoiceMark.filled ? CropinColors.voiceFilled : CropinColors.voiceCheck,
                    ),
                  ),
                ),
              ]),
            ),
        ]),
      );
}

BoxDecoration _boxFor(VoiceMark mark) => BoxDecoration(
      color: switch (mark) {
        VoiceMark.filled => const Color(0xFFF0FAF3),
        VoiceMark.check => const Color(0xFFFFF8E6),
        VoiceMark.none => Colors.white,
      },
      border: Border.all(
        color: switch (mark) {
          VoiceMark.filled => CropinColors.voiceFilled,
          VoiceMark.check => CropinColors.voiceCheck,
          VoiceMark.none => CropinColors.border,
        },
        width: mark == VoiceMark.none ? 1.2 : 1.8,
      ),
      borderRadius: BorderRadius.circular(6),
    );

/// Text input styled like Cropin Grow, with voice highlight.
class VoiceTextField extends StatelessWidget {
  const VoiceTextField({
    super.key,
    required this.label,
    required this.controller,
    this.required = false,
    this.mark = VoiceMark.none,
    this.heard,
    this.keyboardType,
    this.hint = 'Please Enter Value',
    this.prefix,
    this.onEdited,
  });

  final String label;
  final TextEditingController controller;
  final bool required;
  final VoiceMark mark;
  final String? heard;
  final TextInputType? keyboardType;
  final String hint;
  final Widget? prefix;
  final VoidCallback? onEdited;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldLabel(label, required: required, mark: mark, heard: heard),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: _boxFor(mark),
            child: Row(children: [
              if (prefix != null) prefix!,
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  onChanged: (_) => onEdited?.call(),
                  style: const TextStyle(fontSize: 18, color: CropinColors.text),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(color: CropinColors.hint, fontSize: 18),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 20),
        ],
      );
}

/// "Select" dropdown that opens a searchable bottom-sheet list.
class VoiceSelectField<T> extends StatelessWidget {
  const VoiceSelectField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.display,
    required this.onChanged,
    this.required = false,
    this.mark = VoiceMark.none,
    this.heard,
    this.subtitle,
    this.compact = false,
  });

  final String label;
  final T? value;
  final List<T> options;
  final String Function(T) display;
  final String Function(T)? subtitle;
  final ValueChanged<T> onChanged;
  final bool required;
  final VoiceMark mark;
  final String? heard;
  final bool compact;

  Future<void> _open(BuildContext context) async {
    final picked = await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (_) => _PickerSheet<T>(
          title: label, options: options, display: display, subtitle: subtitle, selected: value),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldLabel(label, required: required, mark: compact ? VoiceMark.none : mark, heard: heard),
          InkWell(
            onTap: () => _open(context),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: _boxFor(mark),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
              child: Row(children: [
                Expanded(
                  child: Text(
                    value == null ? 'Select' : display(value as T),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 18, color: value == null ? CropinColors.hint : CropinColors.text),
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down, color: CropinColors.subText, size: 28),
              ]),
            ),
          ),
          const SizedBox(height: 20),
        ],
      );
}

class _PickerSheet<T> extends StatefulWidget {
  const _PickerSheet(
      {required this.title, required this.options, required this.display, this.subtitle, this.selected});
  final String title;
  final List<T> options;
  final String Function(T) display;
  final String Function(T)? subtitle;
  final T? selected;

  @override
  State<_PickerSheet<T>> createState() => _PickerSheetState<T>();
}

class _PickerSheetState<T> extends State<_PickerSheet<T>> {
  String q = '';

  @override
  Widget build(BuildContext context) {
    final items = widget.options
        .where((o) => widget.display(o).toLowerCase().contains(q.toLowerCase()))
        .toList();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      builder: (context, scroll) => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
          child: Row(children: [
            Expanded(
                child: Text(widget.title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
          ]),
        ),
        if (widget.options.length > 8)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: TextField(
              onChanged: (v) => setState(() => q = v),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search',
                filled: true,
                fillColor: CropinColors.searchFill,
                border: OutlineInputBorder(borderSide: BorderSide.none),
              ),
            ),
          ),
        Expanded(
          child: ListView.separated(
            controller: scroll,
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final o = items[i];
              return ListTile(
                title: Text(widget.display(o)),
                subtitle: widget.subtitle == null ? null : Text(widget.subtitle!(o)),
                trailing: o == widget.selected
                    ? const Icon(Icons.check, color: CropinColors.green)
                    : null,
                onTap: () => Navigator.pop(context, o),
              );
            },
          ),
        ),
      ]),
    );
  }
}

/// Banner listing words the agent heard but could not map to any field.
class UnmappedBanner extends StatelessWidget {
  const UnmappedBanner({super.key, required this.words, this.onDismiss});
  final List<String> words;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    if (words.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E6),
        border: Border.all(color: CropinColors.voiceCheck),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.hearing_disabled_outlined, size: 18, color: CropinColors.voiceCheck),
          const SizedBox(width: 6),
          const Expanded(
            child: Text("Couldn't map these words — fill manually if needed",
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          if (onDismiss != null)
            InkWell(onTap: onDismiss, child: const Icon(Icons.close, size: 18)),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final w in words)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: CropinColors.voiceCheck),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(w, style: const TextStyle(fontSize: 13)),
            ),
        ]),
      ]),
    );
  }
}
