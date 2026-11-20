import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/models/user_goal.dart';
import 'package:atlas/services/ai/ai_guardrail_service.dart';
import 'package:atlas/services/ai/food_detection_validator.dart';
import 'package:atlas/services/ai/workout_safety_validator.dart';
import 'package:atlas/utils/fitness_input_validator.dart';

void main() {
  group('Phase 13: AI Guardrails, Validation & Error Prevention Test Suite', () {
    setUp(() {
      AIGuardrailService.resetInstance();
    });

    // 1. AI Domain Restriction
    test(
      '1. AIGuardrailService accurately distinguishes fitness questions from off-topic requests',
      () {
        final guardrail = AIGuardrailService.instance;

        // Allowed fitness topics
        expect(
          guardrail.isFitnessRelated(
            'How much protein should I eat for hypertrophy?',
          ),
          isTrue,
        );
        expect(
          guardrail.isFitnessRelated(
            'Create a 4-day push pull legs workout split',
          ),
          isTrue,
        );
        expect(
          guardrail.isFitnessRelated(
            'What is the best way to improve squat depth and form?',
          ),
          isTrue,
        );
        expect(
          guardrail.isFitnessRelated(
            'My HRV dropped today, should I take a rest day?',
          ),
          isTrue,
        );
        expect(guardrail.isFitnessRelated('Good morning coach'), isTrue);

        // Blocked off-topic requests
        expect(
          guardrail.isFitnessRelated('Write my history homework essay on Rome'),
          isFalse,
        );
        expect(
          guardrail.isFitnessRelated('Write python code to scrape a website'),
          isFalse,
        );
        expect(
          guardrail.isFitnessRelated(
            'Who is the president and tell me about politics',
          ),
          isFalse,
        );
        expect(
          guardrail.isFitnessRelated('Tell me a bedtime story about dragons'),
          isFalse,
        );

        expect(
          AIGuardrailService.offTopicResponse,
          contains('I am your fitness coach'),
        );
      },
    );

    // 2. AI Response Safety Filter
    test(
      '2. AIGuardrailService sanitizes harmful advice, medical guarantees, and acute injury queries',
      () {
        final guardrail = AIGuardrailService.instance;

        // Replace extreme fat loss guarantee
        const unsafeFatLoss =
            'Follow this routine and I guarantee you will lose 20kg in 10 days.';
        final sanitizedFatLoss = guardrail.sanitizeAIResponse(
          unsafeFatLoss,
          'how to lose fat',
        );
        expect(sanitizedFatLoss, contains('Safe and sustainable fat loss'));
        expect(sanitizedFatLoss, contains('0.5kg to 1.0kg per week'));

        // Replace dangerous injury advice
        const unsafeInjury =
            'Ignore your injury and train harder through the sharp pain.';
        final sanitizedInjury = guardrail.sanitizeAIResponse(
          unsafeInjury,
          'my knee hurts',
        );
        expect(sanitizedInjury, contains('Stop the exercise immediately'));

        // Append clinical safety advisory on diagnostic inquiry
        const safeText =
            'Here are general mobility exercises for mild tightness.';
        final diagnosedText = guardrail.sanitizeAIResponse(
          safeText,
          'Please diagnose my chest pain and torn muscle',
        );
        expect(diagnosedText, contains('Safety Advisory'));
        expect(diagnosedText, contains('not clinical or medical diagnoses'));
      },
    );

    // 3. Food Detection & Non-Food Scanner Validation
    test(
      '3. FoodDetectionValidator enforces confidence thresholds and rejects non-food items',
      () {
        // High confidence food
        final highConfidence = FoodDetectionValidator.validateScan(
          itemName: 'Grilled Chicken Breast with Brown Rice',
          confidence: 0.92,
        );
        expect(highConfidence.isAccepted, isTrue);
        expect(
          highConfidence.confidenceRating,
          equals(FoodConfidenceRating.high),
        );

        // Medium confidence food
        final mediumConfidence = FoodDetectionValidator.validateScan(
          itemName: 'Lentil Curry Soup',
          confidence: 0.65,
        );
        expect(mediumConfidence.isAccepted, isTrue);
        expect(
          mediumConfidence.confidenceRating,
          equals(FoodConfidenceRating.medium),
        );

        // Low confidence (< 50%)
        final lowConfidence = FoodDetectionValidator.validateScan(
          itemName: 'Unknown blurry meal',
          confidence: 0.32,
        );
        expect(lowConfidence.isAccepted, isFalse);
        expect(
          lowConfidence.confidenceRating,
          equals(FoodConfidenceRating.low),
        );
        expect(
          lowConfidence.userGuidanceMessage,
          contains('Unable to confidently identify this food'),
        );

        // Non-food objects
        final phoneScan = FoodDetectionValidator.validateScan(
          itemName: 'Apple iPhone Smartphone',
          confidence: 0.95,
        );
        expect(phoneScan.isAccepted, isFalse);
        expect(phoneScan.isValidFood, isFalse);
        expect(phoneScan.userGuidanceMessage, contains('No food detected'));

        final dumbbellScan = FoodDetectionValidator.validateScan(
          itemName: 'Gym Dumbbell 20kg',
          confidence: 0.90,
        );
        expect(dumbbellScan.isAccepted, isFalse);
        expect(dumbbellScan.userGuidanceMessage, contains('No food detected'));
      },
    );

    // 4. Barcode Category Validation
    test(
      '4. FitnessInputValidator checks barcode categories and rejects non-food products',
      () {
        // Valid food categories
        expect(
          FitnessInputValidator.validateBarcodeCategory('Snack Food').isValid,
          isTrue,
        );
        expect(
          FitnessInputValidator.validateBarcodeCategory('Beverages').isValid,
          isTrue,
        );
        expect(
          FitnessInputValidator.validateBarcodeCategory(
            'Protein Supplements',
          ).isValid,
          isTrue,
        );
        expect(
          FitnessInputValidator.validateBarcodeCategory(
            'Dairy Products',
          ).isValid,
          isTrue,
        );

        // Non-food categories
        final electronics = FitnessInputValidator.validateBarcodeCategory(
          'Consumer Electronics',
        );
        expect(electronics.isValid, isFalse);
        expect(
          electronics.errorMessage,
          contains('does not belong to a food product'),
        );

        final cosmetics = FitnessInputValidator.validateBarcodeCategory(
          'Beauty and Cosmetics',
        );
        expect(cosmetics.isValid, isFalse);

        final clothing = FitnessInputValidator.validateBarcodeCategory(
          'Men Apparel and Clothing',
        );
        expect(clothing.isValid, isFalse);
      },
    );

    // 5. User Profile Biometric Validation
    test(
      '5. FitnessInputValidator rejects impossible height, weight, and age values',
      () {
        // Height (100cm - 250cm)
        expect(FitnessInputValidator.validateHeight(178.0).isValid, isTrue);
        expect(FitnessInputValidator.validateHeight(25.0).isValid, isFalse);
        expect(FitnessInputValidator.validateHeight(900.0).isValid, isFalse);

        // Weight (20kg - 300kg)
        expect(FitnessInputValidator.validateWeight(75.0).isValid, isTrue);
        expect(FitnessInputValidator.validateWeight(5.0).isValid, isFalse);
        expect(FitnessInputValidator.validateWeight(500.0).isValid, isFalse);

        // Age (13 - 100)
        expect(FitnessInputValidator.validateAge(25).isValid, isTrue);
        expect(FitnessInputValidator.validateAge(-5).isValid, isFalse);
        expect(FitnessInputValidator.validateAge(150).isValid, isFalse);
      },
    );

    // 6. Weight Goal Feasibility Validation
    test(
      '6. FitnessInputValidator flags unrealistic weight change timelines',
      () {
        // Realistic fat loss (6kg in 12 weeks = 0.5kg/week)
        final realisticLoss = FitnessInputValidator.validateWeightGoal(
          currentWeight: 80.0,
          targetWeight: 74.0,
          durationWeeks: 12,
        );
        expect(realisticLoss.isValid, isTrue);

        // Unrealistic extreme weight gain (60kg to 120kg in 4 weeks = 15kg/week)
        final unrealisticGain = FitnessInputValidator.validateWeightGoal(
          currentWeight: 60.0,
          targetWeight: 120.0,
          durationWeeks: 4,
        );
        expect(unrealisticGain.isValid, isFalse);
        expect(
          unrealisticGain.errorMessage,
          contains('Your goal is unrealistic'),
        );
        expect(unrealisticGain.errorMessage, contains('0.25kg - 1kg per week'));
      },
    );

    // 7. Workout Safety & Injury Contraindication Validation
    test(
      '7. WorkoutSafetyValidator filters contraindicated movements for beginners and injuries',
      () {
        // Beginner trying advanced Olympic snatch
        final beginnerOlympic = WorkoutSafetyValidator.validateWorkoutPlan(
          fitnessLevel: FitnessLevel.beginner,
          exercises: ['Barbell Snatch', 'Clean and Jerk', 'Push-ups'],
        );
        expect(beginnerOlympic.isSafe, isFalse);
        expect(
          beginnerOlympic.contraindicatedExercises,
          contains('Barbell Snatch'),
        );

        // Shoulder injury safety
        final shoulderCheck = WorkoutSafetyValidator.validateWorkoutPlan(
          fitnessLevel: FitnessLevel.intermediate,
          exercises: ['Heavy Overhead Press', 'Lateral Raises', 'Dips'],
          injuries: ['Shoulder impingement'],
        );
        expect(shoulderCheck.isSafe, isFalse);
        expect(
          shoulderCheck.contraindicatedExercises,
          contains('Heavy Overhead Press'),
        );

        // Knee injury safety
        final kneeCheck = WorkoutSafetyValidator.validateWorkoutPlan(
          fitnessLevel: FitnessLevel.intermediate,
          exercises: ['Barbell Back Squat', 'Box Jumps', 'Leg Curls'],
          injuries: ['Knee Meniscus Tear'],
        );
        expect(kneeCheck.isSafe, isFalse);
        expect(
          kneeCheck.contraindicatedExercises,
          contains('Barbell Back Squat'),
        );
      },
    );

    // 8. AI Agent Tool Execution Limits
    test(
      '8. WorkoutSafetyValidator validates AI Agent tool call boundaries',
      () {
        // Calorie modification bounds
        final safeCalorieDelta =
            WorkoutSafetyValidator.validateCalorieTargetModification(
              currentTarget: 2500.0,
              proposedTarget: 2300.0,
            );
        expect(safeCalorieDelta.isSafe, isTrue);

        final extremeCalorieJump =
            WorkoutSafetyValidator.validateCalorieTargetModification(
              currentTarget: 2000.0,
              proposedTarget: 7500.0,
            );
        expect(extremeCalorieJump.isSafe, isFalse);
        expect(
          extremeCalorieJump.warningMessage,
          contains(
            'Calorie target must remain within safe physiological limits',
          ),
        );

        // Duration bounds
        expect(
          WorkoutSafetyValidator.validateWorkoutDuration(45).isSafe,
          isTrue,
        );
        expect(
          WorkoutSafetyValidator.validateWorkoutDuration(5).isSafe,
          isFalse,
        );
        expect(
          WorkoutSafetyValidator.validateWorkoutDuration(200).isSafe,
          isFalse,
        );
      },
    );
  });
}
