import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/models/exercise.dart';
import 'package:atlas/services/exercise_media_service.dart';
import 'package:atlas/screens/exercise_detail_screen.dart';
import 'package:atlas/widgets/exercise/exercise_video_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final batch1ExerciseIds = [
    'bench_press',
    'barbell_back_squat',
    'conventional_deadlift',
    'pull_ups',
    'lat_pulldown',
    'overhead_press',
    'leg_press',
    'push_ups',
    'bicep_curl',
    'tricep_pushdown',
  ];

  final batch2ExerciseIds = [
    'incline_bench_press',
    'dumbbell_bench_press',
    'incline_dumbbell_press',
    'barbell_row',
    'seated_cable_row',
    'romanian_deadlift',
    'dumbbell_goblet_squat',
    'leg_extension',
    'hamstring_curl',
    'standing_calf_raise',
    'lateral_raise',
    'dumbbell_shoulder_press',
  ];

  final batch3ExerciseIds = [
    'chest_press_machine',
    'cable_chest_fly',
    'dumbbell_chest_fly',
    'chest_dips',
    'cable_lateral_raise',
    'rear_delt_fly',
    'face_pulls',
    'arnold_press',
    'chin_ups',
    'dumbbell_row',
    'barbell_bicep_curl',
    'hammer_curl',
    'skull_crushers',
  ];

  final batch4aExerciseIds = [
    'preacher_curl',
    'concentration_curl',
    'incline_dumbbell_curl',
    'cable_bicep_curl',
    'overhead_tricep_extension',
    'tricep_kickbacks',
    'dumbbell_rdl',
    'bulgarian_split_squat',
    'walking_lunges',
    'bodyweight_squat',
    'seated_calf_raise',
    'calf_press_leg_press',
  ];

  final batch4bExerciseIds = [
    // Core
    'hanging_leg_raise',
    'plank',
    // Cardio / HIIT
    'outdoor_run',
    'treadmill_run',
    'sprint_intervals',
    'jogging',
    'stationary_bike',
    'outdoor_cycling',
    'hiit_cycling',
    'rowing_machine',
    'rowing_intervals',
    'jump_rope',
    'burpees',
    'mountain_climbers',
    'hiit_circuit',
    // Sports
    'football',
    'basketball',
    'swimming',
    'boxing',
    // Mobility
    'cat_cow_stretch',
    'world_greatest_stretch',
    'foam_rolling_full_body',
    'doorway_chest_stretch',
    'hip_flexor_stretch',
    'couch_stretch',
  ];

  final allPopulatedExerciseIds = [
    ...batch1ExerciseIds,
    ...batch2ExerciseIds,
    ...batch3ExerciseIds,
    ...batch4aExerciseIds,
    ...batch4bExerciseIds,
  ];

  group('Phase 2 — High Priority Exercise Media Population & Verification', () {
    test(
      'All 72 registry exercises exist in defaultRegistry and have valid media references (100% coverage)',
      () {
        final registry = Exercise.defaultRegistry();
        expect(registry.length, 72);
        expect(allPopulatedExerciseIds.length, 72);
        final map = {for (final e in registry) e.id: e};

        for (final id in allPopulatedExerciseIds) {
          expect(
            map.containsKey(id),
            isTrue,
            reason: 'Exercise $id should exist in registry',
          );
          final ex = map[id]!;
          expect(
            ex.imageUrl,
            isNotNull,
            reason: 'Exercise ${ex.name} ($id) should have imageUrl populated',
          );
          expect(
            ex.imageUrl!.startsWith('https://'),
            isTrue,
            reason: 'Exercise ${ex.name} ($id) should have https imageUrl',
          );
        }
      },
    );

    test(
      'ExerciseMediaService properly resolves highest priority media for each target exercise',
      () {
        final mediaService = ExerciseMediaService();

        // Batch 1
        final bench = Exercise.getById('bench_press')!;
        final benchMedia = mediaService.resolveMedia(bench);
        expect(benchMedia.mediaType, 'video');
        expect(
          benchMedia.url,
          contains('Bench_press_-_exercise_demonstration_video.webm'),
        );

        final squat = Exercise.getById('barbell_back_squat')!;
        final squatMedia = mediaService.resolveMedia(squat);
        expect(squatMedia.mediaType, 'video');
        expect(
          squatMedia.url,
          contains('Squat_-_exercise_demonstration_video.webm'),
        );

        final deadlift = Exercise.getById('conventional_deadlift')!;
        final deadliftMedia = mediaService.resolveMedia(deadlift);
        expect(deadliftMedia.mediaType, 'video');
        expect(
          deadliftMedia.url,
          contains('Deadlift_-_exercise_demonstration_video.webm'),
        );

        final pullups = Exercise.getById('pull_ups')!;
        final pullupsMedia = mediaService.resolveMedia(pullups);
        expect(pullupsMedia.mediaType, 'video');
        expect(
          pullupsMedia.url,
          contains('Pull-ups_-_exercise_demonstration_video.webm'),
        );

        final lat = Exercise.getById('lat_pulldown')!;
        final latMedia = mediaService.resolveMedia(lat);
        expect(latMedia.mediaType, 'video');
        expect(latMedia.url, contains('Common_Lat_Pulldown_Mistakes.webm'));

        final overhead = Exercise.getById('overhead_press')!;
        final overheadMedia = mediaService.resolveMedia(overhead);
        expect(overheadMedia.mediaType, 'video');
        expect(
          overheadMedia.url,
          contains('Shoulder_press_-_exercise_demonstration_video.webm'),
        );

        final legPress = Exercise.getById('leg_press')!;
        final legPressMedia = mediaService.resolveMedia(legPress);
        expect(legPressMedia.mediaType, 'video');
        expect(
          legPressMedia.url,
          contains('Hip_Sled_-_How_to_perform_a_45_degree_leg_press.webm'),
        );

        final pushups = Exercise.getById('push_ups')!;
        final pushupsMedia = mediaService.resolveMedia(pushups);
        expect(pushupsMedia.mediaType, 'gif');
        expect(pushupsMedia.url, contains('Pushups.gif'));

        final bicep = Exercise.getById('bicep_curl')!;
        final bicepMedia = mediaService.resolveMedia(bicep);
        expect(bicepMedia.mediaType, 'video');
        expect(
          bicepMedia.url,
          contains('Video_of_EZ_Bar_Curl_and_Straight_Bar_Curl.webm'),
        );

        final tricep = Exercise.getById('tricep_pushdown')!;
        final tricepMedia = mediaService.resolveMedia(tricep);
        expect(tricepMedia.mediaType, 'gif');
        expect(tricepMedia.url, contains('Triceps-pushdown-with-rope-2.gif'));

        // Batch 2
        final inclineBench = Exercise.getById('incline_bench_press')!;
        final inclineBenchMedia = mediaService.resolveMedia(inclineBench);
        expect(inclineBenchMedia.mediaType, 'video');
        expect(
          inclineBenchMedia.url,
          contains('Incline_press_-_exercise_demonstration_video.webm'),
        );

        final dbBench = Exercise.getById('dumbbell_bench_press')!;
        final dbBenchMedia = mediaService.resolveMedia(dbBench);
        expect(dbBenchMedia.mediaType, 'video');
        expect(
          dbBenchMedia.url,
          contains('Video_showing_how_to_perform_the_dumbbell_bench_press'),
        );

        final inclineDb = Exercise.getById('incline_dumbbell_press')!;
        final inclineDbMedia = mediaService.resolveMedia(inclineDb);
        expect(inclineDbMedia.mediaType, 'video');
        expect(
          inclineDbMedia.url,
          contains('Video_showing_how_to_perform_the_dumbbell_bench_press'),
        );

        final bbRow = Exercise.getById('barbell_row')!;
        final bbRowMedia = mediaService.resolveMedia(bbRow);
        expect(bbRowMedia.mediaType, 'video');
        expect(
          bbRowMedia.url,
          contains('Bent-over_row_-_exercise_demonstration_video.webm'),
        );

        final cableRow = Exercise.getById('seated_cable_row')!;
        final cableRowMedia = mediaService.resolveMedia(cableRow);
        expect(cableRowMedia.mediaType, 'image');
        expect(cableRowMedia.url, contains('Cable-seated-rows-1.png'));

        final rdl = Exercise.getById('romanian_deadlift')!;
        final rdlMedia = mediaService.resolveMedia(rdl);
        expect(rdlMedia.mediaType, 'image');
        expect(rdlMedia.url, contains('Romanian-deadlift-1.png'));

        final goblet = Exercise.getById('dumbbell_goblet_squat')!;
        final gobletMedia = mediaService.resolveMedia(goblet);
        expect(gobletMedia.mediaType, 'image');
        expect(gobletMedia.url, contains('Kettlebell_Front_Squat_1.jpg'));

        final legExt = Exercise.getById('leg_extension')!;
        final legExtMedia = mediaService.resolveMedia(legExt);
        expect(legExtMedia.mediaType, 'video');
        expect(
          legExtMedia.url,
          contains('Muscle_Strengthening_at_the_Gym_-_Leg_Extension.webm'),
        );

        final legCurl = Exercise.getById('hamstring_curl')!;
        final legCurlMedia = mediaService.resolveMedia(legCurl);
        expect(legCurlMedia.mediaType, 'video');
        expect(
          legCurlMedia.url,
          contains('Muscle_Strengthening_at_the_Gym_-_Leg_Curl.webm'),
        );

        final calf = Exercise.getById('standing_calf_raise')!;
        final calfMedia = mediaService.resolveMedia(calf);
        expect(calfMedia.mediaType, 'gif');
        expect(
          calfMedia.url,
          contains('Toe_stand-CDC_strength_training_for_older_adults.gif'),
        );

        final lateralRaise = Exercise.getById('lateral_raise')!;
        final lateralRaiseMedia = mediaService.resolveMedia(lateralRaise);
        expect(lateralRaiseMedia.mediaType, 'image');
        expect(lateralRaiseMedia.url, contains('DumbbellLateralRaise.JPG'));

        final dbShoulder = Exercise.getById('dumbbell_shoulder_press')!;
        final dbShoulderMedia = mediaService.resolveMedia(dbShoulder);
        expect(dbShoulderMedia.mediaType, 'gif');
        expect(
          dbShoulderMedia.url,
          contains('Overhead_press-CDC_strength_training_for_older_adults.gif'),
        );

        // Batch 3
        final chestPress = Exercise.getById('chest_press_machine')!;
        final chestPressMedia = mediaService.resolveMedia(chestPress);
        expect(chestPressMedia.mediaType, 'video');
        expect(
          chestPressMedia.url,
          contains('Muscle_Strengthening_at_the_Gym_-_Chest_Press.webm'),
        );

        final cableFly = Exercise.getById('cable_chest_fly')!;
        final cableFlyMedia = mediaService.resolveMedia(cableFly);
        expect(cableFlyMedia.mediaType, 'image');
        expect(cableFlyMedia.url, contains('Cable-crossover-1.png'));

        final dbFly = Exercise.getById('dumbbell_chest_fly')!;
        final dbFlyMedia = mediaService.resolveMedia(dbFly);
        expect(dbFlyMedia.mediaType, 'gif');
        expect(dbFlyMedia.url, contains('DumbbellFlye.gif'));

        final dips = Exercise.getById('chest_dips')!;
        final dipsMedia = mediaService.resolveMedia(dips);
        expect(dipsMedia.mediaType, 'gif');
        expect(dipsMedia.url, contains('Tricep-dips-2-1.gif'));

        final cableLatRaise = Exercise.getById('cable_lateral_raise')!;
        final cableLatRaiseMedia = mediaService.resolveMedia(cableLatRaise);
        expect(cableLatRaiseMedia.mediaType, 'image');
        expect(
          cableLatRaiseMedia.url,
          contains('Bent-over-cable-lateral-raises-1.png'),
        );

        final rearDeltFly = Exercise.getById('rear_delt_fly')!;
        final rearDeltFlyMedia = mediaService.resolveMedia(rearDeltFly);
        expect(rearDeltFlyMedia.mediaType, 'image');
        expect(
          rearDeltFlyMedia.url,
          contains('Lying-rear-lateral-raise-1.png'),
        );

        final facePulls = Exercise.getById('face_pulls')!;
        final facePullsMedia = mediaService.resolveMedia(facePulls);
        expect(facePullsMedia.mediaType, 'image');
        expect(
          facePullsMedia.url,
          contains('Cable-seated-rear-lateral-raise-1.png'),
        );

        final arnold = Exercise.getById('arnold_press')!;
        final arnoldMedia = mediaService.resolveMedia(arnold);
        expect(arnoldMedia.mediaType, 'image');
        expect(arnoldMedia.url, contains('Arnold-press-1.png'));

        final chinUps = Exercise.getById('chin_ups')!;
        final chinUpsMedia = mediaService.resolveMedia(chinUps);
        expect(chinUpsMedia.mediaType, 'image');
        expect(chinUpsMedia.url, contains('Chin-ups-1.png'));

        final dbRow = Exercise.getById('dumbbell_row')!;
        final dbRowMedia = mediaService.resolveMedia(dbRow);
        expect(dbRowMedia.mediaType, 'image');
        expect(dbRowMedia.url, contains('Rear_deltoid_row_dumbbell_1.svg'));

        final bbCurl = Exercise.getById('barbell_bicep_curl')!;
        final bbCurlMedia = mediaService.resolveMedia(bbCurl);
        expect(bbCurlMedia.mediaType, 'video');
        expect(
          bbCurlMedia.url,
          contains('Video_of_EZ_Bar_Curl_and_Straight_Bar_Curl.webm'),
        );

        final hammerCurl = Exercise.getById('hammer_curl')!;
        final hammerCurlMedia = mediaService.resolveMedia(hammerCurl);
        expect(hammerCurlMedia.mediaType, 'gif');
        expect(hammerCurlMedia.url, contains('Hammer-curls-with-rope-1.gif'));

        final skullCrushers = Exercise.getById('skull_crushers')!;
        final skullCrushersMedia = mediaService.resolveMedia(skullCrushers);
        expect(skullCrushersMedia.mediaType, 'image');
        expect(
          skullCrushersMedia.url,
          contains('DumbbellTricepsExtension.JPG'),
        );

        // Batch 4A - Arms
        final preacher = Exercise.getById('preacher_curl')!;
        final preacherMedia = mediaService.resolveMedia(preacher);
        expect(preacherMedia.mediaType, 'gif');
        expect(preacherMedia.url, contains('Two-arm-preacher-curl-2.gif'));

        final concentration = Exercise.getById('concentration_curl')!;
        final concentrationMedia = mediaService.resolveMedia(concentration);
        expect(concentrationMedia.mediaType, 'image');
        expect(concentrationMedia.url, contains('Concentration-curls-1.png'));

        final inclineCurl = Exercise.getById('incline_dumbbell_curl')!;
        final inclineCurlMedia = mediaService.resolveMedia(inclineCurl);
        expect(inclineCurlMedia.mediaType, 'gif');
        expect(inclineCurlMedia.url, contains('Incline-biceps-curl-1.gif'));

        final cableCurl = Exercise.getById('cable_bicep_curl')!;
        final cableCurlMedia = mediaService.resolveMedia(cableCurl);
        expect(cableCurlMedia.mediaType, 'gif');
        expect(cableCurlMedia.url, contains('Standing-biceps-curl-1.gif'));

        final overheadExt = Exercise.getById('overhead_tricep_extension')!;
        final overheadExtMedia = mediaService.resolveMedia(overheadExt);
        expect(overheadExtMedia.mediaType, 'image');
        expect(overheadExtMedia.url, contains('DumbbellTricepsExtension.JPG'));

        final kickbacks = Exercise.getById('tricep_kickbacks')!;
        final kickbacksMedia = mediaService.resolveMedia(kickbacks);
        expect(kickbacksMedia.mediaType, 'gif');
        expect(
          kickbacksMedia.url,
          contains('Triceps_brachii_muscle_-_animation02.gif'),
        );

        // Batch 4A - Legs
        final dbRdl = Exercise.getById('dumbbell_rdl')!;
        final dbRdlMedia = mediaService.resolveMedia(dbRdl);
        expect(dbRdlMedia.mediaType, 'image');
        expect(dbRdlMedia.url, contains('Romanian-deadlift-1.png'));

        final bulgarian = Exercise.getById('bulgarian_split_squat')!;
        final bulgarianMedia = mediaService.resolveMedia(bulgarian);
        expect(bulgarianMedia.mediaType, 'image');
        expect(
          bulgarianMedia.url,
          contains('Jumping_split_squat_with_dumbbells_1.png'),
        );

        final lunges = Exercise.getById('walking_lunges')!;
        final lungesMedia = mediaService.resolveMedia(lunges);
        expect(lungesMedia.mediaType, 'gif');
        expect(
          lungesMedia.url,
          contains('Lunge-CDC_strength_training_for_older_adults.gif'),
        );

        final bwSquat = Exercise.getById('bodyweight_squat')!;
        final bwSquatMedia = mediaService.resolveMedia(bwSquat);
        expect(bwSquatMedia.mediaType, 'gif');
        expect(bwSquatMedia.url, contains('Squats_wbs.gif'));

        final seatedCalf = Exercise.getById('seated_calf_raise')!;
        final seatedCalfMedia = mediaService.resolveMedia(seatedCalf);
        expect(seatedCalfMedia.mediaType, 'gif');
        expect(
          seatedCalfMedia.url,
          contains('Toe_stand-CDC_strength_training_for_older_adults.gif'),
        );

        final calfPress = Exercise.getById('calf_press_leg_press')!;
        final calfPressMedia = mediaService.resolveMedia(calfPress);
        expect(calfPressMedia.mediaType, 'video');
        expect(
          calfPressMedia.url,
          contains('Hip_Sled_-_How_to_perform_a_45_degree_leg_press.webm'),
        );

        // Batch 4B - Core
        final legRaise = Exercise.getById('hanging_leg_raise')!;
        final legRaiseMedia = mediaService.resolveMedia(legRaise);
        expect(legRaiseMedia.mediaType, 'image');
        expect(legRaiseMedia.url, contains('Leg-raises-1.png'));

        final plank = Exercise.getById('plank')!;
        final plankMedia = mediaService.resolveMedia(plank);
        expect(plankMedia.mediaType, 'image');
        expect(plankMedia.url, contains('Plank.jpg'));

        // Batch 4B - Cardio / HIIT
        final outdoorRun = Exercise.getById('outdoor_run')!;
        final outdoorRunMedia = mediaService.resolveMedia(outdoorRun);
        expect(outdoorRunMedia.mediaType, 'image');
        expect(outdoorRunMedia.url, contains('Speedsuit.jpg'));

        final treadmill = Exercise.getById('treadmill_run')!;
        final treadmillMedia = mediaService.resolveMedia(treadmill);
        expect(treadmillMedia.mediaType, 'image');
        expect(
          treadmillMedia.url,
          contains(
            'Close-up_of_a_determined_athlete_running_on_a_treadmill.jpg',
          ),
        );

        final sprint = Exercise.getById('sprint_intervals')!;
        final sprintMedia = mediaService.resolveMedia(sprint);
        expect(sprintMedia.mediaType, 'image');
        expect(sprintMedia.url, contains('Tulane_Track_and_Field_sprinting'));

        final jogging = Exercise.getById('jogging')!;
        final joggingMedia = mediaService.resolveMedia(jogging);
        expect(joggingMedia.mediaType, 'image');
        expect(joggingMedia.url, contains('Speedsuit.jpg'));

        final spinBike = Exercise.getById('stationary_bike')!;
        final spinBikeMedia = mediaService.resolveMedia(spinBike);
        expect(spinBikeMedia.mediaType, 'image');
        expect(spinBikeMedia.url, contains('Fahrrad-Ergometer_01_KMJ.jpg'));

        final cycling = Exercise.getById('outdoor_cycling')!;
        final cyclingMedia = mediaService.resolveMedia(cycling);
        expect(cyclingMedia.mediaType, 'image');
        expect(cyclingMedia.url, contains('Cycliste_'));

        final hiitBike = Exercise.getById('hiit_cycling')!;
        final hiitBikeMedia = mediaService.resolveMedia(hiitBike);
        expect(hiitBikeMedia.mediaType, 'image');
        expect(hiitBikeMedia.url, contains('Fahrrad-Ergometer_01_KMJ.jpg'));

        final rower = Exercise.getById('rowing_machine')!;
        final rowerMedia = mediaService.resolveMedia(rower);
        expect(rowerMedia.mediaType, 'image');
        expect(rowerMedia.url, contains('Rowing_Machines.jpg'));

        final rowIntervals = Exercise.getById('rowing_intervals')!;
        final rowIntervalsMedia = mediaService.resolveMedia(rowIntervals);
        expect(rowIntervalsMedia.mediaType, 'image');
        expect(rowIntervalsMedia.url, contains('Rowing_Machines.jpg'));

        final jumpRope = Exercise.getById('jump_rope')!;
        final jumpRopeMedia = mediaService.resolveMedia(jumpRope);
        expect(jumpRopeMedia.mediaType, 'image');
        expect(jumpRopeMedia.url, contains('Ghanaian_kid_'));

        final burpees = Exercise.getById('burpees')!;
        final burpeesMedia = mediaService.resolveMedia(burpees);
        expect(burpeesMedia.mediaType, 'image');
        expect(burpeesMedia.url, contains('Airborne_Burpee.jpg'));

        final climbers = Exercise.getById('mountain_climbers')!;
        final climbersMedia = mediaService.resolveMedia(climbers);
        expect(climbersMedia.mediaType, 'image');
        expect(climbersMedia.url, contains('Plank.jpg'));

        final hiitCircuit = Exercise.getById('hiit_circuit')!;
        final hiitCircuitMedia = mediaService.resolveMedia(hiitCircuit);
        expect(hiitCircuitMedia.mediaType, 'image');
        expect(hiitCircuitMedia.url, contains('Airborne_Burpee.jpg'));

        // Batch 4B - Sports
        final football = Exercise.getById('football')!;
        final footballMedia = mediaService.resolveMedia(football);
        expect(footballMedia.mediaType, 'image');
        expect(footballMedia.url, contains('Football_in_Bloomington'));

        final basketball = Exercise.getById('basketball')!;
        final basketballMedia = mediaService.resolveMedia(basketball);
        expect(basketballMedia.mediaType, 'image');
        expect(basketballMedia.url, contains('Steph_Curry_'));

        final swimming = Exercise.getById('swimming')!;
        final swimmingMedia = mediaService.resolveMedia(swimming);
        expect(swimmingMedia.mediaType, 'image');
        expect(swimmingMedia.url, contains('Incheon_AsianGames_Swimming'));

        final boxing = Exercise.getById('boxing')!;
        final boxingMedia = mediaService.resolveMedia(boxing);
        expect(boxingMedia.mediaType, 'image');
        expect(boxingMedia.url, contains('USMC-100509-M-2339L-173.jpg'));

        // Batch 4B - Mobility
        final catCow = Exercise.getById('cat_cow_stretch')!;
        final catCowMedia = mediaService.resolveMedia(catCow);
        expect(catCowMedia.mediaType, 'image');
        expect(catCowMedia.url, contains('Bitilasana.jpg'));

        final worldGreatest = Exercise.getById('world_greatest_stretch')!;
        final worldGreatestMedia = mediaService.resolveMedia(worldGreatest);
        expect(worldGreatestMedia.mediaType, 'image');
        expect(worldGreatestMedia.url, contains('Parivritta_Anjaneyasana.jpg'));

        final foamRolling = Exercise.getById('foam_rolling_full_body')!;
        final foamRollingMedia = mediaService.resolveMedia(foamRolling);
        expect(foamRollingMedia.mediaType, 'image');
        expect(foamRollingMedia.url, contains('masa%C5%BCu3.jpg'));

        final doorwayChest = Exercise.getById('doorway_chest_stretch')!;
        final doorwayChestMedia = mediaService.resolveMedia(doorwayChest);
        expect(doorwayChestMedia.mediaType, 'gif');
        expect(
          doorwayChestMedia.url,
          contains('Chest_stretch-CDC_strength_training_for_older_adults.gif'),
        );

        final hipFlexor = Exercise.getById('hip_flexor_stretch')!;
        final hipFlexorMedia = mediaService.resolveMedia(hipFlexor);
        expect(hipFlexorMedia.mediaType, 'gif');
        expect(
          hipFlexorMedia.url,
          contains('Lunge-CDC_strength_training_for_older_adults.gif'),
        );

        final couch = Exercise.getById('couch_stretch')!;
        final couchMedia = mediaService.resolveMedia(couch);
        expect(couchMedia.mediaType, 'gif');
        expect(
          couchMedia.url,
          contains('Quad_stretch-CDC_strength_training_for_older_adults.gif'),
        );
      },
    );

    testWidgets(
      'ExerciseDetailScreen loads each of the 72 exercises without error',
      (tester) async {
        for (final id in allPopulatedExerciseIds) {
          final ex = Exercise.getById(id)!;

          await tester.pumpWidget(
            MaterialApp(
              home: ExerciseDetailScreen(
                exercise: ex,
                enableWorkoutStart: false,
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 50));

          expect(find.text(ex.name), findsAtLeastNWidgets(1));
          expect(find.byType(ExerciseVideoPlayer), findsOneWidget);
          expect(find.text('How To Perform'), findsOneWidget);
        }
      },
    );

    testWidgets('ExerciseVideoPlayer triggers fullscreen toggle callback', (
      tester,
    ) async {
      final bench = Exercise.getById('bench_press')!;
      bool fullscreenToggled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExerciseVideoPlayer(
              exercise: bench,
              autoPlay: false,
              showControls: true,
              onFullscreenToggle: () {
                fullscreenToggled = true;
              },
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      final fullscreenFinder = find.byIcon(Icons.fullscreen_rounded);
      expect(fullscreenFinder, findsOneWidget);

      await tester.tap(fullscreenFinder);
      await tester.pump(const Duration(milliseconds: 50));
      expect(fullscreenToggled, isTrue);
    });

    testWidgets(
      'Fallback delivers value-adding structured copy when exercise has no media',
      (tester) async {
        const fallbackEx = Exercise(
          id: 'unpopulated_exercise',
          name: 'Custom Core Drill',
          category: 'core',
          primaryMuscles: ['Abs'],
        );

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ExerciseVideoPlayer(
                exercise: fallbackEx,
                autoPlay: false,
                showControls: true,
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.byKey(const Key('no_demonstration')), findsOneWidget);
        expect(find.text('VISUAL CUES'), findsOneWidget);
        expect(
          find.text(
            'Atlas provides: ✓ Instructions  ✓ Muscles  ✓ Mistakes  ✓ Tips',
          ),
          findsOneWidget,
        );
      },
    );

    test(
      'Exercise model exposes required fields and media getter for AI Form Coach',
      () {
        final bench = Exercise.getById('bench_press')!;
        expect(bench.exerciseId, 'bench_press');
        expect(bench.name, 'Barbell Bench Press');
        expect(bench.movementPattern, isNotEmpty);
        expect(bench.equipment, isNotEmpty);
        expect(bench.instructions, isNotEmpty);
        expect(bench.commonMistakes, isNotEmpty);
        expect(bench.media, isNotNull);
        expect(bench.media.mediaType, 'video');
        expect(
          bench.media.url,
          contains('Bench_press_-_exercise_demonstration_video.webm'),
        );
      },
    );
  });
}
