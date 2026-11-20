import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/equipment.dart';
import 'package:atlas/models/exercise.dart';
import 'package:atlas/models/fitness_context.dart';
import 'package:atlas/models/user_equipment_profile.dart';
import 'package:atlas/repositories/equipment_repository.dart';
import 'package:atlas/screens/equipment_setup_screen.dart';
import 'package:atlas/services/ai/coach_prompt_builder.dart';
import '../mocks/mock_ai_provider.dart';
import 'package:atlas/services/equipment_workout_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  group('Phase 1 — Equipment Data Models & Presets', () {
    test('Master catalog contains valid items across all categories', () {
      final catalog = Equipment.masterCatalog();
      expect(catalog.isNotEmpty, isTrue);

      final categories = catalog.map((e) => e.category).toSet();
      expect(categories.contains(EquipmentCategory.freeWeight), isTrue);
      expect(categories.contains(EquipmentCategory.machine), isTrue);
      expect(categories.contains(EquipmentCategory.bodyweight), isTrue);
      expect(categories.contains(EquipmentCategory.cardio), isTrue);
      expect(categories.contains(EquipmentCategory.accessory), isTrue);
    });

    test('Equipment serialization round-trip works correctly', () {
      const equipment = Equipment(
        id: 'dumbbells',
        name: 'Dumbbells',
        category: EquipmentCategory.freeWeight,
        icon: Icons.fitness_center_rounded,
        description: 'Adjustable dumbbells',
      );

      final json = equipment.toJson();
      final decoded = Equipment.fromJson(json);

      expect(decoded.id, 'dumbbells');
      expect(decoded.name, 'Dumbbells');
      expect(decoded.category, EquipmentCategory.freeWeight);
    });

    test('UserEquipmentProfile presets configure correct item IDs', () {
      final fullGym = UserEquipmentProfile.fullCommercialGym();
      expect(
        fullGym.availableEquipmentIds.length,
        Equipment.masterCatalog().length,
      );
      expect(fullGym.isEquipmentAvailable('barbell'), isTrue);
      expect(fullGym.isEquipmentAvailable('dumbbells'), isTrue);
      expect(fullGym.isEquipmentAvailable('cable_machine'), isTrue);

      final homeSetup = UserEquipmentProfile.homeDumbbellsAndBench();
      expect(homeSetup.isEquipmentAvailable('dumbbells'), isTrue);
      expect(homeSetup.isEquipmentAvailable('bench'), isTrue);
      expect(homeSetup.isEquipmentAvailable('barbell'), isFalse);
      expect(homeSetup.isEquipmentAvailable('leg_press'), isFalse);

      final calisthenics = UserEquipmentProfile.bodyweightCalisthenics();
      expect(calisthenics.isEquipmentAvailable('pull_up_bar'), isTrue);
      expect(calisthenics.isEquipmentAvailable('dip_station'), isTrue);
      expect(calisthenics.isEquipmentAvailable('dumbbells'), isFalse);

      final minimalist = UserEquipmentProfile.minimalist();
      expect(minimalist.isEquipmentAvailable('exercise_mat'), isTrue);
      expect(minimalist.isEquipmentAvailable('pull_up_bar'), isFalse);
    });

    test('UserEquipmentProfile multi-equipment validation checks work', () {
      final profile = UserEquipmentProfile(
        userId: 'test_athlete',
        availableEquipmentIds: const ['dumbbells', 'bench'],
        updatedAt: DateTime.now(),
      );

      expect(profile.hasAllEquipment(['dumbbells', 'bench']), isTrue);
      expect(profile.hasAllEquipment(['dumbbells', 'barbell']), isFalse);
      expect(profile.hasAnyEquipment(['barbell', 'bench']), isTrue);
      expect(profile.hasAnyEquipment(['barbell', 'cable_machine']), isFalse);
    });
  });

  group('Phase 2 & 3 — Exercise Expansion & Repository Storage', () {
    test('Exercise model supports requiredEquipment and defaults', () {
      final registry = Exercise.defaultRegistry();
      expect(registry.isNotEmpty, isTrue);

      final bench = registry.firstWhere((e) => e.id == 'bench_press');
      expect(bench.requiredEquipment, contains('barbell'));
      expect(bench.requiredEquipment, contains('bench'));
      expect(bench.alternatives, contains('dumbbell_bench_press'));

      final pushups = registry.firstWhere((e) => e.id == 'push_ups');
      expect(pushups.requiredEquipment, contains('exercise_mat'));
    });

    test(
      'LocalEquipmentRepository saves, retrieves, and resets profiles',
      () async {
        const repository = LocalEquipmentRepository();

        final initial = await repository.getProfile();
        expect(initial.availableEquipmentIds.isNotEmpty, isTrue);

        final custom = UserEquipmentProfile(
          userId: 'local_user',
          availableEquipmentIds: const ['dumbbells', 'exercise_mat'],
          updatedAt: DateTime.now(),
        );

        await repository.saveProfile(custom);
        final reloaded = await repository.getProfile();
        expect(reloaded.availableEquipmentIds, ['dumbbells', 'exercise_mat']);

        await repository.resetToFullGym();
        final resetProfile = await repository.getProfile();
        expect(
          resetProfile.availableEquipmentIds.length,
          Equipment.masterCatalog().length,
        );
      },
    );
  });

  group('Phase 5 — Workout Recommendation & Filtering Engine', () {
    const service = EquipmentWorkoutService();
    final registry = Exercise.defaultRegistry();

    test('canPerformExercise accurately evaluates equipment availability', () {
      final dumbbellOnly = UserEquipmentProfile(
        userId: 'test',
        availableEquipmentIds: const ['dumbbells', 'bench'],
        updatedAt: DateTime.now(),
      );

      final barbellBench = registry.firstWhere((e) => e.id == 'bench_press');
      final dbBench = registry.firstWhere(
        (e) => e.id == 'dumbbell_bench_press',
      );

      expect(service.canPerformExercise(barbellBench, dumbbellOnly), isFalse);
      expect(service.canPerformExercise(dbBench, dumbbellOnly), isTrue);
    });

    test('filterAvailableExercises returns only feasible movements', () {
      final homeProfile = UserEquipmentProfile.homeDumbbellsAndBench();
      final filtered = service.filterAvailableExercises(
        exercises: registry,
        profile: homeProfile,
      );

      expect(filtered.any((e) => e.id == 'bench_press'), isFalse);
      expect(filtered.any((e) => e.id == 'barbell_back_squat'), isFalse);
      expect(filtered.any((e) => e.id == 'dumbbell_bench_press'), isTrue);
      expect(filtered.any((e) => e.id == 'dumbbell_goblet_squat'), isTrue);
    });

    test(
      'findAlternatives finds substitute when primary equipment is missing',
      () {
        final dumbbellOnly = UserEquipmentProfile(
          userId: 'test',
          availableEquipmentIds: const ['dumbbells', 'bench'],
          updatedAt: DateTime.now(),
        );

        final barbellBench = registry.firstWhere((e) => e.id == 'bench_press');
        final alternatives = service.findAlternatives(
          target: barbellBench,
          profile: dumbbellOnly,
          pool: registry,
        );

        expect(alternatives.isNotEmpty, isTrue);
        expect(alternatives.first.id, 'dumbbell_bench_press');
      },
    );

    test(
      'adaptWorkoutSession replaces Barbell Bench Press with Dumbbell Bench Press',
      () {
        final noBarbellProfile = UserEquipmentProfile(
          userId: 'test',
          availableEquipmentIds: const ['dumbbells', 'bench', 'pull_up_bar'],
          updatedAt: DateTime.now(),
        );

        final originalSession = [
          registry.firstWhere((e) => e.id == 'bench_press'),
          registry.firstWhere((e) => e.id == 'pull_ups'),
          registry.firstWhere((e) => e.id == 'barbell_back_squat'),
        ];

        final result = service.adaptWorkoutSession(
          originalSession: originalSession,
          profile: noBarbellProfile,
          exercisePool: registry,
        );

        expect(result.requiredSubstitutions, isTrue);
        expect(result.substitutions.length, 2);

        // Verify Bench Press replacement
        final firstAdapted = result.adaptedExercises[0];
        expect(firstAdapted.id, 'dumbbell_bench_press');

        // Verify Pull-ups kept (profile has pull-up bar)
        final secondAdapted = result.adaptedExercises[1];
        expect(secondAdapted.id, 'pull_ups');

        // Verify Squat replacement (barbell squat -> dumbbell goblet squat)
        final thirdAdapted = result.adaptedExercises[2];
        expect(thirdAdapted.id, 'dumbbell_goblet_squat');
      },
    );
  });

  group('Phase 6 — AI Coach Integration', () {
    test('FitnessContext helpers format equipment names correctly', () {
      final profile = UserEquipmentProfile(
        userId: 'test',
        availableEquipmentIds: const ['dumbbells', 'bench'],
        updatedAt: DateTime.now(),
      );

      final context = FitnessContext.initial().copyWith(
        equipmentProfile: profile,
      );

      expect(context.availableEquipmentNames, contains('Dumbbells'));
      expect(context.availableEquipmentNames, contains('Adjustable Bench'));
      expect(
        context.unavailableEquipmentNames,
        contains('Barbell & Weight Plates'),
      );
      expect(context.unavailableEquipmentNames, contains('Leg Press Machine'));
    });

    test(
      'CoachPromptBuilder includes available and excluded equipment in system prompt',
      () {
        final profile = UserEquipmentProfile(
          userId: 'test',
          availableEquipmentIds: const ['dumbbells', 'bench'],
          updatedAt: DateTime.now(),
        );

        final context = FitnessContext.initial().copyWith(
          equipmentProfile: profile,
        );
        const builder = CoachPromptBuilder();

        final prompt = builder.buildPrompt(
          message: 'Give me a chest workout',
          context: context,
        );

        expect(prompt, contains('Available Gym Equipment:'));
        expect(prompt, contains('Dumbbells'));
        expect(prompt, contains('Unavailable / Excluded Equipment:'));
        expect(
          prompt,
          contains(
            'NEVER prescribe exercises requiring equipment listed under Unavailable',
          ),
        );
      },
    );

    test('MockAIProvider responds accurately to equipment inquiries', () async {
      final profile = UserEquipmentProfile(
        userId: 'test',
        availableEquipmentIds: const ['dumbbells', 'bench'],
        updatedAt: DateTime.now(),
      );

      final context = FitnessContext.initial().copyWith(
        equipmentProfile: profile,
      );
      const provider = MockAIProvider();

      final response = await provider.generateResponse(
        message:
            'What equipment do I have and can you replace barbell workouts?',
        context: context,
        history: const [],
      );

      expect(response, contains('equipment profile loaded'));
      expect(response, contains('Dumbbells'));
      expect(response, contains('calibrated to only use your available gear'));
    });
  });

  group('Phase 4 & 8 — Multi-Device Responsive UI Tests', () {
    final viewports = [
      const Size(320, 600), // 320px ultra compact
      const Size(360, 740), // 360px small Android
      const Size(390, 844), // 390px modern iPhone
      const Size(412, 915), // 412px large Android
    ];

    for (final size in viewports) {
      testWidgets(
        'EquipmentSetupScreen renders cleanly at ${size.width.toInt()}px without overflow',
        (tester) async {
          tester.view.physicalSize = Size(size.width * 2, size.height * 2);
          tester.view.devicePixelRatio = 2.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await tester.pumpWidget(
            const MaterialApp(home: EquipmentSetupScreen()),
          );
          await tester.pumpAndSettle();

          expect(find.text('Equipment Setup'), findsOneWidget);
          expect(find.text('Available Gear'), findsOneWidget);
          expect(find.byType(TextField), findsOneWidget);

          // Verify presets exist and are interactive
          expect(find.text('Full Commercial Gym'), findsOneWidget);
          expect(find.text('Home Dumbbell & Bench'), findsOneWidget);

          // Tap preset safely
          await tester.tap(
            find.text('Full Commercial Gym'),
            warnIfMissed: false,
          );
          await tester.pumpAndSettle();

          // Check save button is visible and active
          expect(find.textContaining('Save Equipment Setup'), findsOneWidget);
          await tester.tap(
            find.textContaining('Save Equipment Setup'),
            warnIfMissed: false,
          );
          await tester.pumpAndSettle();

          // 0 overflow errors
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}
