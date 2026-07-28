import 'dart:async';
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../data/local_storage.dart';
import '../models/workout_history.dart';

class Exercise {
  final String name;
  final int sets;
  final int reps;
  final String description;

  const Exercise({
    required this.name,
    required this.sets,
    required this.reps,
    required this.description,
  });
}

class WorkoutSessionScreen extends StatefulWidget {
  final String workoutName;

  const WorkoutSessionScreen({
    super.key,
    this.workoutName = 'Workout Session',
  });

  @override
  State<WorkoutSessionScreen> createState() => _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends State<WorkoutSessionScreen> {
  final List<Exercise> _exercises = const [
    Exercise(
      name: 'Goblet Squats',
      sets: 4,
      reps: 10,
      description: 'Keep your trunk vertical, grip the kettlebell by the horns, and descend to parallel.',
    ),
    Exercise(
      name: 'Romanian Deadlifts',
      sets: 4,
      reps: 12,
      description: 'Hinge at your hips, keep the weight close to your shins, and engage your hamstrings.',
    ),
    Exercise(
      name: 'Leg Press',
      sets: 3,
      reps: 15,
      description: 'Position your feet shoulder-width apart, lower the sled smoothly, and press up without locking knees.',
    ),
    Exercise(
      name: 'Leg Extensions',
      sets: 3,
      reps: 15,
      description: 'Squeeze your quadriceps at the top of the range of motion and lower the weight under control.',
    ),
  ];

  int _currentIndex = 0;
  late List<List<bool>> _completedSets;
  int _seconds = 0;
  bool _isPaused = false;
  Timer? _timer;

  // Rest Timer State
  int _restSecondsRemaining = 0;
  Timer? _restTimer;
  bool _isResting = false;

  @override
  void initState() {
    super.initState();
    _loadOrCreateSession();
    _startTimer();
  }

  void _loadOrCreateSession() {
    final saved = LocalStorage.getActiveSession();
    if (saved != null) {
      _currentIndex = saved['currentIndex'] ?? 0;
      _seconds = saved['seconds'] ?? 0;
      _isPaused = saved['isPaused'] ?? false;
      final rawSets = saved['completedSets'] as List?;
      if (rawSets != null) {
        _completedSets = rawSets.map((e) => List<bool>.from(e as List)).toList();
      } else {
        _initEmptySets();
      }
    } else {
      _initEmptySets();
    }
  }

  void _initEmptySets() {
    _completedSets = List.generate(
      _exercises.length,
      (index) => List.filled(_exercises[index].sets, false),
    );
  }

  void _saveSession() {
    LocalStorage.saveActiveSession({
      'currentIndex': _currentIndex,
      'seconds': _seconds,
      'isPaused': _isPaused,
      'completedSets': _completedSets.map((e) => e).toList(),
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused && mounted) {
        setState(() {
          _seconds++;
        });
        // Save once every 5 seconds to reduce storage writes
        if (_seconds % 5 == 0) {
          _saveSession();
        }
      }
    });
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
    });
    _saveSession();
  }

  void _startRestTimer() {
    _restTimer?.cancel();
    setState(() {
      _restSecondsRemaining = 60; // 60 seconds rest duration
      _isResting = true;
    });
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        if (_restSecondsRemaining > 0) {
          setState(() {
            _restSecondsRemaining--;
          });
        } else {
          _stopRestTimer();
        }
      }
    });
  }

  void _stopRestTimer() {
    _restTimer?.cancel();
    setState(() {
      _isResting = false;
      _restSecondsRemaining = 0;
    });
  }

  void _nextExercise() {
    if (_currentIndex < _exercises.length - 1) {
      setState(() {
        _currentIndex++;
        _stopRestTimer();
      });
      _saveSession();
    }
  }

  void _prevExercise() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _stopRestTimer();
      });
      _saveSession();
    }
  }

  Future<void> _finishWorkout() async {
    _timer?.cancel();
    _restTimer?.cancel();

    await LocalStorage.saveWorkoutCompletion(
      WorkoutHistory(
        workoutName: widget.workoutName,
        dateCompleted: DateTime.now(),
        durationSeconds: _seconds,
        exercisesCompleted: _countExercisesCompleted(),
        completionPercentage: _getCompletionPercentage(),
      ),
    );
    await LocalStorage.clearActiveSession();

    if (!mounted) return;

    // Show completion alert
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: AppColors.background,
          title: Text(
            'Workout Complete!',
            style: AppTheme.headlineMd,
          ),
          content: Text(
            'Great job of staying disciplined today. Your volume metrics have been updated.',
            style: AppTheme.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // pop alert
                Navigator.of(context).pop(); // exit workout screen
              },
              child: Text(
                'Return Home',
                style: AppTheme.bodyMd.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  double _getCompletionPercentage() {
    int total = 0;
    int completed = 0;
    for (var list in _completedSets) {
      total += list.length;
      completed += list.where((element) => element).length;
    }
    if (total == 0) return 0.0;
    return completed / total;
  }

  int _countExercisesCompleted() {
    int count = 0;
    for (int i = 0; i < _exercises.length; i++) {
      if (_completedSets[i].every((done) => done)) {
        count++;
      }
    }
    return count;
  }

  String _formatDuration(int totalSeconds) {
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    final int seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _restTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = _exercises[_currentIndex];
    final progress = _getCompletionPercentage();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
          onPressed: () {
            _saveSession();
            Navigator.pop(context);
          },
        ),
        title: Text(
          'Workout Session',
          style: AppTheme.headlineMd.copyWith(fontSize: 18),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                _formatDuration(_seconds),
                style: AppTheme.dataDisplay.copyWith(
                  fontSize: 16,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Workout progress bar
          LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.surfaceContainer,
            color: AppColors.primary,
            minHeight: 6,
          ),
          const SizedBox(height: 16),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Rest Timer Panel if resting
                  if (_isResting) _buildRestTimerPanel(),

                  // Exercise image/animation placeholder
                  _buildMediaPlaceholder(current.name),
                  const SizedBox(height: 24),

                  // Exercise info
                  Text(
                    'EXERCISE ${_currentIndex + 1} OF ${_exercises.length}',
                    style: AppTheme.labelCaps.copyWith(color: AppColors.tertiary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    current.name,
                    style: AppTheme.headlineLgMobile,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    current.description,
                    style: AppTheme.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),

                  // Set Checklist Header
                  Text(
                    'SETS & REPS (${current.sets}SETS x ${current.reps}REPS)',
                    style: AppTheme.labelCaps.copyWith(color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),

                  // Sets Checklist
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: current.sets,
                    itemBuilder: (context, setIdx) {
                      final isDone = _completedSets[_currentIndex][setIdx];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isDone
                              ? AppColors.primaryFixed.withValues(alpha: 0.15)
                              : AppColors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDone ? AppColors.primary : AppColors.outlineVariant,
                          ),
                        ),
                        child: CheckboxListTile(
                          activeColor: AppColors.primary,
                          title: Text(
                            'Set ${setIdx + 1}',
                            style: AppTheme.bodyMd.copyWith(
                              fontWeight: FontWeight.w600,
                              decoration: isDone ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          subtitle: Text(
                            '${current.reps} reps • Target RPE 8',
                            style: AppTheme.bodySm.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                          value: isDone,
                          onChanged: (val) {
                            setState(() {
                              _completedSets[_currentIndex][setIdx] = val ?? false;
                            });
                            _saveSession();
                            if (val == true) {
                              _startRestTimer();
                            }
                          },
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
          // Action Buttons panel
          _buildActionButtonPanel(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildRestTimerPanel() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.tertiaryFixed,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.timer, color: AppColors.onTertiaryFixed),
              const SizedBox(width: 8),
              Text(
                'RESTING: ${_restSecondsRemaining}s',
                style: AppTheme.labelCaps.copyWith(
                  color: AppColors.onTertiaryFixed,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          TextButton(
            onPressed: _stopRestTimer,
            child: Text(
              'SKIP REST',
              style: AppTheme.labelCaps.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaPlaceholder(String name) {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.fitness_center_sharp,
              size: 48,
              color: AppColors.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'Instructional Animation Placeholder',
              style: AppTheme.bodySm.copyWith(color: AppColors.onSurfaceVariant),
            ),
            Text(
              '[$name Demo]',
              style: AppTheme.labelCaps.copyWith(color: AppColors.outline, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtonPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(
          top: BorderSide(color: AppColors.outlineVariant, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: _currentIndex > 0 ? _prevExercise : null,
                icon: const Icon(Icons.arrow_back_ios),
                color: AppColors.primary,
                disabledColor: AppColors.outlineVariant,
                tooltip: 'Previous Exercise',
              ),
              ElevatedButton.icon(
                onPressed: _togglePause,
                icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                label: Text(_isPaused ? 'Resume Workout' : 'Pause Workout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isPaused ? AppColors.secondary : AppColors.surfaceContainer,
                  foregroundColor: _isPaused ? AppColors.onSecondary : AppColors.onSurface,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              IconButton(
                onPressed: _currentIndex < _exercises.length - 1 ? _nextExercise : null,
                icon: const Icon(Icons.arrow_forward_ios),
                color: AppColors.primary,
                disabledColor: AppColors.outlineVariant,
                tooltip: 'Next Exercise',
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _finishWorkout,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Finish Workout'),
            ),
          ),
        ],
      ),
    );
  }
}
