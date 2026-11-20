import 'dart:async';
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../data/app_dependencies.dart';
import '../data/local_storage.dart';
import '../data/workout_service.dart';
import '../models/active_workout_session.dart';
import '../models/exercise.dart';
import '../models/workout_session.dart';
import '../providers/fitness_provider.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/app_button.dart';
import '../widgets/exercise/exercise_thumbnail.dart';
import '../widgets/common/progress_ring.dart';
import '../widgets/common/workout_completion_celebration.dart';
import '../services/workout_generator_engine.dart';
import '../services/progressive_overload_service.dart';
import '../services/rest_timer_service.dart';
import '../services/set_timer.dart';
import '../services/workout_summary.dart';
import '../widgets/workout/set_timer_display.dart';
import 'exercise_detail_screen.dart';

class WorkoutSessionScreen extends StatefulWidget {
  final String workoutName;
  final String? workoutId;
  final List<Map<String, dynamic>>? initialExercises;
  final VoidCallback? onExit;

  /// Test hook: replaces the monotonic clock used to time sets.
  @visibleForTesting
  static Duration Function()? setClockOverride;

  const WorkoutSessionScreen({
    super.key,
    this.workoutName = 'Leg Day - Hypertrophy',
    this.workoutId = 'leg_day_hypertrophy_01',
    this.initialExercises,
    this.onExit,
  });

  @override
  State<WorkoutSessionScreen> createState() => _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends State<WorkoutSessionScreen>
    with WidgetsBindingObserver {
  late final WorkoutService _workoutService;

  /// Times the set that is in progress. It lives in the State, so rebuilds
  /// never reset it, and it reads a monotonic clock, so backgrounding cannot
  /// make it drift.
  final SetTimer _setTimer = SetTimer(
    now: WorkoutSessionScreen.setClockOverride,
  );

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
  bool _dismissedReadinessAlert = false;
  DateTime _startTime = DateTime.now();

  late List<Map<String, dynamic>> _exercises;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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

    final List<Map<String, dynamic>> rawExercises;
    if (widget.initialExercises != null &&
        widget.initialExercises!.isNotEmpty) {
      rawExercises = widget.initialExercises!;
    } else {
      final isDefaultLegId =
          widget.workoutId == 'leg_day_hypertrophy_01' &&
          widget.workoutName != 'Leg Day - Hypertrophy';
      rawExercises = WorkoutGeneratorEngine().generateExercisesForWorkout(
        workoutName: widget.workoutName,
        focus: isDefaultLegId ? null : widget.workoutId,
        equipmentProfile: LocalStorage.getUserEquipmentProfile(),
      );
    }
    _exercises = _enrichExercises(rawExercises);

    if (saved != null && matchesIdentity) {
      _elapsedSeconds = saved.seconds;
      _currentExerciseIndex = saved.currentIndex.clamp(
        0,
        _exercises.length - 1,
      );
      _startTime =
          saved.startTime ??
          DateTime.now().subtract(Duration(seconds: saved.seconds));

      // Restore detailed exercise set data (weights, reps, completion flags) if present
      if (saved.exercisesData != null && saved.exercisesData!.isNotEmpty) {
        for (
          int i = 0;
          i < _exercises.length && i < saved.exercisesData!.length;
          i++
        ) {
          final savedEx = saved.exercisesData![i];
          final savedSets = savedEx['sets'] as List?;
          final currentSets = _exercises[i]['sets'] as List;
          if (savedSets != null) {
            for (
              int j = 0;
              j < currentSets.length && j < savedSets.length;
              j++
            ) {
              final sSet = Map<String, dynamic>.from(savedSets[j] as Map);
              currentSets[j]['weight'] =
                  (sSet['weight'] as num?)?.toDouble() ??
                  currentSets[j]['weight'];
              currentSets[j]['reps'] =
                  (sSet['reps'] as num?)?.toInt() ?? currentSets[j]['reps'];
              currentSets[j]['completed'] = sSet['completed'] as bool? ?? false;
              if (sSet['durationSeconds'] is num) {
                currentSets[j]['durationSeconds'] =
                    (sSet['durationSeconds'] as num).toInt();
              }
            }
          }
        }
      } else if (saved.completedSets.isNotEmpty) {
        for (
          int i = 0;
          i < _exercises.length && i < saved.completedSets.length;
          i++
        ) {
          final savedSets = saved.completedSets[i];
          final currentSets = _exercises[i]['sets'] as List;
          for (int j = 0; j < currentSets.length && j < savedSets.length; j++) {
            currentSets[j]['completed'] = savedSets[j];
          }
        }
      }

      // Resume from first incomplete set in the active exercise
      final currentSets = _exercises[_currentExerciseIndex]['sets'] as List;
      final firstIncompleteIndex = currentSets.indexWhere(
        (s) => s['completed'] != true,
      );
      if (firstIncompleteIndex >= 0) {
        _currentSetIndex = firstIncompleteIndex;
      } else {
        // If current exercise sets are all complete, advance to next incomplete exercise
        final nextIncompleteExIndex = _exercises.indexWhere((ex) {
          final sets = ex['sets'] as List;
          return sets.any((s) => s['completed'] != true);
        });
        if (nextIncompleteExIndex >= 0) {
          _currentExerciseIndex = nextIncompleteExIndex;
          final nextSets = _exercises[_currentExerciseIndex]['sets'] as List;
          final nextSetIdx = nextSets.indexWhere((s) => s['completed'] != true);
          _currentSetIndex = nextSetIdx >= 0 ? nextSetIdx : 0;
        } else {
          _currentSetIndex = (currentSets.length - 1).clamp(
            0,
            currentSets.length - 1,
          );
        }
      }
    } else {
      _startTime = DateTime.now();
      final pastSessions = _workoutService.getWorkoutSessions();

      // Calibrate baseline / progressive overload suggestions and previous performance
      for (final ex in _exercises) {
        final name = ex['name'] as String? ?? 'Exercise';
        final id = ex['id'] as String?;
        final sets = ex['sets'] as List;
        final double defaultW =
            (sets.isNotEmpty
                ? (sets.first['weight'] as num?)?.toDouble()
                : 40.0) ??
            40.0;
        final int defaultR =
            (sets.isNotEmpty ? (sets.first['reps'] as num?)?.toInt() : 10) ??
            10;

        // Find past exercise history for previous performance tracking
        WorkoutSessionExercise? pastEx;
        for (final pSession in pastSessions) {
          for (final e in pSession.exercises) {
            if ((id != null &&
                    id.isNotEmpty &&
                    e.id.toLowerCase() == id.toLowerCase()) ||
                e.name.trim().toLowerCase() == name.trim().toLowerCase()) {
              if (e.sets.any((s) => s.completed)) {
                pastEx = e;
                break;
              }
            }
          }
          if (pastEx != null) break;
        }

        final pastCompleted =
            pastEx?.sets.where((s) => s.completed).toList() ?? [];

        final suggestion = ProgressiveOverloadService.instance
            .getSuggestedProgression(
              exerciseName: name,
              exerciseId: id,
              defaultWeight: defaultW,
              defaultReps: defaultR,
              pastSessions: pastSessions,
            );

        for (int i = 0; i < sets.length; i++) {
          final s = sets[i];
          s['weight'] = suggestion.targetWeight;
          s['reps'] = suggestion.targetReps;
          if (i < pastCompleted.length) {
            s['previousWeight'] = pastCompleted[i].weight;
            s['previousReps'] = pastCompleted[i].reps;
          } else if (pastCompleted.isNotEmpty) {
            s['previousWeight'] = pastCompleted.last.weight;
            s['previousReps'] = pastCompleted.last.reps;
          }
        }
      }
    }
  }

  List<Map<String, dynamic>> _enrichExercises(
    List<Map<String, dynamic>> rawList,
  ) {
    return rawList.map((ex) {
      final name = ex['name']?.toString() ?? 'Exercise';
      final id =
          ex['id']?.toString() ?? name.toLowerCase().replaceAll(' ', '_');
      final matched = Exercise.getById(id) ?? Exercise.findByName(name);

      final tipsRaw = ex['tips'] as List?;
      final List<String> tipsList = tipsRaw != null
          ? tipsRaw.map((e) => e.toString()).toList()
          : (matched?.tips ??
                [
                  'Maintain a neutral spine throughout movement.',
                  'Control the eccentric lowering phase for 2-3 seconds.',
                  'Drive through movement with controlled breathing.',
                ]);

      final sets =
          ex['sets'] ??
          [
            {'reps': 10, 'weight': 40.0, 'completed': false},
            {'reps': 10, 'weight': 40.0, 'completed': false},
            {'reps': 10, 'weight': 40.0, 'completed': false},
          ];

      return {
        'id': matched?.id ?? id,
        'name': matched?.name ?? name,
        'primaryTarget':
            matched?.muscleGroup ??
            ex['primaryTarget'] ??
            'Target Muscle Group',
        'muscleGroup':
            matched?.muscleGroup ?? ex['muscleGroup'] ?? 'Target Muscle Group',
        'equipment': matched?.equipment ?? ex['equipment'] ?? 'Gym Equipment',
        'imagePath': ex['imagePath'],
        'imageUrl': matched?.imageUrl ?? ex['imageUrl'],
        'videoUrl': matched?.videoUrl ?? ex['videoUrl'],
        'tips': tipsList,
        'sets': sets,
      };
    }).toList();
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
        currentSetIndex: _currentSetIndex,
        seconds: _elapsedSeconds,
        isPaused: !_isTimerRunning,
        completedSets: completedSets,
        exercisesData: _exercises,
        startTime: _startTime,
      ),
    );
  }

  void _startSet() {
    // One timing at a time: a second tap on an active set changes nothing.
    if (_isSetActive && _setTimer.isRunning) return;
    _setTimer.start();
    setState(() {
      _isSetActive = true;
      _isResting = false;
      _restTimer?.cancel();
    });
    _startWorkoutTimer();
    _saveActiveSessionState();
  }

  void _completeSet() {
    // Only a set that was started can be finished; this keeps an unstarted or
    // abandoned set from being saved as completed.
    if (!_isSetActive || !_setTimer.isRunning) return;
    final seconds = _setTimer.stop();
    final currentEx = _exercises[_currentExerciseIndex];
    final sets = currentEx['sets'] as List;

    final recommendedRest = RestTimerService.instance
        .calculateRecommendedRestSeconds(currentEx['name']);

    setState(() {
      sets[_currentSetIndex]['completed'] = true;
      if (seconds != null) sets[_currentSetIndex]['durationSeconds'] = seconds;
      sets[_currentSetIndex]['completedAt'] = DateTime.now().toIso8601String();
      _isSetActive = false;

      if (_currentSetIndex < sets.length - 1) {
        _currentSetIndex++;
        _startRestTimer(recommendedRest);
      } else if (_currentExerciseIndex < _exercises.length - 1) {
        _currentExerciseIndex++;
        _currentSetIndex = 0;
        _startRestTimer(recommendedRest);
      } else {
        _showFinishWorkoutConfirmationDialog();
      }
    });

    _saveActiveSessionState();
  }

  void _startRestTimer(int durationSeconds) {
    _restTimer?.cancel();
    RestTimerService.instance.startRest(
      durationSeconds: durationSeconds,
      exerciseName: _exercises[_currentExerciseIndex]['name'] as String?,
    );
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
        RestTimerService.instance.skip();
        setState(() {
          _isResting = false;
          _restSecondsRemaining = 0;
          _restNotifier.value = 0;
        });
      }
    });
  }

  void _toggleRestPause() {
    if (_isRestPaused) {
      RestTimerService.instance.resume();
    } else {
      RestTimerService.instance.pause();
    }
    setState(() {
      _isRestPaused = !_isRestPaused;
    });
  }

  void _adjustRestTime(int deltaSeconds) {
    RestTimerService.instance.extend(seconds: deltaSeconds);
    setState(() {
      _targetRestSeconds = (_targetRestSeconds + deltaSeconds).clamp(15, 300);
      _restSecondsRemaining = (_restSecondsRemaining + deltaSeconds).clamp(
        0,
        300,
      );
      _restNotifier.value = _restSecondsRemaining;
    });
  }

  void _skipRest() {
    _restTimer?.cancel();
    RestTimerService.instance.skip();
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
        // The set being timed no longer exists: abandon it.
        _setTimer.cancel();
        _isSetActive = false;
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
    // The workout is already being saved: nothing more to confirm.
    if (_isSavingWorkout) return;
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
                    context,
                    'Exercises Completed',
                    '$completedEx of $totalEx',
                  ),
                  const Divider(height: 14, thickness: 0.5),
                  _buildSummaryDialogRow(
                    context,
                    'Sets Tracked',
                    '$completedSets of $totalSets',
                  ),
                  const Divider(height: 14, thickness: 0.5),
                  _buildSummaryDialogRow(
                    context,
                    'Active Duration',
                    durationStr,
                  ),
                  const Divider(height: 14, thickness: 0.5),
                  _buildSummaryDialogRow(
                    context,
                    'Total Volume',
                    '$volumeStr kg',
                  ),
                  const Divider(height: 14, thickness: 0.5),
                  _buildSummaryDialogRow(
                    context,
                    'Target Completion',
                    '${compPercent.toStringAsFixed(0)}%',
                  ),
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
                    // A second press while the first is saving does nothing.
                    if (_isSavingWorkout) return;
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
    BuildContext context,
    String label,
    String value,
  ) {
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

  /// Set while the finished workout is being saved, so pressing Finish & Save
  /// twice cannot record it twice.
  bool _isSavingWorkout = false;

  Future<void> _confirmFinishAndSave() async {
    // The dialog button checks this first, so today this line is never the
    // one that stops a repeat. It keeps the method safe on its own for any
    // other caller, since this is where the flag is set.
    if (_isSavingWorkout) return;
    _isSavingWorkout = true;
    try {
      await _saveFinishedWorkout();
    } catch (_) {
      // Nothing was lost: a saved workout is picked up again on the next try,
      // and a repeat of one that is complete is ignored.
      _isSavingWorkout = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not save your workout. Please tap Finish & Save again.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _saveFinishedWorkout() async {
    _timer?.cancel();
    _restTimer?.cancel();
    _isTimerRunning = false;
    await _workoutService.clearActiveSession();

    // 1. Build structured WorkoutSessionExercise and WorkoutSessionSet objects
    final List<WorkoutSessionExercise> sessionExercises = [];
    int totalCompletedSets = 0;
    double totalVolumeKg = 0.0;

    for (final ex in _exercises) {
      final name = ex['name'] as String? ?? 'Exercise';
      final id = ex['id'] as String? ?? name.toLowerCase().replaceAll(' ', '_');
      final muscle =
          ex['primaryTarget'] as String? ??
          ex['muscleGroup'] as String? ??
          'Full Body';
      final setsList = ex['sets'] as List? ?? [];
      final List<WorkoutSessionSet> sessionSets = [];

      for (int i = 0; i < setsList.length; i++) {
        final s = setsList[i];
        final isCompleted = s['completed'] == true;
        final reps = (s['reps'] as num?)?.toInt() ?? 0;
        final weight = (s['weight'] as num?)?.toDouble() ?? 0.0;

        if (isCompleted) {
          totalCompletedSets++;
          totalVolumeKg += (reps * weight);
        }

        sessionSets.add(
          WorkoutSessionSet(
            setNumber: i + 1,
            weight: weight,
            reps: reps,
            completed: isCompleted,
            rpe: (s['rpe'] as num?)?.toDouble(),
            previousWeight: (s['previousWeight'] as num?)?.toDouble(),
            previousReps: (s['previousReps'] as num?)?.toInt(),
            durationSeconds: isCompleted
                ? (s['durationSeconds'] as num?)?.toInt()
                : null,
          ),
        );
      }

      final isExComplete =
          sessionSets.isNotEmpty && sessionSets.every((s) => s.completed);
      sessionExercises.add(
        WorkoutSessionExercise(
          id: id,
          name: name,
          muscleGroup: muscle,
          sets: sessionSets,
          isCompleted: isExComplete,
        ),
      );
    }

    // 2. Evaluate authentic Personal Records against historical lifting benchmarks
    final prResults = ProgressiveOverloadService.instance
        .evaluatePersonalRecords(
          exercises: sessionExercises,
          workoutId:
              widget.workoutId ??
              'workout_${widget.workoutName.toLowerCase().replaceAll(' ', '_')}',
        );
    final List<String> personalRecords = prResults
        .map((p) => p.displayText)
        .toList();

    // 3. Compute physiological calories burned based on body weight, duration, and mechanical volume
    final double caloriesBurned = ProgressiveOverloadService.instance
        .calculateCaloriesBurned(
          durationSeconds: _elapsedSeconds.toDouble(),
          totalVolumeKg: totalVolumeKg,
          completedSets: totalCompletedSets,
        );

    // 5. Construct primary WorkoutSession model (Single Source of Truth)
    final workoutSession = WorkoutSession(
      id: 'session_${DateTime.now().millisecondsSinceEpoch}',
      workoutId:
          widget.workoutId ??
          'workout_${widget.workoutName.toLowerCase().replaceAll(' ', '_')}',
      workoutName: widget.workoutName,
      startTime: _startTime,
      endTime: DateTime.now(),
      exercises: sessionExercises,
      completedExercises: _completedExercisesCount,
      totalVolume: totalVolumeKg,
      caloriesBurned: caloriesBurned,
      duration: Duration(seconds: _elapsedSeconds),
      state: WorkoutSessionState.completed,
      personalRecords: personalRecords,
    );

    // 6. Convert to WorkoutHistory and persist through single source of truth pipeline.
    // The XP is worked out once, there, and comes back in the result.
    final completedHistory = workoutSession.toWorkoutHistory();

    final completion = await FitnessProvider.instance.saveWorkoutCompletion(
      completedHistory,
      session: workoutSession,
    );
    final int xpEarned = completion.xpEarned;

    if (!mounted) return;

    // The summary is built from the session that was just saved and from the
    // saved history, so it can only show what was really recorded.
    final summary = WorkoutSummaryBuilder.build(
      session: workoutSession,
      personalRecords: prResults,
      streakDays: completion.isDuplicate
          ? null
          : WorkoutSummaryBuilder.streakFor(
              LocalStorage.getWorkoutHistory(),
              completedHistory,
            ),
      xpEarned: completion.isDuplicate ? null : xpEarned,
      caloriesEstimate: caloriesBurned > 0 ? caloriesBurned.round() : null,
    );

    await WorkoutCompletionCelebration.show(
      context,
      workoutTitle: widget.workoutName,
      durationMinutes: (_elapsedSeconds / 60).round(),
      exercisesCompleted: _completedExercisesCount,
      caloriesBurned: caloriesBurned.round(),
      xpEarned: xpEarned,
      isPersonalRecord: personalRecords.isNotEmpty,
      summary: summary,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                              color: AppColors.primaryContainer.withValues(
                                alpha: 0.2,
                              ),
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The set clock is monotonic, so nothing needs correcting on return; this
    // only repaints so the displayed time is right the moment the app resumes.
    if (state == AppLifecycleState.resumed && mounted && _isSetActive) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // A set still being timed when the screen closes was never finished, so it
    // is dropped, not saved.
    _setTimer.cancel();
    _timer?.cancel();
    _restTimer?.cancel();
    RestTimerService.instance.skip();
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _requestExitWorkout();
      },
      child: Scaffold(
        backgroundColor: context.appBackground,
        body: SafeArea(
          bottom: false,
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
                      // Pre-Workout Readiness & Recovery Alert
                      _buildReadinessAlertBanner(context),

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
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: _buildFixedBottomActionBar(context, sets),
        ),
      ),
    );
  }

  /// Pre-workout readiness banner shown when recovery is below optimal
  Widget _buildReadinessAlertBanner(BuildContext context) {
    if (_dismissedReadinessAlert) return const SizedBox.shrink();
    final recovery = FitnessProvider.instance.recoveryState;
    // The low-readiness alert only fires on a recorded recovery score.
    if (recovery == null || !recovery.isMeasured) {
      return const SizedBox.shrink();
    }
    final score = recovery.recoveryScore;
    if (score >= 60) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.bolt_rounded, color: Color(0xFFF59E0B), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recovery: $score%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFF59E0B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'AI Suggestion: Reduce volume by 15%',
                  style: AppTheme.bodySm.copyWith(
                    fontSize: 10,
                    color: context.appTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            onPressed: () => setState(() => _dismissedReadinessAlert = true),
          ),
        ],
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
                    onPressed: _requestExitWorkout,
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: context.appSurfaceElevated,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: context.appOutlineVariant.withValues(
                            alpha: 0.4,
                          ),
                        ),
                      ),
                      child: const Icon(Icons.close_rounded, size: 18),
                    ),
                  ),

                  // Workout Title & Exercise Counter & Timer
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          widget.workoutName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.headlineMd.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: context.appTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
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
                        ),
                      ],
                    ),
                  ),

                  // Status Pill Indicator (Active / Standby)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
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
                  backgroundColor: context.appOutlineVariant.withValues(
                    alpha: 0.2,
                  ),
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

  Future<void> _requestExitWorkout() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: dialogContext.appSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: AppColors.primaryContainer.withValues(
              alpha: dialogContext.isDarkMode ? 0.4 : 0.2,
            ),
          ),
        ),
        title: Text(
          'Pause & Exit Workout?',
          style: AppTheme.headlineMd.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: dialogContext.appTextPrimary,
          ),
        ),
        content: Text(
          'Your workout progress and completed sets will be saved automatically.',
          style: AppTheme.bodySm.copyWith(
            color: dialogContext.appTextSecondary,
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(
                    'Cancel',
                    style: AppTheme.bodySm.copyWith(
                      color: dialogContext.appTextSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryContainer,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(
                    'Exit',
                    style: AppTheme.bodySm.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (shouldExit == true && mounted) {
      await _exitWorkout();
    }
  }

  Future<void> _exitWorkout() async {
    _timer?.cancel();
    _timer = null;
    _restTimer?.cancel();
    _restTimer = null;
    RestTimerService.instance.skip();
    _isTimerRunning = false;
    _isResting = false;

    _saveActiveSessionState();

    if (widget.onExit != null) {
      widget.onExit!();
      return;
    }

    if (!mounted) return;

    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    } else {
      await nav.maybePop();
    }
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withValues(
                          alpha: 0.18,
                        ),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppColors.primaryContainer.withValues(
                            alpha: 0.4,
                          ),
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
                const SizedBox(height: 8),

                // 🎥 View Guide Action Button
                GestureDetector(
                  onTap: () => _openFormGuide(exercise),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withValues(
                        alpha: context.isDarkMode ? 0.2 : 0.1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.primaryContainer.withValues(
                          alpha: 0.4,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.play_circle_fill_rounded,
                          size: 13,
                          color: context.isDarkMode
                              ? AppColors.primaryContainer
                              : AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Form Guide & Tips',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.labelCaps.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: context.isDarkMode
                                  ? AppColors.primaryContainer
                                  : AppColors.primary,
                            ),
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

  void _openFormGuide(Map<String, dynamic> exerciseMap) {
    final String name = exerciseMap['name']?.toString() ?? 'Exercise';
    final String id =
        exerciseMap['id']?.toString() ??
        name.toLowerCase().replaceAll(' ', '_');

    final registry = Exercise.defaultRegistry();
    final Exercise exerciseObj = registry.firstWhere(
      (e) => e.id == id || e.name.toLowerCase() == name.toLowerCase(),
      orElse: () {
        final tipsRaw = exerciseMap['tips'] as List?;
        final List<String> tipsList = tipsRaw != null
            ? tipsRaw.map((e) => e.toString()).toList()
            : [
                'Maintain steady breathing through each rep.',
                'Control the movement through full range of motion.',
              ];
        return Exercise(
          id: id,
          name: name,
          muscleGroup: exerciseMap['primaryTarget']?.toString() ?? 'Full Body',
          equipment: 'Gym Gear',
          difficulty: 'Intermediate',
          instructions: [
            'Set up safely with a strong braced posture.',
            'Execute each repetition with controlled tempo.',
            'Focus on squeezing the target muscle group at peak contraction.',
          ],
          tips: tipsList,
          commonMistakes: [
            'Rushing reps without control.',
            'Compromising spine neutrality.',
          ],
          imageUrl:
              exerciseMap['imageUrl']?.toString() ??
              exerciseMap['imagePath']?.toString(),
        );
      },
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExerciseDetailScreen(
          exercise: exerciseObj,
          enableWorkoutStart: false,
        ),
      ),
    );
  }

  /// The exercise illustration (one static thumbnail per exercise)
  Widget _buildExerciseImageWidget(
    BuildContext context,
    Map<String, dynamic> exercise,
  ) {
    final String exerciseId =
        exercise['id']?.toString() ??
        exercise['name']?.toString() ??
        'exercise';
    final String exerciseName = exercise['name']?.toString() ?? 'Exercise';
    return Container(
      key: ValueKey('${exerciseId}_$_currentExerciseIndex'),
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        color: context.appCardBg,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: context.appCardBorder, width: 1),
      ),
      child: ExerciseThumbnail(
        exerciseId: exerciseId,
        exerciseName: exerciseName,
        size: 76,
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
            Expanded(
              child: Text(
                'SET TRACKING',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.labelCaps.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: context.appTextSecondary,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
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
                const SizedBox(width: 6),
                // Customization: Add set button
                GestureDetector(
                  onTap: _addSetToCurrentExercise,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: context.appSurfaceElevated,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: context.appOutlineVariant.withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Icon(Icons.add, size: 14),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Horizontal List of Set Status Cards
        SizedBox(
          height: 82,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: sets.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final setItem = sets[index];
              final setNum = index + 1;
              final isCompleted = setItem['completed'] == true;
              final isCurrent = index == _currentSetIndex;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _currentSetIndex = index;
                  });
                },
                child: _buildSetCard(
                  context,
                  setNumber: setNum,
                  isDone: isCompleted,
                  isActive: isCurrent,
                  weight: (setItem['weight'] as num).toDouble(),
                  reps: (setItem['reps'] as num).toInt(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSetCard(
    BuildContext context, {
    required int setNumber,
    required bool isDone,
    required bool isActive,
    required double weight,
    required int reps,
  }) {
    final bgColor = isActive
        ? AppColors.primaryContainer.withValues(alpha: 0.12)
        : (isDone ? context.appSurfaceElevated : context.appSurface);
    final borderColor = isActive
        ? AppColors.primaryContainer
        : (isDone
              ? AppColors.primaryContainer.withValues(alpha: 0.4)
              : context.appOutlineVariant.withValues(alpha: 0.3));

    return Container(
      width: 135,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: isActive ? 2.0 : 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDone
                            ? AppColors.primaryContainer
                            : (isActive
                                  ? AppColors.primaryContainer.withValues(
                                      alpha: 0.2,
                                    )
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
                                size: 12,
                                color: Colors.white,
                              )
                            : Text(
                                '$setNumber',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: isActive
                                      ? AppColors.primaryContainer
                                      : context.appTextSecondary,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Set $setNumber',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.headlineMd.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: context.appTextPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
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
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${weight.toStringAsFixed(0)} kg × $reps reps',
                    style: AppTheme.headlineMd.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isDone || isActive
                          ? (context.isDarkMode
                                ? AppColors.primaryContainer
                                : AppColors.primary)
                          : context.appTextPrimary,
                    ),
                  ),
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
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '${weight.toStringAsFixed(0)} kg',
                                style: AppTheme.headlineMd.copyWith(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: context.appTextPrimary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
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
              const SizedBox(width: 8),

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
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '$reps reps',
                                style: AppTheme.headlineMd.copyWith(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: context.appTextPrimary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
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
        child: Icon(icon, size: 14, color: AppColors.primaryContainer),
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
                          color: context.appOutlineVariant.withValues(
                            alpha: 0.4,
                          ),
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
                          color: context.appOutlineVariant.withValues(
                            alpha: 0.4,
                          ),
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
    final bool allSetsFinished = _completedSetsCount == _totalSetsCount;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
              SetTimerDisplay(timer: _setTimer),
              const SizedBox(height: 8),
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
