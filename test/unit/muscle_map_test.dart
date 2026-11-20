import 'package:atlas/models/exercise.dart';
import 'package:atlas/services/exercise/muscle_map.dart';
import 'package:atlas/widgets/exercise/muscle_body_painter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalogue = Exercise.defaultRegistry();

  group('Catalogue coverage', () {
    test(
      'every exercise has a muscle map, and nothing is silently dropped',
      () {
        expect(catalogue.length, 72);
        for (final e in catalogue) {
          final a = MuscleMap.forExercise(e);
          expect(a.isComplete, isTrue, reason: '${e.id} has no muscle map');
          expect(
            a.unmapped,
            isEmpty,
            reason: '${e.id}: unplaced names ${a.unmapped}',
          );
          // Everything left out of the figure is a documented non-muscle name.
          for (final name in a.ignored) {
            final lower = name.toLowerCase();
            expect(
              MuscleMap.ignoredNames.any(lower.startsWith),
              isTrue,
              reason: '${e.id}: "$name" is ignored but not documented',
            );
          }
          expect(
            a.primary.intersection(a.secondary),
            isEmpty,
            reason: '${e.id}: a region cannot be both primary and secondary',
          );
        }
      },
    );

    test(
      'full-body exercises are marked general, not given invented muscles',
      () {
        for (final id in ['hiit_circuit', 'rowing_intervals', 'jogging']) {
          final a = MuscleMap.forExercise(
            catalogue.firstWhere((e) => e.id == id),
          );
          expect(a.general, isTrue, reason: id);
          expect(a.primary, isEmpty, reason: '$id must not invent a muscle');
        }
      },
    );

    test('names that are not muscles are ignored, never turned into one', () {
      final run = MuscleMap.forExercise(
        catalogue.firstWhere((e) => e.id == 'treadmill_run'),
      );
      expect(
        run.ignored.map((s) => s.toLowerCase()),
        contains('cardiovascular'),
      );
      expect(
        run.primary,
        containsAll({MuscleRegion.quads, MuscleRegion.hamstrings}),
      );
    });
  });

  group('Primary and secondary', () {
    MuscleActivation of(String id) =>
        MuscleMap.forExercise(catalogue.firstWhere((e) => e.id == id));

    test('bench press', () {
      final a = of('bench_press');
      expect(a.primary, {MuscleRegion.chest, MuscleRegion.triceps});
      expect(a.secondary, {MuscleRegion.frontDelts});
      expect(a.roleOf(MuscleRegion.chest), MuscleRole.primary);
      expect(a.roleOf(MuscleRegion.frontDelts), MuscleRole.secondary);
      expect(a.roleOf(MuscleRegion.quads), MuscleRole.none);
    });

    test('squat and curl', () {
      expect(of('barbell_back_squat').primary, {
        MuscleRegion.quads,
        MuscleRegion.glutes,
      });
      expect(
        of('barbell_back_squat').secondary,
        contains(MuscleRegion.hamstrings),
      );
      expect(of('bicep_curl').primary, {MuscleRegion.biceps});
      expect(of('bicep_curl').secondary, {MuscleRegion.forearms});
    });

    test('rear delts and lateral raise are told apart', () {
      expect(of('lateral_raise').primary, {MuscleRegion.sideDelts});
      expect(of('rear_delt_fly').primary, contains(MuscleRegion.rearDelts));
      expect(
        of('rear_delt_fly').primary,
        isNot(contains(MuscleRegion.sideDelts)),
      );
    });

    test('lateral does not get read as lats', () {
      expect(
        MuscleMap.regionsForName('Lateral Head'),
        isNot(contains(MuscleRegion.lats)),
      );
      expect(MuscleMap.regionsForName('Lats'), [MuscleRegion.lats]);
    });
  });

  group('Workout level', () {
    test('combines the exercises of a workout', () {
      final map = MuscleMap.forWorkout([
        {'id': 'bench_press', 'name': 'Bench'},
        {'id': 'barbell_back_squat', 'name': 'Squat'},
      ]);
      expect(
        map.primary,
        containsAll({
          MuscleRegion.chest,
          MuscleRegion.triceps,
          MuscleRegion.quads,
        }),
      );
      expect(map.primary, isNot(contains(MuscleRegion.biceps)));
    });

    test('a muscle that is primary in one exercise is not also secondary', () {
      final map = MuscleMap.forWorkout([
        {'id': 'bench_press'}, // front delts secondary
        {'id': 'overhead_press'}, // front delts primary
      ]);
      expect(map.primary, contains(MuscleRegion.frontDelts));
      expect(map.secondary, isNot(contains(MuscleRegion.frontDelts)));
    });

    test('a plan entry outside the catalogue uses its own muscle text', () {
      final a = MuscleMap.forPlanExercise({
        'id': 'my_custom_move',
        'primaryTarget': 'Quads',
      });
      expect(a.primary, {MuscleRegion.quads});
    });

    test(
      'an exercise nothing can place is flagged incomplete, not guessed',
      () {
        final a = MuscleMap.forPlanExercise({
          'id': 'mystery',
          'primaryTarget': 'Flux Capacitor',
        });
        expect(a.isComplete, isFalse);
        expect(a.unmapped, contains('Flux Capacitor'));
        expect(a.primary, isEmpty);
      },
    );
  });

  group('Views', () {
    MuscleActivation of(String id) =>
        MuscleMap.forExercise(catalogue.firstWhere((e) => e.id == id));

    test('exercises that show on one side only have no switch', () {
      for (final id in [
        'leg_extension',
        'cable_chest_fly',
        'dumbbell_chest_fly',
      ]) {
        final a = of(id);
        expect(a.availableViews, {MuscleView.front}, reason: id);
        expect(a.hasBothViews, isFalse, reason: id);
        expect(a.defaultView, MuscleView.front);
      }
    });

    test('exercises that need both sides have the switch', () {
      expect(of('bench_press').hasBothViews, isTrue); // chest + triceps
      expect(of('barbell_back_squat').hasBothViews, isTrue);
    });

    test('back-dominant work opens on the back', () {
      expect(of('lat_pulldown').defaultView, MuscleView.back);
      expect(of('romanian_deadlift').defaultView, MuscleView.back);
    });

    test('a region is drawn on exactly the sides it declares', () {
      for (final view in MuscleView.values) {
        final drawn = MuscleBodyGeometry.regionsFor(view).keys.toSet();
        final declared = MuscleRegion.values
            .where((r) => r.views.contains(view))
            .toSet();
        expect(drawn, declared, reason: view.name);
      }
    });

    test('every drawn region sits inside the figure box', () {
      for (final view in MuscleView.values) {
        for (final e in MuscleBodyGeometry.regionsFor(view).entries) {
          final b = e.value.getBounds();
          expect(b.isEmpty, isFalse, reason: '${e.key}');
          expect(b.left, greaterThanOrEqualTo(0));
          expect(b.right, lessThanOrEqualTo(MuscleBodyGeometry.width));
          expect(b.bottom, lessThanOrEqualTo(MuscleBodyGeometry.height));
        }
      }
    });
  });
}
