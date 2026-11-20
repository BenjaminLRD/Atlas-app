import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/models/fitness_context.dart';
import 'package:atlas/models/nutrition_summary.dart';
import 'package:atlas/models/progress_summary.dart';
import 'package:atlas/models/user_progress.dart';
import 'package:atlas/models/nutrition_progress.dart';
import 'package:atlas/models/user_profile.dart';
import 'package:atlas/models/workout_history.dart';
import 'package:atlas/models/workout_session.dart';
import 'package:atlas/services/ai/coach_prompt_builder.dart';

void main() {
  group('Workout & AI Coach Integration Tests', () {
    test(
      'WorkoutSession and WorkoutHistory store form scores and AI corrections',
      () {
        final session = WorkoutSession(
          id: 'ws_vision_01',
          workoutId: 'w_squat_mastery',
          workoutName: 'Squat Mastery',
          startTime: DateTime.now().subtract(const Duration(minutes: 40)),
          endTime: DateTime.now(),
          completedExercises: 1,
          totalVolume: 3200.0,
          caloriesBurned: 240.0,
          duration: const Duration(minutes: 40),
          formScore: 88.0,
          averageTechniqueScore: 88.0,
          aiCorrections: const ['Keep knees outward.'],
          exercises: const [
            WorkoutSessionExercise(
              id: 'ex_squat',
              name: 'Barbell Squat',
              muscleGroup: 'Legs',
              sets: [
                WorkoutSessionSet(
                  setNumber: 1,
                  weight: 100.0,
                  reps: 8,
                  completed: true,
                ),
              ],
            ),
          ],
        );

        final history = session.toWorkoutHistory();
        expect(history.formScore, 88.0);
        expect(history.aiCorrections, contains('Keep knees outward.'));

        final json = history.toJson();
        expect(json['formScore'], 88.0);
        expect(json['aiCorrections'], contains('Keep knees outward.'));
      },
    );

    test(
      'CoachPromptBuilder embeds [FORM ANALYSIS CONTEXT] into AI prompts',
      () {
        const builder = CoachPromptBuilder();

        final context = FitnessContext(
          userProfile: UserProfile.defaultProfile(),
          workoutHistory: [
            WorkoutHistory(
              workoutName: 'Barbell Squat Session',
              dateCompleted: DateTime.now(),
              durationSeconds: 1800,
              exercisesCompleted: 3,
              completionPercentage: 100.0,
              formScore: 82.0,
              aiCorrections: const ['Knee collapse during heavy ascent'],
            ),
          ],
          nutritionSummary: NutritionSummary.empty(),
          progressSummary: ProgressSummary.zero(),
          userProgress: UserProgress.initial(),
          nutritionProgress: NutritionProgress.initial(),
          generatedAt: DateTime.now(),
        );

        final prompt = builder.buildPrompt(
          message: 'How is my squat technique?',
          context: context,
        );

        expect(prompt, contains('[FORM ANALYSIS CONTEXT]'));
        expect(prompt, contains('Recent Squat analysis:'));
        expect(prompt, contains('Average form: 82%'));
        expect(
          prompt,
          contains('Common issue: Knee collapse during heavy ascent'),
        );
        expect(prompt, contains('AI recommendation:'));
      },
    );
  });
}
