import 'alert_parser.dart';
import 'form_parser.dart';
import 'intent_router.dart';
import 'search_parser.dart';

/// N-best rescoring: the recogniser returns several alternative transcripts.
/// Instead of trusting the top one, every hypothesis is parsed and the one that
/// yields the most consistent slots wins (cf. Ganesan et al., "N-Best ASR
/// Transformer", ACL 2021; Sun et al., "Speech-based Slot Filling using LLMs",
/// 2023 — multiple hypotheses consistently beat 1-best for slot filling).
class NBest {
  /// Small penalty per rank so ties keep the recogniser's own preference.
  static const rankPenalty = 0.15;

  static (String, T) pick<T>(
      List<String> hypotheses, T Function(String) parse, double Function(T) score) {
    final hyps = hypotheses.where((h) => h.trim().isNotEmpty).toList();
    if (hyps.isEmpty) return ('', parse(''));
    String bestText = hyps.first;
    T best = parse(hyps.first);
    var bestScore = score(best);
    for (var i = 1; i < hyps.length; i++) {
      final r = parse(hyps[i]);
      final s = score(r) - rankPenalty * i;
      if (s > bestScore) {
        bestScore = s;
        best = r;
        bestText = hyps[i];
      }
    }
    return (bestText, best);
  }

  static double formScore(FormParseResult r) => r.score;
  static double alertScore(AlertParseResult r) => r.score;
  static double searchScore(SearchQuery q) => q.score;

  /// First hypothesis (in recogniser order) that maps to a known intent.
  static (String, AgentIntent) intent(List<String> hypotheses) {
    for (final h in hypotheses) {
      final i = IntentRouter.detect(h);
      if (i != AgentIntent.unknown) return (h, i);
    }
    return (hypotheses.isEmpty ? '' : hypotheses.first, AgentIntent.unknown);
  }
}
