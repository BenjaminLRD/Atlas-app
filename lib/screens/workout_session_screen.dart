import 'dart:async';
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../data/app_dependencies.dart';
import '../data/workout_service.dart';
import '../models/active_workout_session.dart';
import '../models/workout_history.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/primary_button.dart';
import '../widgets/common/progress_ring.dart';

class WorkoutSessionScreen extends StatefulWidget {
  final String workoutName;
  final String? workoutId;
  final List<Map<String, dynamic>>? initialExercises;

  const WorkoutSessionScreen({
    super.key,
    this.workoutName = 'Workout Session',
    this.workoutId,
    this.initialExercises,
  });

  @override
  State<WorkoutSessionScreen> createState() => _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends State<WorkoutSessionScreen> {
  late final WorkoutService _workoutService;

  int _elapsedSeconds = 0;
  Timer? _timer;

  int _restSecondsRemaining = 0;
  Timer? _restTimer;
  bool _isResting = false;

  int _currentExerciseIndex = 0;
  int _currentSetIndex = 0;

  late List<Map<String, dynamic>> _exercises;

  @override
  void initState() {
    super.initState();
    _workoutService = AppDependencies.instance.workoutService;
    _loadOrCreateSession();
    _startTimer();
  }

  void _loadOrCreateSession() {
    final saved = _workoutService.getActiveSession();
    final bool matchesIdentity = saved != null &&
        ((widget.workoutId != null && saved.workoutId == widget.workoutId) ||
         (saved.workoutName == widget.workoutName));

    if (saved != null && matchesIdentity) {
      _elapsedSeconds = saved.seconds;
      _currentExerciseIndex = saved.currentIndex;
      _currentSetIndex = 0;
      _exercises = saved.completedSets.isNotEmpty
          ? [
              {
                'name': 'Barbell Back Squat',
                'sets': saved.completedSets[0]
                    .map((done) => {'reps': 10, 'weight': 80.0, 'completed': done})
                    .toList()
              }
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
        'sets': [
          {'reps': 10, 'weight': 80.0, 'completed': true},
          {'reps': 10, 'weight': 80.0, 'completed': false},
          {'reps': 8, 'weight': 85.0, 'completed': false},
          {'reps': 8, 'weight': 85.0, 'completed': false},
        ]
      },
      {
        'name': 'Romanian Deadlift',
        'sets': [
          {'reps': 12, 'weight': 70.0, 'completed': false},
          {'reps': 12, 'weight': 70.0, 'completed': false},
          {'reps': 10, 'weight': 75.0, 'completed': false},
        ]
      },
      {
        'name': 'Leg Press',
        'sets': [
          {'reps': 12, 'weight': 140.0, 'completed': false},
          {'reps': 12, 'weight': 140.0, 'completed': false},
          {'reps': 12, 'weight': 150.0, 'completed': false},
        ]
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
        .map((ex) => (ex['sets'] as List).map((s) => s['completed'] as bool).toList())
        .toList();

    _workoutService.saveActiveSession(
      ActiveWorkoutSession(
        workoutName: widget.workoutName,
        workoutId: widget.workoutId ?? 'workout_session_default',
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

  void _addRestTime(int seconds) {
    setState(() {
      _restSecondsRemaining += seconds;
    });
  }

  void _completeSet() {
    final currentEx = _exercises[_currentExerciseIndex];
    final sets = currentEx['sets'] as List;

    setState(() {
      sets[_currentSetIndex]['completed'] = true;

      if (_currentSetIndex < sets.length - 1) {
        _currentSetIndex++;
        _startRestTimer(60);
      } else if (_currentExerciseIndex < _exercises.length - 1) {
        _currentExerciseIndex++;
        _currentSetIndex = 0;
        _startRestTimer(90);
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              const Icon(Icons.emoji_events_rounded, color: AppColors.primary, size: 28),
              const SizedBox(width: 10),
              Text('Workout Complete!', style: AppTheme.headlineMd.copyWith(fontSize: 20, color: context.appTextPrimary)),
            ],
          ),
          content: Text(
            'Great job! You completed ${widget.workoutName} in ${(_elapsedSeconds / 60).ceil()} mins with a total volume of ${_calculateTotalVolume().toStringAsFixed(0)} kg.',
            style: AppTheme.bodySm.copyWith(color: context.appTextSecondary),
          ),
          actions: [
            PrimaryButton(
              label: 'Done',
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
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
    final nextEx = (_currentExerciseIndex < _exercises.length - 1)
        ? _exercises[_currentExerciseIndex + 1]
        : null;

    final progressRatio = ((_currentExerciseIndex * 4 + _currentSetIndex) / (_exercises.length * 4)).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: context.appBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Top Session Bar & Progress Line
            Column(
              children: [
                ClipRRect(
                  child: LinearProgressIndicator(
                    value: progressRatio,
                    minHeight: 4,
                    backgroundColor: context.appSurfaceElevated,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryContainer),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close_rounded, color: context.appTextPrimary),
                      ),
                      Column(
                        children: [
                          Text(widget.workoutName, style: AppTheme.headlineMd.copyWith(fontSize: 16, color: context.appTextPrimary)),
                          Text(_formatTime(_elapsedSeconds), style: AppTheme.labelCaps.copyWith(color: AppColors.primary, fontSize: 12)),
                        ],
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: Icon(Icons.settings_outlined, color: context.appTextPrimary),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Exercise Hero Illustration Card
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: Stack(
                        children: [
                          Container(
                            height: 180,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: context.appSurfaceElevated,
                              image: const DecorationImage(
                                image: NetworkImage(
                                  'https://lh3.googleusercontent.com/aida-public/AB6AXuAsYyazByPTsyiT_LiMHpDdLVOo9V4DmeJOzAU3ppu9MAN4CYOCd_FgBb2O8nreFRkbS1KN2mUAIBouHkLZ4smCX1ukxs9LLlRRlyPePSI75ZNPticqyxtk44buA5yV064lHszbkaeWgqbrs61CjIRRMgG4X85ppRUxR_o8mUPyS6KoR0_n0NSGnlvM9e9URSVvLUOTlSlJ3dy6hTLEXWHQzkPKMr5-DJW6YN2IcFFVlNRmiCzKvU6k5A',
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
                                  Colors.black.withValues(alpha: 0.8),
                                  Colors.transparent,
                                ],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 16,
                            left: 16,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'CURRENT EXERCISE',
                                  style: AppTheme.labelCaps.copyWith(color: AppColors.secondaryContainer, fontSize: 10),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  currentEx['name'],
                                  style: AppTheme.headlineLg.copyWith(fontSize: 22, color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Sets & Reps Counter + Weight Load Cards
                    Row(
                      children: [
                        Expanded(
                          child: AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.repeat_rounded, color: AppColors.primary, size: 18),
                                    const SizedBox(width: 6),
                                    Text(
                                      'SET ${_currentSetIndex + 1} OF ${sets.length}',
                                      style: AppTheme.labelCaps.copyWith(fontSize: 10, color: context.appTextSecondary),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text('${currentSet['reps']}', style: AppTheme.displayMetrics.copyWith(fontSize: 36, color: context.appPrimary)),
                                    const SizedBox(width: 4),
                                    Text('Reps', style: AppTheme.bodySm.copyWith(color: context.appTextSecondary)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.fitness_center_rounded, color: AppColors.primary, size: 18),
                                    const SizedBox(width: 6),
                                    Text('LOAD', style: AppTheme.labelCaps.copyWith(fontSize: 10, color: context.appTextSecondary)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text('${currentSet['weight'].toStringAsFixed(0)}', style: AppTheme.displayMetrics.copyWith(fontSize: 36, color: context.appTextPrimary)),
                                    const SizedBox(width: 4),
                                    Text('kg', style: AppTheme.bodySm.copyWith(color: context.appTextSecondary)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Rest Timer Circular Widget
                    AppCard(
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                      child: Column(
                        children: [
                          ProgressRing.single(
                            size: 160,
                            progress: _isResting ? (_restSecondsRemaining / 60.0).clamp(0.0, 1.0) : 1.0,
                            color: _isResting ? AppColors.primaryContainer : context.appSurfaceElevated,
                            strokeWidth: 8,
                            centerChild: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('REST TIMER', style: AppTheme.labelCaps.copyWith(fontSize: 10, color: context.appTextSecondary)),
                                const SizedBox(height: 4),
                                Text(
                                  _isResting ? _formatTime(_restSecondsRemaining) : '00:00',
                                  style: AppTheme.displayMetrics.copyWith(fontSize: 32, color: context.appTextPrimary),
                                ),
                                if (_isResting)
                                  TextButton.icon(
                                    onPressed: () => _addRestTime(30),
                                    icon: const Icon(Icons.add_rounded, size: 16, color: AppColors.primary),
                                    label: Text('+30s', style: AppTheme.bodySm.copyWith(fontWeight: FontWeight.w700, color: AppColors.primary)),
                                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Next Up Preview Row
                    if (nextEx != null)
                      AppCard(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: context.appSurfaceElevated,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.fitness_center_outlined, color: context.appTextSecondary),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('NEXT UP', style: AppTheme.labelCaps.copyWith(fontSize: 10, color: context.appTextSecondary)),
                                  Text(nextEx['name'], style: AppTheme.headlineMd.copyWith(fontSize: 15, color: context.appTextPrimary)),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded, color: context.appTextSecondary),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Fixed Bottom Complete Set Bar
            Padding(
              padding: const EdgeInsets.all(20),
              child: PrimaryButton(
                width: double.infinity,
                label: (_currentExerciseIndex == _exercises.length - 1 && _currentSetIndex == sets.length - 1)
                    ? 'Finish Workout'
                    : 'Complete Set ${_currentSetIndex + 1}',
                onPressed: _completeSet,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
