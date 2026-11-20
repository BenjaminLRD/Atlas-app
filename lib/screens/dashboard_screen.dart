import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_theme.dart';
import '../services/steps/step_counter_service.dart';
import '../widgets/activity/step_status_panel.dart';
import '../data/app_dependencies.dart';
import '../data/profile_provider.dart';
import '../providers/fitness_provider.dart';
import '../providers/showcase_mode_provider.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/app_header.dart';
import '../widgets/common/app_hero_card.dart';
import '../widgets/common/app_button.dart';
import '../widgets/common/app_bottom_sheet.dart';
import '../widgets/common/app_list_tile.dart';
import '../widgets/common/metric_card.dart';
import '../widgets/common/progress_ring.dart';
import '../widgets/common/section_header.dart';
import 'ai_coach_screen.dart';
import 'body_composition_screen.dart';
import 'edit_profile_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'workout_session_screen.dart';
import 'weekly_workout_plan_screen.dart';
import '../widgets/coach/coach_summary_card.dart';
import '../widgets/recovery/sleep_recovery_card.dart';
import '../widgets/common/deload_alert_card.dart';
import '../widgets/common/adaptive_workout_card.dart';
import '../widgets/common/daily_motivation_card.dart';
import '../widgets/common/animated_rank_progress_card.dart';
import '../widgets/common/ranked_invitation_card.dart';
import 'ranked_screen.dart';
import '../widgets/common/water_intake_card.dart';
import '../models/hydration.dart';
import '../services/hydration/hydration_service.dart';
import 'hydration_screen.dart';
import '../widgets/activity/today_activity_card.dart';
import '../widgets/health/today_health_card.dart';
import '../widgets/dashboard/weight_trends_card.dart';
import '../widgets/dashboard/dashboard_achievements_card.dart';
import '../services/step_tracking_service.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final ProfileProvider _profileProvider;

  double _proteinConsumed = 0.0;
  double _proteinGoal = 140.0;
  DateTime _lastWaterTap = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _profileProvider = AppDependencies.instance.profileProvider;
    _profileProvider.addListener(_onProfileChanged);
    FitnessProvider.instance.addListener(_onFitnessChanged);
    ShowcaseModeProvider.instance.addListener(_onShowcaseChanged);
    StepCounterService.instance.addListener(_onStepsChanged);
    HydrationService.instance.addListener(_onHydrationChanged);
    HydrationService.instance.refreshTodayGoal();
    _loadState();
  }

  void _onHydrationChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    HydrationService.instance.removeListener(_onHydrationChanged);
    StepCounterService.instance.removeListener(_onStepsChanged);
    ShowcaseModeProvider.instance.removeListener(_onShowcaseChanged);
    FitnessProvider.instance.removeListener(_onFitnessChanged);
    _profileProvider.removeListener(_onProfileChanged);
    super.dispose();
  }

  void _onStepsChanged() {
    if (mounted) setState(() {});
  }

  void _onShowcaseChanged() {
    if (mounted) {
      _loadState();
      setState(() {});
    }
  }

  void _onFitnessChanged() {
    if (mounted) {
      _loadState();
    }
  }

  void _onProfileChanged() {
    if (mounted) setState(() {});
  }

  void _loadState() {
    setState(() {
      _proteinConsumed = FitnessProvider.instance.proteinConsumed;
      _proteinGoal = FitnessProvider.instance.proteinGoal > 0
          ? FitnessProvider.instance.proteinGoal
          : 140.0;
    });
  }

  void _showActivityRingsModal() {
    final provider = FitnessProvider.instance;
    final streakDays = provider.userProgress.workoutStreak;
    final streakPct = (streakDays / 7.0).clamp(0.0, 1.0);
    final calTarget = provider.todayNutritionLog.calorieGoal;
    final calPct = provider.todayNutritionLog.calorieProgress;
    final protPct = _proteinGoal > 0
        ? (_proteinConsumed / _proteinGoal).clamp(0.0, 1.0)
        : 0.0;

    AppBottomSheet.show(
      context: context,
      title: 'Daily Activity Breakdown',
      child: Column(
        children: [
          AppListTile(
            leadingIcon: Icons.bolt,
            iconColor: AppColors.ringStreak,
            title: 'Workout Streak',
            subtitle: streakDays > 0
                ? '$streakDays consecutive active ${streakDays == 1 ? 'day' : 'days'} completed'
                : 'No active streak yet — complete a workout today',
            trailing: Text(
              '${(streakPct * 100).toInt()}%',
              style: AppTheme.headlineMd.copyWith(
                fontSize: 16,
                color: AppColors.ringStreak,
              ),
            ),
          ),
          const Divider(height: 1),
          AppListTile(
            leadingIcon: Icons.local_fire_department,
            iconColor: AppColors.ringCalories,
            title: 'Calories Burned',
            subtitle:
                '${provider.todayNutritionLog.dailyCaloriesLabel} kcal of ${calTarget.toInt()} kcal daily target',
            trailing: Text(
              '${(calPct * 100).toInt()}%',
              style: AppTheme.headlineMd.copyWith(
                fontSize: 16,
                color: AppColors.ringCalories,
              ),
            ),
          ),
          const Divider(height: 1),
          AppListTile(
            leadingIcon: Icons.restaurant,
            iconColor: AppColors.ringProtein,
            title: 'Protein Consumed',
            subtitle:
                '${FitnessProvider.instance.todayConsumed.proteinText} of ${_proteinGoal.toStringAsFixed(0)}g target',
            trailing: Text(
              '${(protPct * 100).toInt()}%',
              style: AppTheme.headlineMd.copyWith(
                fontSize: 16,
                color: AppColors.ringProtein,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showStepsAnalyticsModal() {
    final stepGoal = const StepTrackingService().getStepGoal();
    AppBottomSheet.show(
      context: context,
      title: 'Daily Step Breakdown',
      child: ListenableBuilder(
        listenable: StepCounterService.instance,
        builder: (context, _) {
          final today = StepCounterService.instance.today;
          final steps = today.steps;
          final stepProgress = (steps == null || stepGoal <= 0)
              ? 0.0
              : (steps / stepGoal).clamp(0.0, 1.0);
          final km = StepTrackingService.distanceKmFor(steps);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                steps == null
                    ? 'Steps today: -- / $stepGoal'
                    : 'Steps today: $steps / $stepGoal',
                style: AppTheme.headlineMd.copyWith(
                  fontSize: 15,
                  color: context.appTextPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                km == null
                    ? 'Distance: --'
                    : 'Distance: ~${km.toStringAsFixed(1)} km (from your steps and an average stride)',
                style: AppTheme.bodySm.copyWith(
                  fontSize: 12,
                  color: context.appTextSecondary,
                ),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: stepProgress,
                  minHeight: 8,
                  color: AppColors.primary,
                  backgroundColor: AppColors.surfaceElevated,
                ),
              ),
              const SizedBox(height: 12),
              const StepStatusPanel(),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekdays = [
      'MONDAY',
      'TUESDAY',
      'WEDNESDAY',
      'THURSDAY',
      'FRIDAY',
      'SATURDAY',
      'SUNDAY',
    ];
    final months = [
      'OCT',
      'NOV',
      'DEC',
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
    ];
    final dateLabel =
        '${weekdays[now.weekday - 1]}, ${months[(now.month - 1) % 12]} ${now.day}';
    final hour = now.hour;
    final greetingPrefix = hour >= 5 && hour < 12
        ? 'Good morning'
        : hour >= 12 && hour < 17
        ? 'Good afternoon'
        : hour >= 17 && hour < 21
        ? 'Good evening'
        : 'Good night';

    final rawName = _profileProvider.displayName.trim();
    final hasName = rawName.isNotEmpty;
    final greetingTitle = hasName
        ? '$greetingPrefix, $rawName'
        : greetingPrefix;
    final userInitials = _profileProvider.isShowcaseIdentity
        ? ''
        : hasName
        ? rawName[0].toUpperCase()
        : 'AG';
    final avatarPic = _profileProvider.displayProfilePic.trim();

    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppHeader.standard(
        title: greetingTitle,
        subtitle: dateLabel,
        avatarUrl: avatarPic.isNotEmpty ? avatarPic : null,
        userInitials: userInitials,
        onAvatarTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProfileScreen()),
        ),
        showNotifications: false,
        showSettings: true,
        onSettingsTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        ),
      ),
      body: SingleChildScrollView(
        key: const PageStorageKey('dashboard_scroll_view'),
        padding: EdgeInsets.only(
          top: 12,
          bottom: bottomInset + 130,
          left: 16,
          right: 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!hasName) ...[
              AppCard(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
                child: InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EditProfileScreen(),
                    ),
                  ),
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.person_add_outlined,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Complete your profile to personalize your fitness journey',
                          style: AppTheme.bodySm.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: context.appTextSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: context.appTextSecondary,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ──────────────────────────────────────────
            // 0. SHOWCASE MODE BANNER (If Active)
            // ──────────────────────────────────────────
            _buildShowcaseBanner(context),

            // ──────────────────────────────────────────
            // 1. AI COACH QUICK ACTION PILLS
            // ──────────────────────────────────────────
            _buildAICoachQuickBar(context),
            const SizedBox(height: 16),

            // ──────────────────────────────────────────
            // 2. IMPORTANT ACTION: Active Protocol Card
            // ──────────────────────────────────────────
            _buildProtocolCard(context),
            const SizedBox(height: 16),

            // ──────────────────────────────────────────
            // 2. PROGRESS: Motivation, Activity Rings, Ranked & Metrics
            // ──────────────────────────────────────────
            const DailyMotivationCard(),
            const SizedBox(height: 14),

            // Daily Activity Rings Card
            _buildActivityRingsCard(context),
            const SizedBox(height: 14),

            // Ranked Mode Card
            Builder(
              builder: (context) {
                final provider = FitnessProvider.instance;
                final progress = provider.userProgress;
                final isJoined = progress.rankedUnlocked;

                if (!isJoined) {
                  return RankedInvitationCard(
                    onJoin: () async {
                      await provider.joinRankedMode();
                      if (context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RankedScreen(),
                          ),
                        );
                      }
                    },
                  );
                }

                final nextReq = provider.nextRankRequirement;
                final points = nextReq['points'] as int? ?? 0;
                final needed = nextReq['neededMilestones'] as int? ?? 0;
                final nextRank = (nextReq['nextRank'] as String?) ?? '';

                // Rank, next target and progress all come from the same
                // position, so they cannot disagree.
                return AnimatedRankProgressCard(
                  currentRank:
                      (nextReq['currentRank'] as String?) ?? provider.fullRank,
                  nextRank: nextRank,
                  currentPoints: points,
                  targetPoints: (nextReq['topPoints'] as int?) ?? points,
                  milestonesToNext: needed,
                  isMaxRank: nextReq['isMaxRank'] as bool? ?? false,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RankedScreen()),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 14),

            // 2. Today's Activity & Step Intelligence Card
            const TodayActivityCard(),
            const SizedBox(height: 14),

            // 3. Today's Health Telemetry (Steps, Kcal, Heart Rate, Sleep)
            const TodayHealthCard(),
            const SizedBox(height: 14),

            // Responsive Health Metric Section (2-Column Bento Grid)
            _buildResponsiveMetricsGrid(context),
            const SizedBox(height: 16),

            // ──────────────────────────────────────────
            // 3. RECOMMENDATIONS: AI Coach, Readiness & Adaptive Intelligence
            // ──────────────────────────────────────────
            const SectionHeader(
              title: 'Recommendations & Intelligence',
              subtitle:
                  'Tailored daily guidance from AI Coach & Recovery Engine',
            ),
            const SizedBox(height: 12),

            // AI Coach Summary Card
            const CoachSummaryCard(),
            const SizedBox(height: 14),

            // Readiness, Recovery & Adaptive Workout Intelligence Section
            Builder(
              builder: (context) {
                final provider = FitnessProvider.instance;
                final recoveryState = provider.recoveryState;
                final recommendation = provider.todaysRecommendation;

                return Column(
                  children: [
                    const SleepRecoveryCard(),
                    const SizedBox(height: 14),
                    const WeightTrendsCard(),
                    const SizedBox(height: 14),
                    const DashboardAchievementsCard(),
                    const SizedBox(height: 14),
                    if (recoveryState?.isDeloadRecommended ?? false) ...[
                      const DeloadAlertCard(),
                      const SizedBox(height: 14),
                    ],
                    AdaptiveWorkoutCard(
                      workout: recommendation,
                      onStartWorkout: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => WorkoutSessionScreen(
                              workoutName:
                                  recommendation?.title ?? 'Adaptive Workout',
                              workoutId:
                                  recommendation?.id ?? 'rec_adaptive_01',
                              initialExercises: recommendation?.exercises
                                  .map((e) => {'name': e})
                                  .toList(),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                  ],
                );
              },
            ),

            // Performance Trend Section Header & Bar Chart
            const SectionHeader(
              title: 'Performance Trend',
              subtitle: '7-day workout volume & intensity',
            ),
            const SizedBox(height: 12),
            _buildPerformanceTrendChart(context),
          ],
        ),
      ),
    );
  }

  Widget _buildProtocolCard(BuildContext context) {
    final provider = FitnessProvider.instance;
    final rec = provider.todaysRecommendation;
    final title = rec?.title ?? 'Daily Workout Protocol';
    final duration = rec?.estimatedDuration ?? 45;
    final calories = (duration * 7);
    final subtitle = '$duration mins · $calories kcal targeted burn';
    final workoutId = rec?.id ?? 'rec_daily_01';
    final initialEx = rec?.exercises.map((e) => {'name': e}).toList();

    return AppHeroCard(
      tag: 'ACTIVE PROTOCOL',
      title: title,
      subtitle: subtitle,
      actionButton: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppButton.secondary(
              label: 'Plan',
              isFullWidth: false,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const WeeklyWorkoutPlanScreen(),
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
            AppButton.primary(
              label: 'Start Workout',
              icon: Icons.play_arrow_rounded,
              isFullWidth: false,
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WorkoutSessionScreen(
                      workoutName: title,
                      workoutId: workoutId,
                      initialExercises: initialEx,
                    ),
                  ),
                );
                if (context.mounted) {
                  setState(() {});
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShowcaseBanner(BuildContext context) {
    final showcaseProvider = ShowcaseModeProvider.instance;
    if (!showcaseProvider.isShowcaseModeEnabled) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.isDarkMode
            ? AppColors.primaryContainer.withValues(alpha: 0.15)
            : AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 16,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '✨ Showcase Mode: Active',
                  style: AppTheme.bodySm.copyWith(
                    fontWeight: FontWeight.w700,
                    color: context.appTextPrimary,
                    fontSize: 13,
                  ),
                ),
                Text(
                  'Exploring Atlas with realistic demo athlete data',
                  style: AppTheme.bodySm.copyWith(
                    color: context.appTextSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () async {
              await showcaseProvider.disableShowcaseMode();
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: context.appSurfaceElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: context.appOutlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                'Exit Demo',
                style: AppTheme.labelCaps.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityRingsCard(BuildContext context) {
    final isShowcase = ShowcaseModeProvider.instance.isShowcaseModeEnabled;
    final provider = FitnessProvider.instance;
    final streakDays = isShowcase ? 7 : provider.userProgress.workoutStreak;
    final streakProgress = (streakDays / 7.0).clamp(0.0, 1.0);
    final calBurned = isShowcase
        ? 2153.0
        : provider.todayNutritionLog.dailyCalories;
    final calProgress = isShowcase
        ? (2153.0 / 2300.0)
        : provider.todayNutritionLog.calorieProgress;
    final protConsumed = isShowcase ? 142.0 : _proteinConsumed;
    final protProgress = isShowcase
        ? (142.0 / 160.0)
        : (_proteinGoal > 0
              ? (_proteinConsumed / _proteinGoal).clamp(0.0, 1.0)
              : 0.0);

    final hasActivity =
        isShowcase || (streakDays > 0 || calBurned > 0 || protConsumed > 0);

    return AppCard(
      padding: const EdgeInsets.all(16),
      onTap: _showActivityRingsModal,
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Daily Activity',
                    style: AppTheme.headlineMd.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: context.appTextPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.auto_awesome,
                size: 14,
                color: AppColors.primaryContainer,
              ),
            ],
          ),
          const SizedBox(height: 12),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeOutCubic,
            builder: (context, animVal, child) {
              return Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryContainer.withValues(
                        alpha: context.isDarkMode ? 0.25 : 0.1,
                      ),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ProgressRing.activityRings(
                  size: 130,
                  streakProgress: (streakProgress * animVal).clamp(0.0, 1.0),
                  caloriesProgress: (calProgress * animVal).clamp(0.0, 1.0),
                  proteinProgress: (protProgress * animVal).clamp(0.0, 1.0),
                  centerChild: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryContainer.withValues(alpha: 0.15),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryContainer.withValues(
                            alpha: 0.3,
                          ),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.bolt,
                      color: AppColors.primaryContainer,
                      size: 24,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(
                child: Center(
                  child: _buildRingLegend(
                    context: context,
                    color: AppColors.ringStreak,
                    label: 'STREAK',
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: _buildRingLegend(
                    context: context,
                    color: AppColors.ringCalories,
                    label: 'CALORIES',
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: _buildRingLegend(
                    context: context,
                    color: AppColors.ringProtein,
                    label: 'PROTEIN',
                  ),
                ),
              ),
            ],
          ),
          if (!hasActivity) ...[
            const SizedBox(height: 14),
            Text(
              'No activity data yet',
              style: AppTheme.headlineMd.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: context.appTextPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Start logging your workouts and meals to see your progress here.',
              textAlign: TextAlign.center,
              style: AppTheme.bodySm.copyWith(
                fontSize: 11,
                color: context.appTextSecondary,
              ),
            ),
          ] else ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '$streakDays',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ringStreak,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Day Streak',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: context.appTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '${NumberFormat('#,###').format(calBurned.round())}${!isShowcase && provider.todayNutritionLog.unknownCalorieItems > 0 ? '+' : ''}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ringCalories,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'kcal',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: context.appTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        isShowcase
                            ? '${protConsumed.round()}g'
                            : provider.todayConsumed.proteinText,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ringProtein,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Protein',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: context.appTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRingLegend({
    required BuildContext context,
    required Color color,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.labelCaps.copyWith(
                fontSize: 10,
                color: context.appTextSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Responsive Health Metric Bento Section (2-Column Layout on Mobile, 3-Column on Desktop)
  Widget _buildResponsiveMetricsGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;
        final hasWeight = _profileProvider.weight.isNotEmpty;
        final weightCard = MetricCard(
          iconAsset: 'assets/icons/weight.svg',
          iconBgColor: AppColors.primaryContainer,
          iconColor: Colors.white,
          label: 'Weight',
          value: hasWeight ? _profileProvider.weight : '--',
          unit: hasWeight ? _profileProvider.massUnit : '',
          subtext: hasWeight ? 'Active profile' : 'Tap to log weight',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BodyCompositionScreen()),
            );
          },
        );

        final stepsToday = const StepTrackingService().today;
        final stepGoal = const StepTrackingService().getStepGoal();
        final stepProgress = (stepsToday.steps == null || stepGoal <= 0)
            ? 0.0
            : (stepsToday.steps! / stepGoal).clamp(0.0, 1.0);
        final stepSubtext = stepsToday.hasReading
            ? '${(stepProgress * 100).toInt()}% of goal'
            : StepStatusText.shortHint(
                StepCounterService.instance.status,
                supported: StepCounterService.isSupportedPlatform,
              );

        final stepsCard = MetricCard(
          iconAsset: 'assets/icons/steps.svg',
          iconBgColor: AppColors.primaryContainer,
          iconColor: Colors.white,
          label: 'Steps',
          value: stepsToday.display,
          unit: '/ ${(stepGoal / 1000).toStringAsFixed(0)}K',
          progress: stepProgress,
          subtext: stepSubtext,
          subtextColor: AppColors.primary,
          onTap: _showStepsAnalyticsModal,
        );

        // Water is saved by the hydration service; the card opens the full
        // Hydration screen.
        final hydration = HydrationService.instance;
        final waterCard = GestureDetector(
          key: const Key('water_card'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const HydrationScreen()),
          ),
          child: WaterIntakeCard(
            currentLiters: hydration.today.consumedMl / 1000,
            goalLiters: (hydration.today.goalMl ?? 2000) / 1000,
            onAddWater: () {
              final now = DateTime.now();
              if (now.difference(_lastWaterTap) <
                  const Duration(milliseconds: 400)) {
                return;
              }
              _lastWaterTap = now;
              hydration.log(hydrationGlassMl);
            },
          ),
        );

        if (isWide) {
          return Row(
            children: [
              Expanded(child: weightCard),
              const SizedBox(width: 12),
              Expanded(child: stepsCard),
              const SizedBox(width: 12),
              Expanded(child: waterCard),
            ],
          );
        }

        // Mobile: 2-column bento grid for clean layout without clipping
        return Column(
          children: [
            Row(
              children: [
                Expanded(child: weightCard),
                const SizedBox(width: 12),
                Expanded(child: stepsCard),
              ],
            ),
            const SizedBox(height: 12),
            waterCard,
          ],
        );
      },
    );
  }

  int _selectedDayIndex = DateTime.now().weekday - 1;

  Widget _buildPerformanceTrendChart(BuildContext context) {
    final now = DateTime.now();
    final todayIndex = now.weekday - 1;
    final days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final fullDays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final monday = now.subtract(Duration(days: now.weekday - 1));
    final history = FitnessProvider.instance.workoutHistory;

    final fullDates = <String>[];
    final dayVolumesKg = <double>[];
    final dayWorkoutsCount = <int>[];
    final dayIntensities = <int>[];

    for (int i = 0; i < 7; i++) {
      final d = monday.add(Duration(days: i));
      fullDates.add('${months[d.month - 1]} ${d.day}');

      final matching = history.where((w) {
        return w.dateCompleted.year == d.year &&
            w.dateCompleted.month == d.month &&
            w.dateCompleted.day == d.day;
      }).toList();

      final vol = matching.fold<double>(0.0, (sum, w) => sum + w.totalVolume);
      dayVolumesKg.add(vol);
      dayWorkoutsCount.add(matching.length);
    }

    final maxVolume = dayVolumesKg.fold<double>(
      0.0,
      (maxVal, v) => v > maxVal ? v : maxVal,
    );
    final heights = dayVolumesKg.map((v) {
      if (maxVolume <= 0) return 0.05;
      return (v / maxVolume).clamp(0.08, 1.0);
    }).toList();

    for (int i = 0; i < 7; i++) {
      final intensity = maxVolume > 0
          ? ((dayVolumesKg[i] / maxVolume) * 100).toInt()
          : 0;
      dayIntensities.add(intensity);
    }

    final volumes = dayVolumesKg.map((v) => '${v.toInt()} kg').toList();
    final workouts = dayWorkoutsCount;

    final selectedIndex = _selectedDayIndex.clamp(0, 6);
    final selectedDayName = fullDays[selectedIndex];
    final selectedDateStr = fullDates[selectedIndex];
    final selectedIntensity = dayIntensities[selectedIndex];
    final selectedVolume = volumes[selectedIndex];
    final selectedWorkouts = workouts[selectedIndex];

    final weekChange =
        FitnessProvider.instance.athleteAnalytics.weeklyVolumeDeltaPercent;
    final changeText = weekChange >= 0
        ? '↑ ${weekChange.toStringAsFixed(0)}% vs last week'
        : '↓ ${weekChange.abs().toStringAsFixed(0)}% vs last week';

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Weekly Relative Intensity',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.bodySm.copyWith(
                    color: context.appTextSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppColors.primaryContainer.withValues(alpha: 0.4),
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      changeText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.labelCaps.copyWith(
                        color: AppColors.primaryContainer,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Bar Chart with Dynamic Selection, Glows, and Animations
          SizedBox(
            height: 148,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Y-Axis Labels
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: ['100', '75', '50', '25', '0']
                      .map(
                        (val) => Text(
                          val,
                          style: AppTheme.labelCaps.copyWith(
                            fontSize: 9,
                            color: context.appTextSecondary.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(width: 8),

                // Grid & Bars Stack
                Expanded(
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      // Horizontal Background Grid Lines
                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(5, (index) {
                          return Divider(
                            height: 1,
                            thickness: 0.8,
                            color: context.appOutlineVariant.withValues(
                              alpha: 0.3,
                            ),
                          );
                        }),
                      ),

                      // Bars Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(7, (i) {
                          final isSelected = i == selectedIndex;
                          final isToday = i == todayIndex;

                          return Expanded(
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(() {
                                  _selectedDayIndex = i;
                                });
                              },
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  // White Glow Indicator Dot on Selected Bar
                                  AnimatedOpacity(
                                    duration: const Duration(milliseconds: 250),
                                    opacity: isSelected ? 1.0 : 0.0,
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primaryContainer,
                                            blurRadius: 8,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),

                                  // Dynamic Height Animated Bar
                                  TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0.0, end: heights[i]),
                                    duration: Duration(
                                      milliseconds: 600 + (i * 80),
                                    ),
                                    curve: Curves.easeOutCubic,
                                    builder: (context, animValue, child) {
                                      return AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 250,
                                        ),
                                        width: isSelected ? 24 : 20,
                                        height: 90 * animValue,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: isSelected
                                                ? [
                                                    AppColors.primaryContainer,
                                                    AppColors.primary,
                                                  ]
                                                : isToday
                                                ? [
                                                    context.appPrimary
                                                        .withValues(alpha: 0.9),
                                                    context.appPrimary
                                                        .withValues(alpha: 0.5),
                                                  ]
                                                : [
                                                    context.appPrimary
                                                        .withValues(alpha: 0.5),
                                                    context.appSurfaceElevated,
                                                  ],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          boxShadow: isSelected
                                              ? [
                                                  BoxShadow(
                                                    color: AppColors
                                                        .primaryContainer
                                                        .withValues(alpha: 0.6),
                                                    blurRadius: 12,
                                                    spreadRadius: 2,
                                                  ),
                                                ]
                                              : null,
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 6),

                                  // Day Label Pill
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: isSelected
                                        ? BoxDecoration(
                                            color: AppColors.primaryContainer,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: AppColors
                                                    .primaryContainer
                                                    .withValues(alpha: 0.4),
                                                blurRadius: 6,
                                              ),
                                            ],
                                          )
                                        : isToday
                                        ? BoxDecoration(
                                            color: AppColors.primaryContainer
                                                .withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          )
                                        : null,
                                    child: Text(
                                      days[i],
                                      style: AppTheme.labelCaps.copyWith(
                                        fontSize: 10,
                                        fontWeight: (isSelected || isToday)
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? Colors.white
                                            : isToday
                                            ? AppColors.primaryContainer
                                            : context.appTextSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // Selected Day Insights Panel
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.appSurfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: context.isDarkMode
                    ? AppColors.primaryContainer.withValues(alpha: 0.2)
                    : context.appOutlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$selectedDayName ($selectedDateStr)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.labelCaps.copyWith(
                          color: AppColors.primaryContainer,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '$selectedIntensity',
                            style: AppTheme.headlineLg.copyWith(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: context.appTextPrimary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Relative Intensity',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.bodySm.copyWith(
                                fontSize: 11,
                                color: context.appTextSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Volume: $selectedVolume',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.bodySm.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: context.appTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Workouts: $selectedWorkouts',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.bodySm.copyWith(
                            fontSize: 11,
                            color: context.appTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAICoachQuickBar(BuildContext context) {
    final chips = const [
      {
        'label': "Create today's workout",
        'icon': Icons.fitness_center_rounded,
        'prompt':
            "Create today's workout protocol based on my current recovery and goals.",
      },
      {
        'label': "Analyze my diet",
        'icon': Icons.restaurant_rounded,
        'prompt':
            "Analyze my diet, calories, and macronutrient intake for today.",
      },
      {
        'label': "Am I recovering?",
        'icon': Icons.self_improvement_rounded,
        'prompt':
            "Am I recovering well? Check my sleep, HRV, training load, and readiness score.",
      },
      {
        'label': "Improve my form",
        'icon': Icons.accessibility_new_rounded,
        'prompt':
            "How can I improve my lifting form and movement quality on compound exercises?",
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.psychology_rounded,
              color: AppColors.primaryContainer,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              'ASK AI COACH',
              style: AppTheme.labelCaps.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
                color: AppColors.primaryContainer,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: chips.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, idx) {
              final chip = chips[idx];
              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AICoachScreen(
                        initialPrompt: chip['prompt'] as String,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: context.appSurfaceElevated,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: context.appOutlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        chip['icon'] as IconData,
                        size: 14,
                        color: AppColors.primaryContainer,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        chip['label'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: context.appTextPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
