/// Built-in offline summarizer — runs entirely on the device, no
/// internet and no API key needed. It is EXTRACTIVE: it selects the
/// most informative sentences from the original text (word-frequency
/// scoring) and returns them in their original order. It never invents
/// content, and results are labeled as offline/extractive in the UI.
class OfflineSummarizer {
  static const _stopWords = {
    'the', 'a', 'an', 'and', 'or', 'but', 'of', 'to', 'in', 'on', 'for',
    'with', 'as', 'by', 'at', 'from', 'is', 'are', 'was', 'were', 'be',
    'been', 'it', 'its', 'this', 'that', 'these', 'those', 'i', 'you',
    'he', 'she', 'we', 'they', 'not', 'no', 'yes', 'if', 'then', 'than',
    'so', 'such', 'into', 'over', 'under', 'about', 'after', 'before',
    'في', 'من', 'إلى', 'على', 'عن', 'ما', 'لا', 'هو', 'هي', 'أن', 'إن',
    'كان', 'مع', 'هذا', 'هذه', 'ذلك', 'تلك', 'التي', 'الذي', 'لم', 'لن',
    'قد', 'لقد', 'عند', 'لدى', 'بين', 'غير', 'كل', 'أي', 'بعد', 'قبل',
    'حتى', 'إذا', 'لو', 'كما', 'لكن', 'بل', 'ثم', 'أو', 'و', 'يا',
  };

  /// Splits [text] into sentences (Arabic + Latin punctuation).
  static List<String> splitSentences(String text) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) return const [];
    return normalized
        .split(RegExp(r'(?<=[.!؟?。])\s+'))
        .map((s) => s.trim())
        .where((s) => s.length > 15)
        .toList();
  }

  static List<String> _words(String sentence) => sentence
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.length > 2 && !_stopWords.contains(w))
      .toList();

  /// Returns an extractive summary of [text] with about [maxSentences]
  /// sentences, preserving the original order.
  static String summarize(String text, {int maxSentences = 8}) {
    final sentences = splitSentences(text);
    if (sentences.isEmpty) return '';
    if (sentences.length <= maxSentences) return sentences.join(' ');

    final freq = <String, int>{};
    for (final s in sentences) {
      for (final w in _words(s)) {
        freq[w] = (freq[w] ?? 0) + 1;
      }
    }
    final scored = <(int, double)>[];
    for (var i = 0; i < sentences.length; i++) {
      final words = _words(sentences[i]);
      if (words.isEmpty) continue;
      var score = 0.0;
      for (final w in words) {
        score += (freq[w] ?? 0).toDouble();
      }
      score /= words.length;
      // Slight bonus for early sentences (introductions carry key ideas).
      score *= 1 + (1 - i / sentences.length) * 0.15;
      scored.add((i, score));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    final chosen = scored.take(maxSentences).map((e) => e.$1).toList()..sort();
    return chosen.map((i) => sentences[i]).join(' ');
  }

  /// Key sentences as bullet-ready list (for "key ideas" style offline).
  static List<String> keySentences(String text, {int count = 6}) {
    final summary = summarize(text, maxSentences: count);
    return splitSentences(summary);
  }
}
