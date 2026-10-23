/// Joins the pieces of one spoken command across recogniser sessions.
///
/// Android ends a recognition session at the first short pause, so a farmer
/// saying "name is Ramesh Kumar, mobile 98450 12345 … (pause) … add him to the
/// paddy project" arrives as two separate results. The speech service keeps
/// listening and collects every segment here; the joined text is what the
/// agents parse. Silence produces no segment, so pauses simply disappear.
class Dictation {
  final List<String> segments = [];

  /// Recogniser alternatives for each segment (N-best), best first.
  final List<List<String>> alternates = [];

  bool get isEmpty => segments.isEmpty;
  String get text => segments.join(' ');

  void clear() {
    segments.clear();
    alternates.clear();
  }

  void add(String segment, [List<String> alts = const []]) {
    final s = segment.trim();
    if (s.isEmpty) return;
    segments.add(s);
    alternates.add(alts.map((a) => a.trim()).where((a) => a.isNotEmpty).toList());
  }

  /// Committed text plus the words of the segment still being spoken.
  String withPartial(String partial) =>
      [...segments, if (partial.trim().isNotEmpty) partial.trim()].join(' ');

  /// Whole-command hypotheses for N-best rescoring: the joined text, then
  /// variants where one segment is swapped for one of its alternatives.
  List<String> hypotheses({int max = 12}) {
    final out = <String>[text];
    for (var i = 0; i < segments.length && out.length < max; i++) {
      for (final alt in alternates[i]) {
        if (alt == segments[i]) continue;
        final copy = List.of(segments)..[i] = alt;
        final h = copy.join(' ');
        if (!out.contains(h)) out.add(h);
        if (out.length >= max) break;
      }
    }
    return out;
  }

  /// Words a field worker says to finish dictating early.
  static const doneWords = [
    'done', "that's it", 'thats it', 'that is it', "that's all", 'finish', 'finished',
    'submit', 'बस', 'हो गया', 'खत्म', 'ಮುಗಿತು', 'ಮುಗಿಯಿತು', 'ಆಯ್ತು', 'ಸಾಕು', 'முடிந்தது',
    'போதும்', 'அவ்வளவுதான்', 'அவ்வளவு தான்',
  ];

  /// Strips a trailing "done" word; returns the cleaned text and whether the
  /// speaker asked to finish.
  static (String, bool) stripDone(String segment) {
    final s = segment.trim().replaceAll(RegExp(r'[.!?।,]+$'), '').trim();
    final lower = s.toLowerCase();
    for (final w in doneWords) {
      if (lower == w) return ('', true);
      if (lower.endsWith(' $w')) return (s.substring(0, s.length - w.length).trim(), true);
    }
    return (segment.trim(), false);
  }
}
