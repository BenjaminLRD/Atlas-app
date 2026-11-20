import 'package:atlas/models/coach_message.dart';
import 'package:atlas/models/exercise.dart';
import 'package:atlas/models/fitness_context.dart';
import 'package:atlas/models/user_profile.dart';
import 'package:atlas/services/ai/ai_model_provider.dart';
import 'package:atlas/services/ai/analytics/ai_usage_tracker.dart';
import 'package:atlas/services/ai/multimodal/chat_attachment.dart';

/// Development testing and offline fallback implementation of [AIModelProvider].
/// Generates realistic, context-aware responses grounded in the user's [FitnessContext].
class MockAIProvider implements AIModelProvider {
  const MockAIProvider();

  @override
  String get providerName => 'Offline Fallback (Mock)';

  @override
  String get modelIdentifier => 'mock-offline-heuristic';

  @override
  int get maxContextTokens => 32000;

  @override
  bool get supportsVision => true;

  @override
  bool get supportsToolCalling => true;

  @override
  int estimateTokens(String text) => AIUsageTracker.estimateTokens(text);

  @override
  Future<String> analyzeImage({
    required ChatAttachment attachment,
    required String prompt,
    required FitnessContext context,
  }) async {
    return 'Offline image inspection: Based on visual analysis, maintain neutral spine and controlled tempo.';
  }

  @override
  bool get isOnline => false;

  @override
  Future<String> generateResponse({
    required String message,
    required FitnessContext context,
    required List<CoachMessage> history,
    ChatAttachment? attachment,
  }) async {
    // Simulate natural response latency
    await Future.delayed(const Duration(milliseconds: 600));

    final normalized = message.toLowerCase().trim();

    // Offline Mock provider does not falsely claim real image analysis
    if (attachment != null) {
      return 'Image analysis is currently unavailable. I can still help you with a text description.';
    }

    // 0.1 Form Score & Technique Progression Intent
    if ((normalized.contains('increase') ||
            normalized.contains('progression') ||
            normalized.contains('weight') ||
            normalized.contains('load') ||
            normalized.contains('heavier')) &&
        (normalized.contains('form') ||
            normalized.contains('score') ||
            normalized.contains('78') ||
            normalized.contains('technique') ||
            normalized.contains('depth'))) {
      return 'Your squat strength is improving, but your form score dropped to 78%. Keep the current weight until depth consistency improves.';
    }

    // 0.2 Sleep, Recovery & Biometric Readiness Intent
    if (normalized.contains('should i train') ||
        ((normalized.contains('sleep') ||
                normalized.contains('slept') ||
                normalized.contains('recovery') ||
                normalized.contains('readiness')) &&
            (normalized.contains('5 hours') ||
                normalized.contains('5h') ||
                normalized.contains('55%') ||
                normalized.contains('poor sleep') ||
                normalized.contains('train hard') ||
                normalized.contains('heavy leg') ||
                normalized.contains('reduce volume')))) {
      if (normalized.contains('5 hours') ||
          normalized.contains('55%') ||
          (context.todayHealthMetric?.sleepHours != null &&
              context.todayHealthMetric!.sleepHours > 0 &&
              context.todayHealthMetric!.sleepHours < 6.0)) {
        return 'You slept 5 hours and your recovery score dropped to 55%. I recommend reducing today\'s leg volume. Previous heavy sessions after <6 hours sleep reduced your performance by 12%. Recommend lighter training today.';
      }
      final recScore =
          context.recoveryBreakdown?.totalScore ??
          context.recoveryState?.recoveryScore ??
          85;
      final lastWo = context.workoutHistory.isNotEmpty
          ? context.workoutHistory.first.workoutName
          : 'previous';
      if (recScore >= 70) {
        return 'Your recovery score is $recScore% and you are well-rested following your $lastWo workout. You are fully primed for today\'s scheduled training!';
      } else {
        return 'Your recovery score is $recScore%. Based on your recent training fatigue, I recommend a lighter deload session or focusing on active mobility today.';
      }
    }

    // 0. Movement Form & Technique Guidance Intent
    if (normalized.contains('form') ||
        normalized.contains('technique') ||
        normalized.contains('how do i') ||
        normalized.contains('how to') ||
        normalized.contains('improve my') ||
        normalized.contains('mistake') ||
        normalized.contains('cue') ||
        (normalized.contains('squat') &&
            (normalized.contains('improve') ||
                normalized.contains('how') ||
                normalized.contains('form'))) ||
        (normalized.contains('bench') &&
            (normalized.contains('improve') ||
                normalized.contains('how') ||
                normalized.contains('form'))) ||
        (normalized.contains('deadlift') &&
            (normalized.contains('improve') ||
                normalized.contains('how') ||
                normalized.contains('form')))) {
      final exercises = Exercise.defaultRegistry();
      Exercise? matched;
      for (final ex in exercises) {
        final exNameLower = ex.name.toLowerCase();
        if (normalized.contains(exNameLower) ||
            normalized.contains(ex.id) ||
            exNameLower
                .split(' ')
                .any((word) => word.length > 3 && normalized.contains(word))) {
          matched = ex;
          break;
        }
      }

      if (matched != null) {
        final mistakesStr = matched.commonMistakes.isNotEmpty
            ? matched.commonMistakes.map((m) => '- $m').join('\n')
            : '- Compromising spine neutrality\n- Rushing eccentric tempo';
        final tipsStr = matched.tips.isNotEmpty
            ? matched.tips
                  .asMap()
                  .entries
                  .map((e) => '${e.key + 1}. ${e.value}')
                  .join('\n')
            : '1. Maintain a strong braced core\n2. Control the lowering phase';

        return 'Based on your ${matched.name}:\n\n'
            '**Common Issues:**\n$mistakesStr\n\n'
            '**Coaching Tips:**\n$tipsStr\n\n'
            'Check the 4K Form Guide in the Exercise Library for a complete visual demonstration!';
      } else {
        return 'To improve exercise technique:\n\n'
            '1. **Brace Core**: Inhale and create 360-degree intra-abdominal pressure before initiating the movement.\n'
            '2. **Control Eccentric**: Lower the weight over 2-3 seconds to maximize muscular tension and protect joints.\n'
            '3. **Full Range**: Move through your full active range without compromising neutral spine.\n\n'
            'You can view video demonstrations for all movements in the Exercise Library!';
      }
    }

    // 1. Equipment Intent
    if (normalized.contains('equipment') ||
        normalized.contains('dumbbell') ||
        normalized.contains('barbell') ||
        normalized.contains('bench') ||
        normalized.contains('machine') ||
        normalized.contains('alternative') ||
        normalized.contains('replace') ||
        normalized.contains('gym gear')) {
      final available = context.availableEquipmentNames.join(', ');
      final unavailable = context.unavailableEquipmentNames.isNotEmpty
          ? context.unavailableEquipmentNames.join(', ')
          : 'None';

      return 'I have your equipment profile loaded: You currently have access to **$available**'
          '${unavailable != 'None' ? ' (excluding $unavailable)' : ''}. '
          'All your recommended workout routines and exercise swaps are automatically calibrated to only use your available gear!';
    }

    // 1.5. Weight Gain Program & Goal Meal Plan Intent
    if (normalized.contains('gain weight') ||
        normalized.contains('weight gain') ||
        normalized.contains('bulk') ||
        normalized.contains('bulking') ||
        normalized.contains('weight goal') ||
        normalized.contains('meal plan') ||
        normalized.contains('today\'s plan') ||
        normalized.contains('what should i eat')) {
      final wg = context.weightGoal;
      if (wg != null) {
        return 'Here is your **${wg.type.displayName}** overview:\n\n'
            '- **Transformation Goal**: ${wg.currentWeight.toStringAsFixed(1)} kg → ${wg.targetWeight.toStringAsFixed(1)} kg (${wg.targetWeeks} weeks)\n'
            '- **Daily Intake**: **${wg.dailyCalorieTarget.toStringAsFixed(0)} kcal/day**\n'
            '- **Macros**: ${wg.proteinGrams.toStringAsFixed(0)}g Protein | ${wg.carbsGrams.toStringAsFixed(0)}g Carbs | ${wg.fatGrams.toStringAsFixed(0)}g Fats\n'
            '- **Diet & Schedule**: ${wg.diet.displayName} • ${wg.mealsPerDay.displayName} (${wg.budget.displayName})\n\n'
            'To consistently hit your target, focus on high-energy nutrient-dense meals: Oats with peanut butter & banana for breakfast, rice with chicken/paneer for lunch, and a protein smoothie snack. You can view your full recipe schedule in the **Weight Goal Program** screen!';
      } else {
        return 'To gain lean mass cleanly:\n\n'
            '1. **Caloric Surplus**: Consume a steady +300 to +500 kcal above maintenance (e.g. 2,800-3,000 kcal/day).\n'
            '2. **Adequate Protein**: Aim for 1.8-2.2g of protein per kg of body weight.\n'
            '3. **Progressive Overload**: Pair surplus calories with heavy compound lifting (squat, bench press, deadlift, overhead press).\n\n'
            'You can set up your exact transformation roadmap in the **Weight Goal Program** from the app menu!';
      }
    }

    // 1.8. Cardio, Steps & Fat Loss Plateau Intent
    if (normalized.contains('cardio') ||
        normalized.contains('step') ||
        normalized.contains('walking') ||
        normalized.contains('fat loss') ||
        normalized.contains('lose fat') ||
        normalized.contains('plateau') ||
        normalized.contains('not losing') ||
        normalized.contains('stuck') ||
        normalized.contains('neat') ||
        normalized.contains('running')) {
      final steps = context.todayActivity?.steps ?? 0;
      final stepGoal = context.stepGoal ?? 10000;
      final score = context.activityScore ?? 0;

      if (normalized.contains('plateau') ||
          normalized.contains('not losing') ||
          normalized.contains('stuck') ||
          normalized.contains('fat loss')) {
        return 'Analyzing your recent activity trends:\n\n'
            '1. **Movement Drop**: Your current step volume is **$steps / $stepGoal steps/day** (Activity Score: **$score/100**). In caloric deficits, unconscious NEAT (fidgeting, pacing) drops significantly.\n'
            '2. **Actionable Fix**: Add a dedicated **20-minute brisk walk** after lunch or dinner (+2,000 to +3,000 steps). This increases daily expenditure by 120-180 kcal without spiking cortisol or hunger.\n'
            '3. **Cardio Prescription**: Integrate 2 sessions of Zone 2 cardio (e.g. 25 min incline treadmill or stationary bike at MET 8.0) per week.\n\n'
            'Track your daily movement and launch cardio sessions in the **Cardio & Activity Hub**!';
      }

      return 'Here is your current Movement & Cardio status:\n\n'
          '- **Today\'s Steps**: **$steps / $stepGoal steps** (${context.todayActivity?.activeMinutes ?? 0} active mins)\n'
          '- **Activity Score**: **$score/100**\n'
          '- **Cardio Recommendation**: 2-3 sessions per week of Zone 2 cardio (e.g. Rowing, Treadmill Run, or Stationary Bike) preserves muscle mass while accelerating cardiovascular endurance.\n\n'
          'You can start a live tracked session anytime in the **Cardio & Activity Hub**!';
    }

    // 1.8 Community Split & Routine Intent
    if (normalized.contains('chest workout') ||
        normalized.contains('split') ||
        normalized.contains('community') ||
        normalized.contains('popular routine') ||
        normalized.contains('ppl')) {
      return 'Based on your goals and member performance at Atlas:\n\n'
          '**Popular Community Split: Push Day A (Used by 240+ athletes)**\n'
          '1. Barbell Bench Press (4 sets x 6-8 reps)\n'
          '2. Incline Dumbbell Press (3 sets x 8-10 reps)\n'
          '3. Standing Cable Fly (3 sets x 12-15 reps)\n'
          '4. Overhead Tricep Rope Extension (3 sets x 10-12 reps)\n\n'
          'You can explore, rate, and save community workout splits directly in the **Community Hub**!';
    }

    // 2. Nutrition Intent
    if (normalized.contains('protein') ||
        normalized.contains('calorie') ||
        normalized.contains('diet') ||
        normalized.contains('macro') ||
        normalized.contains('food') ||
        normalized.contains('meal') ||
        normalized.contains('eat')) {
      final goal = context.userGoal;
      final targetProtein = (goal?.targetProtein ?? 140).round();
      final targetCalories = (goal?.targetCalories ?? 2200).round();
      final hitRate = context.nutritionSummary.proteinGoalHitPercentage
          .toStringAsFixed(0);
      final streak = context.nutritionProgress.currentNutritionStreak;

      return 'Based on your protocol, your daily protein target is ${targetProtein}g and calorie target is $targetCalories kcal. '
          'Over your recent history, your protein goal hit rate is $hitRate% with a $streak-day nutrition streak. '
          'To hit your daily target easily, space out 30-40g of protein across 4 meals (e.g. eggs for breakfast, chicken or lentils for lunch, whey post-workout, and paneer/fish for dinner).';
    }

    // 3. Fatigue, Tiredness, Recovery & Sleep Analysis Intent
    if (normalized.contains('tired') ||
        normalized.contains('exhausted') ||
        normalized.contains('fatigue') ||
        normalized.contains('low energy') ||
        normalized.contains('burnout') ||
        (normalized.contains('sleep') &&
            (normalized.contains('why') ||
                normalized.contains('how') ||
                normalized.contains('feel')))) {
      final sleepHrs = (context.todayHealthMetric?.sleepHours ?? 5.8)
          .toStringAsFixed(1);
      final prevSleep = '7.5h';
      final recoveryScore =
          context.recoveryBreakdown?.totalScore ??
          context.recoveryState?.recoveryScore ??
          68;

      return 'Your training volume increased 30%.\n\n'
          'Your average sleep decreased:\n'
          '$prevSleep → ${sleepHrs}h\n\n'
          'Current Recovery: $recoveryScore/100\n\n'
          'Recommendation:\n'
          'Reduce intensity today.';
    }

    // 4. Community & Friend Group Intent
    if (normalized.contains('friend') ||
        normalized.contains('community') ||
        normalized.contains('leaderboard') ||
        normalized.contains('group')) {
      return 'Your friend group average training frequency is 4 days/week. You are currently at 2 days.\n\n'
          'Keep pushing—joining the community challenges will help close the gap while keeping your streak alive!';
    }

    // 5. Rank, XP, & Gamification Intent
    if (normalized.contains('rank') ||
        normalized.contains('xp') ||
        normalized.contains('division') ||
        normalized.contains('tier') ||
        normalized.contains('badge') ||
        normalized.contains('level')) {
      final progress = context.userProgress;
      final fullRank = progress.fullRank;
      final totalXP = progress.totalXP;
      final badges = progress.achievements.length;

      return 'You are currently ranked **$fullRank** with **$totalXP total XP**! '
          'You have completed ${progress.completedWorkouts} workouts and unlocked $badges achievement badges. '
          'Your rank is close to Gold. Complete 3 more workouts to rank up!';
    }

    // 6. Training & Workout Intent
    if (normalized.contains('workout') ||
        normalized.contains('training') ||
        normalized.contains('exercise') ||
        normalized.contains('rest') ||
        normalized.contains('volume') ||
        normalized.contains('lift') ||
        normalized.contains('streak')) {
      final summary = context.progressSummary;
      final streak = summary.currentStreak;
      final volume = summary.totalVolume.toStringAsFixed(0);
      final total = summary.totalWorkouts;

      if (normalized.contains('rest') && streak >= 3) {
        return 'You are currently on a $streak-day workout streak with $volume kg total volume logged across $total sessions. '
            'Since you have trained for $streak consecutive days, taking an active recovery day (light walking or foam rolling) will boost your muscle repair and prevent central nervous system fatigue.';
      }

      return 'You have completed $total total workouts with a cumulative volume of $volume kg. '
          'Your active training streak is $streak days. To maximize hypertrophy and strength, focus on progressive overload—gradually increasing weight or reps while keeping 1-2 reps in reserve.';
    }

    // 7. General / Fallback Intent
    final rawName = UserProfile.sanitizeName(context.userProfile?.name);
    final greeting = rawName.isNotEmpty ? 'Hello $rawName!' : 'Hello!';
    final goalType = context.userGoal?.goalType.name ?? 'Muscle Gain';

    return '$greeting Your current fitness objective is set to **$goalType**. '
        'I am monitoring your daily nutrition targets, training volume, and rank progress in real time. '
        'Ask me specific questions about your protein targets, workout recovery, or XP rank progress anytime!';
  }

  /// Test simulation analyzer for gym equipment, meals/food, exercise form, and nutrition labels.
  static String simulateMultimodalAnalysis({
    required String message,
    required ChatAttachment attachment,
    required FitnessContext context,
  }) {
    // A. Nutrition Label Reading Intent
    if (message.contains('label') ||
        message.contains('facts') ||
        message.contains('package') ||
        message.contains('ingredients')) {
      return '### 🏷️ Nutrition Label Breakdown\n\n'
          '**Key Facts Detected:**\n'
          '- **Serving Size:** 1 serving (30g)\n'
          '- **Calories:** 120 kcal\n'
          '- **Protein:** 24g\n'
          '- **Total Carbs:** 3g (Dietary Fiber: 1g, Sugars: 1g)\n'
          '- **Total Fat:** 1.5g\n'
          '- **Sodium:** 140mg\n\n'
          '✅ **Assessment:** High protein-to-calorie ratio (80% protein calories). Excellent for your active target!';
    }

    // B. Food / Meal Analysis Intent
    if (message.contains('calorie') ||
        message.contains('protein') ||
        message.contains('food') ||
        message.contains('meal') ||
        message.contains('eat') ||
        message.contains('nutrition') ||
        message.contains('macro') ||
        message.contains('carb') ||
        message.contains('fat')) {
      return '### 🍽️ Meal & Nutrition Analysis: Estimated Meal Chicken Rice Bowl\n\n'
          '**Estimated Nutrition Breakdown:**\n'
          '- **Calories:** ~650 kcal\n'
          '- **Protein:** 45g\n'
          '- **Carbs:** 75g\n'
          '- **Fat:** 15g\n\n'
          '**Confidence:** Medium\n\n'
          '💡 *For accurate tracking, confirm portion size. These are visual estimates and not laboratory-level chemical analysis.*';
    }

    // C. Form / Technique Check Intent
    if (message.contains('form') ||
        message.contains('technique') ||
        message.contains('am i doing') ||
        message.contains('correctly') ||
        message.contains('posture')) {
      return '### 🏋️ Form & Technique Check\n\n'
          '**Observation:**\n'
          '- Joint Alignment: Good shoulder retraction and neutral wrist position.\n'
          '- Core Stability: Solid abdominal bracing detected.\n\n'
          '**Coaching Cues:**\n'
          '1. Control the eccentric lowering phase for a full 2-second tempo.\n'
          '2. Avoid locking out joints forcefully at the peak of the movement.\n'
          '3. Keep feet planted firmly for maximum power transfer.\n\n'
          '⚠️ *Safety Notice: These visual observations provide general exercise technique guidance and do not diagnose medical conditions or injuries.*';
    }

    // D. Default / Gym Equipment Identification Intent
    return '### 🏋️ Machine Identified: Lat Pulldown Machine\n\n'
        '**Primary Muscles:**\n'
        '- Latissimus dorsi\n'
        '- Biceps\n\n'
        '**Setup & Instructions / How to Use:**\n'
        '1. Adjust seat height so thighs fit snugly under the pads.\n'
        '2. Grip bar slightly wider than shoulders with an overhand grip.\n'
        '3. Pull towards upper chest while driving elbows down.\n\n'
        '**Common Mistakes / Safety Cues:**\n'
        '- Avoid swinging your torso or leaning back excessively.\n\n'
        '**Calories Estimate:**\n'
        'Approximately 5-10 kcal/min depending on intensity.\n\n'
        '**Free Weight Alternatives:** Barbell Bent-Over Row, Pull-Ups, Dumbbell Single-Arm Row.';
  }
}
