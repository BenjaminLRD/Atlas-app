/// The one illustration shown for each exercise in lists, cards and the
/// workout screen.
///
/// Every thumbnail is a static image rendered once from the same figure
/// (see tool/exercise_thumbnails): a green humanoid on Atlas's charcoal
/// background, in the pose that makes the exercise recognisable. Nothing here
/// is a photograph, a stock image or a frame from someone else's video, and
/// nothing is drawn when a screen opens.
///
/// An exercise without an entry (a custom one the user added) gets no
/// picture, never somebody else's, and the caller shows a plain icon tile.
class ExerciseThumbnails {
  const ExerciseThumbnails._();

  /// Exercise id to its thumbnail asset. Each exercise has exactly one.
  static const Map<String, String> assets = {
    'bench_press': 'assets/exercises/thumb_bench_press.webp',
    'incline_bench_press': 'assets/exercises/thumb_incline_bench_press.webp',
    'dumbbell_bench_press': 'assets/exercises/thumb_dumbbell_bench_press.webp',
    'incline_dumbbell_press':
        'assets/exercises/thumb_incline_dumbbell_press.webp',
    'cable_chest_fly': 'assets/exercises/thumb_cable_chest_fly.webp',
    'dumbbell_chest_fly': 'assets/exercises/thumb_dumbbell_chest_fly.webp',
    'chest_press_machine': 'assets/exercises/thumb_chest_press_machine.webp',
    'push_ups': 'assets/exercises/thumb_push_ups.webp',
    'chest_dips': 'assets/exercises/thumb_chest_dips.webp',
    'overhead_press': 'assets/exercises/thumb_overhead_press.webp',
    'dumbbell_shoulder_press':
        'assets/exercises/thumb_dumbbell_shoulder_press.webp',
    'lateral_raise': 'assets/exercises/thumb_lateral_raise.webp',
    'cable_lateral_raise': 'assets/exercises/thumb_cable_lateral_raise.webp',
    'rear_delt_fly': 'assets/exercises/thumb_rear_delt_fly.webp',
    'face_pulls': 'assets/exercises/thumb_face_pulls.webp',
    'arnold_press': 'assets/exercises/thumb_arnold_press.webp',
    'conventional_deadlift':
        'assets/exercises/thumb_conventional_deadlift.webp',
    'pull_ups': 'assets/exercises/thumb_pull_ups.webp',
    'chin_ups': 'assets/exercises/thumb_chin_ups.webp',
    'lat_pulldown': 'assets/exercises/thumb_lat_pulldown.webp',
    'barbell_row': 'assets/exercises/thumb_barbell_row.webp',
    'dumbbell_row': 'assets/exercises/thumb_dumbbell_row.webp',
    'seated_cable_row': 'assets/exercises/thumb_seated_cable_row.webp',
    'bicep_curl': 'assets/exercises/thumb_bicep_curl.webp',
    'barbell_bicep_curl': 'assets/exercises/thumb_barbell_bicep_curl.webp',
    'hammer_curl': 'assets/exercises/thumb_hammer_curl.webp',
    'tricep_pushdown': 'assets/exercises/thumb_tricep_pushdown.webp',
    'skull_crushers': 'assets/exercises/thumb_skull_crushers.webp',
    'preacher_curl': 'assets/exercises/thumb_preacher_curl.webp',
    'concentration_curl': 'assets/exercises/thumb_concentration_curl.webp',
    'incline_dumbbell_curl':
        'assets/exercises/thumb_incline_dumbbell_curl.webp',
    'cable_bicep_curl': 'assets/exercises/thumb_cable_bicep_curl.webp',
    'overhead_tricep_extension':
        'assets/exercises/thumb_overhead_tricep_extension.webp',
    'tricep_kickbacks': 'assets/exercises/thumb_tricep_kickbacks.webp',
    'barbell_back_squat': 'assets/exercises/thumb_barbell_back_squat.webp',
    'bodyweight_squat': 'assets/exercises/thumb_bodyweight_squat.webp',
    'romanian_deadlift': 'assets/exercises/thumb_romanian_deadlift.webp',
    'dumbbell_goblet_squat':
        'assets/exercises/thumb_dumbbell_goblet_squat.webp',
    'dumbbell_rdl': 'assets/exercises/thumb_dumbbell_rdl.webp',
    'leg_press': 'assets/exercises/thumb_leg_press.webp',
    'leg_extension': 'assets/exercises/thumb_leg_extension.webp',
    'hamstring_curl': 'assets/exercises/thumb_hamstring_curl.webp',
    'bulgarian_split_squat':
        'assets/exercises/thumb_bulgarian_split_squat.webp',
    'standing_calf_raise': 'assets/exercises/thumb_standing_calf_raise.webp',
    'seated_calf_raise': 'assets/exercises/thumb_seated_calf_raise.webp',
    'calf_press_leg_press': 'assets/exercises/thumb_calf_press_leg_press.webp',
    'walking_lunges': 'assets/exercises/thumb_walking_lunges.webp',
    'hanging_leg_raise': 'assets/exercises/thumb_hanging_leg_raise.webp',
    'plank': 'assets/exercises/thumb_plank.webp',
    'outdoor_run': 'assets/exercises/thumb_outdoor_run.webp',
    'treadmill_run': 'assets/exercises/thumb_treadmill_run.webp',
    'sprint_intervals': 'assets/exercises/thumb_sprint_intervals.webp',
    'jogging': 'assets/exercises/thumb_jogging.webp',
    'stationary_bike': 'assets/exercises/thumb_stationary_bike.webp',
    'outdoor_cycling': 'assets/exercises/thumb_outdoor_cycling.webp',
    'hiit_cycling': 'assets/exercises/thumb_hiit_cycling.webp',
    'rowing_machine': 'assets/exercises/thumb_rowing_machine.webp',
    'rowing_intervals': 'assets/exercises/thumb_rowing_intervals.webp',
    'jump_rope': 'assets/exercises/thumb_jump_rope.webp',
    'burpees': 'assets/exercises/thumb_burpees.webp',
    'mountain_climbers': 'assets/exercises/thumb_mountain_climbers.webp',
    'hiit_circuit': 'assets/exercises/thumb_hiit_circuit.webp',
    'football': 'assets/exercises/thumb_football.webp',
    'basketball': 'assets/exercises/thumb_basketball.webp',
    'swimming': 'assets/exercises/thumb_swimming.webp',
    'boxing': 'assets/exercises/thumb_boxing.webp',
    'cat_cow_stretch': 'assets/exercises/thumb_cat_cow_stretch.webp',
    'world_greatest_stretch':
        'assets/exercises/thumb_world_greatest_stretch.webp',
    'foam_rolling_full_body':
        'assets/exercises/thumb_foam_rolling_full_body.webp',
    'doorway_chest_stretch':
        'assets/exercises/thumb_doorway_chest_stretch.webp',
    'hip_flexor_stretch': 'assets/exercises/thumb_hip_flexor_stretch.webp',
    'couch_stretch': 'assets/exercises/thumb_couch_stretch.webp',
  };

  /// Asset path for [exerciseId], or null if it has no thumbnail.
  static String? assetFor(String exerciseId) => assets[exerciseId];

  /// Exercises that deliberately share a thumbnail (none at present). A shared
  /// picture is allowed only if it is listed here.
  static const Set<String> intentionallyShared = {};
}
