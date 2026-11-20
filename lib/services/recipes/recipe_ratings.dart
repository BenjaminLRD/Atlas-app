import 'dart:convert';

import '../../data/local_storage.dart';
import '../community/sample_world.dart';

/// One person's rating of one recipe.
class RecipeRating {
  final String recipeId;

  /// Who rated. One rating per person per recipe: a new one replaces theirs.
  final String raterId;
  final String raterName;
  final String? raterAvatar;

  /// 1 to 5.
  final int stars;
  final String? review;
  final DateTime updatedAt;

  /// Demonstration content from Showcase Mode.
  final bool isSample;

  const RecipeRating({
    required this.recipeId,
    required this.raterId,
    required this.raterName,
    this.raterAvatar,
    required this.stars,
    this.review,
    required this.updatedAt,
    this.isSample = false,
  });
}

/// The average and count of real submitted ratings. With none, [average] is
/// null: "no ratings yet" is not the same as a rating of zero.
class RatingSummary {
  final double? average;
  final int count;

  const RatingSummary(this.average, this.count);

  bool get hasRatings => count > 0;

  /// "4.3 (12)" or "No ratings yet".
  String get label => average == null
      ? 'No ratings yet'
      : '${average!.toStringAsFixed(1)} ($count)';

  static RatingSummary of(Iterable<RecipeRating> ratings) {
    final list = ratings.toList();
    if (list.isEmpty) return const RatingSummary(null, 0);
    final sum = list.fold<int>(0, (a, r) => a + r.stars);
    return RatingSummary(sum / list.length, list.length);
  }
}

/// Why a rating was refused.
class RatingException implements Exception {
  final String message;
  const RatingException(this.message);
  @override
  String toString() => message;
}

/// Where ratings live. Real community ratings need a backend table that does
/// not exist yet (see supabase/proposed), so the real mode uses
/// [UnavailableRatingRepository] and nothing is faked.
abstract class RecipeRatingRepository {
  /// False when ratings cannot be given or read.
  bool get available;
  String? get unavailableReason;

  List<RecipeRating> ratingsFor(String recipeId);
  RatingSummary summaryFor(String recipeId) =>
      RatingSummary.of(ratingsFor(recipeId));
  RecipeRating? mine(String recipeId);

  /// Gives or updates the signed-in athlete's own rating. Throws
  /// [RatingException] for a rating outside 1 to 5 or a recipe the athlete
  /// made themselves.
  Future<RecipeRating> submit({
    required String recipeId,
    required int stars,
    String? review,
    String? creatorId,
  });
}

class UnavailableRatingRepository implements RecipeRatingRepository {
  const UnavailableRatingRepository();

  @override
  bool get available => false;

  @override
  String get unavailableReason =>
      'Ratings and reviews need the shared recipe service, which is not '
      'switched on yet.';

  @override
  List<RecipeRating> ratingsFor(String recipeId) => const [];

  @override
  RatingSummary summaryFor(String recipeId) => const RatingSummary(null, 0);

  @override
  RecipeRating? mine(String recipeId) => null;

  @override
  Future<RecipeRating> submit({
    required String recipeId,
    required int stars,
    String? review,
    String? creatorId,
  }) async => throw const RatingException('Ratings are not available yet.');
}

/// Showcase Mode ratings: a few sample reviews from the sample athletes plus
/// the viewer's own rating, which is kept in a Showcase-only storage key.
/// Nothing here reads or writes a real record.
class SampleRatingRepository implements RecipeRatingRepository {
  SampleRatingRepository({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  static const String storageKey = 'showcase_recipe_ratings_v1';
  static const String selfId = 'showcase_you';

  /// recipeId -> (athleteKey, stars, review)
  static const Map<String, List<(String, int, String)>> _seed = {
    'sample_recipe_tuna_box': [
      ('maya', 5, 'Easy and no cooking. I pack it every Monday.'),
      ('liam', 4, 'Good protein for the price. A squeeze of lemon helps.'),
      ('sophia', 4, 'Solid. I add a bit more corn.'),
    ],
    'sample_recipe_tofu_curry': [
      ('david', 5, 'Cheap, filling and tastes better the next day.'),
      ('zothanpuii', 4, 'Nice. I add a little chilli.'),
    ],
    'sample_recipe_chicken_broccoli_rice': [
      ('alex', 5, 'Simple fuel. Exactly what I need before a long day.'),
      ('daniel', 4, 'Good, but I double the broccoli.'),
      ('maya', 5, 'Reliable. Made it three weeks in a row.'),
      ('liam', 3, 'Fine, a bit plain without a sauce.'),
    ],
    'sample_recipe_tofu_spinach': [('sophia', 4, 'Quick and light.')],
    'sample_recipe_dal_bhat': [
      ('zothanpuii', 5, 'Tastes like home.'),
      ('hminga', 5, 'My pre-run favourite.'),
    ],
  };

  Map<String, dynamic> _loadMine() {
    final raw = LocalStorage.getString(storageKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final v = jsonDecode(raw);
      return v is Map<String, dynamic> ? v : {};
    } catch (_) {
      return {};
    }
  }

  @override
  bool get available => true;

  @override
  String? get unavailableReason => null;

  SampleAthlete? _athlete(String key) {
    for (final a in SampleWorld.athletes) {
      if (a.key == key) return a;
    }
    return null;
  }

  @override
  List<RecipeRating> ratingsFor(String recipeId) {
    final out = <RecipeRating>[];
    final seed = _seed[recipeId];
    for (final (key, stars, text) in seed ?? const <(String, int, String)>[]) {
      final a = _athlete(key);
      if (a == null) continue;
      out.add(
        RecipeRating(
          recipeId: recipeId,
          raterId: 'sample_${a.key}',
          raterName: a.name,
          raterAvatar: a.avatar,
          stars: stars,
          review: text,
          updatedAt: DateTime(2026, 11, 5),
          isSample: true,
        ),
      );
    }
    final own = mine(recipeId);
    if (own != null) out.add(own);
    return out;
  }

  @override
  RatingSummary summaryFor(String recipeId) =>
      RatingSummary.of(ratingsFor(recipeId));

  @override
  RecipeRating? mine(String recipeId) {
    final m = _loadMine()[recipeId];
    if (m is! Map) return null;
    final stars = m['stars'];
    if (stars is! int || stars < 1 || stars > 5) return null;
    return RecipeRating(
      recipeId: recipeId,
      raterId: selfId,
      raterName: 'You',
      stars: stars,
      review: m['review'] is String ? m['review'] as String : null,
      updatedAt: DateTime.tryParse('${m['at']}') ?? _clock(),
      isSample: true,
    );
  }

  @override
  Future<RecipeRating> submit({
    required String recipeId,
    required int stars,
    String? review,
    String? creatorId,
  }) async {
    if (stars < 1 || stars > 5) {
      throw const RatingException('Choose 1 to 5 stars.');
    }
    if (creatorId != null && creatorId == selfId) {
      throw const RatingException('You cannot rate your own recipe.');
    }
    final text = review?.trim();
    if (text != null && text.length > 600) {
      throw const RatingException('Keep the review under 600 characters.');
    }
    final all = _loadMine();
    // One entry per recipe: submitting again updates it, never adds another.
    all[recipeId] = {
      'stars': stars,
      if (text != null && text.isNotEmpty) 'review': text,
      'at': _clock().toIso8601String(),
    };
    await LocalStorage.setString(storageKey, jsonEncode(all));
    return mine(recipeId)!;
  }
}
