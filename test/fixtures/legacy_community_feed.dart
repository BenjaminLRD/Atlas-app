import 'package:atlas/models/activity_post.dart';
import 'package:atlas/models/post_comment.dart';

/// Test-only fixture: the original hand-written feed that older widget and
/// unit tests were written against. The app itself uses `SampleCommunity`
/// (the sample world) everywhere, including Showcase Mode.
List<ActivityPost> legacyCommunityFeed() {
  final now = DateTime.now();
  return [
    // 1. Workout Photo & PR Post (12 Comments)
    ActivityPost(
      id: 'post_pr_1',
      userId: 'usr_alex',
      userName: 'Alex Carter',
      userAvatar:
          'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&auto=format&fit=crop&q=80',
      userRank: 'Diamond II',
      type: ActivityPostType.achievement,
      title: 'New Deadlift PR Crushed! 🏆',
      description: 'New deadlift PR today. Finally broke through 140 kg.',
      images: const [
        'https://images.unsplash.com/photo-1517838277536-f5f99be501cd?w=800&auto=format&fit=crop&q=80',
      ],
      metadata: {
        'exerciseName': 'Barbell Deadlift',
        'previousWeightKg': 120.0,
        'newWeightKg': 140.0,
        'improvementKg': 20.0,
        'reps': 3,
      },
      likes: 54,
      savesCount: 18,
      createdAt: now.subtract(const Duration(minutes: 35)),
      commentsList: [
        PostComment(
          id: 'c_pr_1',
          postId: 'post_pr_1',
          userId: 'usr_maya',
          userName: 'Maya Chen',
          userAvatar:
              'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=200&auto=format&fit=crop&q=80',
          userRank: 'Platinum I',
          text: 'That lockout was insane 🔥',
          createdAt: now.subtract(const Duration(minutes: 32)),
          likes: 4,
        ),
        PostComment(
          id: 'c_pr_2',
          postId: 'post_pr_1',
          userId: 'usr_coach_zuala',
          userName: 'Coach Zuala',
          userAvatar:
              'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&auto=format&fit=crop&q=80',
          userRank: 'Master Coach 🏆',
          text: 'Huge PR! The 8-week progression is paying off. Form stayed tight all the way up.',
          createdAt: now.subtract(const Duration(minutes: 28)),
          likes: 6,
        ),
        PostComment(
          id: 'c_pr_3',
          postId: 'post_pr_1',
          userId: 'usr_daniel',
          userName: 'Daniel Kim',
          userAvatar:
              'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&auto=format&fit=crop&q=80',
          userRank: 'Elite 👑',
          text: '140 kg is crazy work. Looked like an easy RPE 7 honestly 💪',
          createdAt: now.subtract(const Duration(minutes: 24)),
          likes: 3,
        ),
        PostComment(
          id: 'c_pr_4',
          postId: 'post_pr_1',
          userId: 'usr_sophia',
          userName: 'Sophia Martinez',
          userAvatar:
              'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=200&auto=format&fit=crop&q=80',
          userRank: 'Iron Warrior ⚔️',
          text: 'Clean pull! Great hip drive off the floor.',
          createdAt: now.subtract(const Duration(minutes: 20)),
          likes: 2,
        ),
        PostComment(
          id: 'c_pr_5',
          postId: 'post_pr_1',
          userId: 'usr_liam',
          userName: "Liam O'Connor",
          userAvatar:
              'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200&auto=format&fit=crop&q=80',
          userRank: 'Rising Athlete ⚡',
          text: 'Inspiring stuff man, next stop 160 kg!',
          createdAt: now.subtract(const Duration(minutes: 18)),
          likes: 1,
        ),
        PostComment(
          id: 'c_pr_6',
          postId: 'post_pr_1',
          userId: 'usr_jenny',
          userName: 'Jenny Ralte',
          userAvatar:
              'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=200&auto=format&fit=crop&q=80',
          userRank: 'Coach ⚡',
          text: 'Notice how your bar path didn’t drift forward. Solid mechanical efficiency.',
          createdAt: now.subtract(const Duration(minutes: 15)),
          likes: 5,
        ),
        PostComment(
          id: 'c_pr_7',
          postId: 'post_pr_1',
          userId: 'usr_marcus',
          userName: 'Marcus Vance',
          userAvatar:
              'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=200&auto=format&fit=crop&q=80',
          userRank: 'Gold II',
          text: 'What belt are you using here?',
          createdAt: now.subtract(const Duration(minutes: 12)),
        ),
        PostComment(
          id: 'c_pr_8',
          postId: 'post_pr_1',
          userId: 'usr_alex',
          userName: 'Alex Carter',
          userAvatar:
              'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&auto=format&fit=crop&q=80',
          userRank: 'Diamond II',
          text: '@Marcus Vance Inzer 10mm lever belt, best investment I ever made.',
          createdAt: now.subtract(const Duration(minutes: 10)),
          likes: 2,
        ),
        PostComment(
          id: 'c_pr_9',
          postId: 'post_pr_1',
          userId: 'usr_david',
          userName: 'David Lian',
          userAvatar:
              'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=200&auto=format&fit=crop&q=80',
          userRank: 'Silver I',
          text: 'Light weight buddy! Keep crushing it.',
          createdAt: now.subtract(const Duration(minutes: 8)),
        ),
        PostComment(
          id: 'c_pr_10',
          postId: 'post_pr_1',
          userId: 'usr_sarah',
          userName: 'Sarah T.',
          userAvatar:
              'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=200&auto=format&fit=crop&q=80',
          userRank: 'Gold I',
          text: 'That speed off the floor was lightning fast ⚡',
          createdAt: now.subtract(const Duration(minutes: 6)),
        ),
        PostComment(
          id: 'c_pr_11',
          postId: 'post_pr_1',
          userId: 'usr_hminga',
          userName: 'Hminga Pachuau',
          userAvatar:
              'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&auto=format&fit=crop&q=80',
          userRank: 'Diamond I',
          text: 'Aizawl gym powerlifters represent! 🏋️',
          createdAt: now.subtract(const Duration(minutes: 4)),
          likes: 3,
        ),
        PostComment(
          id: 'c_pr_12',
          postId: 'post_pr_1',
          userId: 'usr_robert',
          userName: 'Robert R.',
          userAvatar:
              'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200&auto=format&fit=crop&q=80',
          userRank: 'Bronze I',
          text: 'Grip strength goals right there.',
          createdAt: now.subtract(const Duration(minutes: 2)),
        ),
      ],
    ),

    // 2. Food / Meal Prep Photo (9 Comments)
    ActivityPost(
      id: 'post_meal_1',
      userId: 'usr_maya',
      userName: 'Maya Chen',
      userAvatar:
          'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=200&auto=format&fit=crop&q=80',
      userRank: 'Platinum I',
      type: ActivityPostType.meal,
      title: 'Meal Prep Sunday: High-Protein Chicken Bowl 🍱',
      description: 'Meal prep for the week. High-protein chicken bowl.',
      images: const [
        'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=800&auto=format&fit=crop&q=80',
      ],
      metadata: {
        'mealName': 'High-Protein Chicken Bowl',
        'calories': 850,
        'proteinGrams': 60,
        'carbsGrams': 95,
        'fatGrams': 22,
        'ingredients': [
          '250g Chicken Breast',
          '1.5 Cups Jasmine Rice',
          'Steamed Broccoli',
          'Olive Oil & Garlic',
        ],
      },
      likes: 42,
      savesCount: 31,
      createdAt: now.subtract(const Duration(hours: 2)),
      commentsList: [
        PostComment(
          id: 'c_meal_1',
          postId: 'post_meal_1',
          userId: 'usr_daniel',
          userName: 'Daniel Kim',
          userAvatar:
              'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&auto=format&fit=crop&q=80',
          userRank: 'Elite 👑',
          text: 'That chicken bowl actually looks amazing.',
          createdAt: now.subtract(const Duration(hours: 1, minutes: 50)),
          likes: 3,
        ),
        PostComment(
          id: 'c_meal_2',
          postId: 'post_meal_1',
          userId: 'usr_alex',
          userName: 'Alex Carter',
          userAvatar:
              'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&auto=format&fit=crop&q=80',
          userRank: 'Diamond II',
          text: 'How much protein per serving? Need this in my macro split.',
          createdAt: now.subtract(const Duration(hours: 1, minutes: 45)),
          likes: 1,
        ),
        PostComment(
          id: 'c_meal_3',
          postId: 'post_meal_1',
          userId: 'usr_maya',
          userName: 'Maya Chen',
          userAvatar:
              'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=200&auto=format&fit=crop&q=80',
          userRank: 'Platinum I',
          text: '@Alex Carter 60g protein total! 250g raw chicken breast with 1.5 cups jasmine rice.',
          createdAt: now.subtract(const Duration(hours: 1, minutes: 40)),
          likes: 5,
        ),
        PostComment(
          id: 'c_meal_4',
          postId: 'post_meal_1',
          userId: 'usr_liam',
          userName: "Liam O'Connor",
          userAvatar:
              'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200&auto=format&fit=crop&q=80',
          userRank: 'Rising Athlete ⚡',
          text: 'Do you weigh the chicken raw or cooked?',
          createdAt: now.subtract(const Duration(hours: 1, minutes: 30)),
        ),
        PostComment(
          id: 'c_meal_5',
          postId: 'post_meal_1',
          userId: 'usr_maya',
          userName: 'Maya Chen',
          userAvatar:
              'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=200&auto=format&fit=crop&q=80',
          userRank: 'Platinum I',
          text: '@Liam O\'Connor Always raw for accuracy!',
          createdAt: now.subtract(const Duration(hours: 1, minutes: 25)),
          likes: 2,
        ),
        PostComment(
          id: 'c_meal_6',
          postId: 'post_meal_1',
          userId: 'usr_jenny',
          userName: 'Jenny Ralte',
          userAvatar:
              'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=200&auto=format&fit=crop&q=80',
          userRank: 'Coach ⚡',
          text: 'Jasmine rice + broccoli is the ultimate classic bodybuilding combo 🍱',
          createdAt: now.subtract(const Duration(hours: 1, minutes: 10)),
          likes: 4,
        ),
        PostComment(
          id: 'c_meal_7',
          postId: 'post_meal_1',
          userId: 'usr_emma',
          userName: 'Emma Watson',
          userAvatar:
              'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=200&auto=format&fit=crop&q=80',
          userRank: 'Gold I',
          text: 'What seasoning did you use on the chicken?',
          createdAt: now.subtract(const Duration(minutes: 50)),
        ),
        PostComment(
          id: 'c_meal_8',
          postId: 'post_meal_1',
          userId: 'usr_coach_zuala',
          userName: 'Coach Zuala',
          userAvatar:
              'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&auto=format&fit=crop&q=80',
          userRank: 'Master Coach 🏆',
          text: 'Macro distribution is on point. Perfect recovery meal.',
          createdAt: now.subtract(const Duration(minutes: 40)),
          likes: 3,
        ),
        PostComment(
          id: 'c_meal_9',
          postId: 'post_meal_1',
          userId: 'usr_kevin',
          userName: 'Kevin L.',
          userAvatar:
              'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=200&auto=format&fit=crop&q=80',
          userRank: 'Silver II',
          text: 'Meal prepping mine for tomorrow right now 🙌',
          createdAt: now.subtract(const Duration(minutes: 25)),
          likes: 1,
        ),
      ],
    ),

    // 3. Protein Shake Post (14 Comments)
    ActivityPost(
      id: 'post_shake_1',
      userId: 'usr_daniel',
      userName: 'Daniel Kim',
      userAvatar:
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&auto=format&fit=crop&q=80',
      userRank: 'Elite 👑',
      type: ActivityPostType.meal,
      title: 'Post-Workout Anabolic Shake 🥤',
      description: 'Post-workout shake. Simple and actually tastes good.',
      images: const [
        'https://images.unsplash.com/photo-1553530666-ba11a7da3888?w=800&auto=format&fit=crop&q=80',
      ],
      metadata: {
        'mealName': 'Power Whey Smoothie',
        'calories': 420,
        'proteinGrams': 45,
        'carbsGrams': 38,
        'fatGrams': 12,
        'ingredients': [
          'Whey',
          'Banana',
          'Milk',
          'Peanut butter',
        ],
      },
      likes: 68,
      savesCount: 25,
      createdAt: now.subtract(const Duration(hours: 4)),
      commentsList: [
        PostComment(
          id: 'c_shake_1',
          postId: 'post_shake_1',
          userId: 'usr_sophia',
          userName: 'Sophia Martinez',
          userAvatar:
              'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=200&auto=format&fit=crop&q=80',
          userRank: 'Iron Warrior ⚔️',
          text: 'Simple and effective! Peanut butter + banana is unbeatable 🥤',
          createdAt: now.subtract(const Duration(hours: 3, minutes: 40)),
          likes: 6,
        ),
        PostComment(
          id: 'c_shake_2',
          postId: 'post_shake_1',
          userId: 'usr_alex',
          userName: 'Alex Carter',
          userAvatar:
              'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&auto=format&fit=crop&q=80',
          userRank: 'Diamond II',
          text: 'What brand whey do you use?',
          createdAt: now.subtract(const Duration(hours: 3, minutes: 30)),
          likes: 2,
        ),
        PostComment(
          id: 'c_shake_3',
          postId: 'post_shake_1',
          userId: 'usr_daniel',
          userName: 'Daniel Kim',
          userAvatar:
              'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&auto=format&fit=crop&q=80',
          userRank: 'Elite 👑',
          text: '@Alex Carter Optimum Nutrition Gold Standard Double Rich Chocolate.',
          createdAt: now.subtract(const Duration(hours: 3, minutes: 20)),
          likes: 4,
        ),
        PostComment(
          id: 'c_shake_4',
          postId: 'post_shake_1',
          userId: 'usr_liam',
          userName: "Liam O'Connor",
          userAvatar:
              'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200&auto=format&fit=crop&q=80',
          userRank: 'Rising Athlete ⚡',
          text: 'Adding frozen berries takes this to another level.',
          createdAt: now.subtract(const Duration(hours: 3)),
          likes: 3,
        ),
        PostComment(
          id: 'c_shake_5',
          postId: 'post_shake_1',
          userId: 'usr_maya',
          userName: 'Maya Chen',
          userAvatar:
              'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=200&auto=format&fit=crop&q=80',
          userRank: 'Platinum I',
          text: '45g protein in under 2 minutes prep time, love it.',
          createdAt: now.subtract(const Duration(hours: 2, minutes: 45)),
          likes: 5,
        ),
        PostComment(
          id: 'c_shake_6',
          postId: 'post_shake_1',
          userId: 'usr_lucas',
          userName: 'Lucas Miller',
          userAvatar:
              'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=200&auto=format&fit=crop&q=80',
          userRank: 'Gold I',
          text: 'Do you use whole milk or almond milk?',
          createdAt: now.subtract(const Duration(hours: 2, minutes: 30)),
        ),
        PostComment(
          id: 'c_shake_7',
          postId: 'post_shake_1',
          userId: 'usr_daniel',
          userName: 'Daniel Kim',
          userAvatar:
              'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&auto=format&fit=crop&q=80',
          userRank: 'Elite 👑',
          text: '@Lucas Miller Whole milk when bulking, unsweetened almond when cutting!',
          createdAt: now.subtract(const Duration(hours: 2, minutes: 20)),
          likes: 3,
        ),
        PostComment(
          id: 'c_shake_8',
          postId: 'post_shake_1',
          userId: 'usr_coach_zuala',
          userName: 'Coach Zuala',
          userAvatar:
              'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&auto=format&fit=crop&q=80',
          userRank: 'Master Coach 🏆',
          text: 'Ideal 30-minute post-workout nutrient timing window.',
          createdAt: now.subtract(const Duration(hours: 2)),
          likes: 4,
        ),
        PostComment(
          id: 'c_shake_9',
          postId: 'post_shake_1',
          userId: 'usr_eric',
          userName: 'Eric Tan',
          userAvatar:
              'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=200&auto=format&fit=crop&q=80',
          userRank: 'Silver III',
          text: 'Adding 30g rolled oats gives insane sustained energy.',
          createdAt: now.subtract(const Duration(hours: 1, minutes: 40)),
          likes: 2,
        ),
        PostComment(
          id: 'c_shake_10',
          postId: 'post_shake_1',
          userId: 'usr_brandon',
          userName: 'Brandon K.',
          userAvatar:
              'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200&auto=format&fit=crop&q=80',
          userRank: 'Gold II',
          text: 'That texture looks perfect, not too chalky.',
          createdAt: now.subtract(const Duration(hours: 1, minutes: 20)),
        ),
        PostComment(
          id: 'c_shake_11',
          postId: 'post_shake_1',
          userId: 'usr_jenny',
          userName: 'Jenny Ralte',
          userAvatar:
              'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=200&auto=format&fit=crop&q=80',
          userRank: 'Coach ⚡',
          text: 'Great potassium and electrolyte replenishment after heavy compound sets.',
          createdAt: now.subtract(const Duration(hours: 1)),
          likes: 3,
        ),
        PostComment(
          id: 'c_shake_12',
          postId: 'post_shake_1',
          userId: 'usr_tyler',
          userName: 'Tyler R.',
          userAvatar:
              'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=200&auto=format&fit=crop&q=80',
          userRank: 'Bronze II',
          text: 'Gonna blend this right after leg day today.',
          createdAt: now.subtract(const Duration(minutes: 45)),
        ),
        PostComment(
          id: 'c_shake_13',
          postId: 'post_shake_1',
          userId: 'usr_nathan',
          userName: 'Nathan P.',
          userAvatar:
              'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&auto=format&fit=crop&q=80',
          userRank: 'Silver I',
          text: 'Solid macros for only 420 calories.',
          createdAt: now.subtract(const Duration(minutes: 30)),
          likes: 1,
        ),
        PostComment(
          id: 'c_shake_14',
          postId: 'post_shake_1',
          userId: 'usr_chris',
          userName: 'Chris Evans',
          userAvatar:
              'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&auto=format&fit=crop&q=80',
          userRank: 'Platinum II',
          text: 'Bookmark saved! 🥤',
          createdAt: now.subtract(const Duration(minutes: 15)),
        ),
      ],
    ),

    // 4. Workout Video Post (19 Comments)
    ActivityPost(
      id: 'post_video_1',
      userId: 'usr_sophia',
      userName: 'Sophia Martinez',
      userAvatar:
          'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=200&auto=format&fit=crop&q=80',
      userRank: 'Iron Warrior ⚔️',
      type: ActivityPostType.workout,
      title: 'Squat Depth & Form Check 🎥',
      description: 'Trying to clean up my squat depth. Getting there.',
      images: const [
        'https://images.unsplash.com/photo-1574680096145-d05b474e2155?w=800&auto=format&fit=crop&q=80',
      ],
      metadata: {
        'isVideo': true,
        'videoDuration': '0:45',
        'durationMinutes': 45,
        'totalVolumeKg': 8400.0,
        'exercisesCount': 5,
        'caloriesBurned': 380.0,
        'xpEarned': 220,
      },
      likes: 89,
      savesCount: 14,
      createdAt: now.subtract(const Duration(hours: 7)),
      commentsList: [
        PostComment(
          id: 'c_vid_1',
          postId: 'post_video_1',
          userId: 'usr_coach_zuala',
          userName: 'Coach Zuala',
          userAvatar:
              'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&auto=format&fit=crop&q=80',
          userRank: 'Master Coach 🏆',
          text: 'Squat depth is well below parallel, great ankle mobility! 🎥',
          createdAt: now.subtract(const Duration(hours: 6, minutes: 30)),
          likes: 7,
        ),
        PostComment(
          id: 'c_vid_2',
          postId: 'post_video_1',
          userId: 'usr_daniel',
          userName: 'Daniel Kim',
          userAvatar:
              'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&auto=format&fit=crop&q=80',
          userRank: 'Elite 👑',
          text: 'Solid volume today. That final set looked brutal 💀',
          createdAt: now.subtract(const Duration(hours: 6, minutes: 15)),
          likes: 4,
        ),
        PostComment(
          id: 'c_vid_3',
          postId: 'post_video_1',
          userId: 'usr_alex',
          userName: 'Alex Carter',
          userAvatar:
              'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&auto=format&fit=crop&q=80',
          userRank: 'Diamond II',
          text: 'Knee travel and torso angle look locked in.',
          createdAt: now.subtract(const Duration(hours: 6)),
          likes: 3,
        ),
        PostComment(
          id: 'c_vid_4',
          postId: 'post_video_1',
          userId: 'usr_liam',
          userName: "Liam O'Connor",
          userAvatar:
              'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200&auto=format&fit=crop&q=80',
          userRank: 'Rising Athlete ⚡',
          text: 'What’s your current push/pull/legs split?',
          createdAt: now.subtract(const Duration(hours: 5, minutes: 40)),
        ),
        PostComment(
          id: 'c_vid_5',
          postId: 'post_video_1',
          userId: 'usr_sophia',
          userName: 'Sophia Martinez',
          userAvatar:
              'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=200&auto=format&fit=crop&q=80',
          userRank: 'Iron Warrior ⚔️',
          text: '@Liam O\'Connor Running a 4-day Upper/Lower hypertrophy split right now!',
          createdAt: now.subtract(const Duration(hours: 5, minutes: 30)),
          likes: 5,
        ),
        PostComment(
          id: 'c_vid_6',
          postId: 'post_video_1',
          userId: 'usr_maya',
          userName: 'Maya Chen',
          userAvatar:
              'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=200&auto=format&fit=crop&q=80',
          userRank: 'Platinum I',
          text: 'The eccentric tempo control is textbook.',
          createdAt: now.subtract(const Duration(hours: 5)),
          likes: 4,
        ),
        PostComment(
          id: 'c_vid_7',
          postId: 'post_video_1',
          userId: 'usr_jenny',
          userName: 'Jenny Ralte',
          userAvatar:
              'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=200&auto=format&fit=crop&q=80',
          userRank: 'Coach ⚡',
          text: 'Great bracing before every rep. Core was rock solid.',
          createdAt: now.subtract(const Duration(hours: 4, minutes: 30)),
          likes: 3,
        ),
        PostComment(
          id: 'c_vid_8',
          postId: 'post_video_1',
          userId: 'usr_marcus',
          userName: 'Marcus Vance',
          userAvatar:
              'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=200&auto=format&fit=crop&q=80',
          userRank: 'Gold II',
          text: 'Are those Olympic lifters shoes or flat soles?',
          createdAt: now.subtract(const Duration(hours: 4)),
        ),
        PostComment(
          id: 'c_vid_9',
          postId: 'post_video_1',
          userId: 'usr_sophia',
          userName: 'Sophia Martinez',
          userAvatar:
              'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=200&auto=format&fit=crop&q=80',
          userRank: 'Iron Warrior ⚔️',
          text: '@Marcus Vance Nike Romaleos 4! Elevated heel helps a ton.',
          createdAt: now.subtract(const Duration(hours: 3, minutes: 45)),
          likes: 2,
        ),
        PostComment(
          id: 'c_vid_10',
          postId: 'post_video_1',
          userId: 'usr_david',
          userName: 'David Lian',
          userAvatar:
              'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=200&auto=format&fit=crop&q=80',
          userRank: 'Silver I',
          text: 'Looked effortless! What weight was on the bar?',
          createdAt: now.subtract(const Duration(hours: 3, minutes: 30)),
        ),
        PostComment(
          id: 'c_vid_11',
          postId: 'post_video_1',
          userId: 'usr_sarah',
          userName: 'Sarah T.',
          userAvatar:
              'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=200&auto=format&fit=crop&q=80',
          userRank: 'Gold I',
          text: 'Goals! I need to work on my hip mobility like this.',
          createdAt: now.subtract(const Duration(hours: 3)),
        ),
        PostComment(
          id: 'c_vid_12',
          postId: 'post_video_1',
          userId: 'usr_hminga',
          userName: 'Hminga Pachuau',
          userAvatar:
              'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&auto=format&fit=crop&q=80',
          userRank: 'Diamond I',
          text: 'Pure power and precision 💪',
          createdAt: now.subtract(const Duration(hours: 2, minutes: 30)),
          likes: 1,
        ),
        PostComment(
          id: 'c_vid_13',
          postId: 'post_video_1',
          userId: 'usr_robert',
          userName: 'Robert R.',
          userAvatar:
              'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200&auto=format&fit=crop&q=80',
          userRank: 'Bronze I',
          text: 'How long did it take to achieve this depth?',
          createdAt: now.subtract(const Duration(hours: 2)),
        ),
        PostComment(
          id: 'c_vid_14',
          postId: 'post_video_1',
          userId: 'usr_sophia',
          userName: 'Sophia Martinez',
          userAvatar:
              'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=200&auto=format&fit=crop&q=80',
          userRank: 'Iron Warrior ⚔️',
          text: '@Robert R. About 6 months of daily calf and ankle stretching!',
          createdAt: now.subtract(const Duration(hours: 1, minutes: 40)),
          likes: 4,
        ),
        PostComment(
          id: 'c_vid_15',
          postId: 'post_video_1',
          userId: 'usr_lucas',
          userName: 'Lucas Miller',
          userAvatar:
              'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=200&auto=format&fit=crop&q=80',
          userRank: 'Gold I',
          text: 'Insane quad engagement!',
          createdAt: now.subtract(const Duration(hours: 1, minutes: 15)),
        ),
        PostComment(
          id: 'c_vid_16',
          postId: 'post_video_1',
          userId: 'usr_eric',
          userName: 'Eric Tan',
          userAvatar:
              'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=200&auto=format&fit=crop&q=80',
          userRank: 'Silver III',
          text: 'Nice work!',
          createdAt: now.subtract(const Duration(minutes: 50)),
        ),
        PostComment(
          id: 'c_vid_17',
          postId: 'post_video_1',
          userId: 'usr_brandon',
          userName: 'Brandon K.',
          userAvatar:
              'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200&auto=format&fit=crop&q=80',
          userRank: 'Gold II',
          text: 'Clean form throughout all reps.',
          createdAt: now.subtract(const Duration(minutes: 30)),
        ),
        PostComment(
          id: 'c_vid_18',
          postId: 'post_video_1',
          userId: 'usr_tyler',
          userName: 'Tyler R.',
          userAvatar:
              'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=200&auto=format&fit=crop&q=80',
          userRank: 'Bronze II',
          text: 'Motivating video for leg day tomorrow.',
          createdAt: now.subtract(const Duration(minutes: 15)),
        ),
        PostComment(
          id: 'c_vid_19',
          postId: 'post_video_1',
          userId: 'usr_chris',
          userName: 'Chris Evans',
          userAvatar:
              'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&auto=format&fit=crop&q=80',
          userRank: 'Platinum II',
          text: 'Flawless execution! 🔥',
          createdAt: now.subtract(const Duration(minutes: 5)),
          likes: 2,
        ),
      ],
    ),

    // 5. Progress / Achievement Post (28 Comments)
    ActivityPost(
      id: 'post_progress_1',
      userId: 'usr_liam',
      userName: 'Liam O\'Connor',
      userAvatar:
          'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200&auto=format&fit=crop&q=80',
      userRank: 'Rising Athlete ⚡',
      type: ActivityPostType.transformation,
      title: '8-Week Consistent Training Block ⚡',
      description: '8 weeks of consistent training.',
      images: const [
        'https://images.unsplash.com/photo-1583454110551-21f2fa2afe61?w=800&auto=format&fit=crop&q=80',
      ],
      metadata: {
        'startWeightKg': 68.0,
        'currentWeightKg': 76.0,
        'durationWeeks': 8,
        'strengthGain': '+15% Strength',
        'weightGain': '+8 kg bodyweight',
        'streak': '8 week streak',
      },
      likes: 112,
      savesCount: 44,
      createdAt: now.subtract(const Duration(days: 1)),
      commentsList: List.generate(28, (i) {
        final users = [
          ('Alex Carter', 'usr_alex', 'Diamond II', 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&auto=format&fit=crop&q=80', 'Insane transformation! That back definition is crazy.'),
          ('Maya Chen', 'usr_maya', 'Platinum I', 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=200&auto=format&fit=crop&q=80', '8kg of lean mass in 8 weeks? What was your daily caloric surplus?'),
          ('Coach Zuala', 'usr_coach_zuala', 'Master Coach 🏆', 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&auto=format&fit=crop&q=80', 'Discipline and progressive overload never lie. Excellent execution.'),
          ('Daniel Kim', 'usr_daniel', 'Elite 👑', 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&auto=format&fit=crop&q=80', 'Shoulders and traps blew up. Respect the work ethic! 💪'),
          ('Sophia Martinez', 'usr_sophia', 'Iron Warrior ⚔️', 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=200&auto=format&fit=crop&q=80', 'Consistency is king. Super inspiring transformation!'),
          ('Jenny Ralte', 'usr_jenny', 'Coach ⚡', 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=200&auto=format&fit=crop&q=80', 'Proof that sticking to the program produces real results.'),
          ('Marcus Vance', 'usr_marcus', 'Gold II', 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=200&auto=format&fit=crop&q=80', 'What was your main compound lift focus during this block?'),
        ];
        final u = users[i % users.length];
        return PostComment(
          id: 'c_prog_${i + 1}',
          postId: 'post_progress_1',
          userId: u.$2,
          userName: u.$1,
          userAvatar: u.$4,
          userRank: u.$3,
          text: i < users.length ? u.$5 : 'Great work on week ${8 - (i % 8)} milestone! Keep grinding 🔥',
          createdAt: now.subtract(Duration(hours: 23 - (i % 20), minutes: i * 2)),
          likes: (28 - i) % 5,
        );
      }),
    ),

    // 6. Workout Split Routine Post (24 Comments)
    ActivityPost(
      id: 'post_routine_1',
      userId: 'usr_daniel',
      userName: 'Daniel Kim',
      userAvatar:
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&auto=format&fit=crop&q=80',
      userRank: 'Gold I',
      type: ActivityPostType.routine,
      title: 'My 6-Day PPL Hypertrophy Split 📋',
      description:
          'Tested and proven mass builder split. Optimized for mechanical tension and high weekly volume without joint fatigue.',
      metadata: {
        'splitName': 'Power PPL Split',
        'days': [
          {
            'dayName': 'Day 1: Push (Chest & Triceps)',
            'exercises': [
              'Barbell Bench Press',
              'Incline Dumbbell Press',
              'Tricep Rope Pushdown',
              'Lateral Raises',
            ],
          },
          {
            'dayName': 'Day 2: Pull (Back & Biceps)',
            'exercises': [
              'Barbell Deadlift',
              'Chest-Supported Row',
              'Lat Pulldown',
              'Hammer Curls',
            ],
          },
          {
            'dayName': 'Day 3: Legs (Quads & Calves)',
            'exercises': [
              'Barbell Squat',
              'Romanian Deadlift',
              'Leg Extension',
              'Calf Raises',
            ],
          },
        ],
      },
      likes: 89,
      savesCount: 120,
      createdAt: now.subtract(const Duration(hours: 18)),
      commentsList: List.generate(24, (i) {
        final users = [
          ('Alex Carter', 'usr_alex', 'Diamond II', 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&auto=format&fit=crop&q=80', 'Saving this routine! Perfect chest and triceps pairing.'),
          ('Maya Chen', 'usr_maya', 'Platinum I', 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=200&auto=format&fit=crop&q=80', 'PPL is undefeated for hypertrophy. How long are your rest periods?'),
          ('Coach Zuala', 'usr_coach_zuala', 'Master Coach 🏆', 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&auto=format&fit=crop&q=80', 'Great exercise selection balancing horizontal and vertical pressing.'),
          ('Sophia Martinez', 'usr_sophia', 'Iron Warrior ⚔️', 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=200&auto=format&fit=crop&q=80', 'Bookmarked! Gonna run this for my next 12-week block.'),
          ('Liam O\'Connor', 'usr_liam', 'Rising Athlete ⚡', 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200&auto=format&fit=crop&q=80', 'Do you take rest days between PPL cycles or after leg day?'),
          ('Jenny Ralte', 'usr_jenny', 'Coach ⚡', 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=200&auto=format&fit=crop&q=80', 'Chest-supported rows are so underrated for mid-back thickness.'),
        ];
        final u = users[i % users.length];
        return PostComment(
          id: 'c_rout_${i + 1}',
          postId: 'post_routine_1',
          userId: u.$2,
          userName: u.$1,
          userAvatar: u.$4,
          userRank: u.$3,
          text: i < users.length ? u.$5 : 'Solid exercise ordering on Day ${(i % 3) + 1} 👌',
          createdAt: now.subtract(Duration(hours: 17 - (i % 14), minutes: i * 3)),
          likes: (24 - i) % 4,
        );
      }),
    ),
  ];
}
