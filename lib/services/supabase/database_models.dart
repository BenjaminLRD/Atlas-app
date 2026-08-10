import '../../models/user_profile.dart';
import '../../models/user_goal.dart';
import '../../models/workout_history.dart';

/// Database table mapping definitions for Supabase tables:
/// - profiles
/// - user_goals
/// - workout_sessions
/// - workout_exercises
class SupabaseTableNames {
  static const String profiles = 'profiles';
  static const String userGoals = 'user_goals';
  static const String workoutSessions = 'workout_sessions';
  static const String workoutExercises = 'workout_exercises';
}

/// Mapper between domain models and Supabase database row maps.
class SupabaseModelMappers {
  /// Map [UserProfile] to Supabase `profiles` table payload.
  static Map<String, dynamic> userProfileToTable(UserProfile profile, {String? userId}) {
    return {
      'id': userId ?? 'usr_local_01',
      'full_name': profile.name,
      'email': profile.email,
      'height': profile.height,
      'weight': profile.weight,
      'fitness_goal': profile.fitnessGoal,
      'workout_experience': profile.workoutExperience,
      'profile_pic': profile.profilePic,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  /// Map Supabase `profiles` table payload to [UserProfile].
  static UserProfile tableToUserProfile(Map<String, dynamic> row) {
    final base = UserProfile.defaultProfile();
    if (row['full_name'] != null) base.name = row['full_name'] as String;
    if (row['email'] != null) base.email = row['email'] as String;
    if (row['height'] != null) base.height = row['height'].toString();
    if (row['weight'] != null) base.weight = row['weight'].toString();
    if (row['fitness_goal'] != null) {
      base.fitnessGoal = row['fitness_goal'] as String;
    }
    if (row['workout_experience'] != null) {
      base.workoutExperience = row['workout_experience'] as String;
    }
    if (row['profile_pic'] != null) {
      base.profilePic = row['profile_pic'] as String;
    }
    return base;
  }

  /// Map [UserGoal] to Supabase `user_goals` table payload.
  static Map<String, dynamic> userGoalToTable(UserGoal goal, {String? userId}) {
    return {
      'id': goal.id,
      'user_id': userId ?? 'usr_local_01',
      'goal_type': goal.goalType.name,
      'fitness_level': goal.fitnessLevel.name,
      'activity_level': goal.activityLevel.name,
      'age': goal.age,
      'height': goal.height,
      'current_weight': goal.currentWeight,
      'target_weight': goal.targetWeight,
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
    return UserGoal.fromJson({
      'id': row['id'] ?? 'default_goal',
      'goalType': row['goal_type'],
      'fitnessLevel': row['fitness_level'],
      'activityLevel': row['activity_level'],
      'age': row['age'],
      'height': row['height'],
      'currentWeight': row['current_weight'],
      'targetWeight': row['target_weight'],
      'targetCalories': row['target_calories'],
      'targetProtein': row['target_protein'],
      'targetCarbohydrates': row['target_carbohydrates'],
      'targetFats': row['target_fats'],
      'createdDate': row['created_at'],
      'updatedDate': row['updated_at'],
    });
  }

  /// Map [WorkoutHistory] to Supabase `workout_sessions` table payload.
  static Map<String, dynamic> workoutHistoryToTable(WorkoutHistory history, {String? userId}) {
    return {
      'id': 'wh_${history.dateCompleted.millisecondsSinceEpoch}',
      'user_id': userId ?? 'usr_local_01',
      'workout_name': history.workoutName,
      'completed_at': history.dateCompleted.toIso8601String(),
      'duration_seconds': history.durationSeconds,
      'exercises_completed': history.exercisesCompleted,
      'completion_percentage': history.completionPercentage,
      'total_volume': history.totalVolume,
      'calories_burned': history.caloriesBurned,
    };
  }

  /// Map Supabase `workout_sessions` table payload to [WorkoutHistory].
  static WorkoutHistory tableToWorkoutHistory(Map<String, dynamic> row) {
    return WorkoutHistory(
      workoutName: row['workout_name'] as String? ?? 'Workout Session',
      dateCompleted: row['completed_at'] != null
          ? DateTime.parse(row['completed_at'] as String)
          : DateTime.now(),
      durationSeconds: (row['duration_seconds'] as num?)?.toInt() ?? 0,
      exercisesCompleted: (row['exercises_completed'] as num?)?.toInt() ?? 0,
      completionPercentage:
          (row['completion_percentage'] as num?)?.toDouble() ?? 100.0,
      totalVolume: (row['total_volume'] as num?)?.toDouble() ?? 0.0,
      caloriesBurned: (row['calories_burned'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
