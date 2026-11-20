// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/models/exercise.dart';

void main() {
  test('Print full 63-exercise media inventory', () {
    final registry = Exercise.defaultRegistry();
    print('TOTAL EXERCISES: ${registry.length}');

    final highPriorityIds = {
      'bench_press',
      'incline_bench_press',
      'dumbbell_bench_press',
      'barbell_back_squat',
      'conventional_deadlift',
      'romanian_deadlift',
      'pull_ups',
      'lat_pulldown',
      'overhead_press',
      'dumbbell_shoulder_press',
      'leg_press',
      'push_ups',
      'dumbbell_bicep_curl',
      'tricep_rope_pushdown',
      'barbell_row',
      'plank',
      'outdoor_run',
      'hiit_cycling',
    };

    final mediumPriorityCategories = {'chest', 'back', 'legs', 'shoulders', 'arms'};

    print('| Exercise Name | Exercise ID | Category | Current Media Status | Priority | Recommended Media Type |');
    print('|---|---|---|---|---|---|');

    for (final ex in registry) {
      String status;
      if (ex.videoUrl != null && ex.videoUrl!.isNotEmpty) {
        status = 'Video available';
      } else if (ex.animationAsset != null && ex.animationAsset!.isNotEmpty) {
        status = 'Animation available';
      } else if (ex.imageUrl != null && ex.imageUrl!.isNotEmpty) {
        status = 'Image reference (Asset: ${ex.imageUrl})';
      } else {
        status = 'Missing media';
      }

      String priority;
      if (highPriorityIds.contains(ex.id) || highPriorityIds.contains(ex.id.toLowerCase())) {
        priority = 'High';
      } else if (mediumPriorityCategories.contains(ex.category.toLowerCase()) || ex.isCompound) {
        priority = 'Medium';
      } else {
        priority = 'Low';
      }

      String recommended;
      if (ex.isCompound || ex.category == 'cardio' || ex.exerciseType == 'compound') {
        recommended = 'Video';
      } else if (ex.category == 'mobility' || ex.category == 'stretching' || ex.category == 'core') {
        recommended = 'GIF/animation';
      } else {
        recommended = 'GIF/animation';
      }

      print('| ${ex.name} | `${ex.id}` | ${ex.category.toUpperCase()} | $status | $priority | $recommended |');
    }
  });
}
