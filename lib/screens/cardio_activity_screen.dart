import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../data/local_storage.dart';
import '../models/activity_record.dart';
import '../models/exercise.dart';
import '../services/activity_score_service.dart';
import '../providers/fitness_provider.dart';
import '../services/step_tracking_service.dart';
import '../services/steps/step_counter_service.dart';
import '../widgets/activity/step_status_panel.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/app_header.dart';
import 'ai_coach_screen.dart';
import 'cardio_activity_detail_screen.dart';
import 'cardio_history_screen.dart';
import '../services/cardio/cardio_journal.dart';
import '../services/cardio/cardio_tracker.dart';
import '../data/profile_provider.dart';
import 'cardio_session_screen.dart';
import 'gps_cardio_screen.dart';
import '../models/cardio_activity_data.dart';
import '../models/cardio_route.dart';
import '../models/activity_post.dart';
import '../services/community/sample_community.dart';
import '../widgets/cardio/cardio_stats.dart';

/// Cardio & Daily Movement Intelligence Hub Screen.
class CardioActivityScreen extends StatefulWidget {
  const CardioActivityScreen({super.key});

  @override
  State<CardioActivityScreen> createState() => _CardioActivityScreenState();
}

class _CardioActivityScreenState extends State<CardioActivityScreen> {
  final StepTrackingService _stepService = const StepTrackingService();
  final ActivityScoreService _scoreService = const ActivityScoreService();

  late ActivityScoreResult _todayScore;
  late int _stepGoal;
  List<CardioSession> _recentSessions = [];
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Running',
    'Cycling',
    'Rowing',
    'Sports',
    'Conditioning',
  ];

  @override
  void initState() {
    super.initState();
    _refreshData();
    // The score and the step card follow the live step count.
    StepCounterService.instance.addListener(_onStepsChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkRecovery());
  }

  /// A run or ride that was still being recorded when the app was ended
  /// (low memory, a crash). Offers to save what was recorded.
  Future<void> _checkRecovery() async {
    if (!mounted || LocalStorage.isShowcaseModeEnabled()) return;
    if (CardioTracker.isAnyRecording) return;
    final journal = CardioJournal();
    final snap = journal.load();
    if (snap == null) return;
    final draft = snap.toDraft(
      weightKg: parseProfileWeightKg(ProfileProvider().weight),
    );
    if (draft.distanceM < 10 || draft.activeSeconds < 10) {
      await journal.clear();
      return;
    }
    final save = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('Unfinished ${snap.kind.noun.toLowerCase()} found'),
        content: Text(
          'Atlas was closed while recording a ${snap.kind.noun.toLowerCase()}. '
          'Up to the last saved point it had '
          '${draft.distanceKm.toStringAsFixed(2)} km in '
          '${CardioFormat.duration(draft.activeSeconds)}. Anything after that '
          'was not recorded. Save it?',
          key: const Key('recover_text'),
        ),
        actions: [
          TextButton(
            key: const Key('recover_discard'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Discard'),
          ),
          TextButton(
            key: const Key('recover_save'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (save == true) {
      final (session, activity) = CardioSessionBuilder.build(draft);
      await FitnessProvider.instance.recordCardioCompletion(session, activity);
      if (mounted) _refreshData();
    }
    await journal.clear();
  }

  @override
  void dispose() {
    StepCounterService.instance.removeListener(_onStepsChanged);
    super.dispose();
  }

  void _onStepsChanged() {
    if (mounted) _refreshData();
  }

  void _refreshData() {
    setState(() {
      _todayScore = _scoreService.getTodayScore();
      _stepGoal = _stepService.getStepGoal();
      // Showcase Mode never reads the athlete's own sessions.
      _recentSessions = LocalStorage.isShowcaseModeEnabled()
          ? []
          : LocalStorage.getCardioSessions().take(6).toList();
    });
  }

  List<Exercise> get _filteredCardioExercises {
    final allCardio = Exercise.defaultRegistry()
        .where((e) => e.type == ExerciseType.cardio)
        .toList();

    if (_selectedCategory == 'All') return allCardio;
    return allCardio
        .where(
          (e) =>
              e.cardioCategory?.toLowerCase() ==
              _selectedCategory.toLowerCase(),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppHeader.back(
          title: 'CARDIO & ACTIVITY',
          subtitle: 'Track movement, endurance & step goals',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Daily Activity Score Hero Card
              _buildActivityScoreHero(context, _todayScore),
              const SizedBox(height: 16),

              // 2. Today's Step & Movement Metrics Card
              _buildTodayMovementCard(context, _stepGoal),
              const SizedBox(height: 20),

              // Outdoor tracking with GPS and a route map.
              _buildOutdoorTracking(context),
              const SizedBox(height: 20),

              // 3. Start Cardio Workout Header & Category Filter
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'START CARDIO WORKOUT',
                      style: AppTheme.labelCaps.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: context.appTextSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${_filteredCardioExercises.length} Activities',
                    style: AppTheme.bodySm.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Category Filter Pills
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _categories.map((cat) {
                    final isSelected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(cat),
                        selected: isSelected,
                        onSelected: (val) {
                          setState(() {
                            _selectedCategory = cat;
                          });
                        },
                        selectedColor: AppColors.primary,
                        backgroundColor: context.appSurfaceElevated,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? Colors.black
                              : context.appTextPrimary,
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          fontSize: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 14),

              // Cardio Exercise Cards
              for (final ex in _filteredCardioExercises) ...[
                _buildCardioExerciseCard(context, ex),
                const SizedBox(height: 12),
              ],

              const SizedBox(height: 16),

              // 4. Recent Cardio Sessions History
              if (_recentSessions.isNotEmpty) ...[
                Text(
                  'RECENT CARDIO SESSIONS',
                  style: AppTheme.labelCaps.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: context.appTextSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                for (final session in _recentSessions) ...[
                  _buildRecentSessionCard(context, session),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 16),
              ],

              if (LocalStorage.isShowcaseModeEnabled()) ...[
                _buildSampleActivities(context),
                const SizedBox(height: 16),
              ],

              // 5. Ask AI Coach Action Banner
              AppCard(
                padding: const EdgeInsets.all(14),
                borderColor: AppColors.primary.withValues(alpha: 0.3),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withValues(
                          alpha: isDark ? 0.3 : 0.15,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.psychology_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Need cardio & step advice?',
                            style: AppTheme.headlineMd.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: context.appTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Chat with AI Coach to balance cardio with hypertrophy and optimize fat loss.',
                            style: AppTheme.bodySm.copyWith(
                              fontSize: 11,
                              color: context.appTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AICoachScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityScoreHero(
    BuildContext context,
    ActivityScoreResult score,
  ) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer.withValues(
                            alpha: 0.2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'DAILY ACTIVITY SCORE',
                            style: AppTheme.labelCaps.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(score.emoji, style: const TextStyle(fontSize: 16)),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF10B981), width: 1),
                ),
                child: Text(
                  score.rating.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF10B981),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${score.totalScore}',
                    style: AppTheme.displayMetrics.copyWith(
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '/ 100 pts',
                style: AppTheme.headlineMd.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: context.appTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            score.recommendation,
            style: AppTheme.bodySm.copyWith(
              fontSize: 12,
              color: context.appTextSecondary,
            ),
          ),
          const SizedBox(height: 14),
          // Breakdown Pills (Steps 40%, Workout 40%, Cardio 20%)
          Row(
            children: [
              Expanded(
                child: _buildScoreBreakdownItem(
                  'Steps (40%)',
                  score.stepsKnown
                      ? '${score.stepsScore.toStringAsFixed(0)}/40'
                      : '--/40',
                  const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildScoreBreakdownItem(
                  'Workout (40%)',
                  '${score.workoutScore.toStringAsFixed(0)}/40',
                  const Color(0xFF3B82F6),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildScoreBreakdownItem(
                  'Cardio (20%)',
                  '${score.cardioScore.toStringAsFixed(0)}/20',
                  const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScoreBreakdownItem(String label, String val, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              val,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTheme.labelCaps.copyWith(
              fontSize: 8,
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayMovementCard(BuildContext context, int goal) {
    final steps = StepCounterService.instance;
    return ListenableBuilder(
      listenable: steps,
      builder: (context, _) {
        final today = steps.today;
        final count = today.steps;
        final progress = count == null || goal <= 0
            ? 0.0
            : (count / goal).clamp(0.0, 1.0);
        final weightKg =
            double.tryParse(
              (FitnessProvider.instance.profile.weight).replaceAll(
                RegExp(r'[^0-9.]'),
                '',
              ),
            ) ??
            70.0;
        final calories = StepTrackingService.caloriesFor(
          count,
          userWeightKg: weightKg,
        );
        final cardioMinutes = ActivityScoreService.cardioMinutesOn(
          DateTime.now(),
        );

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
                      "TODAY'S MOVEMENT",
                      style: AppTheme.labelCaps.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: context.appTextSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    count == null
                        ? 'Goal ${_thousandsOf(goal)}'
                        : '${(progress * 100).toInt()}% of ${_thousandsOf(goal)} Goal',
                    style: AppTheme.bodySm.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: context.appSurfaceElevated,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.primary,
                  ),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _buildMovementStat(
                      'STEPS',
                      today.display,
                      Icons.directions_walk_rounded,
                      AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildMovementStat(
                      'CALORIES (EST.)',
                      calories == null ? '--' : '~${calories.round()} kcal',
                      Icons.local_fire_department_rounded,
                      const Color(0xFFF59E0B),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildMovementStat(
                      'CARDIO TODAY',
                      '$cardioMinutes min',
                      Icons.timer_rounded,
                      const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const StepStatusPanel(),
            ],
          ),
        );
      },
    );
  }

  static String _thousandsOf(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return '$b';
  }

  Widget _buildMovementStat(
    String title,
    String val,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: context.appSurfaceElevated,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              val,
              style: AppTheme.headlineMd.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: context.appTextPrimary,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: AppTheme.labelCaps.copyWith(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              color: context.appTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardioExerciseCard(BuildContext context, Exercise ex) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.directions_run_rounded,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ex.name,
                  style: AppTheme.headlineMd.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: context.appTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'MET ${ex.metValue?.toStringAsFixed(1) ?? '8.0'}',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFF59E0B),
                        ),
                      ),
                    ),
                    Text(
                      '~${ex.estimatedCaloriesPerMinute?.toStringAsFixed(0) ?? '10'} kcal/min',
                      style: AppTheme.bodySm.copyWith(
                        fontSize: 11,
                        color: context.appTextSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              // Outdoor running and cycling are recorded with GPS; the other
              // cardio exercises keep the timer.
              final gps = ex.id == 'outdoor_run'
                  ? CardioKind.running
                  : (ex.id == 'outdoor_cycling' ? CardioKind.cycling : null);
              final finished = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => gps != null
                      ? GpsCardioScreen(initialKind: gps)
                      : CardioSessionScreen(exercise: ex),
                ),
              );
              if (finished == true) {
                _refreshData();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }

  Widget _buildOutdoorTracking(BuildContext context) {
    Widget tile(CardioKind kind) {
      return Expanded(
        child: GestureDetector(
          key: Key('outdoor_${kind.key}'),
          onTap: () async {
            final saved = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => GpsCardioScreen(initialKind: kind),
              ),
            );
            if (saved == true && mounted) _refreshData();
          },
          child: AppCard(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            borderColor: AppColors.primary.withValues(alpha: 0.35),
            child: Column(
              children: [
                Icon(cardioIcon(kind), size: 30, color: AppColors.primary),
                const SizedBox(height: 8),
                Text(
                  'Outdoor ${kind.noun}',
                  style: AppTheme.headlineMd.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: context.appTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'GPS route & stats',
                  style: AppTheme.bodySm.copyWith(
                    fontSize: 11,
                    color: context.appTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TRACK AN OUTDOOR ACTIVITY',
          style: AppTheme.labelCaps.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: context.appTextSecondary,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            tile(CardioKind.running),
            const SizedBox(width: 10),
            tile(CardioKind.cycling),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: const Key('open_cardio_history'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const CardioHistoryScreen(),
              ),
            ),
            icon: const Icon(Icons.history_rounded),
            label: const Text('Cardio history'),
          ),
        ),
      ],
    );
  }

  /// Showcase Mode: a few sample runs and rides, clearly labelled, opened with
  /// the same detail view as a real activity.
  Widget _buildSampleActivities(BuildContext context) {
    final samples = [
      for (final p in SampleCommunity.posts())
        if (p.type == ActivityPostType.cardio) p,
    ].take(3).toList();
    if (samples.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SAMPLE ACTIVITIES (DEMO)',
          key: const Key('sample_activities_header'),
          style: AppTheme.labelCaps.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: context.appTextSecondary,
          ),
        ),
        const SizedBox(height: 10),
        for (final p in samples)
          if (CardioActivityData.fromPost(p) case final data?) ...[
            GestureDetector(
              key: Key('sample_activity_${p.id}'),
              onTap: () => CardioActivityDetailScreen.open(context, data),
              child: AppCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(cardioIcon(data.kind), color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${p.userName} · ${data.title}',
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.bodySm.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: context.appTextPrimary,
                        ),
                      ),
                    ),
                    Text(
                      data.distanceKm == null
                          ? '–'
                          : '${data.distanceKm!.toStringAsFixed(1)} km',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }

  Widget _buildRecentSessionCard(BuildContext context, CardioSession session) {
    final card = _recentSessionBody(context, session);
    if (session.kind == null) return card;
    return GestureDetector(
      key: Key('recent_${session.id}'),
      onTap: () => CardioActivityDetailScreen.open(
        context,
        CardioActivityData.fromSession(session),
      ),
      child: card,
    );
  }

  Widget _recentSessionBody(BuildContext context, CardioSession session) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.exerciseName,
                  style: AppTheme.headlineMd.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: context.appTextPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${session.category} • ${session.formattedDuration}',
                  style: AppTheme.bodySm.copyWith(
                    fontSize: 11,
                    color: context.appTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                session.caloriesKnown
                    ? '${session.caloriesBurned.toStringAsFixed(0)} kcal'
                    : '– kcal',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFF59E0B),
                ),
              ),
              if (session.distanceKm > 0.05)
                Text(
                  '${session.distanceKm.toStringAsFixed(1)} km',
                  style: AppTheme.bodySm.copyWith(
                    fontSize: 11,
                    color: const Color(0xFF10B981),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
