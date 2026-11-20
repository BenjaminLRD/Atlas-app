import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../data/app_dependencies.dart';
import '../data/local_storage.dart';
import '../models/workout_history.dart';
import '../providers/fitness_provider.dart';
import '../services/challenges/atlas_challenge_service.dart';
import '../services/challenges/thirty_day_challenge.dart';
import '../widgets/workout/thirty_day_challenge_card.dart';
import '../models/active_workout_session.dart';
import '../models/exercise.dart';
import '../widgets/common/app_button.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/app_chip.dart';
import '../widgets/common/app_header.dart';
import '../services/exercise/muscle_map.dart';
import '../widgets/exercise/exercise_thumbnail.dart';
import '../widgets/exercise/muscle_map_card.dart';
import 'custom_workouts_screen.dart';
import 'exercise_detail_screen.dart';
import 'weekly_workout_plan_screen.dart';
import 'workout_session_screen.dart';

/// Rough session length used on the overview: 40 s of work per set plus the
/// 90 s default rest of the session screen, and a 5 minute warm-up.
class WorkoutDurationEstimate {
  static const int secondsPerSet = 40;
  static const int restSeconds = 90;
  static const int warmUpMinutes = 5;

  static int totalSets(List<Map<String, dynamic>> exercises) {
    var total = 0;
    for (final ex in exercises) {
      final sets = ex['sets'];
      total += sets is List ? sets.length : 3;
    }
    return total;
  }

  /// Estimated minutes, rounded to the nearest 5.
  static int minutes(List<Map<String, dynamic>> exercises) {
    final seconds = totalSets(exercises) * (secondsPerSet + restSeconds);
    final raw = seconds / 60 + warmUpMinutes;
    return ((raw / 5).round() * 5).clamp(5, 240);
  }
}

/// The Workouts tab: today's planned workout, reviewed before the session
/// starts. The session itself is the existing [WorkoutSessionScreen].
class WorkoutOverviewScreen extends StatefulWidget {
  /// Replaces the weekly plan builder. Only for tests.
  @visibleForTesting
  final List<DailyPlan> Function()? planBuilder;

  /// Replaces the saved-session lookup. Only for tests.
  @visibleForTesting
  final ActiveWorkoutSession? Function()? activeSessionReader;

  /// Replaces the 30-day challenge lookup. Only for tests.
  @visibleForTesting
  final ThirtyDayView? Function()? challengeLoader;

  /// Replaces the check for a workout already completed today. Only for tests.
  @visibleForTesting
  final bool Function(DailyPlan plan)? completedTodayChecker;

  const WorkoutOverviewScreen({
    super.key,
    this.planBuilder,
    this.activeSessionReader,
    this.challengeLoader,
    this.completedTodayChecker,
  });

  @override
  State<WorkoutOverviewScreen> createState() => _WorkoutOverviewScreenState();
}

class _WorkoutOverviewScreenState extends State<WorkoutOverviewScreen> {
  late List<DailyPlan> _plans;
  ActiveWorkoutSession? _active;
  bool _viewTodayAnyway = false;
  ThirtyDayView? _challenge;
  bool _accepting = false;

  static Map<String, Exercise>? _registry;

  @override
  void initState() {
    super.initState();
    _plans = _loadPlans();
    _active = _readActive();
    _challenge = _loadChallenge();
    FitnessProvider.instance.addListener(_dataChanged);
  }

  @override
  void dispose() {
    FitnessProvider.instance.removeListener(_dataChanged);
    super.dispose();
  }

  /// A finished workout, or Showcase being switched, changes what is shown.
  void _dataChanged() {
    if (!mounted) return;
    setState(() {
      _plans = _loadPlans();
      _active = _readActive();
      _challenge = _loadChallenge();
    });
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// The athlete's own accepted 30-day challenge, or in Showcase Mode a sample
  /// one that is already accepted. Days are filled only by workouts that were
  /// really completed.
  ThirtyDayView? _loadChallenge() {
    if (widget.challengeLoader != null) return widget.challengeLoader!();
    final now = DateTime.now();
    final history = FitnessProvider.instance.workoutHistory;
    if (LocalStorage.isShowcaseModeEnabled()) {
      // Never reads or writes the athlete's own challenges.
      return ThirtyDayChallenge.sample(
        now: now,
        demoWorkoutDates: [
          for (final w in history)
            if (_sameDay(w.dateCompleted, now)) w.dateCompleted,
        ],
      );
    }
    final c = ThirtyDayChallenge.find(AtlasChallengeService.instance.active());
    if (c == null) return null;
    return ThirtyDayChallenge.view(
      challenge: c,
      workoutDates: [for (final w in history) w.dateCompleted],
      now: now,
    );
  }

  Future<void> _acceptChallenge() async {
    if (_accepting) return;
    setState(() => _accepting = true);
    try {
      await ThirtyDayChallenge.accept(AtlasChallengeService.instance);
    } finally {
      if (mounted) {
        setState(() {
          _accepting = false;
          _challenge = _loadChallenge();
        });
      }
    }
  }

  /// True when today's planned workout is already in the history.
  bool _completedToday(DailyPlan plan) {
    if (widget.completedTodayChecker != null) {
      return widget.completedTodayChecker!(plan);
    }
    final now = DateTime.now();
    for (final WorkoutHistory w in FitnessProvider.instance.workoutHistory) {
      if (_sameDay(w.dateCompleted, now) && w.workoutName == plan.title) {
        return true;
      }
    }
    return false;
  }

  List<DailyPlan> _loadPlans() {
    try {
      return (widget.planBuilder ?? buildWeeklyPlans)();
    } catch (e) {
      debugPrint('[WorkoutOverview] could not build the weekly plan: $e');
      return const [];
    }
  }

  ActiveWorkoutSession? _readActive() => widget.activeSessionReader != null
      ? widget.activeSessionReader!()
      : AppDependencies.instance.workoutService.getActiveSession();

  DailyPlan? get _today {
    for (final plan in _plans) {
      if (plan.isToday) return plan;
    }
    return null;
  }

  /// The id the weekly plan uses for a day, so history and saved sessions
  /// line up with the weekly plan screen.
  static String workoutIdFor(DailyPlan plan) =>
      'weekly_plan_${plan.dayName.toLowerCase()}';

  bool _activeMatches(DailyPlan plan) {
    final active = _active;
    if (active == null) return false;
    return active.workoutId == workoutIdFor(plan) ||
        active.workoutName == plan.title;
  }

  Exercise? _exerciseFor(Map<String, dynamic> ex) {
    final id = ex['id']?.toString();
    if (id == null || id.isEmpty) return null;
    _registry ??= {for (final e in Exercise.defaultRegistry()) e.id: e};
    return _registry![id];
  }

  Future<void> _openSession({
    required String name,
    required String id,
    required List<Map<String, dynamic>>? exercises,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutSessionScreen(
          workoutName: name,
          workoutId: id,
          initialExercises: exercises,
        ),
      ),
    );
    if (mounted) {
      setState(() {
        _active = _readActive();
        _viewTodayAnyway = false;
      });
    }
  }

  Future<void> _resume() {
    final active = _active!;
    return _openSession(
      name: active.workoutName,
      id: active.workoutId ?? 'resumed_session',
      exercises: active.exercisesData,
    );
  }

  Future<void> _openWeeklyPlan() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WeeklyWorkoutPlanScreen()),
    );
    if (mounted) {
      setState(() {
        _plans = _loadPlans();
        _active = _readActive();
      });
    }
  }

  Future<void> _reviewAndStart(DailyPlan plan) async {
    final exercises = plan.structuredExercises;
    final replaces = _active != null && !_activeMatches(plan);
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: context.appSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ready to start?',
                style: AppTheme.headlineMd.copyWith(
                  fontWeight: FontWeight.w900,
                  color: ctx.appTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${plan.title}: ${exercises.length} exercises, '
                '${WorkoutDurationEstimate.totalSets(exercises)} sets, '
                'about ${WorkoutDurationEstimate.minutes(exercises)} min.',
                style: AppTheme.bodyMd.copyWith(color: ctx.appTextSecondary),
              ),
              if (replaces) ...[
                const SizedBox(height: 8),
                Text(
                  'Starting this replaces your unfinished '
                  '"${_active!.workoutName}".',
                  key: const Key('replace_warning'),
                  style: AppTheme.bodyMd.copyWith(
                    color: Theme.of(ctx).colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              AppButton.primary(
                label: 'Start workout',
                icon: Icons.play_arrow_rounded,
                onPressed: () => Navigator.pop(ctx, true),
              ),
              const SizedBox(height: 8),
              AppButton.text(
                label: 'Keep reviewing',
                onPressed: () => Navigator.pop(ctx, false),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    await _openSession(
      name: plan.title,
      id: workoutIdFor(plan),
      exercises: exercises,
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = _today;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final active = _active;
    final todayMatchesActive = today != null && _activeMatches(today);

    final children = <Widget>[
      ThirtyDayChallengeCard(
        view: _challenge,
        onAccept: _acceptChallenge,
        accepting: _accepting,
      ),
      const SizedBox(height: 20),
      if (active != null) _buildResumeCard(context, active, today),
      if (active == null || todayMatchesActive || _viewTodayAnyway)
        ..._buildToday(context, today, hasActive: todayMatchesActive),
      if (active != null && !todayMatchesActive && !_viewTodayAnyway) ...[
        const SizedBox(height: 12),
        AppButton.outlined(
          key: const Key('view_today_plan'),
          label: today == null || today.isRestDay
              ? 'View weekly plan'
              : "View today's plan",
          onPressed: today == null || today.isRestDay
              ? _openWeeklyPlan
              : () => setState(() => _viewTodayAnyway = true),
        ),
      ],
      const SizedBox(height: 12),
      AppButton.outlined(
        key: const Key('my_workouts_button'),
        label: 'My workouts: build your own',
        icon: Icons.edit_note_rounded,
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const CustomWorkoutsScreen())),
      ),
    ];

    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppHeader.standard(
        title: 'WORKOUTS',
        subtitle: today == null ? 'Plan your training' : "Today's workout",
        showSettings: false,
      ),
      body: ListView(
        key: const PageStorageKey('workout_overview_list'),
        padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset + 130),
        children: children,
      ),
    );
  }

  Widget _buildResumeCard(
    BuildContext context,
    ActiveWorkoutSession active,
    DailyPlan? today,
  ) {
    final done = active.completedSets.fold<int>(
      0,
      (sum, sets) => sum + sets.where((c) => c).length,
    );
    final total = active.completedSets.fold<int>(
      0,
      (sum, sets) => sum + sets.length,
    );
    final minutes = (active.seconds / 60).floor();
    final differs = today != null && !_activeMatches(today);

    return AppCard(
      key: const Key('resume_card'),
      borderColor: AppColors.primary.withValues(alpha: 0.5),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timelapse_rounded, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Workout in progress',
                  style: AppTheme.headlineSm.copyWith(
                    fontWeight: FontWeight.w800,
                    color: context.appTextPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${active.workoutName}: $done of $total sets done, '
            '$minutes min elapsed.',
            style: AppTheme.bodyMd.copyWith(color: context.appTextSecondary),
          ),
          if (differs) ...[
            const SizedBox(height: 6),
            Text(
              'This is not today\'s planned workout '
              '(${today.isRestDay ? 'rest day' : today.title}).',
              key: const Key('resume_differs'),
              style: AppTheme.bodySm.copyWith(color: context.appTextSecondary),
            ),
          ],
          const SizedBox(height: 12),
          AppButton.primary(
            key: const Key('resume_button'),
            label: 'Resume workout',
            icon: Icons.play_arrow_rounded,
            onPressed: _resume,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildToday(
    BuildContext context,
    DailyPlan? today, {
    required bool hasActive,
  }) {
    if (today == null ||
        (!today.isRestDay && today.structuredExercises.isEmpty)) {
      return [_buildEmptyState(context)];
    }
    if (today.isRestDay) return [_buildRestDay(context, today)];

    final exercises = today.structuredExercises;
    final minutes = WorkoutDurationEstimate.minutes(exercises);
    final sets = WorkoutDurationEstimate.totalSets(exercises);

    final completed = _completedToday(today);
    return [
      if (hasActive) const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          "TODAY'S WORKOUT",
          key: const Key('today_heading'),
          style: AppTheme.headlineMd.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: context.appTextPrimary,
          ),
        ),
      ),
      AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (completed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  key: const Key('today_completed'),
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Completed today',
                      style: AppTheme.bodySm.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            Text(
              today.title,
              key: const Key('overview_title'),
              style: AppTheme.headlineMd.copyWith(
                fontWeight: FontWeight.w900,
                color: context.appTextPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Focus: ${today.muscleGroups}',
              style: AppTheme.bodyMd.copyWith(color: context.appTextSecondary),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AppChip(
                  label: '${exercises.length} exercises',
                  icon: Icons.fitness_center_rounded,
                ),
                AppChip(label: '$sets sets', icon: Icons.repeat_rounded),
                AppChip(label: '~$minutes min', icon: Icons.schedule_rounded),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Estimate: ${WorkoutDurationEstimate.secondsPerSet} s per set + '
              '${WorkoutDurationEstimate.restSeconds} s rest, plus '
              '${WorkoutDurationEstimate.warmUpMinutes} min warm-up. '
              'Plan target: ${today.durationMinutes} min.',
              style: AppTheme.bodySm.copyWith(
                color: context.appTextSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      for (var i = 0; i < exercises.length; i++)
        _buildExerciseTile(
          context,
          i,
          exercises[i],
          done: completed || _exerciseDone(i),
        ),
      if (!hasActive) ...[
        const SizedBox(height: 16),
        AppButton.primary(
          key: const Key('review_start'),
          label: completed ? 'Train again' : 'Review & Start',
          icon: Icons.play_arrow_rounded,
          onPressed: () => _reviewAndStart(today),
        ),
      ],
      const SizedBox(height: 8),
      AppButton.outlined(
        key: const Key('open_weekly_plan'),
        label: 'Change session in weekly plan',
        icon: Icons.calendar_month_rounded,
        onPressed: _openWeeklyPlan,
      ),
      const SizedBox(height: 12),
      MuscleMapCard(
        activation: MuscleMap.forWorkout(exercises),
        subtitle: 'What ${today.title} trains today.',
        footer: AppButton.outlined(
          key: const Key('muscle_map_by_exercise'),
          label: 'See muscles by exercise',
          icon: Icons.accessibility_new_rounded,
          onPressed: () => MuscleMapSheet.show(
            context,
            workoutName: today.title,
            exercises: exercises,
          ),
        ),
      ),
      const SizedBox(height: 12),
    ];
  }

  /// An exercise of an unfinished session whose sets are all ticked.
  bool _exerciseDone(int index) {
    final active = _active;
    final today = _today;
    if (active == null || today == null || !_activeMatches(today)) return false;
    if (index >= active.completedSets.length) return false;
    final sets = active.completedSets[index];
    return sets.isNotEmpty && sets.every((c) => c);
  }

  Widget _buildExerciseTile(
    BuildContext context,
    int index,
    Map<String, dynamic> ex, {
    bool done = false,
  }) {
    final name = ex['name']?.toString() ?? 'Exercise';
    final sets = ex['sets'];
    final setCount = sets is List ? sets.length : 3;
    final reps = ex['reps'] ?? 10;
    final muscle =
        ex['primaryTarget']?.toString() ?? ex['muscleGroup']?.toString() ?? '';
    final reasons = ex['aiReasoning'];
    final reason = reasons is List && reasons.isNotEmpty
        ? reasons.first.toString()
        : null;
    final detail = _exerciseFor(ex);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        key: Key('exercise_tile_$index'),
        padding: const EdgeInsets.all(12),
        onTap: detail == null
            ? null
            : () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ExerciseDetailScreen(
                    exercise: detail,
                    enableWorkoutStart: false,
                  ),
                ),
              ),
        child: Row(
          children: [
            // The order to do them in.
            Container(
              key: Key('exercise_number_$index'),
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done
                    ? AppColors.primary
                    : AppColors.primary.withValues(alpha: 0.14),
              ),
              child: done
                  ? const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: Colors.black,
                    )
                  : Text(
                      '${index + 1}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            // Fixed-size thumbnail: loads asynchronously, falls back to an
            // icon tile, and never shifts the layout.
            SizedBox(
              width: 56,
              height: 56,
              child: ExerciseThumbnail(
                key: Key('exercise_image_$index'),
                exerciseId: (ex['id'] ?? detail?.id ?? name).toString(),
                exerciseName: name,
                size: 56,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.bodyMd.copyWith(
                      fontWeight: FontWeight.w700,
                      color: context.appTextPrimary,
                      decoration: done ? TextDecoration.lineThrough : null,
                      decorationColor: context.appTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    muscle.isEmpty
                        ? '$setCount sets × $reps reps'
                        : '$setCount sets × $reps reps · $muscle',
                    style: AppTheme.bodySm.copyWith(
                      color: context.appTextSecondary,
                    ),
                  ),
                  if (reason != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      reason,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.bodySm.copyWith(
                        color: context.appTextSecondary,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (detail != null)
              Icon(
                Icons.chevron_right_rounded,
                color: context.appTextSecondary,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestDay(BuildContext context, DailyPlan today) {
    return AppCard(
      key: const Key('rest_day_card'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.self_improvement_rounded,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Rest day',
                  style: AppTheme.headlineMd.copyWith(
                    fontWeight: FontWeight.w900,
                    color: context.appTextPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${today.title} is on today\'s plan. Recovery is part of '
            'training: keep it light and see the rest of the week below.',
            style: AppTheme.bodyMd.copyWith(color: context.appTextSecondary),
          ),
          const SizedBox(height: 12),
          AppButton.outlined(
            key: const Key('open_weekly_plan'),
            label: 'View weekly plan',
            icon: Icons.calendar_month_rounded,
            onPressed: _openWeeklyPlan,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return AppCard(
      key: const Key('no_plan_card'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No workout planned for today',
            style: AppTheme.headlineMd.copyWith(
              fontWeight: FontWeight.w900,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Open your weekly plan to see this week\'s sessions and start one.',
            style: AppTheme.bodyMd.copyWith(color: context.appTextSecondary),
          ),
          const SizedBox(height: 12),
          AppButton.primary(
            key: const Key('open_weekly_plan'),
            label: 'Open weekly plan',
            icon: Icons.calendar_month_rounded,
            onPressed: _openWeeklyPlan,
          ),
        ],
      ),
    );
  }
}
