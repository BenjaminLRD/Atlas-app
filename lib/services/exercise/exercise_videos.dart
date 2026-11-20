import '../../models/exercise.dart';

/// One verified YouTube demonstration of an exercise.
///
/// The title and channel are what YouTube itself reported for the video on
/// [ExerciseVideos.verifiedOn] (through its public oEmbed endpoint), so the
/// entry can be checked against the real video. [matchTerms] are words that
/// must appear in that title for the video to count as showing this exercise;
/// a test enforces it so a wrong id cannot slip in unnoticed.
class ExerciseVideo {
  final String videoId;
  final String title;
  final String channel;
  final List<String> matchTerms;

  const ExerciseVideo({
    required this.videoId,
    required this.title,
    required this.channel,
    required this.matchTerms,
  });

  /// The page for this video on youtube.com.
  Uri get watchUri => Uri.https('www.youtube.com', '/watch', {'v': videoId});

  /// An 11-character YouTube video id.
  static final RegExp idPattern = RegExp(r'^[A-Za-z0-9_-]{11}$');
}

/// Which exercises have a verified YouTube demonstration, and which do not.
///
/// The built-in form animations remain the default and work offline; a video is
/// an optional extra, opened in the YouTube app or the browser. Nothing is
/// downloaded or re-hosted, and an exercise with no verified video says so
/// instead of linking something unrelated.
class ExerciseVideos {
  const ExerciseVideos._();

  /// The date every entry below was checked against YouTube.
  static const String verifiedOn = '2026-11-16';

  static const Map<String, ExerciseVideo> byExerciseId = {
    "bench_press": ExerciseVideo(
      videoId: "4Y2ZdHCOXok",
      title: "How to PROPERLY Bench Press for Growth (5 Easy Steps)",
      channel: "Jeremy Ethier",
      matchTerms: ["bench press"],
    ),
    "incline_bench_press": ExerciseVideo(
      videoId: "SrqOu55lrYU",
      title:
          "How To: Incline Barbell Bench Press | 3 GOLDEN RULES! (MADE BETTER!)",
      channel: "ScottHermanFitness",
      matchTerms: ["incline", "bench"],
    ),
    "dumbbell_bench_press": ExerciseVideo(
      videoId: "5Y3VZsLb1Ys",
      title: "How To Do Dumbbell Bench Press Correctly",
      channel: "Jack Hanrahan Fitness",
      matchTerms: ["dumbbell bench press"],
    ),
    "incline_dumbbell_press": ExerciseVideo(
      videoId: "8iPEnn-ltC8",
      title: "How To: Dumbbell Incline Chest Press",
      channel: "ScottHermanFitness",
      matchTerms: ["dumbbell", "incline"],
    ),
    "cable_chest_fly": ExerciseVideo(
      videoId: "JUDTGZh4rhg",
      title: "STOP F*cking Up Cable Flys (PROPER FORM!)",
      channel: "ATHLEAN-X™",
      matchTerms: ["cable"],
    ),
    "dumbbell_chest_fly": ExerciseVideo(
      videoId: "QENKPHhQVi4",
      title: "How to Properly Do a DUMBBELL FLY | Mind Pump",
      channel: "Mind Pump TV",
      matchTerms: ["dumbbell fly"],
    ),
    "chest_press_machine": ExerciseVideo(
      videoId: "xUm0BiZCWlQ",
      title: "How To: Chest Press (Cybex)",
      channel: "ScottHermanFitness",
      matchTerms: ["chest press"],
    ),
    "push_ups": ExerciseVideo(
      videoId: "IODxDxX7oi4",
      title: "The Perfect Push Up | Do it right!",
      channel: "Calisthenicmovement",
      matchTerms: ["push up"],
    ),
    "chest_dips": ExerciseVideo(
      videoId: "vi1-BOcj3cQ",
      title: "Are You Doing Dips Properly? (AVOID MISTAKES!)",
      channel: "ATHLEAN-X™",
      matchTerms: ["dips"],
    ),
    "overhead_press": ExerciseVideo(
      videoId: "2yjwXTZQDDI",
      title: "How To: Standing Straight-Bar Military / Overhead Press",
      channel: "ScottHermanFitness",
      matchTerms: ["overhead press"],
    ),
    "dumbbell_shoulder_press": ExerciseVideo(
      videoId: "rO_iEImwHyo",
      title:
          "How to do the SEATED DUMBBELL SHOULDER PRESS! | 2 Minute Tutorial",
      channel: "Max Euceda",
      matchTerms: ["dumbbell shoulder press"],
    ),
    "lateral_raise": ExerciseVideo(
      videoId: "PzsMitRdI_8",
      title: "How to do the DUMBBELL LATERAL RAISE! | 2 Minute Tutorial",
      channel: "Max Euceda",
      matchTerms: ["lateral raise"],
    ),
    "cable_lateral_raise": ExerciseVideo(
      videoId: "Sp8be0IFNvk",
      title: "How to Fix your Cable Lateral Raise | DB vs. CABLE",
      channel: "John Jewett",
      matchTerms: ["cable lateral raise"],
    ),
    "rear_delt_fly": ExerciseVideo(
      videoId: "buuYPLVXsJg",
      title:
          "How to PROPERLY Dumbbell Rear Delt Fly | Reverse Dumbbell Fly Tutorial",
      channel: "Colossus Fitness",
      matchTerms: ["rear delt fly"],
    ),
    "face_pulls": ExerciseVideo(
      videoId: "ljgqer1ZpXg",
      title: "STOP F*cking Up Face Pulls (PROPER FORM!)",
      channel: "ATHLEAN-X™",
      matchTerms: ["face pulls"],
    ),
    "arnold_press": ExerciseVideo(
      videoId: "Tux8PGVa9wQ",
      title: "How to do the SEATED DUMBBELL ARNOLD PRESS! | 2 Minute Tutorial",
      channel: "Max Euceda",
      matchTerms: ["arnold press"],
    ),
    "conventional_deadlift": ExerciseVideo(
      videoId: "wYREQkVtvEc",
      title: "How To Deadlift: Starting Strength 5 Step Deadlift",
      channel: "Alan Thrall (Untamed Strength)",
      matchTerms: ["deadlift"],
    ),
    "pull_ups": ExerciseVideo(
      videoId: "eGo4IYlbE5g",
      title: "The Perfect Pull Up  - Do it right!",
      channel: "Calisthenicmovement",
      matchTerms: ["pull up"],
    ),
    "chin_ups": ExerciseVideo(
      videoId: "e1YSApl-QcM",
      title:
          "PERFECT CHIN-UPS | The Only Chin-up Tutorial You'll Ever Need (Full Guide)",
      channel: "Simonster Strength",
      matchTerms: ["chin-up"],
    ),
    "lat_pulldown": ExerciseVideo(
      videoId: "SALxEARiMkw",
      title: "How to do Lat Pulldowns (AVOID MISTAKES!)",
      channel: "ATHLEAN-X™",
      matchTerms: ["lat pulldown"],
    ),
    "barbell_row": ExerciseVideo(
      videoId: "9efgcAjQe7E",
      title: "How To: Barbell Bent-Over Row",
      channel: "ScottHermanFitness",
      matchTerms: ["row"],
    ),
    "dumbbell_row": ExerciseVideo(
      videoId: "gfUg6qWohTk",
      title: "STOP F*cking Up Dumbbell Rows (PROPER FORM!)",
      channel: "ATHLEAN-X™",
      matchTerms: ["dumbbell row"],
    ),
    "seated_cable_row": ExerciseVideo(
      videoId: "xQNrFHEMhI4",
      title: "Seated Cable Row | Exercise Guide",
      channel: "Bodybuilding.com",
      matchTerms: ["seated cable row"],
    ),
    "bicep_curl": ExerciseVideo(
      videoId: "in7PaeYlhrM",
      title: "The ONLY Way You Should Be Doing Dumbbell Bicep Curls!",
      channel: "Mind Pump TV",
      matchTerms: ["dumbbell bicep curl"],
    ),
    "barbell_bicep_curl": ExerciseVideo(
      videoId: "QZEqB6wUPxQ",
      title: "How To: Barbell Bicep Curl | 3 GOLDEN RULES",
      channel: "ScottHermanFitness",
      matchTerms: ["barbell bicep curl"],
    ),
    "hammer_curl": ExerciseVideo(
      videoId: "zC3nLlEvin4",
      title: "How To: Dumbbell Hammer Curl",
      channel: "ScottHermanFitness",
      matchTerms: ["hammer curl"],
    ),
    "tricep_pushdown": ExerciseVideo(
      videoId: "_w-HpW70nSQ",
      title: "HOW TO: Cable Triceps Pushdown || 3 Golden Rules (FOR GROWTH)",
      channel: "ScottHermanFitness",
      matchTerms: ["pushdown"],
    ),
    "skull_crushers": ExerciseVideo(
      videoId: "d_KZxkY_0cM",
      title: "How To: Skull Crushers",
      channel: "ScottHermanFitness",
      matchTerms: ["skull crusher"],
    ),
    "preacher_curl": ExerciseVideo(
      videoId: "Gydpcouclx8",
      title: "Conquer the EZ-Bar Preacher Curl, Max Out Your Biceps",
      channel: "Men's Health",
      matchTerms: ["preacher curl"],
    ),
    "concentration_curl": ExerciseVideo(
      videoId: "Jvj2wV0vOYU",
      title: "How To: Dumbbell Concentration Curl",
      channel: "ScottHermanFitness",
      matchTerms: ["concentration curl"],
    ),
    "incline_dumbbell_curl": ExerciseVideo(
      videoId: "soxrZlIl35U",
      title: "How To: Seated Incline Dumbbell Bicep Curl",
      channel: "ScottHermanFitness",
      matchTerms: ["incline", "curl"],
    ),
    "cable_bicep_curl": ExerciseVideo(
      videoId: "ppcIRaYJteI",
      title: "Cable Bicep Curls: The Secret to Massive Gains",
      channel: "Colossus Fitness",
      matchTerms: ["cable bicep curl"],
    ),
    "overhead_tricep_extension": ExerciseVideo(
      videoId: "-Vyt2QdsR7E",
      title: "How To: Standing Overhead Dumbbell Tricep Extension",
      channel: "ScottHermanFitness",
      matchTerms: ["overhead", "tricep extension"],
    ),
    "tricep_kickbacks": ExerciseVideo(
      videoId: "6SS6K3lAwZ8",
      title: "How To: Tricep Kickback (Dumbbell)",
      channel: "ScottHermanFitness",
      matchTerms: ["kickback"],
    ),
    "barbell_back_squat": ExerciseVideo(
      videoId: "gcNh17Ckjgg",
      title: "How to PROPERLY Squat for Growth (4 Easy Steps)",
      channel: "Jeremy Ethier",
      matchTerms: ["squat"],
    ),
    "bodyweight_squat": ExerciseVideo(
      videoId: "gsNoPYwWXeM",
      title: "Fix Your Squat (In Just 3-Minutes)",
      channel: "Calisthenicmovement",
      matchTerms: ["squat"],
    ),
    "romanian_deadlift": ExerciseVideo(
      videoId: "_oyxCn2iSjU",
      title:
          "HOW TO DO ROMANIAN DEADLIFTS (RDLs): Build Beefy Hamstrings With Perfect Technique",
      channel: "Jeff Nippard",
      matchTerms: ["romanian deadlift"],
    ),
    "dumbbell_goblet_squat": ExerciseVideo(
      videoId: "MeIiIdhvXT4",
      title: "How To: Goblet Squat",
      channel: "ScottHermanFitness",
      matchTerms: ["goblet squat"],
    ),
    "dumbbell_rdl": ExerciseVideo(
      videoId: "FQKfr1YDhEk",
      title: "How To: Dumbbell Romanian Deadlift",
      channel: "ScottHermanFitness",
      matchTerms: ["dumbbell romanian deadlift"],
    ),
    "leg_press": ExerciseVideo(
      videoId: "K5n2vg3oZa4",
      title: "How to PROPERLY Leg Press (FIX YOUR FORM NOW)",
      channel: "Colossus Fitness",
      matchTerms: ["leg press"],
    ),
    "leg_extension": ExerciseVideo(
      videoId: "ljO4jkwv8wQ",
      title:
          "How To Do Leg Extensions With Perfect Technique (Grow Every Quad Head)",
      channel: "Jeff Nippard",
      matchTerms: ["leg extension"],
    ),
    "hamstring_curl": ExerciseVideo(
      videoId: "q1cKTmaeQWo",
      title:
          "How to PROPERLY Hamstring Curl for Muscle Gain & Injury Prevention",
      channel: "Colossus Fitness",
      matchTerms: ["hamstring curl"],
    ),
    "bulgarian_split_squat": ExerciseVideo(
      videoId: "hiLF_pF3EJM",
      title: "Stop F*cking Up Bulgarian Split Squats (PROPER FORM!)",
      channel: "ATHLEAN-X™",
      matchTerms: ["bulgarian split squat"],
    ),
    "standing_calf_raise": ExerciseVideo(
      videoId: "SVtg-1loH4c",
      title: "How to PROPERLY Standing Calf Raise | Tips & Common Mistakes",
      channel: "Colossus Fitness",
      matchTerms: ["standing calf raise"],
    ),
    "seated_calf_raise": ExerciseVideo(
      videoId: "6O5hh1rBtx8",
      title: "How to PROPERLY Calf Raise (SEATED CALF RAISE TIPS)",
      channel: "Colossus Fitness",
      matchTerms: ["seated calf raise"],
    ),
    "calf_press_leg_press": ExerciseVideo(
      videoId: "PYZY00hI43w",
      title: "How to PROPERLY Calf Raise on The Leg Press Machine (FIX THIS!)",
      channel: "Colossus Fitness",
      matchTerms: ["leg press machine"],
    ),
    "walking_lunges": ExerciseVideo(
      videoId: "Pbmj6xPo-Hw",
      title: "Walking Lunges Exercise Tutorial | Build Legendary Legs & Cardio",
      channel: "Buff Dudes Workouts",
      matchTerms: ["walking lunge"],
    ),
    "hanging_leg_raise": ExerciseVideo(
      videoId: "Pr1ieGZ5atk",
      title: "Hanging Leg Raise | HOW-TO",
      channel: "ATHLEAN-X™",
      matchTerms: ["hanging leg raise"],
    ),
    "plank": ExerciseVideo(
      videoId: "F-nQ_KJgfCY",
      title: "STOP Doing Planks Like That!",
      channel: "Calisthenicmovement",
      matchTerms: ["plank"],
    ),
    "outdoor_run": ExerciseVideo(
      videoId: "_kGESn8ArrU",
      title: "How To Run Properly | Running Technique Explained",
      channel: "Global Triathlon Network",
      matchTerms: ["run"],
    ),
    "treadmill_run": ExerciseVideo(
      videoId: "P8fmIvqQEf4",
      title:
          "Mo’s Tips on Using a Treadmill | How to Win Like Mo | Mo Farah (2020)",
      channel: "Mo Farah",
      matchTerms: ["treadmill"],
    ),
    "sprint_intervals": ExerciseVideo(
      videoId: "2YogM9wXAJg",
      title: "HIIT vs HIRT | How to Do a Sprint Workout the RIGHT Way",
      channel: "Mark's Daily Apple",
      matchTerms: ["sprint"],
    ),
    "jogging": ExerciseVideo(
      videoId: "ZTBRQ5MEJsE",
      title:
          "Your Jogging Technique Matters! Slow Jogging Dos & Don'ts: Part 3",
      channel: "Slow Jogging",
      matchTerms: ["jogging"],
    ),
    "stationary_bike": ExerciseVideo(
      videoId: "csNeUKYBW0E",
      title:
          "How to Set up your Spinning® Bike | Quick, Easy & Proper Indoor Cycling Bike Setup & Basic Bike Fit",
      channel: "Studio SWEAT",
      matchTerms: ["bike"],
    ),
    "outdoor_cycling": ExerciseVideo(
      videoId: "hPcR6MQ5dJo",
      title: "How To Pedal | Cycling Technique",
      channel: "Global Cycling Network",
      matchTerms: ["cycling"],
    ),
    "hiit_cycling": ExerciseVideo(
      videoId: "TO1h5fbOLAA",
      title: "Quick HIIT Sprint Workout | 20 Minute Indoor Cycling Workout",
      channel: "GCN Training",
      matchTerms: ["hiit", "cycling"],
    ),
    "rowing_machine": ExerciseVideo(
      videoId: "4zWu1yuJ0_g",
      title:
          "Correct Rowing Machine Technique, Improve Your Rowing  | Concept2",
      channel: "concept2usa",
      matchTerms: ["rowing machine"],
    ),
    "rowing_intervals": ExerciseVideo(
      videoId: "mrexeRFo4UM",
      title: "Rowing Machine: Sprint & Cardio Technique",
      channel: "Training Tall",
      matchTerms: ["rowing machine", "sprint"],
    ),
    "jump_rope": ExerciseVideo(
      videoId: "u3zgHI8QnqE",
      title: "How To Jump Rope | The Right Way | Well+Good",
      channel: "Well+Good",
      matchTerms: ["jump rope"],
    ),
    "burpees": ExerciseVideo(
      videoId: "wS4OsJ4yzx4",
      title: "How To: Burpee",
      channel: "ScottHermanFitness",
      matchTerms: ["burpee"],
    ),
    "mountain_climbers": ExerciseVideo(
      videoId: "cnyTQDSE884",
      title: "How to Do Mountain Climbers | The Right Way | Well+Good",
      channel: "Well+Good",
      matchTerms: ["mountain climber"],
    ),
    "swimming": ExerciseVideo(
      videoId: "AQy_c30lNjI",
      title: "How To Swim Freestyle | Technique For Front Crawl Swimming",
      channel: "Global Triathlon Network",
      matchTerms: ["swim"],
    ),
    "boxing": ExerciseVideo(
      videoId: "7EHSN5T-ZQE",
      title: "How to Punch the Heavy Bag for Beginners | Part 1",
      channel: "Tony Jeffries",
      matchTerms: ["heavy bag"],
    ),
    "cat_cow_stretch": ExerciseVideo(
      videoId: "1Y0YjXS9sKI",
      title: "How to Do a Cat Cow Stretch: A Guide from Physical Therapists",
      channel: "Hinge Health",
      matchTerms: ["cat cow"],
    ),
    "world_greatest_stretch": ExerciseVideo(
      videoId: "-CiWQ2IvY34",
      title:
          "The World's Greatest Stretch (Mobility Exercise) by Squat University",
      channel: "Squat University",
      matchTerms: ["greatest stretch"],
    ),
    "foam_rolling_full_body": ExerciseVideo(
      videoId: "Oz4xHEgMaLY",
      title: "10 minute Full Body Foam Roller Routine I FOLLOW ALONG",
      channel: "Tom Peto Training",
      matchTerms: ["foam roller"],
    ),
    "doorway_chest_stretch": ExerciseVideo(
      videoId: "Dmm8_S23I74",
      title: "Doorway Pec and Shoulder Stretch with Dr. Raz",
      channel: "Center For Total Back Care",
      matchTerms: ["doorway"],
    ),
    "hip_flexor_stretch": ExerciseVideo(
      videoId: "Q4Ko275cluo",
      title: "Kneeling hip flexor stretch",
      channel: "Competitive EDGE PT (Short Form Content)",
      matchTerms: ["hip flexor"],
    ),
    "couch_stretch": ExerciseVideo(
      videoId: "eoPmgjyj9-Q",
      title: "Couch Stretch",
      channel: "Men's Health",
      matchTerms: ["couch stretch"],
    ),
  };

  /// Exercises with no suitable video, and why. Every exercise in the
  /// catalogue is in exactly one of [byExerciseId] and this map.
  static const Map<String, String> unavailable = {
    'hiit_circuit':
        'A circuit of many different movements, so no single demonstration '
        'fits it.',
    'football':
        'A sport, not one repeatable movement; no demonstration of this '
        'exercise could be matched exactly.',
    'basketball':
        'A sport, not one repeatable movement; no demonstration of this '
        'exercise could be matched exactly.',
  };

  static ExerciseVideo? forExercise(String exerciseId) =>
      byExerciseId[exerciseId];

  static ExerciseVideo? forExerciseObject(Exercise exercise) =>
      byExerciseId[exercise.id];

  static String? unavailableReason(String exerciseId) =>
      unavailable[exerciseId];
}
