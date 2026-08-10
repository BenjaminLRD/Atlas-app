import 'dart:math';

/// Representation of a single daily motivational quote & fitness tip.
class DailyMotivationQuote {
  final String id;
  final String quote;
  final String author;
  final String category;
  final String coachTip;

  const DailyMotivationQuote({
    required this.id,
    required this.quote,
    required this.author,
    required this.category,
    required this.coachTip,
  });
}

/// Presentation service providing curated daily fitness motivation quotes and coaching tips.
class DailyMotivationService {
  static const List<DailyMotivationQuote> _quotes = [
    DailyMotivationQuote(
      id: 'quote_1',
      quote: 'The body achieves what the mind believes.',
      author: 'Arnold Schwarzenegger',
      category: 'Strength',
      coachTip: 'Focus on your mind-muscle connection during every repetition today.',
    ),
    DailyMotivationQuote(
      id: 'quote_2',
      quote: 'Consistency is what transforms average into excellence.',
      author: 'Aizawl Gym AI Coach',
      category: 'Consistency',
      coachTip: 'Showing up even for 20 minutes keeps the streak momentum alive.',
    ),
    DailyMotivationQuote(
      id: 'quote_3',
      quote: 'Success isn’t always about greatness. It’s about consistency. Hard work gains success.',
      author: 'Dwayne Johnson',
      category: 'Hypertrophy',
      coachTip: 'Ensure you hit your daily protein target for maximum recovery today.',
    ),
    DailyMotivationQuote(
      id: 'quote_4',
      quote: 'The hard days are what make you stronger.',
      author: 'Aly Raisman',
      category: 'Endurance',
      coachTip: 'Embrace progressive overload: add 1 rep or slight weight today.',
    ),
    DailyMotivationQuote(
      id: 'quote_5',
      quote: 'Small daily improvements over time lead to stunning results.',
      author: 'Robin Sharma',
      category: 'General',
      coachTip: 'Prioritize 7-8 hours of quality sleep for peak neuromuscular recovery.',
    ),
    DailyMotivationQuote(
      id: 'quote_6',
      quote: 'Do something today that your future self will thank you for.',
      author: 'Sean Patrick Flanery',
      category: 'Weight Loss',
      coachTip: 'Stay hydrated with at least 3L of water throughout your workout.',
    ),
  ];

  /// Get daily quote deterministically derived from current day or optional seed.
  static DailyMotivationQuote getDailyQuote({String? category, int? seed}) {
    final daySeed = seed ?? (DateTime.now().year * 1000 + DateTime.now().day);
    final rng = Random(daySeed);

    if (category != null && category.isNotEmpty) {
      final matching = _quotes
          .where((q) => q.category.toLowerCase() == category.toLowerCase())
          .toList();
      if (matching.isNotEmpty) {
        return matching[rng.nextInt(matching.length)];
      }
    }

    return _quotes[rng.nextInt(_quotes.length)];
  }

  /// Get a random quote when user clicks refresh.
  static DailyMotivationQuote getRandomQuote({String? category}) {
    final rng = Random();
    if (category != null && category.isNotEmpty) {
      final matching = _quotes
          .where((q) => q.category.toLowerCase() == category.toLowerCase())
          .toList();
      if (matching.isNotEmpty) {
        return matching[rng.nextInt(matching.length)];
      }
    }
    return _quotes[rng.nextInt(_quotes.length)];
  }

  /// List of all motivational quotes
  static List<DailyMotivationQuote> get allQuotes => _quotes;
}
