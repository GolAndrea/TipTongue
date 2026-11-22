/// Pure-Dart algorithm that distinguishes a mid-sentence lexical hesitation
/// ("tip-of-the-tongue" moment) from a completed conversational turn.
class HesitationDetector {
  const HesitationDetector();

  static const Set<String> _hesitationFillers = {
    'uh',
    'um',
    'er',
    'ah',
    'ehm',
    'eh',
    'euh',
    'äh',
    'ähm',
    'este',
    'mmm',
    'hmm',
  };

  /// Words that almost always require a following noun, verb, or complement
  /// across EN, ES, FR, DE, IT, PT, NL, SV, FI, NO, DA, and PL.
  static const Set<String> _danglingSyntaxMarkers = {
    // English
    'a', 'an', 'the', 'to', 'of', 'in', 'on', 'for', 'with', 'about', 'into',
    'from', 'by', 'at', 'as', 'very', 'more', 'most', 'quite', 'really', 'too',
    'my', 'your', 'our', 'their', 'his', 'her', 'its', 'this', 'that', 'these',
    'those', 'some', 'any', 'every', 'no', 'and', 'but', 'or', 'because', 'if',
    'when', 'while', 'although', 'is', 'are', 'was', 'were', 'be', 'been',
    'have', 'has', 'had', 'will', 'would', 'can', 'could', 'should', 'must',
    'need', 'want', 'like',
    // Spanish
    'el', 'la', 'los', 'las', 'un', 'una', 'unos', 'unas', 'de', 'del', 'al',
    'en', 'con', 'por', 'para', 'sin', 'muy', 'más', 'mi', 'tu', 'su', 'pero',
    'porque',
    // French
    'le', 'les', 'des', 'du', 'au', 'aux', 'dans', 'pour', 'avec', 'sans',
    'très', 'plus', 'mon', 'ma', 'mes', 'ton', 'son', 'mais', 'parce', 'que',
    // German
    'der', 'die', 'das', 'den', 'dem', 'ein', 'eine', 'einen', 'einem', 'zu',
    'mit', 'für', 'auf', 'sehr', 'mehr', 'mein', 'meine', 'aber', 'weil', 'und',
    // Italian
    'il', 'lo', 'gli', 'uno', 'di', 'da', 'nel', 'sul', 'per', 'molto', 'più',
    'mio', 'mia', 'perché', 'che',
    // Portuguese (omitting shared tokens 'as', 'da', 'no' already listed above)
    'o', 'os', 'um', 'uma', 'do', 'na', 'com', 'sem', 'muito',
    // Dutch / Swedish / Finnish / Norwegian / Danish / Polish
    'het', 'een', 'van', 'voor', 'met', 'och', 'att', 'för', 'med', 'på',
    'että', 'mutta', 'koska', 'ja', 'og', 'til', 'czy', 'ale', 'oraz',
  };

  /// Returns `true` when the speaker has paused long enough mid-phrase to
  /// warrant surfacing a single-word contextual prompt.
  bool shouldTrigger({
    required String transcript,
    required int silenceMs,
    required int thresholdMs,
    String? lastTriggeredTranscript,
  }) {
    final normalized = _normalize(transcript);
    if (normalized.isEmpty) return false;

    if (lastTriggeredTranscript != null &&
        _normalize(lastTriggeredTranscript) == normalized) {
      return false;
    }

    // Check if the utterance explicitly closed with terminal punctuation
    // (unless it ends with an ellipsis "...").
    final trimmedRaw = transcript.trim();
    final endsWithEllipsis =
        trimmedRaw.endsWith('...') || trimmedRaw.endsWith('…');
    final endsWithTerminalPunctuation = !endsWithEllipsis &&
        (trimmedRaw.endsWith('.') ||
            trimmedRaw.endsWith('!') ||
            trimmedRaw.endsWith('?'));

    final tokens = normalized.split(' ').where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty) return false;

    final lastWord = _stripPunctuation(tokens.last);
    final hasFillerAtEnd = _hesitationFillers.contains(lastWord);
    final hasDanglingMarker = _danglingSyntaxMarkers.contains(lastWord);

    if (endsWithTerminalPunctuation && !hasFillerAtEnd && !hasDanglingMarker) {
      return false;
    }

    // Require at least 2 words (or 1 word + ellipsis/filler) so single greetings
    // like "Hello" don't falsely trigger a prompt.
    if (tokens.length < 2 && !endsWithEllipsis && !hasFillerAtEnd) {
      return false;
    }

    // Strong syntactic cliff (article/preposition/filler): slightly faster rescue
    final effectiveThreshold = (hasDanglingMarker || hasFillerAtEnd || endsWithEllipsis)
        ? (thresholdMs * 0.85).round()
        : thresholdMs;

    return silenceMs >= effectiveThreshold;
  }

  /// Strips trailing vocalized fillers ("uh", "ehm", "...") so the LLM completes
  /// the clean unfinished clause.
  String cleanContextForPrediction(String transcript) {
    var cleaned = transcript
        .trim()
        .replaceAll('…', '')
        .replaceAll(RegExp(r'\.{2,}$'), '')
        .trim();
    final parts = cleaned.split(RegExp(r'\s+'));
    while (parts.isNotEmpty &&
        _hesitationFillers.contains(_stripPunctuation(parts.last.toLowerCase()))) {
      parts.removeLast();
    }
    return parts.join(' ').trim();
  }

  String _normalize(String input) =>
      input.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  String _stripPunctuation(String token) =>
      token.replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');
}
