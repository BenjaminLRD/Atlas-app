import 'package:atlas/data/app_dependencies.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/exercise.dart';
import 'package:atlas/screens/weekly_workout_plan_screen.dart';
import 'package:atlas/screens/workout_overview_screen.dart';
import 'package:atlas/services/exercise_media_service.dart';
import 'package:atlas/widgets/common/app_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wikimedia only serves thumbnails at fixed widths; other widths (such as
/// 800px) answer HTTP 400, which left exercises without a picture.
const _supportedThumbWidths = {20, 40, 60, 120, 250, 330, 500, 960, 1280};

int? _thumbWidth(String url) {
  final match = RegExp(r'/(\d+)px-[^/]+$').firstMatch(url);
  return match == null ? null : int.parse(match.group(1)!);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    AppDependencies.reset();
  });

  group('exercise image data', () {
    test('every registry exercise has an image', () {
      final registry = Exercise.defaultRegistry();
      expect(registry.length, 72);
      final missing = registry
          .where((e) => (e.imageUrl ?? '').trim().isEmpty)
          .map((e) => e.id)
          .toList();
      expect(missing, isEmpty);
    });

    test('Wikimedia thumbnails use a width the server accepts', () {
      final bad = <String>[];
      for (final e in Exercise.defaultRegistry()) {
        for (final url in [e.imageUrl, e.animationAsset]) {
          if (url == null || !url.contains('upload.wikimedia.org')) continue;
          final width = _thumbWidth(url);
          if (width != null && !_supportedThumbWidths.contains(width)) {
            bad.add('${e.id}: ${width}px');
          }
        }
      }
      expect(bad, isEmpty);
    });

    test('media resolution prefers video, then animation, then image', () {
      final service = ExerciseMediaService();
      final bench = Exercise.getById('bench_press')!;
      final fly = Exercise.getById('dumbbell_chest_fly')!;
      final curl = Exercise.getById('concentration_curl')!;
      expect(service.resolveMedia(bench).mediaType, 'video');
      expect(service.resolveMedia(fly).mediaType, 'gif');
      expect(service.resolveMedia(curl).mediaType, 'image');
      expect(service.resolveMedia(curl).url, curl.imageUrl);
    });
  });

  group('Showcase Mode exercises', () {
    test(
      'every exercise in the showcase weekly plan has a usable image',
      () async {
        await LocalStorage.setShowcaseModeEnabled(true);
        final names = <String>{};
        final problems = <String>[];
        for (final plan in buildWeeklyPlans()) {
          for (final ex in plan.structuredExercises) {
            final name = ex['name'].toString();
            if (!names.add(name)) continue;
            final url = (ex['imageUrl'] ?? '').toString();
            if (url.isEmpty) problems.add('$name: no image');
            final width = _thumbWidth(url);
            if (width != null && !_supportedThumbWidths.contains(width)) {
              problems.add('$name: unsupported ${width}px thumbnail');
            }
          }
        }
        expect(names, isNotEmpty);
        expect(problems, isEmpty, reason: 'checked ${names.length}: $names');
      },
    );
  });

  group('image widgets', () {
    testWidgets('a missing image shows the fallback tile, not an error', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppImage.exercise(size: 56, exerciseName: 'Mystery Lift'),
          ),
        ),
      );
      expect(find.byIcon(Icons.fitness_center_rounded), findsOneWidget);
      expect(tester.getSize(find.byType(AppImage)), const Size(56, 56));
      expect(tester.takeException(), isNull);
    });

    testWidgets('overview tiles reserve the thumbnail space and fall back', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      Map<String, dynamic> ex(String name, {String? image}) => {
        'id': name,
        'name': name,
        'primaryTarget': 'Quads',
        'imageUrl': image,
        'sets': [
          {'reps': 8, 'weight': 40.0, 'completed': false},
        ],
        'reps': 8,
      };
      await tester.pumpWidget(
        MaterialApp(
          home: WorkoutOverviewScreen(
            planBuilder: () => [
              DailyPlan(
                dayName: 'MONDAY',
                date: '1',
                title: 'Legs',
                duration: '45 mins',
                muscleGroups: 'Quads',
                exercises: const [],
                structuredExercises: [ex('No Picture Squat'), ex('Lunge')],
                isToday: true,
                focus: 'legs',
                durationMinutes: 45,
              ),
            ],
            activeSessionReader: () => null,
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('exercise_image_0')), findsOneWidget);
      expect(find.byKey(const Key('exercise_image_1')), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const Key('exercise_image_0'))),
        const Size(56, 56),
      );
      expect(find.byIcon(Icons.fitness_center_rounded), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}
