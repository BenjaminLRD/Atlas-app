import '../../models/user_profile.dart';
import '../../models/user_goal.dart';
import '../../models/weight_goal.dart';
import '../../models/workout_history.dart';
import '../../models/workout_session.dart';
import '../../models/personal_record.dart';
import '../../models/daily_nutrition.dart';
import '../../models/food_item.dart';
import '../../models/consumed_food.dart';
import '../../models/health_metric.dart';
import '../../models/activity_post.dart';
import '../../models/coach_message.dart';

/// Database table mapping definitions for Atlas Supabase tables.
class SupabaseTableNames {
  // User Domain
  static const String profiles = 'profiles';
  static const String fitnessProfiles = 'fitness_profiles';
  static const String userPreferences = 'user_preferences';
  static const String userGoals = 'user_goals';
  static const String weightGoals = 'weight_goals';

  // Workout Domain
  static const String workouts = 'workouts';
  static const String workoutSessions = 'workout_sessions';
  static const String workoutExercises = 'workout_exercises';
  static const String workoutSets = 'workout_sets';
  static const String personalRecords = 'personal_records';

  // Nutrition Domain
  static const String foods = 'foods';
  static const String nutritionLogs = 'nutrition_logs';
  static const String mealEntries = 'meal_entries';

  // AI Domain
  static const String aiMemory = 'ai_memory';
  static const String aiConversations = 'ai_conversations';
  static const String aiFeedback = 'ai_feedback';

  // Health Domain
  static const String healthMetrics = 'health_metrics';
  static const String recoveryScores = 'recovery_scores';

  // Social Domain
  static const String posts = 'posts';
  static const String communityPosts = 'posts';
  static const String comments = 'comments';
  static const String postReactions = 'post_reactions';
  static const String challenges = 'challenges';
  static const String challengeParticipants = 'challenge_participants';
  static const String leaderboards = 'leaderboards';
  static const String friendships = 'friendships';

  // Analytics & Beta Testing Domain
  static const String analyticsEvents = 'analytics_events';
  static const String betaFeedbacks = 'beta_feedbacks';

  // Machine Learning & Personalization Domain
  static const String userBehaviorEvents = 'user_behavior_events';
  static const String modelPredictions = 'model_predictions';
  static const String personalizationProfiles = 'personalization_profiles';
  static const String mlTrainingEvents = 'ml_training_events';

  // Digital Athlete & Research Domain
  static const String digitalAthleteProfiles = 'digital_athlete_profiles';
  static const String athleteInsights = 'athlete_insights';
  static const String predictionResults = 'prediction_results';
}

/// Model representing a persistent AI memory entry in Supabase `ai_memory` table.
class AIMemoryEntry {
  final String id;
  final String userId;
  final String memoryType;
  final Map<String, dynamic> memoryValue;
  final double confidence;
  final String? conversation;
  final Map<String, dynamic>? fitnessContext;
  final Map<String, dynamic>? preferences;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AIMemoryEntry({
    required this.id,
    required this.userId,
    this.memoryType = 'general',
    this.memoryValue = const {},
    this.confidence = 1.0,
    this.conversation,
    this.fitnessContext,
    this.preferences,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AIMemoryEntry.fromJson(Map<String, dynamic> json) {
    return AIMemoryEntry(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      memoryType: json['memory_type']?.toString() ?? 'general',
      memoryValue: json['memory_value'] != null
          ? Map<String, dynamic>.from(json['memory_value'] as Map)
          : {},
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
      conversation: json['conversation']?.toString(),
      fitnessContext: json['fitness_context'] != null
          ? Map<String, dynamic>.from(json['fitness_context'] as Map)
          : null,
      preferences: json['preferences'] != null
          ? Map<String, dynamic>.from(json['preferences'] as Map)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'memory_type': memoryType,
    'memory_value': memoryValue,
    'confidence': confidence,
    if (conversation != null) 'conversation': conversation,
    if (fitnessContext != null) 'fitness_context': fitnessContext,
    if (preferences != null) 'preferences': preferences,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}

/// Model representing user feedback on AI recommendations in `ai_feedback` table.
class AIFeedbackEntry {
  final String id;
  final String userId;
  final String recommendation;
  final String feedback;
  final int rating;
  final DateTime createdAt;

  const AIFeedbackEntry({
    required this.id,
    required this.userId,
    required this.recommendation,
    required this.feedback,
    required this.rating,
    required this.createdAt,
  });

  factory AIFeedbackEntry.fromJson(Map<String, dynamic> json) {
    return AIFeedbackEntry(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      recommendation: json['recommendation']?.toString() ?? '',
      feedback: json['feedback']?.toString() ?? '',
      rating: (json['rating'] as num?)?.toInt() ?? 5,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'recommendation': recommendation,
    'feedback': feedback,
    'rating': rating,
    'created_at': createdAt.toIso8601String(),
  };
}

/// Model representing an analytics event payload for `analytics_events` table.
class AnalyticsEventData {
  final String id;
  final String? userId;
  final String eventName;
  final Map<String, dynamic> properties;
  final String? sessionId;
  final DateTime clientTimestamp;
  final DateTime createdAt;

  const AnalyticsEventData({
    required this.id,
    this.userId,
    required this.eventName,
    this.properties = const {},
    this.sessionId,
    required this.clientTimestamp,
    required this.createdAt,
  });

  factory AnalyticsEventData.fromJson(Map<String, dynamic> json) {
    return AnalyticsEventData(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString(),
      eventName: json['event_name']?.toString() ?? 'generic_event',
      properties: json['properties'] != null
          ? Map<String, dynamic>.from(json['properties'] as Map)
          : const {},
      sessionId: json['session_id']?.toString(),
      clientTimestamp: json['client_timestamp'] != null
          ? DateTime.tryParse(json['client_timestamp'].toString()) ??
                DateTime.now()
          : DateTime.now(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'event_name': eventName,
    'properties': properties,
    'session_id': sessionId,
    'client_timestamp': clientTimestamp.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
  };
}

/// Model representing a behavior event record in Supabase `user_behavior_events` table.
class UserBehaviorEventData {
  final String id;
  final String userId;
  final String domain;
  final String eventType;
  final Map<String, dynamic> payload;
  final DateTime timestamp;

  const UserBehaviorEventData({
    required this.id,
    required this.userId,
    required this.domain,
    required this.eventType,
    this.payload = const {},
    required this.timestamp,
  });

  factory UserBehaviorEventData.fromJson(Map<String, dynamic> json) {
    return UserBehaviorEventData(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      domain: json['domain']?.toString() ?? 'workout',
      eventType: json['event_type']?.toString() ?? '',
      payload: json['payload'] != null
          ? Map<String, dynamic>.from(json['payload'] as Map)
          : const {},
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'domain': domain,
    'event_type': eventType,
    'payload': payload,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Model representing a machine learning prediction record in Supabase `model_predictions` table.
class ModelPredictionData {
  final String id;
  final String userId;
  final String modelName;
  final Map<String, dynamic> predictionOutput;
  final double confidenceScore;
  final DateTime createdAt;

  const ModelPredictionData({
    required this.id,
    required this.userId,
    required this.modelName,
    required this.predictionOutput,
    this.confidenceScore = 1.0,
    required this.createdAt,
  });

  factory ModelPredictionData.fromJson(Map<String, dynamic> json) {
    return ModelPredictionData(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      modelName: json['model_name']?.toString() ?? '',
      predictionOutput: json['prediction_output'] != null
          ? Map<String, dynamic>.from(json['prediction_output'] as Map)
          : (json['prediction_payload'] != null
                ? Map<String, dynamic>.from(json['prediction_payload'] as Map)
                : const {}),
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 1.0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'model_name': modelName,
    'prediction_output': predictionOutput,
    'confidence_score': confidenceScore,
    'created_at': createdAt.toIso8601String(),
  };
}

/// Model representing a personalized habit profile in Supabase `personalization_profiles` table.
class PersonalizationProfileData {
  final String userId;
  final Map<String, dynamic> featureVector;
  final String preferredTrainingTime;
  final String churnRisk;
  final List<dynamic> discoveredInsights;
  final DateTime updatedAt;

  const PersonalizationProfileData({
    required this.userId,
    this.featureVector = const {},
    this.preferredTrainingTime = 'evening',
    this.churnRisk = 'low',
    this.discoveredInsights = const [],
    required this.updatedAt,
  });

  factory PersonalizationProfileData.fromJson(Map<String, dynamic> json) {
    return PersonalizationProfileData(
      userId: json['user_id']?.toString() ?? '',
      featureVector: json['feature_vector'] != null
          ? Map<String, dynamic>.from(json['feature_vector'] as Map)
          : const {},
      preferredTrainingTime:
          json['preferred_training_time']?.toString() ?? 'evening',
      churnRisk: json['churn_risk']?.toString() ?? 'low',
      discoveredInsights:
          json['discovered_insights'] as List<dynamic>? ?? const [],
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'feature_vector': featureVector,
    'preferred_training_time': preferredTrainingTime,
    'churn_risk': churnRisk,
    'discovered_insights': discoveredInsights,
    'updated_at': updatedAt.toIso8601String(),
  };
}

/// Model representing a training event record in Supabase `ml_training_events` table.
class MLTrainingEventData {
  final String id;
  final String anonymizedUserId;
  final String domain;
  final String eventType;
  final Map<String, dynamic> featurePayload;
  final bool isAnonymized;
  final bool consentVerified;
  final DateTime timestamp;

  const MLTrainingEventData({
    required this.id,
    required this.anonymizedUserId,
    required this.domain,
    required this.eventType,
    this.featurePayload = const {},
    this.isAnonymized = true,
    this.consentVerified = true,
    required this.timestamp,
  });

  factory MLTrainingEventData.fromJson(Map<String, dynamic> json) {
    return MLTrainingEventData(
      id: json['id']?.toString() ?? '',
      anonymizedUserId:
          json['anonymized_user_id']?.toString() ??
          json['user_id']?.toString() ??
          '',
      domain: json['domain']?.toString() ?? 'workout',
      eventType: json['event_type']?.toString() ?? '',
      featurePayload: json['feature_payload'] != null
          ? Map<String, dynamic>.from(json['feature_payload'] as Map)
          : (json['payload'] != null
                ? Map<String, dynamic>.from(json['payload'] as Map)
                : const {}),
      isAnonymized: json['is_anonymized'] as bool? ?? true,
      consentVerified: json['consent_verified'] as bool? ?? true,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': anonymizedUserId,
    'anonymized_user_id': anonymizedUserId,
    'domain': domain,
    'event_type': eventType,
    'feature_payload': featurePayload,
    'is_anonymized': isAnonymized,
    'consent_verified': consentVerified,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Model representing a digital athlete profile record in Supabase `digital_athlete_profiles` table.
class DigitalAthleteProfileData {
  final String userId;
  final Map<String, dynamic> physicalProfile;
  final Map<String, dynamic> strengthProfile;
  final Map<String, dynamic> trainingProfile;
  final Map<String, dynamic> recoveryProfile;
  final Map<String, dynamic> nutritionProfile;
  final Map<String, dynamic> behaviorProfile;
  final Map<String, dynamic> goalProfile;
  final List<dynamic> biomechanicsWeaknesses;
  final Map<String, dynamic> formScoreAverages;
  final DateTime updatedAt;

  const DigitalAthleteProfileData({
    required this.userId,
    this.physicalProfile = const {},
    this.strengthProfile = const {},
    this.trainingProfile = const {},
    this.recoveryProfile = const {},
    this.nutritionProfile = const {},
    this.behaviorProfile = const {},
    this.goalProfile = const {},
    this.biomechanicsWeaknesses = const [],
    this.formScoreAverages = const {},
    required this.updatedAt,
  });

  factory DigitalAthleteProfileData.fromJson(Map<String, dynamic> json) {
    return DigitalAthleteProfileData(
      userId: json['user_id']?.toString() ?? '',
      physicalProfile: json['physical_profile'] != null
          ? Map<String, dynamic>.from(json['physical_profile'] as Map)
          : const {},
      strengthProfile: json['strength_profile'] != null
          ? Map<String, dynamic>.from(json['strength_profile'] as Map)
          : const {},
      trainingProfile: json['training_profile'] != null
          ? Map<String, dynamic>.from(json['training_profile'] as Map)
          : const {},
      recoveryProfile: json['recovery_profile'] != null
          ? Map<String, dynamic>.from(json['recovery_profile'] as Map)
          : const {},
      nutritionProfile: json['nutrition_profile'] != null
          ? Map<String, dynamic>.from(json['nutrition_profile'] as Map)
          : const {},
      behaviorProfile: json['behavior_profile'] != null
          ? Map<String, dynamic>.from(json['behavior_profile'] as Map)
          : const {},
      goalProfile: json['goal_profile'] != null
          ? Map<String, dynamic>.from(json['goal_profile'] as Map)
          : const {},
      biomechanicsWeaknesses:
          json['biomechanics_weaknesses'] as List<dynamic>? ?? const [],
      formScoreAverages: json['form_score_averages'] != null
          ? Map<String, dynamic>.from(json['form_score_averages'] as Map)
          : const {},
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'physical_profile': physicalProfile,
    'strength_profile': strengthProfile,
    'training_profile': trainingProfile,
    'recovery_profile': recoveryProfile,
    'nutrition_profile': nutritionProfile,
    'behavior_profile': behaviorProfile,
    'goal_profile': goalProfile,
    'biomechanics_weaknesses': biomechanicsWeaknesses,
    'form_score_averages': formScoreAverages,
    'updated_at': updatedAt.toIso8601String(),
  };
}

/// Model representing an athlete insight record in Supabase `athlete_insights` table.
class AthleteInsightData {
  final String id;
  final String userId;
  final String category;
  final String title;
  final String description;
  final String recommendation;
  final double significanceScore;
  final DateTime createdAt;

  const AthleteInsightData({
    required this.id,
    required this.userId,
    required this.category,
    required this.title,
    required this.description,
    required this.recommendation,
    this.significanceScore = 0.85,
    required this.createdAt,
  });

  factory AthleteInsightData.fromJson(Map<String, dynamic> json) {
    return AthleteInsightData(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      category: json['category']?.toString() ?? 'strength',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      recommendation: json['recommendation']?.toString() ?? '',
      significanceScore:
          (json['significance_score'] as num?)?.toDouble() ?? 0.85,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'category': category,
    'title': title,
    'description': description,
    'recommendation': recommendation,
    'significance_score': significanceScore,
    'created_at': createdAt.toIso8601String(),
  };
}

/// Model representing a prediction result record in Supabase `prediction_results` table.
class PredictionResultData {
  final String id;
  final String userId;
  final String predictionType;
  final Map<String, dynamic> predictionPayload;
  final double confidenceScore;
  final DateTime createdAt;

  const PredictionResultData({
    required this.id,
    required this.userId,
    required this.predictionType,
    required this.predictionPayload,
    this.confidenceScore = 0.90,
    required this.createdAt,
  });

  factory PredictionResultData.fromJson(Map<String, dynamic> json) {
    return PredictionResultData(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      predictionType: json['prediction_type']?.toString() ?? '',
      predictionPayload: json['prediction_payload'] != null
          ? Map<String, dynamic>.from(json['prediction_payload'] as Map)
          : const {},
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0.90,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'prediction_type': predictionType,
    'prediction_payload': predictionPayload,
    'confidence_score': confidenceScore,
    'created_at': createdAt.toIso8601String(),
  };
}

/// Model representing a beta tester feedback submission in Supabase `beta_feedbacks` table.
class BetaFeedbackData {
  final String id;
  final String userId;
  final String feedback;
  final String category;
  final String priority;
  final Map<String, dynamic> deviceInfo;
  final DateTime timestamp;

  const BetaFeedbackData({
    required this.id,
    required this.userId,
    required this.feedback,
    required this.category,
    this.priority = 'medium',
    this.deviceInfo = const {},
    required this.timestamp,
  });

  factory BetaFeedbackData.fromJson(Map<String, dynamic> json) {
    return BetaFeedbackData(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      feedback: json['feedback']?.toString() ?? '',
      category: json['category']?.toString() ?? 'bug',
      priority: json['priority']?.toString() ?? 'medium',
      deviceInfo: json['device_info'] != null
          ? Map<String, dynamic>.from(json['device_info'] as Map)
          : const {},
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'feedback': feedback,
    'category': category,
    'priority': priority,
    'device_info': deviceInfo,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Mapper between domain models and Supabase database row maps.
/// Strictly excludes sensitive authentication tokens from cloud payloads.
class SupabaseModelMappers {
  // ------------------------------------------------------------
  // USER DOMAIN MAPPERS
  // ------------------------------------------------------------

  /// Map [UserProfile] to Supabase `profiles` table payload.
  static Map<String, dynamic> userProfileToTable(
    UserProfile profile, {
    String? userId,
  }) {
    return {
      'id': userId ?? 'usr_local_01',
      'username': profile.name.isNotEmpty
          ? profile.name
          : (profile.email.contains('@')
                ? profile.email.split('@').first
                : 'user'),
      'full_name': profile.name,
      'email': profile.email,
      'avatar_url': profile.profilePic,
      'phone': profile.phone,
      'dob': profile.dob,
      'gender': profile.gender,
      'height_cm': double.tryParse(profile.height) ?? 175.0,
      'weight_kg': double.tryParse(profile.weight) ?? 70.0,
      'fitness_goal': profile.fitnessGoal,
      'workout_experience': profile.workoutExperience,
      'diet_preference': profile.dietPreference,
      'subscription_tier': profile.subscription,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  /// Map Supabase `profiles` table payload to [UserProfile].
  static UserProfile tableToUserProfile(Map<String, dynamic> row) {
    final base = UserProfile.defaultProfile();
    if (row['full_name'] != null) base.name = row['full_name'] as String;
    if (row['email'] != null) base.email = row['email'] as String;
    if (row['phone'] != null) base.phone = row['phone'] as String;
    if (row['dob'] != null) base.dob = row['dob'] as String;
    if (row['gender'] != null) base.gender = row['gender'] as String;
    if (row['height_cm'] != null) {
      base.height = row['height_cm'].toString();
    } else if (row['height'] != null) {
      base.height = row['height'].toString();
    }
    if (row['weight_kg'] != null) {
      base.weight = row['weight_kg'].toString();
    } else if (row['weight'] != null) {
      base.weight = row['weight'].toString();
    }
    if (row['fitness_goal'] != null) {
      base.fitnessGoal = row['fitness_goal'] as String;
    }
    if (row['workout_experience'] != null) {
      base.workoutExperience = row['workout_experience'] as String;
    }
    if (row['diet_preference'] != null) {
      base.dietPreference = row['diet_preference'] as String;
    }
    if (row['avatar_url'] != null) {
      base.profilePic = row['avatar_url'] as String;
    } else if (row['profile_pic'] != null) {
      base.profilePic = row['profile_pic'] as String;
    }
    if (row['subscription_tier'] != null) {
      base.subscription = row['subscription_tier'] as String;
    }
    return base;
  }

  /// Map User preferences to Supabase `user_preferences` table payload.
  static Map<String, dynamic> userPreferencesToTable({
    required String userId,
    String trainingStyle = 'Hypertrophy',
    int preferredDuration = 45,
    List<String> equipment = const [],
    Map<String, dynamic> exercisePreferences = const {},
    bool notificationsEnabled = true,
    String themeMode = 'dark',
    String massUnit = 'kg',
    String lengthUnit = 'cm',
  }) {
    return {
      'user_id': userId,
      'training_style': trainingStyle,
      'preferred_duration': preferredDuration,
      'equipment': equipment,
      'exercise_preferences': exercisePreferences,
      'notifications_enabled': notificationsEnabled,
      'theme_mode': themeMode,
      'mass_unit': massUnit,
      'length_unit': lengthUnit,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  /// Map [UserProfile] to Supabase `fitness_profiles` table payload.
  static Map<String, dynamic> userProfileToFitnessProfileTable(
    UserProfile profile, {
    String? userId,
  }) {
    final uid =
        userId ?? (profile.userId.isNotEmpty ? profile.userId : 'usr_local_01');
    return {
      'id': uid,
      'user_id': uid,
      'age': profile.age,
      'gender': profile.gender,
      'height': profile.height,
      'weight': profile.weight,
      'fitness_goal': profile.fitnessGoal,
      'experience_level': profile.workoutExperience,
      'equipment': profile.equipment,
      'preferred_days': profile.preferredDays,
      'diet_preference': profile.dietPreference,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  /// Map [UserGoal] to Supabase `user_goals` table payload.
  static Map<String, dynamic> userGoalToTable(UserGoal goal, {String? userId}) {
    return {
      'id': goal.id,
      'user_id': userId ?? 'usr_local_01',
      'goal_type': goal.goalType.name,
      'fitness_level': goal.fitnessLevel.name,
      'activity_level': goal.activityLevel.name,
      'current_weight': goal.currentWeight,
      'target_weight': goal.targetWeight,
      'timeline': '12 weeks',
      'target_calories': goal.targetCalories,
      'target_protein': goal.targetProtein,
      'target_carbohydrates': goal.targetCarbohydrates,
      'target_fats': goal.targetFats,
      'created_at': goal.createdDate.toIso8601String(),
      'updated_at': goal.updatedDate.toIso8601String(),
    };
  }

  /// Map Supabase `user_goals` table payload to [UserGoal].
  static UserGoal tableToUserGoal(Map<String, dynamic> row) {
    return UserGoal(
      id: row['id'] ?? 'default_goal',
      goalType: FitnessGoalType.values.firstWhere(
        (e) =>
            e.name.toLowerCase() ==
            (row['goal_type'] ?? '').toString().toLowerCase(),
        orElse: () => FitnessGoalType.muscleGain,
      ),
      fitnessLevel: FitnessLevel.values.firstWhere(
        (e) =>
            e.name.toLowerCase() ==
            (row['fitness_level'] ?? '').toString().toLowerCase(),
        orElse: () => FitnessLevel.intermediate,
      ),
      activityLevel: ActivityLevel.values.firstWhere(
        (e) =>
            e.name.toLowerCase() ==
            (row['activity_level'] ?? '').toString().toLowerCase(),
        orElse: () => ActivityLevel.moderate,
      ),
      age: (row['age'] as num?)?.toInt() ?? 25,
      height: (row['height'] as num?)?.toDouble() ?? 175.0,
      currentWeight: (row['current_weight'] as num?)?.toDouble() ?? 70.0,
      targetWeight: (row['target_weight'] as num?)?.toDouble() ?? 75.0,
      targetCalories: (row['target_calories'] as num?)?.toDouble() ?? 2500.0,
      targetProtein: (row['target_protein'] as num?)?.toDouble() ?? 150.0,
      targetCarbohydrates:
          (row['target_carbohydrates'] as num?)?.toDouble() ?? 280.0,
      targetFats: (row['target_fats'] as num?)?.toDouble() ?? 70.0,
      createdDate: row['created_at'] != null
          ? DateTime.parse(row['created_at'] as String)
          : DateTime.now(),
      updatedDate: row['updated_at'] != null
          ? DateTime.parse(row['updated_at'] as String)
          : DateTime.now(),
    );
  }

  /// Map [WeightGoal] to Supabase `weight_goals` table payload.
  static Map<String, dynamic> weightGoalToTable(
    WeightGoal goal, {
    String? userId,
  }) {
    return {
      'id': goal.id,
      'user_id': userId ?? goal.userId,
      'goal_type': goal.type.name,
      'start_weight_kg': goal.currentWeight,
      'current_weight_kg': goal.currentWeight,
      'target_weight_kg': goal.targetWeight,
      'weekly_pace_kg': goal.expectedWeeklyRateKg,
      'daily_calories': goal.dailyCalorieTarget.round(),
      'protein_g': goal.proteinGrams,
      'carbs_g': goal.carbsGrams,
      'fats_g': goal.fatGrams,
      'diet_preference': goal.diet.name,
      'created_at': goal.createdAt.toIso8601String(),
      'updated_at': goal.updatedAt.toIso8601String(),
    };
  }

  // ------------------------------------------------------------
  // WORKOUT DOMAIN MAPPERS
  // ------------------------------------------------------------

  /// Map [WorkoutSession] to Supabase `workout_sessions` table payload.
  static Map<String, dynamic> workoutSessionToTable(
    WorkoutSession session, {
    String? userId,
  }) {
    return {
      'id': session.id,
      'user_id': userId ?? 'usr_local_01',
      'workout_id': session.workoutId,
      'workout_name': session.workoutName,
      'started_at': session.startTime.toIso8601String(),
      'completed_at': (session.endTime ?? DateTime.now()).toIso8601String(),
      'duration': session.duration.inSeconds,
      'duration_seconds': session.duration.inSeconds,
      'total_volume': session.totalVolume,
      'total_volume_kg': session.totalVolume,
      'calories_burned': session.caloriesBurned,
      'exercises_completed': session.completedExercises,
      'completion_percentage': session.completionPercentage,
      'notes': session.notes,
      'personal_records': session.personalRecords,
      'xp_earned': session.xpEarned,
      'exercises_data': session.exercises.map((e) => e.toJson()).toList(),
      'created_at': session.startTime.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  /// Map Supabase `workout_sessions` table payload to [WorkoutSession].
  static WorkoutSession tableToWorkoutSession(Map<String, dynamic> row) {
    return WorkoutSession.fromJson({
      'id': row['id'],
      'workoutId': row['workout_id'],
      'workoutName': row['workout_name'],
      'startTime':
          row['started_at'] ??
          row['start_time'] ??
          row['completed_at'] ??
          row['created_at'],
      'endTime': row['completed_at'],
      'exercises': row['exercises_data'] ?? [],
      'completedExercises': row['exercises_completed'] ?? 0,
      'totalVolume':
          (row['total_volume'] as num?)?.toDouble() ??
          (row['total_volume_kg'] as num?)?.toDouble() ??
          0.0,
      'caloriesBurned': (row['calories_burned'] as num?)?.toDouble() ?? 0.0,
      'durationSeconds':
          (row['duration_seconds'] as num?)?.toInt() ??
          (row['duration'] as num?)?.toInt() ??
          0,
      'notes': row['notes'],
      'personalRecords': row['personal_records'] ?? [],
      'xpEarned': (row['xp_earned'] as num?)?.toInt() ?? 0,
    });
  }

  /// Map [WorkoutHistory] to Supabase `workout_sessions` table payload.
  static Map<String, dynamic> workoutHistoryToTable(
    WorkoutHistory history, {
    String? userId,
  }) {
    return {
      'id': 'wh_${history.dateCompleted.millisecondsSinceEpoch}',
      'user_id': userId ?? 'usr_local_01',
      'workout_id':
          'w_${history.workoutName.toLowerCase().replaceAll(' ', '_')}',
      'workout_name': history.workoutName,
      'started_at': history.dateCompleted.toIso8601String(),
      'completed_at': history.dateCompleted.toIso8601String(),
      'duration': history.durationSeconds,
      'duration_seconds': history.durationSeconds,
      'exercises_completed': history.exercisesCompleted,
      'completion_percentage': history.completionPercentage,
      'total_volume': history.totalVolume,
      'total_volume_kg': history.totalVolume,
      'calories_burned': history.caloriesBurned,
      'created_at': history.dateCompleted.toIso8601String(),
    };
  }

  /// Map Supabase `workout_sessions` table payload to [WorkoutHistory].
  static WorkoutHistory tableToWorkoutHistory(Map<String, dynamic> row) {
    return WorkoutHistory(
      workoutName: row['workout_name'] as String? ?? 'Workout Session',
      dateCompleted: row['completed_at'] != null
          ? DateTime.parse(row['completed_at'] as String)
          : DateTime.now(),
      durationSeconds:
          (row['duration_seconds'] as num?)?.toInt() ??
          (row['duration'] as num?)?.toInt() ??
          0,
      exercisesCompleted: (row['exercises_completed'] as num?)?.toInt() ?? 0,
      completionPercentage:
          (row['completion_percentage'] as num?)?.toDouble() ?? 100.0,
      totalVolume:
          (row['total_volume'] as num?)?.toDouble() ??
          (row['total_volume_kg'] as num?)?.toDouble() ??
          0.0,
      caloriesBurned: (row['calories_burned'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Map individual set performance to Supabase `workout_sets` table payload.
  static Map<String, dynamic> workoutSetToTable({
    required String sessionId,
    required String exerciseId,
    required String exerciseName,
    required int setNumber,
    required double weight,
    required int reps,
    double rpe = 8.0,
    bool completed = true,
    bool isPr = false,
  }) {
    return {
      'session_id': sessionId,
      'exercise_id': exerciseId,
      'exercise_name': exerciseName,
      'set_number': setNumber,
      'weight': weight,
      'reps': reps,
      'rpe': rpe,
      'completed': completed,
      'is_pr': isPr,
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  /// Map [PersonalRecord] to Supabase `personal_records` table payload.
  static Map<String, dynamic> personalRecordToTable(
    PersonalRecord pr, {
    String? userId,
  }) {
    return {
      'id': pr.id.isNotEmpty ? pr.id : null,
      'user_id': userId ?? 'usr_local_01',
      'exercise_id':
          pr.exerciseId ?? pr.exerciseName.toLowerCase().replaceAll(' ', '_'),
      'exercise_name': pr.exerciseName,
      'record_type': pr.recordType,
      'value': pr.value,
      'reps': pr.recordType.toLowerCase().contains('rep')
          ? pr.value.toInt()
          : 1,
      'one_rep_max_kg': pr.value,
      'achieved_at': (pr.achievedDate ?? DateTime.now()).toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
    }..removeWhere((k, v) => v == null);
  }

  /// Map Supabase `personal_records` row to [PersonalRecord].
  static PersonalRecord tableToPersonalRecord(Map<String, dynamic> row) {
    return PersonalRecord(
      id: row['id']?.toString() ?? '',
      exerciseId: row['exercise_id']?.toString(),
      exerciseName: row['exercise_name']?.toString() ?? 'Exercise',
      recordType: row['record_type']?.toString() ?? 'Heaviest Lift',
      value: (row['value'] as num?)?.toDouble() ?? 0.0,
      achievedDate: row['achieved_at'] != null
          ? DateTime.tryParse(row['achieved_at'].toString())
          : null,
    );
  }

  // ------------------------------------------------------------
  // NUTRITION DOMAIN MAPPERS
  // ------------------------------------------------------------

  /// Map [FoodItem] to Supabase `foods` table payload.
  static Map<String, dynamic> foodItemToTable(
    FoodItem food, {
    String? creatorId,
  }) {
    return {
      'id': food.id,
      'name': food.name,
      'category': food.category,
      'calories': food.calories.round(),
      'protein': food.protein,
      'carbs': food.carbohydrates,
      'fat': food.fats,
      'source': food.isCustom ? 'user' : 'system',
      'serving_size': food.servingSize,
      'barcode': food.barcode,
      'creator_id': creatorId,
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  /// Map Supabase `foods` row to [FoodItem].
  static FoodItem tableToFoodItem(Map<String, dynamic> row) {
    return FoodItem(
      id: row['id']?.toString() ?? '',
      name: row['name']?.toString() ?? 'Food Item',
      category: row['category']?.toString() ?? 'General',
      calories: (row['calories'] as num?)?.toDouble() ?? 0.0,
      protein: (row['protein'] as num?)?.toDouble() ?? 0.0,
      carbohydrates: (row['carbs'] as num?)?.toDouble() ?? 0.0,
      fats: (row['fat'] as num?)?.toDouble() ?? 0.0,
      servingSize: row['serving_size']?.toString() ?? '100g',
      barcode: row['barcode']?.toString(),
      isCustom: row['source'] == 'user',
    );
  }

  /// Map [DailyNutrition] to Supabase `nutrition_logs` table payload.
  static Map<String, dynamic> dailyNutritionToTable(
    DailyNutrition nutrition, {
    String? userId,
  }) {
    return {
      'id': 'nut_${userId ?? 'usr_local_01'}_${nutrition.date}',
      'user_id': userId ?? 'usr_local_01',
      'date': nutrition.date,
      'log_date': nutrition.date,
      'total_calories': nutrition.totalCaloriesConsumed.round(),
      'total_protein': nutrition.totalProteinConsumed,
      'total_carbs': nutrition.totalCarbsConsumed,
      'total_fats': nutrition.totalFatConsumed,
      'water_liters': nutrition.waterLiters,
      'meals': nutrition.meals.map((m) => m.toJson()).toList(),
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  /// Map individual meal entry to Supabase `meal_entries` table payload.
  static Map<String, dynamic> mealEntryToTable({
    required String nutritionLogId,
    required ConsumedFood food,
    required String mealCategory,
    String source = 'manual',
    DateTime? loggedAt,
  }) {
    return {
      'nutrition_log_id': nutritionLogId,
      'meal_type': mealCategory,
      'food_id': food.food.id,
      'food_name': food.food.name,
      'meal_category': mealCategory,
      'quantity': food.quantity,
      'serving_size': '${food.quantity}${food.unit}',
      'calories': food.calories.round(),
      'protein': food.protein,
      'carbs': food.carbohydrates,
      'fat': food.fats,
      'source': source,
      'logged_at': (loggedAt ?? DateTime.now()).toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  /// Map Workout Exercise to Supabase `workout_exercises` table payload.
  static Map<String, dynamic> workoutExerciseToTable({
    required String sessionId,
    required String exerciseName,
    String? muscleGroup,
    List<Map<String, dynamic>> sets = const [],
    double volume = 0.0,
    double maxWeight = 0.0,
  }) {
    return {
      'session_id': sessionId,
      'exercise_name': exerciseName,
      'muscle_group': muscleGroup,
      'sets': sets,
      'volume': volume,
      'max_weight': maxWeight,
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  // ------------------------------------------------------------
  // AI DOMAIN MAPPERS
  // ------------------------------------------------------------

  /// Map AI Memory to Supabase `ai_memory` table payload.
  static Map<String, dynamic> aiMemoryToTable(AIMemoryEntry memory) {
    return {
      'id': memory.id.isNotEmpty ? memory.id : null,
      'user_id': memory.userId,
      'memory_type': memory.memoryType,
      'memory_value': memory.memoryValue,
      'confidence': memory.confidence,
      if (memory.conversation != null) 'conversation': memory.conversation,
      if (memory.fitnessContext != null)
        'fitness_context': memory.fitnessContext,
      if (memory.preferences != null) 'preferences': memory.preferences,
      'created_at': memory.createdAt.toIso8601String(),
      'updated_at': memory.updatedAt.toIso8601String(),
    }..removeWhere((k, v) => v == null);
  }

  /// Map Supabase `ai_memory` row to [AIMemoryEntry].
  static AIMemoryEntry tableToAiMemory(Map<String, dynamic> row) {
    return AIMemoryEntry.fromJson(row);
  }

  /// Map [CoachMessage] to Supabase `ai_conversations` table payload.
  static Map<String, dynamic> aiConversationToTable(
    CoachMessage message, {
    String? userId,
    String sessionId = 'default_coach_session',
  }) {
    return {
      'id': message.id.isNotEmpty ? message.id : null,
      'user_id': userId ?? 'usr_local_01',
      'session_id': sessionId,
      'role': message.role.name,
      'content': message.content,
      'context_snapshot': message.contextSnapshot ?? {},
      'created_at': message.timestamp.toIso8601String(),
    }..removeWhere((k, v) => v == null);
  }

  /// Map [AIFeedbackEntry] to Supabase `ai_feedback` table payload.
  static Map<String, dynamic> aiFeedbackToTable(AIFeedbackEntry feedback) {
    return {
      'id': feedback.id.isNotEmpty ? feedback.id : null,
      'user_id': feedback.userId,
      'recommendation': feedback.recommendation,
      'feedback': feedback.feedback,
      'rating': feedback.rating,
      'created_at': feedback.createdAt.toIso8601String(),
    }..removeWhere((k, v) => v == null);
  }

  // ------------------------------------------------------------
  // HEALTH & RECOVERY DOMAIN MAPPERS
  // ------------------------------------------------------------

  /// Map [HealthMetric] to Supabase `health_metrics` table payload.
  static Map<String, dynamic> healthMetricToTable(
    HealthMetric metric, {
    String? userId,
  }) {
    final dateStr =
        '${metric.timestamp.year}-${metric.timestamp.month.toString().padLeft(2, '0')}-${metric.timestamp.day.toString().padLeft(2, '0')}';
    return {
      'id': 'hm_${userId ?? 'usr_local_01'}_$dateStr',
      'user_id': userId ?? 'usr_local_01',
      'date': dateStr,
      'metric_date': dateStr,
      'steps': metric.steps,
      'distance_km': metric.distanceKm,
      'active_calories': metric.activeCalories,
      'heart_rate': metric.heartRate,
      'sleep_hours': metric.sleepMinutes != null && metric.sleepMinutes! > 0
          ? (metric.sleepMinutes! / 60.0)
          : null,
      'sleep_minutes': metric.sleepMinutes,
      'deep_sleep_minutes': metric.deepSleepMinutes,
      'resting_heart_rate': metric.restingHeartRate,
      'created_at': metric.timestamp.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  /// Map Recovery score to Supabase `recovery_scores` table payload.
  static Map<String, dynamic> recoveryScoreToTable({
    required String userId,
    required DateTime date,
    required int score,
    Map<String, dynamic> factors = const {},
    double sleepPillar = 0.0,
    double trainingPillar = 0.0,
    double movementPillar = 0.0,
    double restPillar = 0.0,
    String readinessState = 'optimal',
  }) {
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return {
      'user_id': userId,
      'date': dateStr,
      'score_date': dateStr,
      'score': score,
      'recovery_score': score,
      'factors': factors,
      'sleep_pillar': sleepPillar,
      'training_pillar': trainingPillar,
      'movement_pillar': movementPillar,
      'rest_pillar': restPillar,
      'readiness_state': readinessState,
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  // ------------------------------------------------------------
  // SOCIAL & ANALYTICS DOMAIN MAPPERS
  // ------------------------------------------------------------

  /// Map [ActivityPost] to Supabase `community_posts` table payload.
  static Map<String, dynamic> activityPostToTable(
    ActivityPost post, {
    String? userId,
  }) {
    return {
      'id': post.id,
      'user_id': userId ?? post.userId,
      'author_name': post.userName,
      'author_avatar': post.userAvatar,
      'author_rank': post.userRank,
      'post_type': post.type.name,
      'content': post.title,
      'caption': post.title,
      'media_url': post.images.isNotEmpty ? post.images.first : null,
      'metrics_payload': post.metadata ?? {},
      'likes_count': post.likes,
      'comments_count': post.comments,
      'created_at': post.createdAt.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  /// Map [AnalyticsEventData] to Supabase `analytics_events` table payload.
  static Map<String, dynamic> analyticsEventToTable(AnalyticsEventData event) {
    return {
      'id': event.id.isNotEmpty ? event.id : null,
      'user_id': event.userId,
      'event_name': event.eventName,
      'properties': event.properties,
      'session_id': event.sessionId,
      'client_timestamp': event.clientTimestamp.toIso8601String(),
      'created_at': event.createdAt.toIso8601String(),
    }..removeWhere((k, v) => v == null);
  }

  /// Map [UserBehaviorEventData] to Supabase `user_behavior_events` table payload.
  static Map<String, dynamic> userBehaviorEventToTable(
    UserBehaviorEventData event,
  ) {
    return {
      'id': event.id.isNotEmpty ? event.id : null,
      'user_id': event.userId,
      'domain': event.domain,
      'event_type': event.eventType,
      'payload': event.payload,
      'timestamp': event.timestamp.toIso8601String(),
    }..removeWhere((k, v) => v == null);
  }

  /// Map [ModelPredictionData] to Supabase `model_predictions` table payload.
  static Map<String, dynamic> modelPredictionToTable(
    ModelPredictionData prediction,
  ) {
    return {
      'id': prediction.id.isNotEmpty ? prediction.id : null,
      'user_id': prediction.userId,
      'model_name': prediction.modelName,
      'prediction_output': prediction.predictionOutput,
      'confidence_score': prediction.confidenceScore,
      'created_at': prediction.createdAt.toIso8601String(),
    }..removeWhere((k, v) => v == null);
  }

  /// Map [PersonalizationProfileData] to Supabase `personalization_profiles` table payload.
  static Map<String, dynamic> personalizationProfileToTable(
    PersonalizationProfileData profile,
  ) {
    return {
      'user_id': profile.userId,
      'feature_vector': profile.featureVector,
      'preferred_training_time': profile.preferredTrainingTime,
      'churn_risk': profile.churnRisk,
      'discovered_insights': profile.discoveredInsights,
      'updated_at': profile.updatedAt.toIso8601String(),
    };
  }

  /// Map [MLTrainingEventData] to Supabase `ml_training_events` table payload.
  static Map<String, dynamic> mlTrainingEventToTable(
    MLTrainingEventData event,
  ) {
    return {
      'id': event.id.isNotEmpty ? event.id : null,
      'user_id': event.anonymizedUserId,
      'domain': event.domain,
      'event_type': event.eventType,
      'feature_payload': event.featurePayload,
      'is_anonymized': event.isAnonymized,
      'consent_verified': event.consentVerified,
      'created_at': event.timestamp.toIso8601String(),
    }..removeWhere((k, v) => v == null);
  }

  /// Map [DigitalAthleteProfileData] to Supabase `digital_athlete_profiles` table payload.
  static Map<String, dynamic> digitalAthleteProfileToTable(
    DigitalAthleteProfileData profile,
  ) {
    return {
      'user_id': profile.userId,
      'physical_profile': profile.physicalProfile,
      'strength_profile': profile.strengthProfile,
      'training_profile': profile.trainingProfile,
      'recovery_profile': profile.recoveryProfile,
      'nutrition_profile': profile.nutritionProfile,
      'behavior_profile': profile.behaviorProfile,
      'goal_profile': profile.goalProfile,
      'biomechanics_weaknesses': profile.biomechanicsWeaknesses,
      'form_score_averages': profile.formScoreAverages,
      'updated_at': profile.updatedAt.toIso8601String(),
    };
  }

  /// Map [AthleteInsightData] to Supabase `athlete_insights` table payload.
  static Map<String, dynamic> athleteInsightToTable(
    AthleteInsightData insight,
  ) {
    return {
      'id': insight.id.isNotEmpty ? insight.id : null,
      'user_id': insight.userId,
      'category': insight.category,
      'title': insight.title,
      'description': insight.description,
      'recommendation': insight.recommendation,
      'significance_score': insight.significanceScore,
      'created_at': insight.createdAt.toIso8601String(),
    }..removeWhere((k, v) => v == null);
  }

  /// Map [PredictionResultData] to Supabase `prediction_results` table payload.
  static Map<String, dynamic> predictionResultToTable(
    PredictionResultData result,
  ) {
    return {
      'id': result.id.isNotEmpty ? result.id : null,
      'user_id': result.userId,
      'prediction_type': result.predictionType,
      'prediction_payload': result.predictionPayload,
      'confidence_score': result.confidenceScore,
      'created_at': result.createdAt.toIso8601String(),
    }..removeWhere((k, v) => v == null);
  }

  /// Map [BetaFeedbackData] to Supabase `beta_feedbacks` table payload.
  static Map<String, dynamic> betaFeedbackToTable(BetaFeedbackData feedback) {
    return {
      'id': feedback.id.isNotEmpty ? feedback.id : null,
      'user_id': feedback.userId,
      'feedback': feedback.feedback,
      'category': feedback.category,
      'priority': feedback.priority,
      'device_info': feedback.deviceInfo,
      'timestamp': feedback.timestamp.toIso8601String(),
    }..removeWhere((k, v) => v == null);
  }
}
