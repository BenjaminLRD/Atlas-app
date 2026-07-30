import 'dart:async';
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../data/app_dependencies.dart';
import '../data/workout_service.dart';
import '../models/active_workout_session.dart';
import '../models/workout_history.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/app_header.dart';
import '../widgets/common/app_button.dart';
import '../widgets/common/progress_ring.dart';

class WorkoutSessionScreen extends StatefulWidget {
  final String workoutName;
  final String? workoutId;
  final List<Map<String, dynamic>>? initialExercises;

  const WorkoutSessionScreen({
    super.key,
    this.workoutName = 'Leg Day - Hypertrophy',
    this.workoutId = 'leg_day_hypertrophy_01',
    this.initialExercises,
  });

  @override
  State<WorkoutSessionScreen> createState() => _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends State<WorkoutSessionScreen> {
  late final WorkoutService _workoutService;

  int _elapsedSeconds = 23; // Initialized with active duration
  Timer? _timer;

  int _restSecondsRemaining = 51;
  int _targetRestSeconds = 90;
  Timer? _restTimer;
  bool _isResting = true;

  int _currentExerciseIndex = 0;
  int _currentSetIndex = 2; // Active on Set 3

  late List<Map<String, dynamic>> _exercises;

  @override
  void initState() {
    super.initState();
    _workoutService = AppDependencies.instance.workoutService;
    _loadOrCreateSession();
    _startTimer();
    if (_isResting) {
      _startRestTimer(_restSecondsRemaining);
    }
  }

  void _loadOrCreateSession() {
    final saved = _workoutService.getActiveSession();
    final bool matchesIdentity =
        saved != null &&
        ((widget.workoutId != null && saved.workoutId == widget.workoutId) ||
            (saved.workoutName == widget.workoutName));

    if (saved != null && matchesIdentity) {
      _elapsedSeconds = saved.seconds;
      _currentExerciseIndex = saved.currentIndex;
      _exercises = saved.completedSets.isNotEmpty
          ? [
              {
                'name': 'Barbell Back Squat',
                'primaryTarget': 'Quadriceps, Glutes',
                'sets': [
                  {'reps': 10, 'weight': 80.0, 'completed': true},
                  {'reps': 10, 'weight': 80.0, 'completed': true},
                  {'reps': 10, 'weight': 80.0, 'completed': false},
                  {'reps': 10, 'weight': 80.0, 'completed': false},
                ],
              },
            ]
          : _defaultExercises();
    } else {
      _exercises = widget.initialExercises ?? _defaultExercises();
    }
  }

  List<Map<String, dynamic>> _defaultExercises() {
    return [
      {
        'name': 'Barbell Back Squat',
        'primaryTarget': 'Quadriceps, Glutes',
        'sets': [
          {'reps': 10, 'weight': 80.0, 'completed': true},
          {'reps': 10, 'weight': 80.0, 'completed': true},
          {'reps': 10, 'weight': 80.0, 'completed': false},
          {'reps': 10, 'weight': 80.0, 'completed': false},
        ],
      },
      {
        'name': 'Romanian Deadlift',
        'primaryTarget': 'Hamstrings, Glutes',
        'sets': [
          {'reps': 12, 'weight': 70.0, 'completed': false},
          {'reps': 12, 'weight': 70.0, 'completed': false},
          {'reps': 10, 'weight': 75.0, 'completed': false},
        ],
      },
      {
        'name': 'Leg Press',
        'primaryTarget': 'Quadriceps',
        'sets': [
          {'reps': 12, 'weight': 140.0, 'completed': false},
          {'reps': 12, 'weight': 140.0, 'completed': false},
          {'reps': 12, 'weight': 150.0, 'completed': false},
        ],
      },
    ];
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _elapsedSeconds++;
        });
        _saveActiveSessionState();
      }
    });
  }

  void _saveActiveSessionState() {
    final completedSets = _exercises
        .map(
          (ex) =>
              (ex['sets'] as List).map((s) => s['completed'] as bool).toList(),
        )
        .toList();

    _workoutService.saveActiveSession(
      ActiveWorkoutSession(
        workoutName: widget.workoutName,
        workoutId: widget.workoutId ?? 'leg_day_hypertrophy_01',
        currentIndex: _currentExerciseIndex,
        seconds: _elapsedSeconds,
        isPaused: false,
        completedSets: completedSets,
      ),
    );
  }

  void _startRestTimer(int durationSeconds) {
    _restTimer?.cancel();
    setState(() {
      _isResting = true;
      _restSecondsRemaining = durationSeconds;
    });

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_restSecondsRemaining > 1) {
        setState(() {
          _restSecondsRemaining--;
        });
      } else {
        _restTimer?.cancel();
        setState(() {
          _isResting = false;
          _restSecondsRemaining = 0;
        });
      }
    });
  }

  void _adjustRestTime(int deltaSeconds) {
    setState(() {
      _targetRestSeconds = (_targetRestSeconds + deltaSeconds).clamp(30, 300);
      _restSecondsRemaining = (_restSecondsRemaining + deltaSeconds).clamp(
        0,
        300,
      );
    });
  }

  void _skipRest() {
    _restTimer?.cancel();
    setState(() {
      _isResting = false;
      _restSecondsRemaining = 0;
    });
  }

  void _completeSet() {
    final currentEx = _exercises[_currentExerciseIndex];
    final sets = currentEx['sets'] as List;

    setState(() {
      sets[_currentSetIndex]['completed'] = true;

      if (_currentSetIndex < sets.length - 1) {
        _currentSetIndex++;
        _startRestTimer(_targetRestSeconds);
      } else if (_currentExerciseIndex < _exercises.length - 1) {
        _currentExerciseIndex++;
        _currentSetIndex = 0;
        _startRestTimer(_targetRestSeconds);
      } else {
        _finishWorkout();
      }
    });

    _saveActiveSessionState();
  }

  Future<void> _finishWorkout() async {
    _timer?.cancel();
    _restTimer?.cancel();
    await _workoutService.clearActiveSession();

    final completedHistory = WorkoutHistory(
      workoutName: widget.workoutName,
      dateCompleted: DateTime.now(),
      durationSeconds: _elapsedSeconds,
      exercisesCompleted: _exercises.length,
      completionPercentage: 100.0,
    );

    await _workoutService.addHistory(completedHistory);

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.emoji_events_rounded,
                color: AppColors.primary,
                size: 28,
              ),
              const SizedBox(width: 10),
              Text(
                'Workout Complete!',
                style: AppTheme.headlineMd.copyWith(
                  fontSize: 20,
                  color: context.appTextPrimary,
                ),
              ),
            ],
          ),
          content: Text(
            'Great job! You completed ${widget.workoutName} in ${(_elapsedSeconds / 60).ceil()} mins with a total volume of ${_calculateTotalVolume().toStringAsFixed(0)} kg.',
            style: AppTheme.bodySm.copyWith(color: context.appTextSecondary),
          ),
          actions: [
            AppButton.primary(
              label: 'Done',
              onPressed: () {
                Navigator.pop(context);
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              },
              isFullWidth: false,
              isPill: true,
            ),
          ],
        ),
      );
    }
  }

  double _calculateTotalVolume() {
    double vol = 0;
    for (var ex in _exercises) {
      for (var set in (ex['sets'] as List)) {
        if (set['completed'] == true) {
          final reps = (set['reps'] as num).toDouble();
          final weight = (set['weight'] as num).toDouble();
          vol += (reps * weight);
        }
      }
    }
    return vol;
  }

  String _formatTime(int totalSecs) {
    final mins = totalSecs ~/ 60;
    final secs = totalSecs % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _showExerciseDetailsModal(Map<String, dynamic> exercise) {
    final name = exercise['name'] ?? 'Exercise';
    final target = exercise['target'] ?? 'Target Muscle Group';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.appSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                top: 12,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.appOutlineVariant.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        name,
                        style: AppTheme.headlineLg.copyWith(
                          fontSize: 18,
                          color: context.appTextPrimary,
                        ),
                      ),
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: context.appSurfaceElevated,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, size: 18),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Target: $target',
                      style: AppTheme.labelCaps.copyWith(
                        fontSize: 11,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Execution Guidance & Form Tips:',
                    style: AppTheme.headlineMd.copyWith(
                      fontSize: 14,
                      color: context.appTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '1. Maintain a neutral spine throughout the concentric phase.\n2. Control the eccentric downward movement for 2-3 seconds.\n3. Focus on mind-muscle connection and full range of motion.',
                    style: AppTheme.bodySm.copyWith(
                      fontSize: 12,
                      height: 1.5,
                      color: context.appTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _restTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentEx = _exercises[_currentExerciseIndex];
    final sets = currentEx['sets'] as List;
    final currentSet = sets[_currentSetIndex];
    final completedCount = sets.where((s) => s['completed'] == true).length;

    return Scaffold(
      backgroundColor: context.appBackground,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Header Bar
            _buildHeaderBar(context),

            // Main Scrollable Active Workout Experience Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 2. Current Exercise Hero Card
                    _buildCurrentExerciseHero(context, currentEx),
                    const SizedBox(height: 18),

                    // 3. Set Progress Section Header & Set Cards Row
                    _buildSetProgressSection(context, sets, completedCount),
                    const SizedBox(height: 18),

                    // 4. Dedicated Rest Timer Card
                    _buildRestTimerCard(context),
                    const SizedBox(height: 18),

                    // 5. Current Set Summary Cards (Weight & Reps Load)
                    _buildSetSummaryRow(context, currentSet),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // 6. Fixed Primary Complete Set Action Bar
            _buildFixedBottomActionBar(context, sets),
          ],
        ),
      ),
    );
  }

  /// 1. Top Header Bar matching Apple aesthetics
  Widget _buildHeaderBar(BuildContext context) {
    return AppHeader.back(
      title: widget.workoutName,
      subtitle: _formatTime(_elapsedSeconds),
      onBackTap: () {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      },
    );
  }

  /// 2. Current Exercise Hero Glass Card
  Widget _buildCurrentExerciseHero(
    BuildContext context,
    Map<String, dynamic> exercise,
  ) {
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: () => _showExerciseDetailsModal(exercise),
      child: Stack(
        children: [
          Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: context.appSurfaceElevated,
              image: const DecorationImage(
                image: NetworkImage(
                  'https://images.unsplash.com/photo-1574680096145-d05b474e2155?q=80&w=800&auto=format&fit=crop',
                ),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Container(
            height: 180,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.85),
                  Colors.black.withValues(alpha: 0.25),
                  Colors.transparent,
                ],
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
              ),
            ),
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CURRENT EXERCISE',
                  style: AppTheme.labelCaps.copyWith(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  exercise['name'],
                  style: AppTheme.headlineLg.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.fitness_center,
                        color: AppColors.primary,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Primary: ${exercise['primaryTarget'] ?? 'Quadriceps, Glutes'}',
                        style: AppTheme.bodySm.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 3. Set Progress Section
  Widget _buildSetProgressSection(
    BuildContext context,
    List sets,
    int completedCount,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'SET PROGRESS',
              style: AppTheme.labelCaps.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: context.appTextSecondary,
              ),
            ),
            Text(
              '$completedCount OF ${sets.length} COMPLETED',
              style: AppTheme.labelCaps.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Horizontal Row of Set Cards
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(sets.length, (index) {
              final set = sets[index];
              final bool isDone = set['completed'] == true;
              final bool isActive = index == _currentSetIndex;

              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _buildSetCard(
                  context: context,
                  setNumber: index + 1,
                  reps: set['reps'],
                  weight: set['weight'],
                  isDone: isDone,
                  isActive: isActive,
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildSetCard({
    required BuildContext context,
    required int setNumber,
    required int reps,
    required double weight,
    required bool isDone,
    required bool isActive,
  }) {
    Color borderColor;
    if (isDone || isActive) {
      borderColor = AppColors.primary;
    } else {
      borderColor = context.appOutlineVariant;
    }

    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: isActive ? 2.0 : 1.0),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone
                      ? AppColors.primary
                      : context.appSurfaceElevated,
                  border: isDone
                      ? null
                      : Border.all(
                          color: isActive
                              ? AppColors.primary
                              : context.appTextSecondary,
                        ),
                ),
                child: Center(
                  child: isDone
                      ? const Icon(
                          Icons.check,
                          size: 14,
                          color: AppColors.onPrimary,
                        )
                      : Text(
                          '$setNumber',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isActive
                                ? AppColors.primary
                                : context.appTextSecondary,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Set $setNumber',
                style: AppTheme.headlineMd.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDone || isActive
                      ? AppColors.primary
                      : context.appTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$reps reps • ${weight.toStringAsFixed(0)} kg',
            style: AppTheme.bodySm.copyWith(
              fontSize: 11,
              color: context.appTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// 4. Rest Timer Section Card
  Widget _buildRestTimerCard(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.access_time_rounded,
              color: AppColors.primary,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              'Rest before your next set',
              style: AppTheme.bodySm.copyWith(
                fontSize: 12,
                color: context.appTextSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Left Side: Circular Rest Ring with large display metric
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    ProgressRing.single(
                      size: 130,
                      progress: _isResting
                          ? (_restSecondsRemaining / _targetRestSeconds).clamp(
                              0.0,
                              1.0,
                            )
                          : 1.0,
                      color: AppColors.primary,
                      strokeWidth: 8,
                      centerChild: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'RESTING',
                            style: AppTheme.labelCaps.copyWith(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isResting
                                ? _formatTime(_restSecondsRemaining)
                                : '00:00',
                            style: AppTheme.displayMetrics.copyWith(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: context.appTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Target: ${_formatTime(_targetRestSeconds)}',
                            style: AppTheme.labelCaps.copyWith(
                              fontSize: 9,
                              color: context.appTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Vertical Divider line
              Container(
                width: 1,
                height: 110,
                color: context.appOutlineVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 16),

              // Right Side: Rest Time adjustment & Skip Rest controls
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'REST TIME',
                      style: AppTheme.labelCaps.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: context.appTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Adjust buttons row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: () => _adjustRestTime(-15),
                          icon: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: context.appSurfaceElevated,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.remove,
                              color: context.appTextPrimary,
                              size: 16,
                            ),
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatTime(_targetRestSeconds),
                          style: AppTheme.headlineMd.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: context.appTextPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => _adjustRestTime(15),
                          icon: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: context.appSurfaceElevated,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.add,
                              color: context.appTextPrimary,
                              size: 16,
                            ),
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Skip Rest Pill Button
                    OutlinedButton(
                      onPressed: _skipRest,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: AppColors.primary,
                          width: 1.2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Skip Rest',
                            style: AppTheme.bodySm.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.fast_forward_rounded,
                            color: AppColors.primary,
                            size: 14,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 5. Current Set Summary Cards (Weight & Reps)
  Widget _buildSetSummaryRow(
    BuildContext context,
    Map<String, dynamic> currentSet,
  ) {
    return Row(
      children: [
        // Left Card: Weight
        Expanded(
          child: AppCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.fitness_center_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WEIGHT',
                      style: AppTheme.labelCaps.copyWith(
                        fontSize: 10,
                        color: context.appTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${currentSet['weight'].toStringAsFixed(0)}',
                          style: AppTheme.displayMetrics.copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: context.appTextPrimary,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'kg',
                          style: AppTheme.bodySm.copyWith(
                            fontSize: 12,
                            color: context.appTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Right Card: Reps
        Expanded(
          child: AppCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.refresh_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'REPS',
                      style: AppTheme.labelCaps.copyWith(
                        fontSize: 10,
                        color: context.appTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${currentSet['reps']}',
                          style: AppTheme.displayMetrics.copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: context.appTextPrimary,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'reps',
                          style: AppTheme.bodySm.copyWith(
                            fontSize: 12,
                            color: context.appTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 6. Fixed Primary Complete Set Bottom Action Bar
  Widget _buildFixedBottomActionBar(BuildContext context, List sets) {
    final bool isLastSet =
        (_currentExerciseIndex == _exercises.length - 1 &&
        _currentSetIndex == sets.length - 1);
    final String buttonLabel = isLastSet
        ? '✓ Finish Workout'
        : '✓ Complete Set ${_currentSetIndex + 1}';
    final String helperText = isLastSet
        ? "You will complete the workout session."
        : "You'll move to Set ${_currentSetIndex + 2} after completing this set.";

    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: bottomInset + 16,
      ),
      decoration: BoxDecoration(
        color: context.appSurface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppButton.primary(
            label: buttonLabel,
            onPressed: _completeSet,
            isPill: true,
          ),
          const SizedBox(height: 6),
          Text(
            helperText,
            style: AppTheme.bodySm.copyWith(
              fontSize: 11,
              color: context.appTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
