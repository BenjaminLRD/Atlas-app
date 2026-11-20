/// Model representing an inspirational / motivational quote with verified visual artwork.
class MotivationalQuote {
  final String id;
  final String characterName;
  final String characterSource;
  final String quoteText;
  final String highlightText;
  final String avatarSymbol;
  final String powerTag;
  final String? assetPath;
  final String? imageUrl;

  const MotivationalQuote({
    required this.id,
    required this.characterName,
    required this.characterSource,
    required this.quoteText,
    required this.highlightText,
    required this.avatarSymbol,
    required this.powerTag,
    this.assetPath,
    this.imageUrl,
  });

  /// Indicates whether this quote has a verified, dedicated visual asset.
  bool get hasDedicatedAsset =>
      (assetPath != null && assetPath!.trim().isNotEmpty) ||
      (imageUrl != null && imageUrl!.trim().isNotEmpty);

  /// Default curated catalog of motivational quotes with intentional 1:1 asset bindings.
  /// Never uses random exercise images. Quotes without character assets use dedicated Quote placeholders.
  static List<MotivationalQuote> defaultCatalog() {
    return const [
      MotivationalQuote(
        id: 'quote_goku',
        characterName: 'Goku',
        characterSource: 'Dragon Ball',
        quoteText:
            'Power comes in response to a need, not a desire. Train harder, push further, and become stronger.',
        highlightText: 'become stronger.',
        avatarSymbol: '悟',
        powerTag: 'LIMITLESS POTENTIAL',
        assetPath: 'assets/quotes/goku.jpg',
      ),
      MotivationalQuote(
        id: 'quote_naruto',
        characterName: 'Naruto Uzumaki',
        characterSource: 'Naruto',
        quoteText:
            'Hard work can overcome talent. Keep moving forward, even when the path is difficult.',
        highlightText: 'moving forward',
        avatarSymbol: '忍',
        powerTag: 'NEVER GIVE UP',
        assetPath: 'assets/quotes/naruto.png',
      ),
      MotivationalQuote(
        id: 'quote_saitama',
        characterName: 'Saitama',
        characterSource: 'One Punch Man',
        quoteText:
            'Discipline creates strength. Keep showing up and improving every single day.',
        highlightText: 'every single day.',
        avatarSymbol: '👊',
        powerTag: 'UNSTOPPABLE DISCIPLINE',
        assetPath: 'assets/quotes/saitama.jpg',
      ),
      MotivationalQuote(
        id: 'quote_garou',
        characterName: 'Garou',
        characterSource: 'One Punch Man',
        quoteText:
            'Strength is forged through struggle. Every challenge is a chance to evolve.',
        highlightText: 'chance to evolve.',
        avatarSymbol: '狼',
        powerTag: 'EVOLUTION THROUGH STRUGGLE',
        assetPath: 'assets/quotes/garou.jpg',
      ),
      MotivationalQuote(
        id: 'quote_allmight',
        characterName: 'All Might',
        characterSource: 'My Hero Academia',
        quoteText:
            'Whether you win or lose, looking back and learning from your experience is a part of life. Plus Ultra!',
        highlightText: 'Plus Ultra!',
        avatarSymbol: '★',
        powerTag: 'PLUS ULTRA',
        assetPath: 'assets/quotes/allmight.jpg',
      ),
      MotivationalQuote(
        id: 'quote_bruce_lee',
        characterName: 'Bruce Lee',
        characterSource: 'Martial Arts Philosophy',
        quoteText:
            'Do not pray for an easy life, pray for the strength to endure a difficult one.',
        highlightText: 'strength to endure',
        avatarSymbol: '龍',
        powerTag: 'UNYIELDING WILL',
      ),
      MotivationalQuote(
        id: 'quote_marcus_aurelius',
        characterName: 'Marcus Aurelius',
        characterSource: 'Meditations',
        quoteText:
            'You have power over your mind - not outside events. Realize this, and you will find strength.',
        highlightText: 'find strength.',
        avatarSymbol: '🏛',
        powerTag: 'INNER FORTITUDE',
      ),
      MotivationalQuote(
        id: 'quote_arnold',
        characterName: 'Arnold Schwarzenegger',
        characterSource: 'Bodybuilding Legend',
        quoteText:
            'The last three or four reps is what makes the muscle grow. This area of pain divides a champion from someone who is not.',
        highlightText: 'divides a champion',
        avatarSymbol: '👑',
        powerTag: 'CHAMPION MINDSET',
      ),
    ];
  }
}
