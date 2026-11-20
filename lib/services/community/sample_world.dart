import '../../widgets/community/community_avatar_helper.dart';
import 'sample_cardio.dart';

/// Demo content only. Every athlete, post, comment, like, PR and statistic in
/// this file is invented for the built-in sample community. None of it is a
/// measurement of a real person, and it must never be mixed into real user
/// records, rankings or challenges (see `SampleCommunity`).

class SamplePr {
  final String exercise;
  final double kg;
  final int reps;
  final int daysAgo;
  const SamplePr(this.exercise, this.kg, this.reps, this.daysAgo);
}

/// Scripted weekly and lifetime figures for the sample leaderboard.
class SampleStats {
  final int weeklyWorkouts;
  final int weeklyMinutes;
  final int avgDailySteps;
  final int streakDays;
  final int totalWorkouts;
  final double totalVolumeKg;
  final int challengesCompleted;
  const SampleStats({
    required this.weeklyWorkouts,
    required this.weeklyMinutes,
    required this.avgDailySteps,
    required this.streakDays,
    required this.totalWorkouts,
    required this.totalVolumeKg,
    required this.challengesCompleted,
  });
}

class SampleAthlete {
  final String key;
  final String username;
  final String name;
  final String avatar;
  final String rank;
  final String goal;
  final String level;
  final String style;
  final String schedule;
  final String location;
  final String bio;
  final String memberSince;
  final List<SamplePr> prs;
  final List<String> milestones;
  final SampleStats stats;
  const SampleAthlete({
    required this.key,
    required this.username,
    required this.name,
    required this.avatar,
    required this.rank,
    required this.goal,
    required this.level,
    required this.style,
    required this.schedule,
    required this.location,
    required this.bio,
    required this.memberSince,
    required this.prs,
    required this.milestones,
    required this.stats,
  });

  String get id => 'usr_$key';
}

class SampleComment {
  final String by;
  final String text;
  final int minutesAfter;
  const SampleComment(this.by, this.text, this.minutesAfter);
}

class SamplePost {
  final String athlete;
  final int n;
  final String type; // workout, meal, achievement, routine, progress
  final String title;
  final String caption;
  final int hoursAgo;
  final Map<String, dynamic> meta;
  final List<String> likedBy;
  final int extraLikes;
  final int saves;
  final List<SampleComment> comments;
  const SamplePost(
    this.athlete,
    this.n,
    this.type,
    this.title,
    this.caption,
    this.hoursAgo, {
    this.meta = const {},
    this.likedBy = const [],
    this.extraLikes = 0,
    this.saves = 0,
    this.comments = const [],
  });

  String get id => 'sp_${athlete}_$n';
}


class SampleWorld {
  const SampleWorld._();

  static String _av(int i) => CommunityAvatarHelper.defaultAvatars[i];

  static final List<SampleAthlete> athletes = [
    SampleAthlete(
      key: 'alex',
      username: 'alex.carter',
      name: 'Alex Carter',
      avatar: _av(0),
      rank: 'Diamond II',
      goal: 'Muscle gain (lean bulk)',
      level: 'Advanced',
      style: 'Five-day split with a heavy deadlift day',
      schedule: '6 am, five days a week',
      location: 'Aizawl',
      bio:
          'Dev by day, deadlifts at 6 am. Lean bulk, week 14. Bar speed over ego.',
      memberSince: 'Member for 14 months',
      prs: const [
        SamplePr('Barbell Deadlift', 140, 3, 2),
        SamplePr('Barbell Squat', 120, 5, 30),
        SamplePr('Bench Press', 95, 5, 45),
        SamplePr('Overhead Press', 60, 5, 60),
      ],
      milestones: const [
        '100 workouts logged',
        'Deadlift 1.75x bodyweight',
        '14-week lean bulk',
      ],
      stats: const SampleStats(
        weeklyWorkouts: 5,
        weeklyMinutes: 330,
        avgDailySteps: 8200,
        streakDays: 12,
        totalWorkouts: 104,
        totalVolumeKg: 412000,
        challengesCompleted: 7,
      ),
    ),
    SampleAthlete(
      key: 'maya',
      username: 'maya.chen',
      name: 'Maya Chen',
      avatar: _av(1),
      rank: 'Platinum I',
      goal: 'Strength (first powerlifting meet)',
      level: 'Advanced',
      style: 'Four-day upper/lower, peaking block',
      schedule: 'Mon, Tue, Thu, Sat evenings',
      location: 'Aizawl',
      bio:
          'Physio assistant. Squat is my favourite, bench is my enemy. First meet in February, 57 kg class.',
      memberSince: 'Member for 2 years',
      prs: const [
        SamplePr('Barbell Squat', 115, 3, 4),
        SamplePr('Barbell Deadlift', 130, 1, 20),
        SamplePr('Bench Press', 62.5, 5, 35),
        SamplePr('Overhead Press', 40, 5, 50),
      ],
      milestones: const [
        'Squat 2x bodyweight',
        'Meet entry confirmed',
        '200 workouts logged',
      ],
      stats: const SampleStats(
        weeklyWorkouts: 4,
        weeklyMinutes: 290,
        avgDailySteps: 7100,
        streakDays: 9,
        totalWorkouts: 211,
        totalVolumeKg: 530000,
        challengesCompleted: 9,
      ),
    ),
    SampleAthlete(
      key: 'daniel',
      username: 'daniel.kim',
      name: 'Daniel Kim',
      avatar: _av(2),
      rank: 'Elite',
      goal: 'Hypertrophy',
      level: 'Advanced',
      style: 'Six-day push/pull/legs, high volume',
      schedule: 'Lunch breaks and evenings',
      location: 'Aizawl',
      bio:
          'Spreadsheet guy. I log every set, so you do not have to. Chest day is a lifestyle.',
      memberSince: 'Member for 19 months',
      prs: const [
        SamplePr('Bench Press', 110, 5, 9),
        SamplePr('Incline Dumbbell Press', 42, 8, 14),
        SamplePr('Barbell Squat', 140, 5, 40),
        SamplePr('Weighted Pull-up', 30, 5, 25),
      ],
      milestones: const [
        'Bench 110 for 5',
        '300 workouts logged',
        '6-day split for 6 months',
      ],
      stats: const SampleStats(
        weeklyWorkouts: 6,
        weeklyMinutes: 410,
        avgDailySteps: 6400,
        streakDays: 17,
        totalWorkouts: 318,
        totalVolumeKg: 905000,
        challengesCompleted: 12,
      ),
    ),
    SampleAthlete(
      key: 'sophia',
      username: 'sophia.m',
      name: 'Sophia Martinez',
      avatar: _av(3),
      rank: 'Iron Warrior',
      goal: 'Rebuild strength after a knee injury',
      level: 'Intermediate',
      style: 'Three days of strength plus mobility work',
      schedule: 'Tue, Thu, Sun mornings',
      location: 'Aizawl',
      bio:
          'Back under the bar eight months after knee surgery. Slow is fine. Pain-free is the goal.',
      memberSince: 'Member for 11 months',
      prs: const [
        SamplePr('Romanian Deadlift', 70, 8, 6),
        SamplePr('Goblet Squat', 24, 10, 18),
        SamplePr('Hip Thrust', 80, 8, 12),
      ],
      milestones: const [
        'First full-depth squat after surgery',
        '12-week rehab block done',
        '50 workouts logged',
      ],
      stats: const SampleStats(
        weeklyWorkouts: 3,
        weeklyMinutes: 170,
        avgDailySteps: 6900,
        streakDays: 6,
        totalWorkouts: 63,
        totalVolumeKg: 98000,
        challengesCompleted: 4,
      ),
    ),
    SampleAthlete(
      key: 'liam',
      username: 'liam.oc',
      name: "Liam O'Connor",
      avatar: _av(4),
      rank: 'Rising Athlete',
      goal: 'Build a base (first year of training)',
      level: 'Beginner',
      style: 'Home dumbbells and a pull-up bar',
      schedule: 'After college, Mon to Sat',
      location: 'Aizawl',
      bio:
          'Student. Eight weeks in and finally not embarrassed by my push-ups. Asking a lot of questions.',
      memberSince: 'Member for 2 months',
      prs: const [
        SamplePr('Push-up', 0, 28, 3),
        SamplePr('Dumbbell Shoulder Press', 14, 10, 10),
        SamplePr('Goblet Squat', 20, 12, 16),
      ],
      milestones: const [
        'First 8-week block',
        'First pull-up',
        '25 workouts logged',
      ],
      stats: const SampleStats(
        weeklyWorkouts: 4,
        weeklyMinutes: 190,
        avgDailySteps: 9300,
        streakDays: 8,
        totalWorkouts: 27,
        totalVolumeKg: 21000,
        challengesCompleted: 2,
      ),
    ),
    SampleAthlete(
      key: 'david',
      username: 'david.lian',
      name: 'David Lian',
      avatar: _av(5),
      rank: 'Silver I',
      goal: 'Stay strong and healthy (busy parent)',
      level: 'Intermediate',
      style: 'Three full-body sessions a week',
      schedule: 'Mon, Wed, Fri at 5:30 am before the school run',
      location: 'Aizawl',
      bio:
          'Father of two, 43. Three sessions a week, never four. Consistency beats heroics.',
      memberSince: 'Member for 8 months',
      prs: const [
        SamplePr('Barbell Squat', 90, 5, 21),
        SamplePr('Bench Press', 75, 5, 33),
        SamplePr('Barbell Row', 70, 8, 27),
      ],
      milestones: const [
        'Three months without missing a Monday',
        '75 workouts logged',
      ],
      stats: const SampleStats(
        weeklyWorkouts: 3,
        weeklyMinutes: 150,
        avgDailySteps: 7800,
        streakDays: 15,
        totalWorkouts: 81,
        totalVolumeKg: 143000,
        challengesCompleted: 6,
      ),
    ),
    SampleAthlete(
      key: 'zothanpuii',
      username: 'zothanpuii.h',
      name: 'Zothanpuii Hnamte',
      avatar: _av(6),
      rank: 'Gold I',
      goal: 'Run a half marathon',
      level: 'Intermediate',
      style: 'Run four days, lift two',
      schedule: 'Hill runs at dawn, lifting on weekends',
      location: 'Aizawl',
      bio:
          'Aizawl hills are my treadmill. Training for a half marathon in March. Tea after every long run.',
      memberSince: 'Member for 9 months',
      prs: const [
        SamplePr('5 km run (minutes)', 24.5, 1, 11),
        SamplePr('Goblet Squat', 28, 10, 22),
        SamplePr('Walking Lunge', 32, 12, 30),
      ],
      milestones: const [
        'First 15 km run',
        '100 km logged in a month',
        '10-day step goal streak',
      ],
      stats: const SampleStats(
        weeklyWorkouts: 5,
        weeklyMinutes: 380,
        avgDailySteps: 14800,
        streakDays: 21,
        totalWorkouts: 140,
        totalVolumeKg: 61000,
        challengesCompleted: 11,
      ),
    ),
    SampleAthlete(
      key: 'hminga',
      username: 'hminga.p',
      name: 'Hminga Pachuau',
      avatar: _av(7),
      rank: 'Diamond I',
      goal: 'Athletic performance (football)',
      level: 'Advanced',
      style: 'Power, sprints and conditioning',
      schedule: 'Sprints Tue, lifting Mon and Thu, match Sunday',
      location: 'Aizawl',
      bio:
          'Midfielder for a local side. Lift for the pitch, not the mirror. Hill sprints build character.',
      memberSince: 'Member for 16 months',
      prs: const [
        SamplePr('Power Clean', 85, 3, 8),
        SamplePr('Trap Bar Deadlift', 150, 3, 19),
        SamplePr('Box Jump (cm)', 95, 1, 15),
      ],
      milestones: const [
        'Box jump 95 cm',
        'Season opener played injury-free',
        '150 workouts logged',
      ],
      stats: const SampleStats(
        weeklyWorkouts: 5,
        weeklyMinutes: 360,
        avgDailySteps: 12100,
        streakDays: 10,
        totalWorkouts: 156,
        totalVolumeKg: 380000,
        challengesCompleted: 8,
      ),
    ),
    SampleAthlete(
      key: 'coach_zuala',
      username: 'coach.zuala',
      name: 'Coach Zuala',
      avatar: _av(8),
      rank: 'Master Coach',
      goal: 'Coaching and longevity',
      level: 'Advanced',
      style: 'Technique-first strength training',
      schedule: 'Trains clients in the day, himself at night',
      location: 'Aizawl',
      bio:
          'Strength coach for 12 years. I post cues, not motivation. Ask me about your squat.',
      memberSince: 'Member for 2 years',
      prs: const [
        SamplePr('Barbell Squat', 160, 3, 36),
        SamplePr('Barbell Deadlift', 200, 1, 52),
        SamplePr('Bench Press', 120, 3, 44),
      ],
      milestones: const [
        '12 years coaching',
        'Deadlift 2.5x bodyweight',
        '400 workouts logged',
      ],
      stats: const SampleStats(
        weeklyWorkouts: 4,
        weeklyMinutes: 260,
        avgDailySteps: 9500,
        streakDays: 14,
        totalWorkouts: 412,
        totalVolumeKg: 1180000,
        challengesCompleted: 15,
      ),
    ),
    SampleAthlete(
      key: 'jenny',
      username: 'jenny.ralte',
      name: 'Jenny Ralte',
      avatar: _av(9),
      rank: 'Platinum II',
      goal: 'Fat loss and a stronger back',
      level: 'Intermediate',
      style: 'HIIT twice a week, strength three times',
      schedule: 'Meal prep Sundays, gym after work',
      location: 'Aizawl',
      bio:
          'Down 9 kg since May and keeping it boring on purpose. Sunday meal prep, weekday gym.',
      memberSince: 'Member for 7 months',
      prs: const [
        SamplePr('Lat Pulldown', 50, 10, 7),
        SamplePr('Hip Thrust', 90, 8, 17),
        SamplePr('Assisted Pull-up (kg assist)', 15, 6, 24),
      ],
      milestones: const [
        '9 kg lost',
        'First unassisted pull-up attempt',
        '12-week meal prep streak',
      ],
      stats: const SampleStats(
        weeklyWorkouts: 5,
        weeklyMinutes: 300,
        avgDailySteps: 11200,
        streakDays: 19,
        totalWorkouts: 98,
        totalVolumeKg: 118000,
        challengesCompleted: 10,
      ),
    ),
    SampleAthlete(
      key: 'marcus',
      username: 'marcus.vance',
      name: 'Marcus Vance',
      avatar:
          'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=200&auto=format&fit=crop&q=80',
      rank: 'Gold II',
      goal: 'Calisthenics skills (muscle-up, handstand)',
      level: 'Intermediate',
      style: 'Bodyweight skills at the park',
      schedule: 'Park sessions Tue, Thu, Sat',
      location: 'Aizawl',
      bio:
          'No gym membership, one pull-up bar. Chasing the muscle-up. Falls off handstands daily.',
      memberSince: 'Member for 10 months',
      prs: const [
        SamplePr('Pull-up', 0, 18, 5),
        SamplePr('Dip', 0, 30, 13),
        SamplePr('Handstand hold (seconds)', 22, 1, 9),
        SamplePr('Weighted Pull-up', 20, 5, 28),
      ],
      milestones: const [
        'First strict muscle-up',
        '18 strict pull-ups',
        '60-day handstand practice',
      ],
      stats: const SampleStats(
        weeklyWorkouts: 4,
        weeklyMinutes: 250,
        avgDailySteps: 8800,
        streakDays: 11,
        totalWorkouts: 112,
        totalVolumeKg: 36000,
        challengesCompleted: 5,
      ),
    ),
  ];

  static SampleAthlete? byKey(String key) {
    for (final a in athletes) {
      if (a.key == key) return a;
    }
    return null;
  }

  static SampleAthlete? byId(String id) {
    for (final a in athletes) {
      if (a.id == id) return a;
    }
    return null;
  }

  static List<Map<String, dynamic>> _days(List<(String, List<String>)> d) => [
    for (final e in d) {'dayName': e.$1, 'exercises': e.$2},
  ];

  /// Every sample post: the community posts plus the sample runs and rides.
  static final List<SamplePost> posts = [..._communityPosts, ...SampleCardio.posts];

  static final List<SamplePost> _communityPosts = [
    // ---------------------------------------------------------------- Alex
    SamplePost(
      'alex',
      1,
      'achievement',
      '140 for 3',
      'Two years ago I pulled 100 and thought that was the ceiling. 140 moved faster than last month\'s 130, which is the part I care about. Belt off for the first rep, on for the rest.',
      2,
      meta: const {
        'exerciseName': 'Barbell Deadlift',
        'previousWeightKg': 130.0,
        'newWeightKg': 140.0,
        'improvementKg': 10.0,
        'reps': 3,
      },
      likedBy: const ['maya', 'daniel', 'coach_zuala', 'david', 'hminga'],
      extraLikes: 26,
      saves: 4,
      comments: const [
        SampleComment(
          'coach_zuala',
          'Hips and shoulders rose together on rep 3. Film the next one from the side.',
          9,
        ),
        SampleComment(
          'maya',
          'Belt off for the first rep is a detail I am stealing.',
          22,
        ),
        SampleComment('daniel', 'Grip only or straps?', 41),
        SampleComment(
          'alex',
          'Grip only. Hook grip finally clicked last month.',
          47,
        ),
      ],
    ),
    SamplePost(
      'alex',
      2,
      'workout',
      'Pull day, 6:05 am',
      'Gym was empty so I got the rack I wanted. Rows felt heavy, pulldowns better than expected. Skipped curls, my left elbow is cranky.',
      30,
      meta: const {
        'durationMinutes': 62,
        'totalVolumeKg': 9400.0,
        'exercisesCount': 6,
        'xpEarned': 180,
      },
      likedBy: const ['maya', 'hminga'],
      extraLikes: 11,
      saves: 1,
      comments: const [
        SampleComment(
          'coach_zuala',
          'Cranky elbow means drop curls for a week, not a day.',
          15,
        ),
        SampleComment(
          'marcus',
          'Inner side of the elbow? I get that from chin-ups.',
          33,
        ),
      ],
    ),
    SamplePost(
      'alex',
      3,
      'meal',
      'A bulk breakfast that does not make me ill',
      'It sounds heroic but it is four eggs, ham, a bread roll and a lot of milk. About 920 kcal before 7 am.',
      55,
      meta: const {
        'calories': 920,
        'proteinGrams': 52,
        'carbsGrams': 96,
        'fatGrams': 34,
        'ingredients': ['4 eggs', 'ham', 'bread roll', 'milk'],
      },
      likedBy: const ['daniel', 'david'],
      extraLikes: 8,
      saves: 12,
      comments: const [
        SampleComment('jenny', '920 before 7? I am full at 400.', 70),
        SampleComment(
          'alex',
          'It takes practice honestly. Started at 600.',
          85,
        ),
      ],
    ),
    SamplePost(
      'alex',
      4,
      'progress',
      'Week 14 of the bulk: up 6 kg',
      'Scale says 80. Waist went 82 to 84 cm. I will take that ratio. Holding here until the cut in January.',
      120,
      meta: const {
        'startWeightKg': 74.0,
        'currentWeightKg': 80.0,
        'durationWeeks': 14,
      },
      likedBy: const ['maya', 'sophia', 'daniel', 'david'],
      extraLikes: 19,
      saves: 3,
      comments: const [
        SampleComment(
          'sophia',
          'Two centimetres on the waist for six kilos is a very respectable ratio.',
          60,
        ),
        SampleComment('liam', 'How many calories a day?', 95),
        SampleComment('alex', 'Around 3,100, higher on leg days.', 130),
      ],
    ),
    SamplePost(
      'alex',
      5,
      'routine',
      'My 5-day split. Copy it, then change it',
      'Not a pure PPL. Upper and lower twice, plus one heavy deadlift day. Three minutes rest on main lifts, ninety seconds on accessories.',
      200,
      meta: {
        'splitName': 'Upper/Lower + Deadlift Day',
        'days': _days([
          (
            'Mon: Upper A',
            ['Bench Press', 'Barbell Row', 'Overhead Press', 'Lat Pulldown'],
          ),
          (
            'Tue: Lower A',
            ['Barbell Squat', 'Leg Press', 'Leg Curl', 'Calf Raise'],
          ),
          (
            'Thu: Upper B',
            [
              'Incline Dumbbell Press',
              'Chest-Supported Row',
              'Lateral Raise',
              'Curls',
            ],
          ),
          (
            'Fri: Deadlift Day',
            ['Barbell Deadlift', 'Romanian Deadlift', 'Hanging Leg Raise'],
          ),
        ]),
      },
      likedBy: const ['daniel', 'maya', 'liam'],
      extraLikes: 34,
      saves: 51,
      comments: const [
        SampleComment(
          'daniel',
          'Your Wednesday is volume-light. Intentional?',
          40,
        ),
        SampleComment(
          'alex',
          'Yes. Wednesday is easy on purpose so Thursday is not wrecked.',
          52,
        ),
        SampleComment('liam', 'Is this okay for a beginner?', 90),
        SampleComment(
          'coach_zuala',
          'Beginner: run the two upper/lower days only and skip the extra deadlift day.',
          110,
        ),
      ],
    ),
    SamplePost(
      'alex',
      6,
      'progress',
      'Workout number 100',
      'Logged 100 sessions since March. Average 4.6 a week. Missed weeks: two (flu, and my sister\'s wedding).',
      300,
      likedBy: const ['maya', 'zothanpuii', 'david'],
      extraLikes: 15,
      saves: 0,
      comments: const [
        SampleComment(
          'david',
          'Averaging 4.6 a week with a job. I get 3 and feel proud.',
          30,
        ),
        SampleComment(
          'zothanpuii',
          'The wedding week does not count as a miss.',
          55,
        ),
      ],
    ),
    SamplePost(
      'alex',
      7,
      'achievement',
      'Squat 120 for 5, a month on',
      'Not a headline lift for the group here, but it was my target for the year and it came in October.',
      720,
      meta: const {
        'exerciseName': 'Barbell Squat',
        'previousWeightKg': 115.0,
        'newWeightKg': 120.0,
        'improvementKg': 5.0,
        'reps': 5,
      },
      likedBy: const ['maya', 'coach_zuala'],
      extraLikes: 17,
      saves: 2,
      comments: const [
        SampleComment(
          'maya',
          'Depth looks right. Mine always drifts high when it gets heavy.',
          45,
        ),
      ],
    ),

    // ---------------------------------------------------------------- Maya
    SamplePost(
      'maya',
      1,
      'achievement',
      'Squat 115 x 3',
      'Meet is in ten weeks. This is the heaviest triple I have ever done and it was not ugly, which I did not expect.',
      4,
      meta: const {
        'exerciseName': 'Barbell Squat',
        'previousWeightKg': 110.0,
        'newWeightKg': 115.0,
        'improvementKg': 5.0,
        'reps': 3,
      },
      likedBy: const ['alex', 'coach_zuala', 'daniel', 'sophia', 'hminga'],
      extraLikes: 33,
      saves: 6,
      comments: const [
        SampleComment(
          'coach_zuala',
          'Depth was clean and the brace held on all three reps.',
          12,
        ),
        SampleComment(
          'alex',
          '115 at 57 kg bodyweight. The meet is going to be fun.',
          30,
        ),
        SampleComment(
          'sophia',
          'Watching this while rebuilding my own squat. Thank you for the motivation.',
          75,
        ),
        SampleComment(
          'maya',
          'Sophia, you are doing the harder thing. Seriously.',
          90,
        ),
      ],
    ),
    SamplePost(
      'maya',
      2,
      'workout',
      'Bench again',
      'Bench is 62.5 for five and it still feels like pushing a car. Switched to paused reps because my touch-and-go count was a lie.',
      50,
      meta: const {
        'durationMinutes': 70,
        'totalVolumeKg': 6100.0,
        'exercisesCount': 5,
        'xpEarned': 170,
      },
      likedBy: const ['daniel', 'david'],
      extraLikes: 12,
      saves: 2,
      comments: const [
        SampleComment('daniel', 'Paused reps humble everyone.', 20),
        SampleComment(
          'coach_zuala',
          'Two-second pause, chest tight, leg drive on the way up.',
          35,
        ),
      ],
    ),
    SamplePost(
      'maya',
      3,
      'progress',
      '10 weeks out',
      'Opener plan is 105 squat, 62.5 bench, 125 deadlift. Taking weight down slowly, no drama. Still unsure about the bench opener.',
      96,
      likedBy: const ['alex', 'coach_zuala', 'sophia'],
      extraLikes: 18,
      saves: 1,
      comments: const [
        SampleComment(
          'coach_zuala',
          'Open lighter than you think. A missed opener is a bad weekend.',
          40,
        ),
        SampleComment('alex', 'Opening bench at 60 is not a crime.', 66),
      ],
    ),
    SamplePost(
      'maya',
      4,
      'meal',
      'Tuesday lunch',
      'Rice, tofu, bok choy, chilli oil. Boring and exactly the point.',
      150,
      meta: const {
        'calories': 640,
        'proteinGrams': 48,
        'carbsGrams': 70,
        'fatGrams': 18,
        'ingredients': ['rice', 'firm tofu', 'bok choy', 'chilli oil'],
      },
      likedBy: const ['jenny'],
      extraLikes: 9,
      saves: 8,
      comments: const [
        SampleComment(
          'jenny',
          'Pressing tofu first? Mine never goes crisp.',
          25,
        ),
        SampleComment('maya', 'Press it, then dry-fry before the sauce.', 40),
      ],
    ),
    SamplePost(
      'maya',
      5,
      'routine',
      'Peaking block, weeks 6 to 10',
      'Volume drops, intensity climbs. The accessories are short on purpose.',
      220,
      meta: {
        'splitName': 'Peaking Block',
        'days': _days([
          (
            'Mon: Squat',
            ['Squat singles and doubles', 'Pause Squat', 'Leg Curl'],
          ),
          ('Tue: Bench', ['Bench Press', 'Close-Grip Bench', 'Row']),
          (
            'Thu: Deadlift',
            ['Deadlift singles', 'Romanian Deadlift', 'Back Extension'],
          ),
          (
            'Sat: Bench and Squat',
            ['Light Squat', 'Paused Bench', 'Face Pull'],
          ),
        ]),
      },
      likedBy: const ['alex', 'coach_zuala'],
      extraLikes: 21,
      saves: 29,
      comments: const [
        SampleComment(
          'coach_zuala',
          'Good. Resist adding things in week 9.',
          18,
        ),
      ],
    ),
    SamplePost(
      'maya',
      6,
      'workout',
      'Deadlift singles',
      'Worked up to 130 for one. It was ugly, it was fast, and it ruined my shirt with chalk.',
      300,
      meta: const {
        'durationMinutes': 55,
        'totalVolumeKg': 3900.0,
        'exercisesCount': 4,
        'xpEarned': 140,
      },
      likedBy: const ['alex', 'hminga'],
      extraLikes: 10,
      saves: 0,
      comments: const [
        SampleComment('hminga', 'Chalk shirts are a badge.', 22),
      ],
    ),

    // -------------------------------------------------------------- Daniel
    SamplePost(
      'daniel',
      1,
      'achievement',
      'Bench 110 x 5',
      'Four months of adding 1.25 kg whenever I hit the top of the rep range. Boring and it works. The spreadsheet is attached in spirit.',
      9,
      meta: const {
        'exerciseName': 'Bench Press',
        'previousWeightKg': 105.0,
        'newWeightKg': 110.0,
        'improvementKg': 5.0,
        'reps': 5,
      },
      likedBy: const ['alex', 'maya', 'coach_zuala', 'marcus'],
      extraLikes: 29,
      saves: 7,
      comments: const [
        SampleComment(
          'maya',
          'Teach me how to bench like that, my bench is the enemy.',
          14,
        ),
        SampleComment(
          'daniel',
          'It is the arch plus patience. Take a video from the side.',
          30,
        ),
        SampleComment(
          'coach_zuala',
          'Good bar path. Elbows slightly under the wrists at the bottom.',
          38,
        ),
      ],
    ),
    SamplePost(
      'daniel',
      2,
      'routine',
      'My 6-day PPL',
      'Tested for a year. Optimised for weekly volume without cooked joints. Ask before you copy the leg day.',
      60,
      meta: {
        'splitName': 'Push / Pull / Legs x2',
        'days': _days([
          (
            'Day 1: Push',
            [
              'Bench Press',
              'Incline Dumbbell Press',
              'Lateral Raise',
              'Triceps Pushdown',
            ],
          ),
          (
            'Day 2: Pull',
            [
              'Weighted Pull-up',
              'Chest-Supported Row',
              'Face Pull',
              'Hammer Curl',
            ],
          ),
          (
            'Day 3: Legs',
            [
              'Barbell Squat',
              'Romanian Deadlift',
              'Leg Extension',
              'Calf Raise',
            ],
          ),
        ]),
      },
      likedBy: const ['alex', 'liam', 'david'],
      extraLikes: 44,
      saves: 88,
      comments: const [
        SampleComment('liam', 'Do you take a rest day after leg day?', 30),
        SampleComment(
          'daniel',
          'Day 4 is Push again, Day 7 off. Legs are Day 3 and Day 6.',
          44,
        ),
        SampleComment(
          'coach_zuala',
          'Exercise order is sensible. Watch the volume on leg day.',
          70,
        ),
      ],
    ),
    SamplePost(
      'daniel',
      3,
      'workout',
      'Incline day, 42s for 8',
      'Dumbbell incline hit 42s for eight clean reps. Shoulder blades pinned, no flaring. Triceps done after.',
      130,
      meta: const {
        'durationMinutes': 75,
        'totalVolumeKg': 11200.0,
        'exercisesCount': 6,
        'xpEarned': 210,
      },
      likedBy: const ['alex'],
      extraLikes: 13,
      saves: 2,
      comments: const [
        SampleComment('alex', '42s is a lot of dumbbell. Who spots you?', 20),
        SampleComment('daniel', 'Nobody. I bring them up from the knees.', 31),
      ],
    ),
    SamplePost(
      'daniel',
      4,
      'meal',
      'Tuna rice boxes, six for the week',
      'Tinned tuna, rice and whatever veg is cheap. Six boxes, zero decisions on a Wednesday.',
      190,
      meta: const {
        'calories': 640,
        'proteinGrams': 46,
        'carbsGrams': 78,
        'fatGrams': 12,
        'ingredients': ['tuna', 'rice', 'mixed veg'],
      },
      likedBy: const ['jenny', 'david'],
      extraLikes: 16,
      saves: 20,
      comments: const [
        SampleComment(
          'jenny',
          'Tuna rice survives the fridge better than chicken ever does.',
          40,
        ),
      ],
    ),
    SamplePost(
      'daniel',
      5,
      'progress',
      'Six-day split, six months',
      'Hit 180 workouts since April. Never skipped two days in a row. Sleep is the real supplement.',
      280,
      likedBy: const ['alex', 'david'],
      extraLikes: 14,
      saves: 1,
      comments: const [
        SampleComment(
          'david',
          'Sleep is the thing I cannot fix with two kids.',
          50,
        ),
        SampleComment(
          'daniel',
          'Three good sessions a week beats six tired ones. You are fine.',
          70,
        ),
      ],
    ),
    SamplePost(
      'daniel',
      6,
      'achievement',
      'Weighted pull-up, +30 kg for 5',
      'Finally past the plateau I had since the summer. Slowed the negative to three seconds.',
      600,
      meta: const {
        'exerciseName': 'Weighted Pull-up',
        'previousWeightKg': 27.5,
        'newWeightKg': 30.0,
        'improvementKg': 2.5,
        'reps': 5,
      },
      likedBy: const ['marcus', 'alex'],
      extraLikes: 21,
      saves: 5,
      comments: const [
        SampleComment(
          'marcus',
          'Slow negatives are underrated. Same trick for my muscle-up.',
          30,
        ),
      ],
    ),

    // -------------------------------------------------------------- Sophia
    SamplePost(
      'sophia',
      1,
      'achievement',
      'RDL 70 kg for 8, pain free',
      'Eight months ago I could not stand on my left leg for ten seconds. Today I did eight clean Romanian deadlifts with no flare-up. Small, but mine.',
      6,
      meta: const {
        'exerciseName': 'Romanian Deadlift',
        'previousWeightKg': 65.0,
        'newWeightKg': 70.0,
        'improvementKg': 5.0,
        'reps': 8,
      },
      likedBy: const ['maya', 'alex', 'coach_zuala', 'david', 'jenny'],
      extraLikes: 38,
      saves: 9,
      comments: const [
        SampleComment(
          'maya',
          'This is the one I am proudest of all week. Well done.',
          10,
        ),
        SampleComment(
          'coach_zuala',
          'Exactly the kind of progress I want to see. Keep the tempo slow.',
          25,
        ),
        SampleComment(
          'david',
          'My knee says thank you, I am borrowing your warm-up.',
          60,
        ),
        SampleComment(
          'sophia',
          'Warm-up: five minutes bike, glute bridges, band walks. Nothing clever.',
          75,
        ),
      ],
    ),
    SamplePost(
      'sophia',
      2,
      'workout',
      'Tuesday, short and kind',
      'Hip thrusts, split squats off a low box, band work. 45 minutes and I did not hate the stairs afterwards.',
      40,
      meta: const {
        'durationMinutes': 45,
        'totalVolumeKg': 3200.0,
        'exercisesCount': 5,
        'xpEarned': 120,
      },
      likedBy: const ['maya', 'jenny'],
      extraLikes: 10,
      saves: 2,
      comments: const [
        SampleComment('jenny', 'Stairs recovery is the real test.', 18),
      ],
    ),
    SamplePost(
      'sophia',
      3,
      'progress',
      'Rehab block, done',
      'Twelve weeks of the physio plan finished. Next block: back to a normal three-day program, with a deload every fourth week.',
      110,
      likedBy: const ['coach_zuala', 'maya'],
      extraLikes: 24,
      saves: 3,
      comments: const [
        SampleComment(
          'coach_zuala',
          'Deload every fourth week is smart for a returning knee.',
          30,
        ),
      ],
    ),
    SamplePost(
      'sophia',
      4,
      'meal',
      'Lentil bowl, eaten twice',
      'Dal, rice, spinach and a boiled egg. I cook it Sunday and quietly enjoy it for three days.',
      190,
      meta: const {
        'calories': 560,
        'proteinGrams': 28,
        'carbsGrams': 78,
        'fatGrams': 14,
        'ingredients': ['red lentils', 'rice', 'spinach', 'egg'],
      },
      likedBy: const ['jenny'],
      extraLikes: 7,
      saves: 10,
      comments: const [
        SampleComment('jenny', 'Adding to my Sunday prep list.', 15),
      ],
    ),
    SamplePost(
      'sophia',
      5,
      'routine',
      'Three days, no drama',
      'What my week looks like now. Mobility on the other days, if I feel like it.',
      260,
      meta: {
        'splitName': 'Return-to-lifting 3-day',
        'days': _days([
          (
            'Tue: Lower',
            ['Goblet Squat', 'Romanian Deadlift', 'Hip Thrust', 'Calf Raise'],
          ),
          ('Thu: Upper', ['Dumbbell Press', 'One-Arm Row', 'Lat Pulldown']),
          (
            'Sun: Full body light',
            ['Split Squat', 'Push-up', 'Band Pull-apart'],
          ),
        ]),
      },
      likedBy: const ['david', 'liam'],
      extraLikes: 15,
      saves: 23,
      comments: const [
        SampleComment('david', 'I might run this on my busy weeks.', 35),
        SampleComment('liam', 'Is the push-up on your knees?', 55),
        SampleComment(
          'sophia',
          'No, regular ones now. Took until September.',
          62,
        ),
      ],
    ),
    SamplePost(
      'sophia',
      6,
      'achievement',
      'First full-depth squat',
      'To parallel and below, bodyweight, no wobble. I cried a little in the changing room. No shame.',
      700,
      likedBy: const ['maya', 'coach_zuala', 'alex'],
      extraLikes: 45,
      saves: 5,
      comments: const [
        SampleComment('maya', 'Changing room tears are valid.', 20),
        SampleComment('alex', 'Respect. That is not a small thing.', 28),
      ],
    ),

    // ---------------------------------------------------------------- Liam
    SamplePost(
      'liam',
      1,
      'progress',
      'Eight weeks of boring consistency',
      'Weight 68 to 71 kg. Push-ups from 12 to 28. No programme from YouTube lasted more than ten days until this one.',
      14,
      meta: const {
        'startWeightKg': 68.0,
        'currentWeightKg': 71.0,
        'durationWeeks': 8,
      },
      likedBy: const ['alex', 'coach_zuala', 'sophia', 'david'],
      extraLikes: 41,
      saves: 3,
      comments: const [
        SampleComment(
          'coach_zuala',
          'Eight weeks of showing up beats any programme. What changed?',
          20,
        ),
        SampleComment(
          'liam',
          'I put a date and a time in my phone and stopped negotiating with myself.',
          40,
        ),
        SampleComment(
          'david',
          'Same trick works for me. The 5:30 alarm is not optional.',
          55,
        ),
      ],
    ),
    SamplePost(
      'liam',
      2,
      'workout',
      'Living-room pull-up night',
      'Door-frame bar, 14 kg dumbbells, mat. Negatives for pull-ups, then shoulder press. Neighbours probably hate me.',
      70,
      meta: const {
        'durationMinutes': 40,
        'totalVolumeKg': 2100.0,
        'exercisesCount': 4,
        'xpEarned': 90,
      },
      likedBy: const ['marcus'],
      extraLikes: 9,
      saves: 1,
      comments: const [
        SampleComment(
          'marcus',
          'Do the slow negatives for five seconds. You will have a real one soon.',
          25,
        ),
      ],
    ),
    SamplePost(
      'liam',
      3,
      'achievement',
      'First actual pull-up',
      'One. Chin over the bar. I jumped around the room for about a minute.',
      170,
      likedBy: const ['marcus', 'coach_zuala', 'alex', 'jenny'],
      extraLikes: 36,
      saves: 2,
      comments: const [
        SampleComment(
          'marcus',
          'Welcome to the club. Now do it again tomorrow.',
          12,
        ),
        SampleComment('jenny', 'I want one so badly. You give me hope.', 30),
      ],
    ),
    SamplePost(
      'liam',
      4,
      'meal',
      'Student budget protein',
      'Rice with a tofu and veg curry, enough for two meals. Under 40 rupees a plate and surprisingly good.',
      240,
      meta: const {
        'calories': 520,
        'proteinGrams': 20,
        'carbsGrams': 70,
        'fatGrams': 15,
        'ingredients': ['rice', 'tofu', 'mixed veg', 'curry spices'],
      },
      likedBy: const ['jenny', 'david'],
      extraLikes: 8,
      saves: 11,
      comments: const [
        SampleComment(
          'david',
          'Press the tofu first and you get more protein per rupee.',
          18,
        ),
      ],
    ),
    SamplePost(
      'liam',
      5,
      'workout',
      'Leg day without a rack',
      'Goblet squats, lunges, step-ups on the stairs. My legs shook on the bus home.',
      320,
      meta: const {
        'durationMinutes': 35,
        'totalVolumeKg': 1700.0,
        'exercisesCount': 4,
        'xpEarned': 80,
      },
      likedBy: const ['sophia'],
      extraLikes: 6,
      saves: 0,
      comments: const [
        SampleComment(
          'sophia',
          'Step-ups are a favourite of mine. Underrated.',
          22,
        ),
      ],
    ),
    SamplePost(
      'liam',
      6,
      'routine',
      'My beginner dumbbell week',
      'Not claiming this is optimal. It is what I can do at home in 40 minutes.',
      400,
      meta: {
        'splitName': 'Home dumbbell week',
        'days': _days([
          (
            'Mon: Push',
            ['Push-up', 'Dumbbell Shoulder Press', 'Triceps Extension'],
          ),
          ('Wed: Legs', ['Goblet Squat', 'Lunge', 'Calf Raise']),
          (
            'Fri: Pull',
            ['Door-frame pull-up negatives', 'One-Arm Row', 'Curl'],
          ),
        ]),
      },
      likedBy: const ['coach_zuala', 'alex'],
      extraLikes: 12,
      saves: 19,
      comments: const [
        SampleComment(
          'coach_zuala',
          'Good start. Add one hinge movement and you are covered.',
          28,
        ),
      ],
    ),

    // --------------------------------------------------------------- David
    SamplePost(
      'david',
      1,
      'progress',
      'Not missing Mondays',
      'Three months, 13 Mondays at 5:30 am, no misses. Kids still do not believe I am up first.',
      20,
      likedBy: const ['alex', 'maya', 'liam'],
      extraLikes: 22,
      saves: 1,
      comments: const [
        SampleComment('liam', 'What time do you sleep?', 30),
        SampleComment('david', '9:45. Yes, really.', 42),
        SampleComment('zothanpuii', 'Dawn crew. Respect.', 55),
      ],
    ),
    SamplePost(
      'david',
      2,
      'workout',
      'Full body Wednesday, 50 minutes',
      'Squat, bench, row, plank. Home by 6:45, breakfast with the kids. This is the whole plan.',
      80,
      meta: const {
        'durationMinutes': 50,
        'totalVolumeKg': 5200.0,
        'exercisesCount': 4,
        'xpEarned': 130,
      },
      likedBy: const ['alex', 'daniel'],
      extraLikes: 10,
      saves: 2,
      comments: const [
        SampleComment(
          'coach_zuala',
          'Four lifts, fifty minutes. That is a complete session.',
          14,
        ),
      ],
    ),
    SamplePost(
      'david',
      3,
      'achievement',
      'Squat 90 for 5',
      'At 43 I am not chasing numbers, but 90 for 5 felt strong and my back was fine.',
      500,
      meta: const {
        'exerciseName': 'Barbell Squat',
        'previousWeightKg': 85.0,
        'newWeightKg': 90.0,
        'improvementKg': 5.0,
        'reps': 5,
      },
      likedBy: const ['maya', 'coach_zuala', 'sophia'],
      extraLikes: 17,
      saves: 1,
      comments: const [
        SampleComment(
          'coach_zuala',
          'Strong at 43 is the point. Keep the back neutral and it will last decades.',
          22,
        ),
      ],
    ),
    SamplePost(
      'david',
      4,
      'meal',
      'School-run breakfast',
      'Oats with peanut butter and sliced banana. Takes four minutes, keeps me full until lunch.',
      150,
      meta: const {
        'calories': 450,
        'proteinGrams': 18,
        'carbsGrams': 58,
        'fatGrams': 16,
        'ingredients': ['oats', 'peanut butter', 'banana', 'milk'],
      },
      likedBy: const ['jenny'],
      extraLikes: 6,
      saves: 5,
      comments: const [
        SampleComment('jenny', 'Add chia and it holds until two for me.', 20),
      ],
    ),
    SamplePost(
      'david',
      5,
      'workout',
      'Row day, light and clean',
      'Barbell rows 70 for 8. Back felt great, no twinge. Not every week needs to be a PR.',
      360,
      meta: const {
        'durationMinutes': 48,
        'totalVolumeKg': 4800.0,
        'exercisesCount': 4,
        'xpEarned': 120,
      },
      likedBy: const ['daniel'],
      extraLikes: 8,
      saves: 0,
      comments: const [
        SampleComment('daniel', 'Boring weeks build the PR weeks.', 17),
      ],
    ),
    SamplePost(
      'david',
      6,
      'routine',
      'Three-day full body for tired parents',
      'Everything I can fit before 6:30. Replace the squat with leg press if your back is cranky.',
      420,
      meta: {
        'splitName': 'Full body x3',
        'days': _days([
          (
            'Mon: Squat focus',
            ['Barbell Squat', 'Bench Press', 'Barbell Row', 'Plank'],
          ),
          (
            'Wed: Hinge focus',
            [
              'Romanian Deadlift',
              'Overhead Press',
              'Pull-up',
              'Back Extension',
            ],
          ),
          (
            'Fri: Light',
            ['Goblet Squat', 'Incline Press', 'Cable Row', 'Carry'],
          ),
        ]),
      },
      likedBy: const ['sophia', 'liam', 'alex'],
      extraLikes: 20,
      saves: 35,
      comments: const [
        SampleComment(
          'sophia',
          'Saving this for the weeks I cannot do more.',
          30,
        ),
      ],
    ),

    // ---------------------------------------------------------- Zothanpuii
    SamplePost(
      'zothanpuii',
      1,
      'workout',
      'Sunday long run: 15 km',
      'First time over 15. Hills at km 6 and 11 did what hills do. Walked the last 200 m and still call it a run.',
      8,
      meta: const {
        'durationMinutes': 96,
        'totalVolumeKg': 0.0,
        'exercisesCount': 1,
        'xpEarned': 240,
      },
      likedBy: const ['hminga', 'jenny', 'david', 'marcus'],
      extraLikes: 27,
      saves: 3,
      comments: const [
        SampleComment(
          'hminga',
          'Walking the last 200 m is part of it. Do not feel bad.',
          15,
        ),
        SampleComment('jenny', 'I want to do this route. Send it.', 28),
        SampleComment('zothanpuii', 'Sending it Monday. Bring good shoes.', 40),
      ],
    ),
    SamplePost(
      'zothanpuii',
      2,
      'achievement',
      '5 km in 24:30',
      'Parkrun-style test on a flat track. Eleven days after a bad week. I will take it.',
      270,
      likedBy: const ['hminga', 'coach_zuala'],
      extraLikes: 19,
      saves: 2,
      comments: const [
        SampleComment('hminga', '24:30 flat is quick. Sub 24 next?', 35),
        SampleComment(
          'zothanpuii',
          'Maybe after the half. Do not jinx me.',
          50,
        ),
      ],
    ),
    SamplePost(
      'zothanpuii',
      3,
      'progress',
      '100 km in October',
      'Month total: 102 km across 17 runs, two lifting days a week. Knees complained once, so I iced them and moved on.',
      100,
      likedBy: const ['jenny', 'david'],
      extraLikes: 16,
      saves: 1,
      comments: const [
        SampleComment(
          'david',
          'I walked 100 km in a month and felt dramatic.',
          30,
        ),
      ],
    ),
    SamplePost(
      'zothanpuii',
      4,
      'workout',
      'Lifting for runners',
      'Goblet squats, lunges, calf raises, single-leg RDL. 35 minutes and I am done.',
      190,
      meta: const {
        'durationMinutes': 35,
        'totalVolumeKg': 3800.0,
        'exercisesCount': 5,
        'xpEarned': 110,
      },
      likedBy: const ['coach_zuala', 'sophia'],
      extraLikes: 9,
      saves: 4,
      comments: const [
        SampleComment(
          'coach_zuala',
          'Add a bit of heavy low-rep lifting once a week too. It helps running economy.',
          20,
        ),
      ],
    ),
    SamplePost(
      'zothanpuii',
      5,
      'meal',
      'Pre-long-run dal and rice',
      'Dal, rice and one boiled egg two hours before. Boring and it works.',
      120,
      meta: const {
        'calories': 480,
        'proteinGrams': 20,
        'carbsGrams': 72,
        'fatGrams': 10,
        'ingredients': ['dal', 'rice', 'egg'],
      },
      likedBy: const ['jenny'],
      extraLikes: 5,
      saves: 6,
      comments: const [
        SampleComment('jenny', 'I gag on eggs before a run. Respect.', 18),
      ],
    ),
    SamplePost(
      'zothanpuii',
      6,
      'progress',
      '10,000 steps, 21 days in a row',
      'Not an exercise goal, a life goal. The best part is the evening walk with my mother.',
      40,
      likedBy: const ['david', 'liam', 'jenny'],
      extraLikes: 23,
      saves: 0,
      comments: const [
        SampleComment('liam', 'How do you not forget one day?', 12),
        SampleComment(
          'zothanpuii',
          'The walk is the habit. The steps are a side effect.',
          26,
        ),
      ],
    ),

    // -------------------------------------------------------------- Hminga
    SamplePost(
      'hminga',
      1,
      'achievement',
      'Power clean 85 kg x 3',
      'Coach said move the bar, not yourself. Bar speed finally matched the weight. Shoulders still sore from catching.',
      8,
      meta: const {
        'exerciseName': 'Power Clean',
        'previousWeightKg': 80.0,
        'newWeightKg': 85.0,
        'improvementKg': 5.0,
        'reps': 3,
      },
      likedBy: const ['alex', 'coach_zuala', 'daniel'],
      extraLikes: 24,
      saves: 3,
      comments: const [
        SampleComment(
          'coach_zuala',
          'Good extension, and you got under the bar fast. Drop the elbows.',
          12,
        ),
        SampleComment('alex', 'That is a lot of speed.', 26),
      ],
    ),
    SamplePost(
      'hminga',
      2,
      'workout',
      'Hill sprints, 10 x 60 m',
      'The steepest road near my house. Walk down, sprint up. Legs gone by number seven, finished anyway.',
      56,
      meta: const {
        'durationMinutes': 45,
        'totalVolumeKg': 0.0,
        'exercisesCount': 3,
        'xpEarned': 150,
      },
      likedBy: const ['zothanpuii', 'marcus'],
      extraLikes: 14,
      saves: 2,
      comments: const [
        SampleComment(
          'zothanpuii',
          'Which road? I want to ruin my legs too.',
          15,
        ),
        SampleComment('hminga', 'Behind the church. Bring water.', 22),
      ],
    ),
    SamplePost(
      'hminga',
      3,
      'progress',
      'Season opener, no injuries',
      'Played all 90 minutes. A year ago I was out for two months with a hamstring. Strength work fixed it.',
      130,
      likedBy: const ['alex', 'coach_zuala', 'david'],
      extraLikes: 28,
      saves: 2,
      comments: const [
        SampleComment(
          'coach_zuala',
          'Hamstrings and hips. Keep doing the Nordics.',
          20,
        ),
      ],
    ),
    SamplePost(
      'hminga',
      4,
      'achievement',
      'Box jump 95 cm',
      'Landed it soft, which was the real goal. Filmed three attempts, only one was clean.',
      330,
      likedBy: const ['marcus', 'liam'],
      extraLikes: 18,
      saves: 1,
      comments: const [
        SampleComment(
          'marcus',
          'Soft landing matters more than height. Respect.',
          40,
        ),
        SampleComment('liam', '95?! I can barely jump a stair.', 60),
      ],
    ),
    SamplePost(
      'hminga',
      5,
      'routine',
      'Pre-season week',
      'Two lift days, one sprint day, one match, easy jog the day after. Five minutes of skipping to warm up before anything else.',
      400,
      meta: {
        'splitName': 'Pre-season week',
        'days': _days([
          (
            'Mon: Lift',
            ['Trap Bar Deadlift', 'Power Clean', 'Split Squat', 'Pull-up'],
          ),
          ('Tue: Sprints', ['Hill sprints', 'Core circuit']),
          ('Thu: Lift', ['Front Squat', 'Push Press', 'Nordic Curl', 'Row']),
        ]),
      },
      likedBy: const ['alex', 'zothanpuii'],
      extraLikes: 17,
      saves: 22,
      comments: const [
        SampleComment(
          'zothanpuii',
          'Easy jog the day after is the best rule.',
          25,
        ),
      ],
    ),
    SamplePost(
      'hminga',
      6,
      'meal',
      'Match-day rice, chicken and banana',
      'Three hours before kickoff: rice, chicken and an egg, banana after. I tried pasta once and played like a sloth.',
      520,
      meta: const {
        'calories': 780,
        'proteinGrams': 44,
        'carbsGrams': 110,
        'fatGrams': 14,
        'ingredients': ['rice', 'chicken', 'banana'],
      },
      likedBy: const ['david'],
      extraLikes: 8,
      saves: 7,
      comments: const [SampleComment('david', 'I read this and made it.', 30)],
    ),

    // --------------------------------------------------------- Coach Zuala
    SamplePost(
      'coach_zuala',
      1,
      'workout',
      'Cue of the week: squat brace',
      'Breathe into your belt, not your chest. Think about pushing your stomach out against it, then lift. Fix this before adding any weight.',
      3,
      meta: const {
        'durationMinutes': 15,
        'totalVolumeKg': 0.0,
        'exercisesCount': 1,
        'xpEarned': 0,
      },
      likedBy: const ['alex', 'maya', 'daniel', 'liam', 'sophia', 'david'],
      extraLikes: 52,
      saves: 41,
      comments: const [
        SampleComment('liam', 'Does this work with a belt-less brace?', 16),
        SampleComment(
          'coach_zuala',
          'Yes. Same idea, you push out against nothing instead. Practise with a belt first.',
          32,
        ),
        SampleComment('david', 'My back is thanking you in advance.', 50),
      ],
    ),
    SamplePost(
      'coach_zuala',
      2,
      'routine',
      'The beginner template I give everyone',
      'Three days, five lifts, no drama. If you can not name your last session, this is the programme for you.',
      70,
      meta: {
        'splitName': 'Beginner full-body',
        'days': _days([
          ('Day A', ['Goblet Squat', 'Push-up', 'One-Arm Row', 'Plank']),
          (
            'Day B',
            ['Romanian Deadlift', 'Overhead Press', 'Lat Pulldown', 'Carry'],
          ),
          (
            'Day C',
            ['Split Squat', 'Incline Press', 'Cable Row', 'Back Extension'],
          ),
        ]),
      },
      likedBy: const ['liam', 'sophia', 'david', 'jenny'],
      extraLikes: 60,
      saves: 140,
      comments: const [
        SampleComment(
          'liam',
          'This is basically what I am doing already. Nice.',
          20,
        ),
        SampleComment('jenny', 'Saved. Sending it to my sister.', 35),
      ],
    ),
    SamplePost(
      'coach_zuala',
      3,
      'achievement',
      'Squat 160 x 3, at 44',
      'Not for the likes. I wanted to show clients that technique holds at the top end. Slowest descent of my life.',
      860,
      meta: const {
        'exerciseName': 'Barbell Squat',
        'previousWeightKg': 155.0,
        'newWeightKg': 160.0,
        'improvementKg': 5.0,
        'reps': 3,
      },
      likedBy: const ['alex', 'maya', 'daniel', 'hminga'],
      extraLikes: 48,
      saves: 8,
      comments: const [
        SampleComment(
          'maya',
          'The control on the way down is what I want.',
          20,
        ),
      ],
    ),
    SamplePost(
      'coach_zuala',
      4,
      'progress',
      'What I tell new clients on day one',
      'Pick one habit. Do it for six weeks. Skip nothing for six weeks. Everything else comes after that.',
      150,
      likedBy: const ['liam', 'david', 'sophia'],
      extraLikes: 35,
      saves: 12,
      comments: const [
        SampleComment(
          'liam',
          'That is exactly what happened to me this block.',
          25,
        ),
      ],
    ),
    SamplePost(
      'coach_zuala',
      5,
      'workout',
      'Mobility before heavy deadlifts',
      'Ten minutes: hip airplanes, 90/90, cat-cow, and two empty-bar sets. Do not skip it because you are in a rush.',
      240,
      meta: const {
        'durationMinutes': 25,
        'totalVolumeKg': 2600.0,
        'exercisesCount': 5,
        'xpEarned': 80,
      },
      likedBy: const ['alex', 'hminga', 'sophia'],
      extraLikes: 30,
      saves: 26,
      comments: const [
        SampleComment(
          'sophia',
          'The 90/90 saved my hip. Thank you for the tip last month.',
          18,
        ),
      ],
    ),
    SamplePost(
      'coach_zuala',
      6,
      'meal',
      'What I eat on a heavy day',
      'Nothing special: eggs, rice, dal, a fruit, plenty of water. Eat the same meals for three weeks and see what your body says.',
      330,
      meta: const {
        'calories': 2900,
        'proteinGrams': 175,
        'carbsGrams': 330,
        'fatGrams': 85,
        'ingredients': ['eggs', 'rice', 'dal', 'fruit'],
      },
      likedBy: const ['daniel', 'jenny'],
      extraLikes: 22,
      saves: 16,
      comments: const [
        SampleComment(
          'daniel',
          'Three weeks same meals is a great experiment.',
          40,
        ),
      ],
    ),

    // --------------------------------------------------------------- Jenny
    SamplePost(
      'jenny',
      1,
      'meal',
      'Sunday prep: 10 lunches',
      'Greens, cucumber and carrot washed and boxed first, then chicken and rice. Three sauces so I do not get bored. Takes me two hours with a podcast on.',
      12,
      meta: const {
        'calories': 520,
        'proteinGrams': 42,
        'carbsGrams': 52,
        'fatGrams': 14,
        'ingredients': [
          'chicken breast',
          'brown rice',
          'roasted vegetables',
          'three sauces',
        ],
      },
      likedBy: const ['maya', 'daniel', 'sophia', 'david'],
      extraLikes: 25,
      saves: 47,
      comments: const [
        SampleComment(
          'maya',
          'Three sauces is the secret. I just eat the same dry chicken.',
          20,
        ),
        SampleComment('david', 'Can you share the peanut one?', 40),
        SampleComment(
          'jenny',
          'Peanut butter, soy, lime, chilli. That is it.',
          55,
        ),
      ],
    ),
    SamplePost(
      'jenny',
      2,
      'progress',
      'Down 9 kg since May',
      'No crash diets, no cutting out rice. A walk after dinner, two HIIT days, three lifting days, eight hours of sleep when I could.',
      90,
      meta: const {
        'startWeightKg': 74.0,
        'currentWeightKg': 65.0,
        'durationWeeks': 26,
      },
      likedBy: const ['maya', 'sophia', 'coach_zuala', 'liam', 'david'],
      extraLikes: 54,
      saves: 9,
      comments: const [
        SampleComment(
          'sophia',
          'Boring on purpose is the secret. Congratulations.',
          14,
        ),
        SampleComment(
          'coach_zuala',
          'Consistent and sustainable. That is the plan.',
          30,
        ),
        SampleComment('liam', 'How long was the plateau?', 50),
        SampleComment(
          'jenny',
          'Weeks 12 to 15. I changed nothing and it moved.',
          66,
        ),
      ],
    ),
    SamplePost(
      'jenny',
      3,
      'workout',
      'HIIT Thursday',
      'Eight rounds, 30 s on 30 s off: kettlebell swing, burpee, battle rope, jump squat. I saw colours.',
      140,
      meta: const {
        'durationMinutes': 32,
        'totalVolumeKg': 2400.0,
        'exercisesCount': 4,
        'xpEarned': 140,
      },
      likedBy: const ['hminga', 'zothanpuii'],
      extraLikes: 13,
      saves: 2,
      comments: const [
        SampleComment('hminga', 'Burpees are a punishment. Respect.', 18),
      ],
    ),
    SamplePost(
      'jenny',
      4,
      'achievement',
      'Hip thrust 90 kg for 8',
      'Started at 40 kg in May. The glute bridge before every session is not optional.',
      380,
      meta: const {
        'exerciseName': 'Hip Thrust',
        'previousWeightKg': 80.0,
        'newWeightKg': 90.0,
        'improvementKg': 10.0,
        'reps': 8,
      },
      likedBy: const ['maya', 'sophia'],
      extraLikes: 19,
      saves: 2,
      comments: const [
        SampleComment('sophia', 'My hip thrust is 80 now. We are racing.', 25),
      ],
    ),
    SamplePost(
      'jenny',
      5,
      'meal',
      'Post-workout shake',
      'Whey, banana, milk, a spoon of peanut butter. Not glamorous and I drink it in the car.',
      220,
      meta: const {
        'calories': 380,
        'proteinGrams': 32,
        'carbsGrams': 34,
        'fatGrams': 12,
        'ingredients': ['whey', 'banana', 'milk', 'peanut butter'],
      },
      likedBy: const ['daniel'],
      extraLikes: 7,
      saves: 4,
      comments: const [SampleComment('daniel', 'Cheap, effective, good.', 20)],
    ),
    SamplePost(
      'jenny',
      6,
      'routine',
      'My week as a beginner-intermediate',
      'HIIT twice, lifting three times, walking every day. Sundays are for prep and rest.',
      300,
      meta: {
        'splitName': 'Fat-loss week',
        'days': _days([
          ('Mon: Lower', ['Squat', 'Hip Thrust', 'Walking Lunge']),
          ('Tue: HIIT', ['Kettlebell Swing', 'Burpee', 'Rope']),
          ('Wed: Upper', ['Lat Pulldown', 'Dumbbell Press', 'Row']),
        ]),
      },
      likedBy: const ['liam', 'sophia'],
      extraLikes: 14,
      saves: 31,
      comments: const [
        SampleComment('sophia', 'I wish I had found this when I started.', 40),
      ],
    ),

    // -------------------------------------------------------------- Marcus
    SamplePost(
      'marcus',
      1,
      'achievement',
      'First strict muscle-up',
      'No kip, no swing. Took ten months, a hundred failed attempts and one very patient bar. I am lying on the grass now.',
      5,
      meta: const {
        'exerciseName': 'Strict Muscle-up',
        'previousWeightKg': 0.0,
        'newWeightKg': 0.0,
        'improvementKg': 0.0,
        'reps': 1,
      },
      likedBy: const ['liam', 'hminga', 'daniel', 'coach_zuala', 'alex'],
      extraLikes: 58,
      saves: 6,
      comments: const [
        SampleComment(
          'liam',
          'WHAT. I just did my first pull-up and you are doing this.',
          9,
        ),
        SampleComment(
          'coach_zuala',
          'No kip and a clean transition. That is ten months of patience.',
          18,
        ),
        SampleComment(
          'daniel',
          'Weighted pull-ups carry over. Proud of you.',
          30,
        ),
        SampleComment(
          'marcus',
          'Thanks everyone. Slow negatives were the key.',
          44,
        ),
      ],
    ),
    SamplePost(
      'marcus',
      2,
      'workout',
      'Park session, no equipment',
      'Pull-ups, dips, L-sits and hollow holds on the rings I hung from a tree. The squirrels judged.',
      60,
      meta: const {
        'durationMinutes': 70,
        'totalVolumeKg': 0.0,
        'exercisesCount': 6,
        'xpEarned': 190,
      },
      likedBy: const ['liam', 'hminga'],
      extraLikes: 15,
      saves: 3,
      comments: const [
        SampleComment('liam', 'Rings in a tree is incredible.', 16),
      ],
    ),
    SamplePost(
      'marcus',
      3,
      'progress',
      'Handstand diary, day 60',
      'Best hold is 22 seconds against nothing. Two months ago I could not hold one second. Wrists are the limiting factor.',
      150,
      likedBy: const ['sophia', 'jenny', 'coach_zuala'],
      extraLikes: 21,
      saves: 2,
      comments: const [
        SampleComment(
          'coach_zuala',
          'Wrist warm-up for five minutes before. Every time.',
          24,
        ),
        SampleComment('marcus', 'I do it. I will be more boring about it.', 38),
      ],
    ),
    SamplePost(
      'marcus',
      4,
      'achievement',
      '18 strict pull-ups',
      'Went from 8 in January to 18 now. Grease-the-groove all week, four sets to failure once.',
      360,
      likedBy: const ['daniel', 'alex'],
      extraLikes: 25,
      saves: 3,
      comments: const [
        SampleComment('daniel', 'Grease-the-groove is underrated.', 26),
      ],
    ),
    SamplePost(
      'marcus',
      5,
      'routine',
      'My park week',
      'Skills first when fresh, strength second, conditioning last. Nothing here requires a gym.',
      420,
      meta: {
        'splitName': 'Calisthenics skills week',
        'days': _days([
          (
            'Tue: Pull',
            [
              'Pull-ups',
              'Muscle-up negatives',
              'Australian Rows',
              'Hanging Leg Raise',
            ],
          ),
          ('Thu: Push', ['Dips', 'Pike Push-up', 'Handstand holds']),
          (
            'Sat: Skills and legs',
            ['Muscle-up practice', 'Pistol Squat', 'L-sit'],
          ),
        ]),
      },
      likedBy: const ['liam', 'hminga', 'sophia'],
      extraLikes: 31,
      saves: 54,
      comments: const [
        SampleComment('liam', 'I will start with Tuesday. No dips yet.', 15),
        SampleComment(
          'marcus',
          'Do negative dips on the bench. Takes a week.',
          28,
        ),
      ],
    ),
    SamplePost(
      'marcus',
      6,
      'meal',
      'Park lunch',
      'Bananas, a bowl of fruit and a bottle of milk on the grass. No dishes, no plan.',
      480,
      meta: const {
        'calories': 480,
        'proteinGrams': 14,
        'carbsGrams': 90,
        'fatGrams': 8,
        'ingredients': ['bananas', 'mixed fruit', 'milk'],
      },
      likedBy: const ['jenny'],
      extraLikes: 5,
      saves: 3,
      comments: const [SampleComment('jenny', 'Honestly sounds great.', 14)],
    ),
  ];
}
