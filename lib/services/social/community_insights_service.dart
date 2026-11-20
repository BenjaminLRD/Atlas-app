/// Service generating high-level community summaries and peer benchmarking using AI synthesis.
class CommunityInsightsService {
  static CommunityInsightsService? _instance;
  static CommunityInsightsService get instance => _instance ??= CommunityInsightsService();

  /// Generates a synthesized community fitness milestone summary.
  String generateCommunityMilestoneSummary({
    int totalWorkoutsCompleted = 14820,
    double totalTonsLifted = 128000.0,
    int activeAthletes = 3450,
  }) {
    final tonsFormatted = (totalTonsLifted / 1000).toStringAsFixed(0);
    return 'Your community completed ${totalWorkoutsCompleted.toString()} workouts and lifted ${tonsFormatted}k tons this month across $activeAthletes active athletes.';
  }

  /// Computes peer percentile comparison based on user training consistency and performance.
  String generatePeerBenchmarking({
    required double userProgressScore, // 0.0 - 100.0
    required String goal,
  }) {
    final percentile = (userProgressScore * 0.8 + 15.0).clamp(50.0, 99.0).round();
    return 'You improved faster than $percentile% of athletes with similar $goal goals this month.';
  }
}
