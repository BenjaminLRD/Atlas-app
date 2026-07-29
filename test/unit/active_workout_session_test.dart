import 'package:flutter_test/flutter_test.dart';
import 'package:aizawl_gym/models/active_workout_session.dart';

void main() {
  group('ActiveWorkoutSession Model Tests', () {
    test('serialization and deserialization round trip', () {
      final session = ActiveWorkoutSession(
        workoutName: 'Leg Day Blast',
        workoutId: 'leg_day_01',
        currentIndex: 2,
        seconds: 420,
        isPaused: true,
        completedSets: [
          [true, true, true, false],
          [true, true, false, false],
        ],
      );

      final json = session.toJson();
      expect(json['workoutName'], equals('Leg Day Blast'));
      expect(json['workoutId'], equals('leg_day_01'));
      expect(json['currentIndex'], equals(2));
      expect(json['seconds'], equals(420));
      expect(json['isPaused'], isTrue);

      final restored = ActiveWorkoutSession.fromJson(json);
      expect(restored.workoutName, equals('Leg Day Blast'));
      expect(restored.workoutId, equals('leg_day_01'));
      expect(restored.currentIndex, equals(2));
      expect(restored.seconds, equals(420));
      expect(restored.isPaused, isTrue);
      expect(restored.completedSets.length, equals(2));
      expect(restored.completedSets[0], equals([true, true, true, false]));
    });

    test('backward compatibility with old saved sessions without workout identity', () {
      final legacyJson = {
        'currentIndex': 1,
        'seconds': 180,
        'isPaused': false,
        'completedSets': [
          [true, true],
        ],
      };

      final restored = ActiveWorkoutSession.fromJson(legacyJson);

      // Should default workoutName safely to 'Workout Session'
      expect(restored.workoutName, equals('Workout Session'));
      expect(restored.workoutId, null);
      expect(restored.currentIndex, equals(1));
      expect(restored.seconds, equals(180));
      expect(restored.isPaused, isFalse);
      expect(restored.completedSets.length, equals(1));
    });

    test('operator [] and []= accessors preserve compatibility', () {
      final session = ActiveWorkoutSession(
        currentIndex: 0,
        seconds: 0,
        isPaused: false,
        completedSets: [],
      );

      session['workoutName'] = 'Chest & Triceps';
      session['seconds'] = 300;

      expect(session['workoutName'], equals('Chest & Triceps'));
      expect(session.workoutName, equals('Chest & Triceps'));
      expect(session['seconds'], equals(300));
      expect(session.seconds, equals(300));
    });
  });
}
