import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/workout_history.dart';
import '../../../models/workout_session.dart';
import '../personalization/training_preference_profile.dart';
import '../personalization/workout_personalization_engine.dart';
import 'memory_event.dart';
import 'memory_item.dart';
import 'preference_profile.dart';

/// Persistent Fitness Memory service managing long-term personalization,
/// behavioral feedback scoring, structured memory items, and context ranking.
class FitnessMemory {
  static const String _profileKey = 'ai_preference_profile';
  static const String _eventsKey = 'ai_memory_events';
  static const String _itemsKey = 'ai_memory_items';

  static FitnessMemory? _instance;
  PreferenceProfile _cachedProfile = PreferenceProfile.initial();
  List<MemoryEvent> _cachedEvents = [];
  List<MemoryItem> _cachedItems = [];
  bool _isInitialized = false;

  FitnessMemory._();

  static FitnessMemory get instance {
    _instance ??= FitnessMemory._();
    return _instance!;
  }

  /// Resets singleton instance for clean test environments.
  static void resetInstance() {
    _instance = null;
  }

  /// Initializes persistent memory from disk storage.
  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final profileJson = prefs.getString(_profileKey);
      if (profileJson != null) {
        _cachedProfile = PreferenceProfile.fromJson(
          jsonDecode(profileJson) as Map<String, dynamic>,
        );
      }

      final eventsJson = prefs.getString(_eventsKey);
      if (eventsJson != null) {
        final List<dynamic> list = jsonDecode(eventsJson) as List<dynamic>;
        _cachedEvents = list
            .map((e) => MemoryEvent.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      final itemsJson = prefs.getString(_itemsKey);
      if (itemsJson != null) {
        final List<dynamic> itemList = jsonDecode(itemsJson) as List<dynamic>;
        _cachedItems = itemList
            .map((e) => MemoryItem.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      _cachedProfile = PreferenceProfile.initial();
      _cachedEvents = [];
      _cachedItems = [];
    }
    _isInitialized = true;
  }

  /// Synchronously returns current preference profile.
  PreferenceProfile getPreferenceProfile() {
    return _cachedProfile;
  }

  /// Synchronously returns all recorded memory events.
  List<MemoryEvent> getEvents() {
    return List.unmodifiable(_cachedEvents);
  }

  /// Synchronously returns all recorded structured memory items.
  List<MemoryItem> getMemoryItems() {
    return List.unmodifiable(_cachedItems);
  }

  /// Saves updated profile to persistent storage.
  Future<void> saveProfile(PreferenceProfile profile) async {
    _cachedProfile = profile;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_profileKey, jsonEncode(profile.toJson()));
    } catch (_) {}
  }

  static const int maxStoredEvents = 100;
  static const int maxStoredItems = 150;

  /// Records an individual memory event and updates persistent list with compaction to prevent bloat.
  ///
  /// With [replaceSameId] an event that already has this id is replaced
  /// instead of added again, so a caller that builds its ids from a stable key
  /// can record the same thing twice safely. Other events keep being added
  /// even when their millisecond-based ids happen to match.
  Future<void> recordEvent(
    MemoryEvent event, {
    bool replaceSameId = false,
  }) async {
    final existing = replaceSameId
        ? _cachedEvents.indexWhere((e) => e.id == event.id)
        : -1;
    if (existing >= 0) {
      _cachedEvents[existing] = event;
    } else {
      _cachedEvents.add(event);
    }

    if (_cachedEvents.length > maxStoredEvents) {
      _cachedEvents = _cachedEvents.sublist(
        _cachedEvents.length - maxStoredEvents,
      );
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_cachedEvents.map((e) => e.toJson()).toList());
      await prefs.setString(_eventsKey, encoded);
    } catch (_) {}
  }

  // ===========================================================================
  // ADVANCED STRUCTURED MEMORY ITEMS & RETRIEVAL
  // ===========================================================================

  /// Records or updates a structured [MemoryItem] in long-term memory.
  Future<void> recordMemoryItem(MemoryItem item) async {
    final existingIndex = _cachedItems.indexWhere((m) => m.id == item.id);
    if (existingIndex >= 0) {
      _cachedItems[existingIndex] = item;
    } else {
      _cachedItems.add(item);
    }

    if (_cachedItems.length > maxStoredItems) {
      // Sort by importance score descending and keep top items
      _cachedItems.sort(
        (a, b) => b.importanceScore.compareTo(a.importanceScore),
      );
      _cachedItems = _cachedItems.sublist(0, maxStoredItems);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_cachedItems.map((e) => e.toJson()).toList());
      await prefs.setString(_itemsKey, encoded);
    } catch (_) {}
  }

  /// Records an observed behavioral pattern (e.g. skips Friday evening workouts, trains best in mornings).
  Future<MemoryItem> recordBehaviorPattern({
    required String title,
    required String pattern,
    double? importanceScore,
    List<String> tags = const [],
  }) async {
    final score =
        importanceScore ??
        MemoryImportanceScorer.calculateScore(
          category: MemoryCategory.behaviorPattern,
        );

    final item = MemoryItem(
      id: 'mem_beh_${DateTime.now().millisecondsSinceEpoch}_${title.hashCode.abs()}',
      category: MemoryCategory.behaviorPattern,
      title: title,
      content: pattern,
      importanceScore: score,
      tags: tags,
      source: 'behavior_engine',
      createdAt: DateTime.now(),
    );

    await recordMemoryItem(item);
    return item;
  }

  /// Records a successful training/diet strategy (e.g. dynamic shoulder warm-up eliminated pressing discomfort).
  Future<MemoryItem> recordSuccessfulStrategy({
    required String title,
    required String strategy,
    double? importanceScore,
    bool userConfirmed = true,
    List<String> tags = const [],
    String? id,
  }) async {
    final score =
        importanceScore ??
        MemoryImportanceScorer.calculateScore(
          category: MemoryCategory.successfulStrategy,
          userConfirmed: userConfirmed,
        );

    final item = MemoryItem(
      id:
          id ??
          'mem_strat_${DateTime.now().millisecondsSinceEpoch}_${title.hashCode.abs()}',
      category: MemoryCategory.successfulStrategy,
      title: title,
      content: strategy,
      importanceScore: score,
      tags: tags,
      source: 'coaching_feedback',
      createdAt: DateTime.now(),
    );

    await recordMemoryItem(item);
    return item;
  }

  /// Records an explicit training or equipment preference item.
  Future<MemoryItem> recordTrainingPreferenceItem({
    required String title,
    required String preference,
    double? importanceScore,
    List<String> tags = const [],
  }) async {
    final score =
        importanceScore ??
        MemoryImportanceScorer.calculateScore(
          category: MemoryCategory.trainingPreference,
        );

    final item = MemoryItem(
      id: 'mem_pref_${DateTime.now().millisecondsSinceEpoch}_${title.hashCode.abs()}',
      category: MemoryCategory.trainingPreference,
      title: title,
      content: preference,
      importanceScore: score,
      tags: tags,
      source: 'user_dialogue',
      createdAt: DateTime.now(),
    );

    await recordMemoryItem(item);
    return item;
  }

  /// Records a historical coaching decision and outcome (e.g. prescribed 20% deload on Aug 20).
  Future<MemoryItem> recordHistoricalDecision({
    required String title,
    required String decision,
    double? importanceScore,
    List<String> tags = const [],
  }) async {
    final score =
        importanceScore ??
        MemoryImportanceScorer.calculateScore(
          category: MemoryCategory.historicalDecision,
        );

    final item = MemoryItem(
      id: 'mem_dec_${DateTime.now().millisecondsSinceEpoch}_${title.hashCode.abs()}',
      category: MemoryCategory.historicalDecision,
      title: title,
      content: decision,
      importanceScore: score,
      tags: tags,
      source: 'decision_engine',
      createdAt: DateTime.now(),
    );

    await recordMemoryItem(item);
    return item;
  }

  /// Prunes all expired memory items from memory and storage.
  Future<int> pruneExpiredMemories() async {
    final originalCount = _cachedItems.length;
    _cachedItems.removeWhere((item) => item.isExpired);
    final prunedCount = originalCount - _cachedItems.length;
    if (prunedCount > 0) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          _itemsKey,
          jsonEncode(_cachedItems.map((e) => e.toJson()).toList()),
        );
      } catch (_) {}
    }
    return prunedCount;
  }

  /// Retrieves stored memory items filtered by category, minimum score, and optional tag.
  /// Automatically filters out expired memory items.
  List<MemoryItem> retrieveMemories({
    MemoryCategory? category,
    double minScore = 0.0,
    String? tag,
    bool includeExpired = false,
  }) {
    return _cachedItems.where((item) {
      if (!includeExpired && item.isExpired) return false;
      if (category != null && item.category != category) return false;
      if (item.importanceScore < minScore) return false;
      if (tag != null &&
          !item.tags.any((t) => t.toLowerCase() == tag.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();
  }

  /// Ranks stored memory items for a specific conversational or contextual query
  /// using importance scoring, token relevance, confidence scoring, and recency decay.
  List<MemoryItem> rankMemoriesForContext(
    String queryContext, {
    MemoryCategory? category,
    int limit = 5,
    bool includeExpired = false,
  }) {
    final cleanQuery = queryContext.toLowerCase();
    final queryTokens = cleanQuery
        .split(RegExp(r'\s+'))
        .where((t) => t.length > 2)
        .toSet();

    final candidates = _cachedItems.where((item) {
      if (!includeExpired && item.isExpired) return false;
      if (category != null && item.category != category) return false;
      return true;
    }).toList();

    final now = DateTime.now();

    final scored = candidates.map((item) {
      double relevance = 0.0;
      final text = '${item.title} ${item.content} ${item.tags.join(' ')}'
          .toLowerCase();

      for (final token in queryTokens) {
        if (text.contains(token)) {
          relevance += 2.0;
        }
      }

      // Multi-factor ranking:
      // 1. Importance (1.0 to 10.0 scale)
      double totalScore = (item.importanceScore * 1.2) + relevance;

      // 2. Confidence Score (0.0 to 1.0 scale)
      totalScore += (item.confidenceScore * 3.0);

      // 3. Recency weighting and temporal decay
      final ageDays = now.difference(item.createdAt).inDays;
      if (ageDays <= 7) {
        totalScore += 1.5;
      } else if (ageDays <= 30) {
        totalScore += 0.75;
      } else if (ageDays > 90) {
        totalScore -= 0.5; // Mild temporal decay for old memories
      }

      return MapEntry(item, totalScore);
    }).toList();

    scored.sort((a, b) => b.value.compareTo(a.value));

    return scored.take(limit).map((e) => e.key).toList();
  }

  /// Formats top relevant memories into a string for injection into coaching prompts.
  String formatMemoriesForPrompt(String queryContext, {int limit = 4}) {
    final ranked = rankMemoriesForContext(queryContext, limit: limit);
    if (ranked.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.writeln('--- ATHLETE LONG-TERM COACHING MEMORY ---');
    for (final item in ranked) {
      buffer.writeln(
        '• [${item.category.name.toUpperCase()} | Score: ${item.importanceScore.toStringAsFixed(1)} | Conf: ${(item.confidenceScore * 100).round()}%] ${item.title}: ${item.content}',
      );
    }
    return buffer.toString();
  }

  // ===========================================================================
  // EXISTING PREFERENCE & EVENT LOGGING METHODS (PRESERVED)
  // ===========================================================================

  /// Records athlete feedback (Helpful / Not helpful) on AI recommendations.
  Future<void> recordRecommendationFeedback({
    required String recommendationId,
    required bool isHelpful,
    String? recommendationTitle,
  }) async {
    final event = MemoryEvent(
      id: 'evt_rec_${DateTime.now().millisecondsSinceEpoch}',
      type: isHelpful
          ? MemoryEventType.recommendationHelpful
          : MemoryEventType.recommendationUnhelpful,
      target: recommendationId,
      notes: recommendationTitle,
      scoreDelta: isHelpful ? 1 : -1,
      timestamp: DateTime.now(),
    );
    await recordEvent(event);

    final updatedProfile = _cachedProfile.copyWith(
      helpfulRecommendationsCount: isHelpful
          ? _cachedProfile.helpfulRecommendationsCount + 1
          : _cachedProfile.helpfulRecommendationsCount,
      unhelpfulRecommendationsCount: !isHelpful
          ? _cachedProfile.unhelpfulRecommendationsCount + 1
          : _cachedProfile.unhelpfulRecommendationsCount,
    );
    await saveProfile(updatedProfile);

    // Also store as structured successful strategy or historical decision
    if (isHelpful && recommendationTitle != null) {
      await recordSuccessfulStrategy(
        title: 'Effective Recommendation: $recommendationTitle',
        strategy:
            'Athlete found recommendation "$recommendationTitle" helpful and motivating.',
        importanceScore: 8.0,
      );
    }
  }

  /// Records exercise replacement (e.g. Bench Press -> Dumbbell Press),
  /// incrementing preference score of replacement (+1) and decrementing old exercise (-1).
  Future<void> recordExerciseReplacement({
    required String oldExercise,
    required String newExercise,
  }) async {
    final oldEx = oldExercise.trim();
    final newEx = newExercise.trim();

    final event = MemoryEvent(
      id: 'evt_rep_${DateTime.now().millisecondsSinceEpoch}',
      type: MemoryEventType.exerciseReplaced,
      target: oldEx,
      secondaryTarget: newEx,
      scoreDelta: 1,
      notes: 'Replaced $oldEx with $newEx',
      timestamp: DateTime.now(),
    );
    await recordEvent(event);

    final exerciseScores = Map<String, int>.from(_cachedProfile.exerciseScores);
    final oldScore = (exerciseScores[oldEx] ?? 0) - 1;
    final newScore = (exerciseScores[newEx] ?? 0) + 1;

    exerciseScores[oldEx] = oldScore;
    exerciseScores[newEx] = newScore;

    final preferred = List<String>.from(_cachedProfile.preferredExercises);
    final disliked = List<String>.from(_cachedProfile.dislikedExercises);

    if (newScore >= 1 && !preferred.contains(newEx)) {
      preferred.add(newEx);
      disliked.remove(newEx);
    }

    if (oldScore <= -1 && !disliked.contains(oldEx)) {
      disliked.add(oldEx);
      preferred.remove(oldEx);
    }

    final updatedProfile = _cachedProfile.copyWith(
      exerciseScores: exerciseScores,
      preferredExercises: preferred,
      dislikedExercises: disliked,
    );
    await saveProfile(updatedProfile);

    await recordTrainingPreferenceItem(
      title: 'Prefers $newEx over $oldEx',
      preference:
          'Athlete substituted $oldEx with $newEx for better movement comfort/access.',
      importanceScore: 7.0,
      tags: [newEx, oldEx, 'substitution'],
    );
  }

  /// Records explicit liking or disliking of an exercise.
  Future<void> recordExercisePreference({
    required String exercise,
    required bool isPreferred,
  }) async {
    final ex = exercise.trim();
    final event = MemoryEvent(
      id: 'evt_pref_${DateTime.now().millisecondsSinceEpoch}',
      type: isPreferred
          ? MemoryEventType.exerciseLiked
          : MemoryEventType.exerciseDisliked,
      target: ex,
      scoreDelta: isPreferred ? 2 : -2,
      timestamp: DateTime.now(),
    );
    await recordEvent(event);

    final exerciseScores = Map<String, int>.from(_cachedProfile.exerciseScores);
    final score = (exerciseScores[ex] ?? 0) + (isPreferred ? 2 : -2);
    exerciseScores[ex] = score;

    final preferred = List<String>.from(_cachedProfile.preferredExercises);
    final disliked = List<String>.from(_cachedProfile.dislikedExercises);

    if (isPreferred) {
      if (!preferred.contains(ex)) preferred.add(ex);
      disliked.remove(ex);
    } else {
      if (!disliked.contains(ex)) disliked.add(ex);
      preferred.remove(ex);
    }

    final updatedProfile = _cachedProfile.copyWith(
      exerciseScores: exerciseScores,
      preferredExercises: preferred,
      dislikedExercises: disliked,
    );
    await saveProfile(updatedProfile);
  }

  /// Records explicit liking or disliking of a food item.
  Future<void> recordFoodPreference({
    required String food,
    required bool isPreferred,
  }) async {
    final f = food.trim();
    final event = MemoryEvent(
      id: 'evt_food_${DateTime.now().millisecondsSinceEpoch}',
      type: isPreferred
          ? MemoryEventType.foodLiked
          : MemoryEventType.foodDisliked,
      target: f,
      scoreDelta: isPreferred ? 2 : -2,
      timestamp: DateTime.now(),
    );
    await recordEvent(event);

    final foodScores = Map<String, int>.from(_cachedProfile.foodScores);
    final score = (foodScores[f] ?? 0) + (isPreferred ? 2 : -2);
    foodScores[f] = score;

    final preferred = List<String>.from(_cachedProfile.preferredFoods);
    final disliked = List<String>.from(_cachedProfile.dislikedFoods);

    if (isPreferred) {
      if (!preferred.contains(f)) preferred.add(f);
      disliked.remove(f);
    } else {
      if (!disliked.contains(f)) disliked.add(f);
      preferred.remove(f);
    }

    final updatedProfile = _cachedProfile.copyWith(
      foodScores: foodScores,
      preferredFoods: preferred,
      dislikedFoods: disliked,
    );
    await saveProfile(updatedProfile);
  }

  /// Records a food item logged into daily meals.
  Future<void> recordFoodLogged(String foodName) async {
    final name = foodName.trim();
    if (name.isEmpty) return;
    final event = MemoryEvent(
      id: 'evt_foodlog_${DateTime.now().millisecondsSinceEpoch}',
      type: MemoryEventType.foodLiked,
      target: name,
      scoreDelta: 1,
      notes: 'Logged in daily meal',
      timestamp: DateTime.now(),
    );
    await recordEvent(event);
  }

  /// Updates general coaching style and workout duration preferences.
  Future<void> updatePreferences({
    int? durationMinutes,
    String? trainingStyle,
    String? coachPersonality,
  }) async {
    final updatedProfile = _cachedProfile.copyWith(
      preferredWorkoutDurationMinutes:
          durationMinutes ?? _cachedProfile.preferredWorkoutDurationMinutes,
      trainingStyle: trainingStyle ?? _cachedProfile.trainingStyle,
      coachPersonalityPreference:
          coachPersonality ?? _cachedProfile.coachPersonalityPreference,
    );
    await saveProfile(updatedProfile);
  }

  /// Records a completed workout execution in AI Memory to power personalization and progression
  Future<void> recordWorkoutExecution({
    required String workoutTitle,
    required double totalVolume,
    required int completedSets,
    List<String> prs = const [],
    List<dynamic>? exercises,
    String? completionKey,
  }) async {
    // With a completion key the ids come from the key, so recording the same
    // workout again replaces its notes instead of adding copies.
    final stamp = completionKey ?? '${DateTime.now().millisecondsSinceEpoch}';
    final event = MemoryEvent(
      id: 'evt_wo_$stamp',
      type: MemoryEventType.workoutCompleted,
      target: workoutTitle,
      scoreDelta: 5,
      notes:
          'Volume: ${totalVolume.toStringAsFixed(0)} kg, Sets: $completedSets${prs.isNotEmpty ? ', PRs: ${prs.join(', ')}' : ''}',
      timestamp: DateTime.now(),
    );
    await recordEvent(event, replaceSameId: completionKey != null);

    if (exercises != null) {
      for (final ex in exercises) {
        if (ex is WorkoutSessionExercise) {
          final completed = ex.sets.where((s) => s.completed).toList();
          if (completed.isNotEmpty) {
            final maxW = ex.maxWeight;
            final totalR = ex.totalCompletedReps;
            final exEvent = MemoryEvent(
              id: completionKey != null
                  ? 'evt_perf_${completionKey}_${ex.id}'
                  : 'evt_perf_${DateTime.now().millisecondsSinceEpoch}_${ex.id.hashCode}',
              type: MemoryEventType.workoutCompleted,
              target: ex.name,
              scoreDelta: 2,
              notes:
                  '${completed.length} sets completed: peak ${maxW.toStringAsFixed(1)} kg, $totalR total reps',
              timestamp: DateTime.now(),
            );
            await recordEvent(exEvent, replaceSameId: completionKey != null);
          }
        }
      }
    }

    for (var i = 0; i < prs.length; i++) {
      final pr = prs[i];
      final prEvent = MemoryEvent(
        id: completionKey != null
            ? 'evt_pr_${completionKey}_$i'
            : 'evt_pr_${DateTime.now().millisecondsSinceEpoch}_${pr.hashCode}',
        type: MemoryEventType.prAchieved,
        target: pr,
        scoreDelta: 10,
        notes: 'PR Achieved in $workoutTitle',
        timestamp: DateTime.now(),
      );
      await recordEvent(prEvent, replaceSameId: completionKey != null);

      await recordSuccessfulStrategy(
        title: 'PR Milestone: $pr',
        strategy:
            'Achieved PR in $workoutTitle with total volume of ${totalVolume.round()}kg.',
        importanceScore: 9.0,
        tags: [pr, workoutTitle, 'PR'],
        id: completionKey != null ? 'mem_strat_${completionKey}_$i' : null,
      );
    }
  }

  /// Records post-workout difficulty feedback ('Too Easy', 'Perfect', 'Too Hard').
  Future<void> recordWorkoutDifficultyFeedback({
    required String workoutId,
    required String difficultyRating,
    String? notes,
  }) async {
    final event = MemoryEvent(
      id: 'evt_diff_${DateTime.now().millisecondsSinceEpoch}',
      type: MemoryEventType.workoutDifficultyFeedback,
      target: workoutId,
      notes: difficultyRating,
      scoreDelta: difficultyRating == 'Too Easy'
          ? 1
          : (difficultyRating == 'Too Hard' ? -1 : 0),
      timestamp: DateTime.now(),
    );
    await recordEvent(event);
  }

  /// Records post-workout exercise enjoyment feedback (Enjoyed / Replace requested).
  Future<void> recordExerciseEnjoymentFeedback({
    required String exerciseName,
    required bool enjoyed,
    String? replacementRequested,
  }) async {
    final ex = exerciseName.trim();
    if (enjoyed) {
      final event = MemoryEvent(
        id: 'evt_enj_${DateTime.now().millisecondsSinceEpoch}',
        type: MemoryEventType.exerciseEnjoyed,
        target: ex,
        scoreDelta: 2,
        notes: 'Enjoyed in workout feedback',
        timestamp: DateTime.now(),
      );
      await recordEvent(event);
      await recordExercisePreference(exercise: ex, isPreferred: true);
    } else {
      if (replacementRequested != null &&
          replacementRequested.trim().isNotEmpty) {
        await recordExerciseReplacement(
          oldExercise: ex,
          newExercise: replacementRequested.trim(),
        );
      } else {
        await recordExercisePreference(exercise: ex, isPreferred: false);
      }
    }
  }

  /// Records a skipped workout session for proactive volume and split learning.
  Future<void> recordSkippedWorkout({
    required String workoutName,
    required String splitType,
    String? reason,
  }) async {
    final event = MemoryEvent(
      id: 'evt_skip_${DateTime.now().millisecondsSinceEpoch}',
      type: MemoryEventType.workoutSkipped,
      target: splitType.trim(),
      notes: reason ?? workoutName.trim(),
      scoreDelta: -1,
      timestamp: DateTime.now(),
    );
    await recordEvent(event);

    await recordBehaviorPattern(
      title: 'Skipped ${splitType.trim()} session',
      pattern:
          'Skipped "$workoutName" (${splitType.trim()})${reason != null ? ': $reason' : ''}.',
      importanceScore: 6.0,
      tags: [splitType, 'skip_pattern'],
    );
  }

  /// Returns dynamically synthesized [TrainingPreferenceProfile] based on history & feedback.
  TrainingPreferenceProfile getTrainingPreferenceProfile({
    List<WorkoutHistory> history = const [],
  }) {
    return WorkoutPersonalizationEngine.instance.analyzeHistoryAndMemory(
      history: history,
      memoryEvents: _cachedEvents,
      baseProfile: _cachedProfile,
    );
  }

  /// Clears stored memory events, memory items, and resets preferences to default.
  Future<void> clearMemory() async {
    _cachedProfile = PreferenceProfile.initial();
    _cachedEvents = [];
    _cachedItems = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_profileKey);
      await prefs.remove(_eventsKey);
      await prefs.remove(_itemsKey);
    } catch (_) {}
  }
}
