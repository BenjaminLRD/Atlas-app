import 'dart:async';
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../data/app_dependencies.dart';
import '../data/workout_service.dart';
import '../models/active_workout_session.dart';
import '../models/workout_history.dart';
import '../providers/fitness_provider.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/app_button.dart';
import '../widgets/common/app_image.dart';
import '../widgets/common/progress_ring.dart';
import '../widgets/common/workout_completion_celebration.dart';

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

  int _elapsedSeconds = 0;
  late final ValueNotifier<int> _elapsedNotifier;
  Timer? _timer;
  bool _isTimerRunning = false;

  bool _isSetActive = false;

  int _restSecondsRemaining = 0;
  late final ValueNotifier<int> _restNotifier;
  int _targetRestSeconds = 90;
  Timer? _restTimer;
  bool _isResting = false;
  bool _isRestPaused = false;

  int _currentExerciseIndex = 0;
  int _currentSetIndex = 0;

  late List<Map<String, dynamic>> _exercises;

  @override
  void initState() {
    super.initState();
    _workoutService = AppDependencies.instance.workoutService;
    _elapsedNotifier = ValueNotifier<int>(_elapsedSeconds);
    _restNotifier = ValueNotifier<int>(_restSecondsRemaining);
    _loadOrCreateSession();
  }

  void _loadOrCreateSession() {
    final saved = _workoutService.getActiveSession();
    final bool matchesIdentity =
        saved != null &&
        ((widget.workoutId != null && saved.workoutId == widget.workoutId) ||
            (saved.workoutName == widget.workoutName));

    final rawExercises = widget.initialExercises ?? _defaultExercises();
    _exercises = _enrichExercises(rawExercises);

    if (saved != null && matchesIdentity) {
      _elapsedSeconds = saved.seconds;
      _currentExerciseIndex = saved.currentIndex;

      if (saved.completedSets.isNotEmpty) {
        for (int i = 0; i < _exercises.length && i < saved.completedSets.length; i++) {
          final savedSets = saved.completedSets[i];
          final currentSets = _exercises[i]['sets'] as List;
          for (int j = 0; j < currentSets.length && j < savedSets.length; j++) {
            currentSets[j]['completed'] = savedSets[j];
          }
        }
      }
    }
  }

  List<Map<String, dynamic>> _enrichExercises(List<Map<String, dynamic>> rawList) {
    final defaults = _defaultExercises();
    return rawList.map((ex) {
      final name = ex['name'] as String? ?? 'Exercise';
      final match = defaults.firstWhere(
        (d) => d['name'].toString().toLowerCase() == name.toLowerCase(),
        orElse: () => {
          'id': name.toLowerCase().replaceAll(' ', '_'),
          'name': name,
          'primaryTarget': ex['primaryTarget'] ?? 'Target Muscle Group',
          'imagePath': ex['imagePath'] ?? 'assets/exercises/${name.toLowerCase().replaceAll(' ', '_')}.png',
          'imageUrl': ex['imageUrl'],
          'tips': ex['tips'] ?? [
            'Maintain a neutral spine throughout movement.',
            'Control the eccentric lowering phase for 2-3 seconds.',
            'Drive through movement with controlled breathing.',
          ],
        },
      );

      return {
        'id': ex['id'] ?? match['id'],
        'name': name,
        'primaryTarget': ex['primaryTarget'] ?? match['primaryTarget'],
        'imagePath': ex['imagePath'] ?? match['imagePath'],
        'imageUrl': ex['imageUrl'] ?? match['imageUrl'],
        'tips': ex['tips'] ?? match['tips'],
        'sets': ex['sets'] ?? match['sets'],
      };
    }).toList();
  }

  List<Map<String, dynamic>> _defaultExercises() {
    return [
      {
        'id': 'barbell_back_squat',
        'name': 'Barbell Back Squat',
        'primaryTarget': 'Quadriceps, Glutes',
        'imagePath': 'assets/exercises/squat.png',
        'imageUrl': 'https://images.unsplash.com/photo-1574680096145-d05b474e2155?q=80&w=400',
        'tips': [
          'Keep chest up and eyes facing forward.',
          'Brace core tight before descent.',
          'Drive through heels and maintain knee alignment.',
        ],
        'sets': [
          {'reps': 10, 'weight': 80.0, 'completed': false},
          {'reps': 10, 'weight': 80.0, 'completed': false},
          {'reps': 10, 'weight': 80.0, 'completed': false},
          {'reps': 10, 'weight': 80.0, 'completed': false},
        ],
      },
      {
        'id': 'romanian_deadlift',
        'name': 'Romanian Deadlift',
        'primaryTarget': 'Hamstrings, Glutes',
        'imagePath': 'assets/exercises/rdl.png',
        'imageUrl': 'https://images.unsplash.com/photo-1517838277536-f5f99be501cd?q=80&w=400',
        'tips': [
          'Push hips backward with a soft knee bend.',
          'Keep back flat and spine neutral throughout.',
          'Control eccentric lowering to feel a deep stretch.',
        ],
        'sets': [
          {'reps': 12, 'weight': 70.0, 'completed': false},
          {'reps': 12, 'weight': 70.0, 'completed': false},
          {'reps': 10, 'weight': 75.0, 'completed': false},
        ],
      },
      {
        'id': 'leg_press',
        'name': 'Leg Press',
        'primaryTarget': 'Quadriceps',
        'imagePath': 'assets/exercises/leg_press.png',
        'imageUrl': 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?q=80&w=400',
        'tips': [
          'Position feet shoulder-width on footplate.',
          'Avoid locking out knees at full extension.',
          'Lower platform until knees reach 90 degrees.',
        ],
        'sets': [
          {'reps': 12, 'weight': 140.0, 'completed': false},
          {'reps': 12, 'weight': 140.0, 'completed': false},
          {'reps': 12, 'weight': 150.0, 'completed': false},
        ],
      },
    ];
  }

  void _startWorkoutTimer() {
    if (_isTimerRunning) return;
    _isTimerRunning = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _isTimerRunning) {
        _elapsedSeconds++;
        _elapsedNotifier.value = _elapsedSeconds;
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
        isPaused: !_isTimerRunning,
        completedSets: completedSets,
      ),
    );
  }

  void _startSet() {
    setState(() {
      _isSetActive = true;
      _isResting = false;
      _restTimer?.cancel();
    });
    _startWorkoutTimer();
    _saveActiveSessionState();
  }

  void _completeSet() {
    final currentEx = _exercises[_currentExerciseIndex];
    final sets = currentEx['sets'] as List;

    setState(() {
      sets[_currentSetIndex]['completed'] = true;
      _isSetActive = false;

      if (_currentSetIndex < sets.length - 1) {
        _currentSetIndex++;
        _startRestTimer(_targetRestSeconds);
      } else if (_currentExerciseIndex < _exercises.length - 1) {
        _currentExerciseIndex++;
        _currentSetIndex = 0;
        _startRestTimer(_targetRestSeconds);
      } else {
        _showFinishWorkoutConfirmationDialog();
      }
    });

    _saveActiveSessionState();
  }

  void _startRestTimer(int durationSeconds) {
    _restTimer?.cancel();
    setState(() {
      _isResting = true;
      _isRestPaused = false;
      _restSecondsRemaining = durationSeconds;
      _restNotifier.value = durationSeconds;
    });

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_isRestPaused) return;

      if (_restSecondsRemaining > 1) {
        _restSecondsRemaining--;
        _restNotifier.value = _restSecondsRemaining;
      } else {
        _restTimer?.cancel();
        setState(() {
          _isResting = false;
          _restSecondsRemaining = 0;
          _restNotifier.value = 0;
        });
      }
    });
  }

  void _toggleRestPause() {
    setState(() {
      _isRestPaused = !_isRestPaused;
    });
  }

  void _adjustRestTime(int deltaSeconds) {
    setState(() {
      _targetRestSeconds = (_targetRestSeconds + deltaSeconds).clamp(15, 300);
      _restSecondsRemaining =
          (_restSecondsRemaining + deltaSeconds).clamp(0, 300);
      _restNotifier.value = _restSecondsRemaining;
    });
  }

  void _skipRest() {
    _restTimer?.cancel();
    setState(() {
      _isResting = false;
      _restSecondsRemaining = 0;
      _restNotifier.value = 0;
    });
  }

  void _adjustReps(Map<String, dynamic> currentSet, int delta) {
    setState(() {
      final currentReps = (currentSet['reps'] as num).toInt();
      currentSet['reps'] = (currentReps + delta).clamp(1, 100);
    });
    _saveActiveSessionState();
  }

  void _adjustWeight(Map<String, dynamic> currentSet, double delta) {
    setState(() {
      final currentWeight = (currentSet['weight'] as num).toDouble();
      currentSet['weight'] = (currentWeight + delta).clamp(0.0, 500.0);
    });
    _saveActiveSessionState();
  }

  void _addSetToCurrentExercise() {
    final currentEx = _exercises[_currentExerciseIndex];
    final sets = currentEx['sets'] as List;
    final lastSet = sets.isNotEmpty
        ? sets.last
        : {'reps': 10, 'weight': 50.0, 'completed': false};

    setState(() {
      sets.add({
        'reps': lastSet['reps'],
        'weight': lastSet['weight'],
        'completed': false,
      });
    });
    _saveActiveSessionState();
  }

  void _removeSetFromCurrentExercise() {
    final currentEx = _exercises[_currentExerciseIndex];
    final sets = currentEx['sets'] as List;
    if (sets.length <= 1) return;

    setState(() {
      sets.removeLast();
      if (_currentSetIndex >= sets.length) {
        _currentSetIndex = sets.length - 1;
      }
    });
    _saveActiveSessionState();
  }

  int get _completedExercisesCount {
    int count = 0;
    for (final ex in _exercises) {
      final sets = ex['sets'] as List;
      if (sets.any((s) => s['completed'] == true)) {
        count++;
      }
    }
    return count;
  }

  int get _totalSetsCount {
    int total = 0;
    for (final ex in _exercises) {
      total += (ex['sets'] as List).length;
    }
    return total;
  }

  int get _completedSetsCount {
    int completed = 0;
    for (final ex in _exercises) {
      final sets = ex['sets'] as List;
      completed += sets.where((s) => s['completed'] == true).length;
    }
    return completed;
  }

  double get _completionPercentage {
    final total = _totalSetsCount;
    if (total == 0) return 0.0;
    return (_completedSetsCount / total) * 100.0;
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

  String _formatDuration(int totalSecs) {
    final mins = totalSecs ~/ 60;
    final secs = totalSecs % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _showFinishWorkoutConfirmationDialog() {
    final completedEx = _completedExercisesCount;
    final totalEx = _exercises.length;
    final completedSets = _completedSetsCount;
    final totalSets = _totalSetsCount;
    final compPercent = _completionPercentage;
    final volumeStr = _calculateTotalVolume().toStringAsFixed(0);
    final durationStr = _formatDuration(_elapsedSeconds);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.appSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: AppColors.primaryContainer.withValues(
              alpha: context.isDarkMode ? 0.4 : 0.2,
            ),
          ),
        ),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.emoji_events_rounded,
                color: AppColors.primaryContainer,
                size: 32,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Finish Workout?',
              style: AppTheme.headlineLg.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: context.appTextPrimary,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Ready to wrap up your session? Here is your performance summary:',
              textAlign: TextAlign.center,
              style: AppTheme.bodySm.copyWith(
                fontSize: 12,
                color: context.appTextSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.appSurfaceElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: context.appOutlineVariant.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  _buildSummaryDialogRow(
                      context, 'Exercises Completed', '$completedEx of $totalEx'),
                  const Divider(height: 14, thickness: 0.5),
                  _buildSummaryDialogRow(
                      context, 'Sets Tracked', '$completedSets of $totalSets'),
                  const Divider(height: 14, thickness: 0.5),
                  _buildSummaryDialogRow(context, 'Active Duration', durationStr),
                  const Divider(height: 14, thickness: 0.5),
                  _buildSummaryDialogRow(context, 'Total Volume', '$volumeStr kg'),
                  const Divider(height: 14, thickness: 0.5),
                  _buildSummaryDialogRow(context, 'Target Completion',
                      '${compPercent.toStringAsFixed(0)}%'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: AppButton.secondary(
                  label: 'Resume',
                  onPressed: () => Navigator.pop(dialogContext),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton.primary(
                  label: 'Finish & Save',
                  onPressed: () async {
                    Navigator.pop(dialogContext);
                    await _confirmFinishAndSave();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryDialogRow(
      BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTheme.bodySm.copyWith(
            fontSize: 11,
            color: context.appTextSecondary,
          ),
        ),
        Text(
          value,
          style: AppTheme.headlineMd.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: context.appTextPrimary,
          ),
        ),
      ],
    );
  }

  Future<void> _confirmFinishAndSave() async {
    _timer?.cancel();
    _restTimer?.cancel();
    _isTimerRunning = false;
    await _workoutService.clearActiveSession();

    // Calculate detailed workout metrics
    int totalCompletedSets = 0;
    int totalCompletedReps = 0;
    double totalVolumeKg = 0.0;
    final List<String> personalRecords = [];

    for (final ex in _exercises) {
      final name = ex['name'] as String? ?? 'Exercise';
      final setsList = ex['sets'] as List? ?? [];
      double maxWeightInExercise = 0.0;

      for (final s in setsList) {
        if (s['completed'] == true) {
          totalCompletedSets++;
          final reps = (s['reps'] as num?)?.toInt() ?? 0;
          final weight = (s['weight'] as num?)?.toDouble() ?? 0.0;
          totalCompletedReps += reps;
          totalVolumeKg += (reps * weight);
          if (weight > maxWeightInExercise) {
            maxWeightInExercise = weight;
          }
        }
      }

      if (maxWeightInExercise >= 80.0) {
        personalRecords.add('$name: ${maxWeightInExercise.toStringAsFixed(1)} kg');
      }
    }

    final double durationMinutes = _elapsedSeconds / 60.0;
    final double caloriesBurned = (durationMinutes * 6.5) * (totalCompletedSets > 0 ? 1.0 : 0.5);
    final int xpEarned = ((100 * _completionPercentage) + (totalCompletedSets * 15) + (totalVolumeKg / 100)).toInt();

    final completedHistory = WorkoutHistory(
      workoutName: widget.workoutName,
      dateCompleted: DateTime.now(),
      durationSeconds: _elapsedSeconds,
      exercisesCompleted: _completedExercisesCount,
      completionPercentage: _completionPercentage,
      totalSets: totalCompletedSets,
      totalReps: totalCompletedReps,
      totalVolume: totalVolumeKg,
      caloriesBurned: caloriesBurned,
      personalRecords: personalRecords,
      xpEarned: xpEarned,
    );

    await FitnessProvider.instance.saveWorkoutCompletion(completedHistory);

    if (!mounted) return;

    await WorkoutCompletionCelebration.show(
      context,
      workoutTitle: widget.workoutName,
      durationMinutes: (_elapsedSeconds / 60).round(),
      exercisesCompleted: _completedExercisesCount,
      caloriesBurned: caloriesBurned.round(),
      xpEarned: xpEarned,
      isPersonalRecord: personalRecords.isNotEmpty,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Workout Saved! ${widget.workoutName} completed in ${_formatDuration(_elapsedSeconds)}.',
          style: AppTheme.bodySm.copyWith(
            color: AppColors.onPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  void _showExerciseDetailsModal(Map<String, dynamic> exercise) {
    final name = exercise['name'] ?? 'Exercise';
    final target = exercise['primaryTarget'] ?? 'Target Muscle Group';
    final rawTips = exercise['tips'];
    final List<String> tips = (rawTips is List)
        ? rawTips.map((e) => e.toString()).toList()
        : [
            'Maintain a neutral spine throughout the movement.',
            'Control the eccentric downward phase for 2-3 seconds.',
            'Maintain proper breathing and mind-muscle connection.',
          ];

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
                      Expanded(
                        child: Text(
                          name,
                          style: AppTheme.headlineLg.copyWith(
                            fontSize: 18,
                            color: context.appTextPrimary,
                          ),
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
                  const SizedBox(height: 16),
                  Text(
                    'Execution Guidance & Form Tips:',
                    style: AppTheme.headlineMd.copyWith(
                      fontSize: 14,
                      color: context.appTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...tips.asMap().entries.map((entry) {
                    final index = entry.key + 1;
                    final tipText = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$index',
                              style: AppTheme.labelCaps.copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              tipText,
                              style: AppTheme.bodySm.copyWith(
                                fontSize: 13,
                                height: 1.4,
                                color: context.appTextSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
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
    _elapsedNotifier.dispose();
    _restNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentEx = _exercises[_currentExerciseIndex];
    final sets = currentEx['sets'] as List;
    final currentSetIndexBounded = _currentSetIndex.clamp(0, sets.length - 1);
    final currentSet = sets[currentSetIndexBounded];
    final completedCount = sets.where((s) => s['completed'] == true).length;

    return Scaffold(
      backgroundColor: context.appBackground,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Focused Header Bar (Top Finish button removed)
            _buildHeaderBar(context),

            // Main Scrollable Active Workout Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 2. Current Exercise Hero Card (Dynamic Image, Name, Muscles)
                    _buildCurrentExerciseHero(
                      context,
                      currentEx,
                      currentSetIndexBounded + 1,
                      sets.length,
                    ),
                    const SizedBox(height: 16),

                    // 3. Set Tracking Section (+ / - set controls included)
                    _buildSetProgressSection(context, sets, completedCount),
                    const SizedBox(height: 16),

                    // 4. Target Customization Card (Reps & Weight adjusters)
                    _buildExerciseCustomizationCard(context, currentSet),
                    const SizedBox(height: 16),

                    // 5. Rest Timer Card (Shown ONLY when resting)
                    _buildRestTimerCard(context),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // 6. Fixed Primary Bottom Action Bar ("START SET", "COMPLETE SET", "FINISH WORKOUT")
            _buildFixedBottomActionBar(context, sets),
          ],
        ),
      ),
    );
  }

  /// 1. Focused Workout Mode Header Bar
  Widget _buildHeaderBar(BuildContext context) {
    final totalExercises = _exercises.length;
    final currentExNumber = _currentExerciseIndex + 1;
    final overallProgress = (currentExNumber / totalExercises).clamp(0.0, 1.0);

    return ValueListenableBuilder<int>(
      valueListenable: _elapsedNotifier,
      builder: (context, elapsed, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: context.appSurface,
            border: Border(
              bottom: BorderSide(
                color: context.isDarkMode
                    ? AppColors.primaryContainer.withValues(alpha: 0.3)
                    : context.appOutlineVariant.withValues(alpha: 0.5),
              ),
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Exit Workout Button with confirmation dialog
                  IconButton(
                    onPressed: () => _confirmExitWorkout(context),
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: context.appSurfaceElevated,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              context.appOutlineVariant.withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Icon(Icons.close_rounded, size: 18),
                    ),
                  ),

                  // Workout Title & Exercise Counter & Timer
                  Column(
                    children: [
                      Text(
                        widget.workoutName,
                        style: AppTheme.headlineMd.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: context.appTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            'Exercise $currentExNumber of $totalExercises',
                            style: AppTheme.labelCaps.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: context.isDarkMode
                                  ? AppColors.primaryContainer
                                  : AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '•',
                            style: TextStyle(
                              fontSize: 10,
                              color: context.appTextSecondary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.timer_outlined,
                            size: 11,
                            color: _isTimerRunning
                                ? AppColors.primaryContainer
                                : context.appTextSecondary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            _formatDuration(elapsed),
                            style: AppTheme.labelCaps.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _isTimerRunning
                                  ? (context.isDarkMode
                                      ? AppColors.primaryContainer
                                      : AppColors.primary)
                                  : context.appTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Status Pill Indicator (Active / Standby)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _isTimerRunning
                          ? AppColors.primaryContainer.withValues(alpha: 0.2)
                          : context.appSurfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isTimerRunning
                            ? AppColors.primaryContainer.withValues(alpha: 0.4)
                            : context.appOutlineVariant,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isTimerRunning
                                ? AppColors.primaryContainer
                                : Colors.amber,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isTimerRunning ? 'ACTIVE' : 'READY',
                          style: AppTheme.labelCaps.copyWith(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: _isTimerRunning
                                ? AppColors.primaryContainer
                                : context.appTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Segmented Workout Progress Line
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: overallProgress,
                  minHeight: 4,
                  backgroundColor:
                      context.appOutlineVariant.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    context.isDarkMode
                        ? AppColors.primaryContainer
                        : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmExitWorkout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Pause & Exit Workout?',
          style: AppTheme.headlineMd.copyWith(
            fontSize: 18,
            color: context.appTextPrimary,
          ),
        ),
        content: Text(
          'Your workout progress and completed sets will be saved automatically.',
          style: AppTheme.bodySm.copyWith(color: context.appTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: AppTheme.bodySm.copyWith(
                color: context.appTextSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          AppButton.primary(
            label: 'Exit',
            isFullWidth: false,
            onPressed: () {
              Navigator.pop(context);
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    );
  }

  /// 2. Current Exercise Hero Card (Dynamic Image, Name, Muscles)
  Widget _buildCurrentExerciseHero(
    BuildContext context,
    Map<String, dynamic> exercise,
    int currentSetNum,
    int totalSetsNum,
  ) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      borderColor: context.isDarkMode
          ? AppColors.primaryContainer.withValues(alpha: 0.3)
          : null,
      onTap: () => _showExerciseDetailsModal(exercise),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Exercise Dynamic Image Widget with safe fallback handling
          _buildExerciseImageWidget(context, exercise),
          const SizedBox(width: 14),

          // Main Focus Exercise Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Set Badge & Form Info Icon
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppColors.primaryContainer.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        'SET $currentSetNum OF $totalSetsNum',
                        style: AppTheme.labelCaps.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: context.isDarkMode
                              ? AppColors.primaryContainer
                              : AppColors.primary,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: AppColors.primaryContainer,
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Main Focus Exercise Name (Dynamic)
                Text(
                  exercise['name'],
                  style: AppTheme.headlineLg.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: context.appTextPrimary,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),

                // Target Muscles Tag (Dynamic)
                Row(
                  children: [
                    Icon(
                      Icons.fitness_center_rounded,
                      size: 13,
                      color: context.appTextSecondary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        exercise['primaryTarget'] ?? 'Quadriceps, Glutes',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.bodySm.copyWith(
                          color: context.appTextSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Dynamic Exercise Image Widget using scalable AppImage architecture
  Widget _buildExerciseImageWidget(
    BuildContext context,
    Map<String, dynamic> exercise,
  ) {
    final String exerciseId = exercise['id']?.toString() ?? exercise['name']?.toString() ?? 'exercise';
    final String exerciseName = exercise['name']?.toString() ?? 'Exercise';
    final String? imagePath = exercise['imagePath']?.toString();
    final String? imageUrl = exercise['imageUrl']?.toString();

    return Container(
      key: ValueKey('${exerciseId}_$_currentExerciseIndex'),
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        color: context.appCardBg,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(
          color: context.appCardBorder,
          width: 1,
        ),
      ),
      child: AppImage.exercise(
        imageUrl: imageUrl,
        assetPath: imagePath,
        size: 76,
        exerciseName: exerciseName,
      ),
    );
  }

  /// 3. Set Tracking Section with Set Count Controls
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
              'SET TRACKING',
              style: AppTheme.labelCaps.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: context.appTextSecondary,
                letterSpacing: 0.8,
              ),
            ),
            Row(
              children: [
                Text(
                  '$completedCount / ${sets.length} Completed',
                  style: AppTheme.labelCaps.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: context.isDarkMode
                        ? AppColors.primaryContainer
                        : AppColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                // Customization: Remove set button
                GestureDetector(
                  onTap: _removeSetFromCurrentExercise,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: context.appSurfaceElevated,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: context.appOutlineVariant.withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Icon(Icons.remove, size: 14),
                  ),
                ),
                const SizedBox(width: 4),
                // Customization: Add set button
                GestureDetector(
                  onTap: _addSetToCurrentExercise,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.primaryContainer.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.add,
                          size: 12,
                          color: AppColors.primaryContainer,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          'Set',
                          style: AppTheme.labelCaps.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _currentSetIndex = index;
                    });
                  },
                  child: _buildSetCard(
                    context: context,
                    setNumber: index + 1,
                    reps: (set['reps'] as num).toInt(),
                    weight: (set['weight'] as num).toDouble(),
                    isDone: isDone,
                    isActive: isActive,
                  ),
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
    Color bgColor;
    if (isDone) {
      borderColor = AppColors.primaryContainer.withValues(alpha: 0.6);
      bgColor = AppColors.primaryContainer.withValues(alpha: 0.08);
    } else if (isActive) {
      borderColor = AppColors.primaryContainer;
      bgColor = AppColors.primaryContainer.withValues(alpha: 0.15);
    } else {
      borderColor = context.appOutlineVariant.withValues(alpha: 0.4);
      bgColor = context.appSurfaceElevated;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 145,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor,
          width: isActive ? 2.0 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDone
                          ? AppColors.primaryContainer
                          : (isActive
                              ? AppColors.primaryContainer.withValues(alpha: 0.2)
                              : context.appSurface),
                      border: Border.all(
                        color: isDone || isActive
                            ? AppColors.primaryContainer
                            : context.appOutlineVariant,
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: isDone
                          ? const Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: Colors.white,
                            )
                          : Text(
                              '$setNumber',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: isActive
                                    ? AppColors.primaryContainer
                                    : context.appTextSecondary,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Set $setNumber',
                    style: AppTheme.headlineMd.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.appTextPrimary,
                    ),
                  ),
                ],
              ),
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'NOW',
                    style: AppTheme.labelCaps.copyWith(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${weight.toStringAsFixed(0)} kg',
                style: AppTheme.headlineMd.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDone || isActive
                      ? (context.isDarkMode
                          ? AppColors.primaryContainer
                          : AppColors.primary)
                      : context.appTextPrimary,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '× $reps reps',
                style: AppTheme.bodySm.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.appTextSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 4. Target Customization Card (Weight & Reps Adjusters)
  Widget _buildExerciseCustomizationCard(
    BuildContext context,
    Map<String, dynamic> currentSet,
  ) {
    final double weight = (currentSet['weight'] as num).toDouble();
    final int reps = (currentSet['reps'] as num).toInt();

    return AppCard(
      padding: const EdgeInsets.all(14),
      borderColor: context.isDarkMode
          ? context.appOutlineVariant.withValues(alpha: 0.3)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TARGET CUSTOMIZATION (THIS SESSION)',
            style: AppTheme.labelCaps.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: context.appTextSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Weight Customization Stepper
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: context.appSurfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: context.appOutlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TARGET WEIGHT',
                        style: AppTheme.labelCaps.copyWith(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: context.appTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${weight.toStringAsFixed(0)} kg',
                            style: AppTheme.headlineMd.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: context.appTextPrimary,
                            ),
                          ),
                          Row(
                            children: [
                              _buildStepperButton(
                                icon: Icons.remove,
                                onTap: () => _adjustWeight(currentSet, -2.5),
                              ),
                              const SizedBox(width: 4),
                              _buildStepperButton(
                                icon: Icons.add,
                                onTap: () => _adjustWeight(currentSet, 2.5),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Reps Customization Stepper
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: context.appSurfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: context.appOutlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TARGET REPS',
                        style: AppTheme.labelCaps.copyWith(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: context.appTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$reps reps',
                            style: AppTheme.headlineMd.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: context.appTextPrimary,
                            ),
                          ),
                          Row(
                            children: [
                              _buildStepperButton(
                                icon: Icons.remove,
                                onTap: () => _adjustReps(currentSet, -1),
                              ),
                              const SizedBox(width: 4),
                              _buildStepperButton(
                                icon: Icons.add,
                                onTap: () => _adjustReps(currentSet, 1),
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
          ),
        ],
      ),
    );
  }

  Widget _buildStepperButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.primaryContainer.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: AppColors.primaryContainer.withValues(alpha: 0.3),
          ),
        ),
        child: Icon(
          icon,
          size: 14,
          color: AppColors.primaryContainer,
        ),
      ),
    );
  }

  /// 5. Dedicated Rest Timer Card (Shown ONLY when resting)
  Widget _buildRestTimerCard(BuildContext context) {
    if (!_isResting) {
      return const SizedBox.shrink();
    }

    return AppCard(
      padding: const EdgeInsets.all(16),
      borderColor: AppColors.primaryContainer.withValues(
        alpha: context.isDarkMode ? 0.5 : 0.3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.timer_outlined,
                      color: AppColors.primaryContainer,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'REST TIMER',
                    style: AppTheme.labelCaps.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: context.isDarkMode
                          ? AppColors.primaryContainer
                          : AppColors.primary,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),

              // Duration adjust buttons (-15s / +15s)
              Row(
                children: [
                  IconButton(
                    onPressed: () => _adjustRestTime(-15),
                    icon: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: context.appSurfaceElevated,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color:
                              context.appOutlineVariant.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        '-15s',
                        style: AppTheme.labelCaps.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: context.appTextPrimary,
                        ),
                      ),
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    onPressed: () => _adjustRestTime(15),
                    icon: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: context.appSurfaceElevated,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color:
                              context.appOutlineVariant.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        '+15s',
                        style: AppTheme.labelCaps.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: context.appTextPrimary,
                        ),
                      ),
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Timer Circular Countdown & Controls
          ValueListenableBuilder<int>(
            valueListenable: _restNotifier,
            builder: (context, restSecs, _) {
              final progress = _targetRestSeconds > 0
                  ? (restSecs / _targetRestSeconds).clamp(0.0, 1.0)
                  : 0.0;
              return Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: ProgressRing.single(
                      size: 110,
                      progress: progress,
                      color: AppColors.primaryContainer,
                      strokeWidth: 7,
                      centerChild: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _formatDuration(restSecs),
                            style: AppTheme.displayMetrics.copyWith(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: context.appTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isRestPaused ? 'PAUSED' : 'RESTING',
                            style: AppTheme.labelCaps.copyWith(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              color: _isRestPaused
                                  ? Colors.amber
                                  : AppColors.primaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 90,
                    color: context.appOutlineVariant.withValues(alpha: 0.3),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 5,
                    child: Column(
                      children: [
                        AppButton.secondary(
                          label: _isRestPaused ? 'Resume' : 'Pause',
                          icon: _isRestPaused
                              ? Icons.play_arrow_rounded
                              : Icons.pause_rounded,
                          onPressed: _toggleRestPause,
                        ),
                        const SizedBox(height: 8),
                        AppButton.primary(
                          label: 'Skip Rest',
                          icon: Icons.fast_forward_rounded,
                          onPressed: _skipRest,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// 6. Workout-Focused Bottom Action Bar
  Widget _buildFixedBottomActionBar(BuildContext context, List sets) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final bool allSetsFinished = _completedSetsCount == _totalSetsCount;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: bottomInset + 16,
      ),
      decoration: BoxDecoration(
        color: context.appSurface,
        border: Border(
          top: BorderSide(
            color: context.isDarkMode
                ? context.appOutlineVariant.withValues(alpha: 0.3)
                : context.appOutlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (allSetsFinished) ...[
            AppButton.primary(
              label: 'FINISH WORKOUT',
              icon: Icons.emoji_events_rounded,
              onPressed: _showFinishWorkoutConfirmationDialog,
              isPill: true,
            ),
          ] else ...[
            // Main Set Action Button: START SET or COMPLETE SET or SKIP REST
            if (_isResting) ...[
              AppButton.primary(
                label: 'SKIP REST & START SET ${_currentSetIndex + 1}',
                icon: Icons.play_arrow_rounded,
                onPressed: () {
                  _skipRest();
                  _startSet();
                },
                isPill: true,
              ),
            ] else if (!_isSetActive) ...[
              AppButton.primary(
                label: 'START SET ${_currentSetIndex + 1}',
                icon: Icons.play_arrow_rounded,
                onPressed: _startSet,
                isPill: true,
              ),
            ] else ...[
              AppButton.primary(
                label: 'COMPLETE SET ${_currentSetIndex + 1}',
                icon: Icons.check_circle_rounded,
                onPressed: _completeSet,
                isPill: true,
              ),
            ],

            const SizedBox(height: 8),

            // Secondary Bottom Action: Finish Workout Early
            if (_completedSetsCount > 0)
              AppButton.text(
                label: 'Finish Workout Early',
                icon: Icons.flag_outlined,
                onPressed: _showFinishWorkoutConfirmationDialog,
              ),
          ],
        ],
      ),
    );
  }
}
