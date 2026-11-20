import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/app_dependencies.dart';
import '../data/local_storage.dart';
import '../data/workout_service.dart';
import '../models/active_workout_session.dart';
import '../models/exercise.dart';
import '../models/workout_session.dart';
import 'progressive_overload_service.dart';
import 'rest_timer_service.dart';
import 'workout_generator_engine.dart';

/// Central Domain Service encapsulating the complete workout execution state machine,
/// set-by-set progression, volume calculations, and timer orchestrations.
///
/// Ensures strict Clean Architecture separation: UI widgets and screens contain zero
/// business logic and delegate all execution commands to this service.
class WorkoutExecutionService {
  static WorkoutExecutionService? _instance;

  WorkoutExecutionService({
    WorkoutService? workoutService,
    ProgressiveOverloadService? overloadService,
    RestTimerService? restTimerService,
  }) : _workoutService =
           workoutService ?? AppDependencies.instance.workoutService,
       _overloadService =
           overloadService ?? ProgressiveOverloadService.instance,
       _restTimerService = restTimerService ?? RestTimerService.instance;

  static WorkoutExecutionService get instance {
    _instance ??= WorkoutExecutionService();
    return _instance!;
  }

  /// Reset singleton for unit tests
  static void resetInstance() {
    _instance?.dispose();
    _instance = null;
  }

  final WorkoutService _workoutService;
  final ProgressiveOverloadService _overloadService;
  final RestTimerService _restTimerService;

  WorkoutSessionState _state = WorkoutSessionState.notStarted;
  String _workoutId = 'workout_session_01';
  String _workoutName = 'Workout Session';
  DateTime _startTime = DateTime.now();
  int _elapsedSeconds = 0;
  Timer? _ticker;

  int _currentExerciseIndex = 0;
  int _currentSetIndex = 0;
  bool _isSetActive = false;

  List<Map<String, dynamic>> _exercises = [];

  // Reactive State Notifiers for UI presentation
  final ValueNotifier<WorkoutSessionState> stateNotifier =
      ValueNotifier<WorkoutSessionState>(WorkoutSessionState.notStarted);
  final ValueNotifier<int> elapsedNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> currentExerciseIndexNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> currentSetIndexNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> isSetActiveNotifier = ValueNotifier<bool>(false);

  // Getters
  WorkoutSessionState get state => _state;
  String get workoutId => _workoutId;
  String get workoutName => _workoutName;
  DateTime get startTime => _startTime;
  int get elapsedSeconds => _elapsedSeconds;
  int get currentExerciseIndex => _currentExerciseIndex;
  int get currentSetIndex => _currentSetIndex;
  bool get isSetActive => _isSetActive;
  List<Map<String, dynamic>> get exercises => List.unmodifiable(_exercises);

  bool get isActive => _state == WorkoutSessionState.active;
  bool get isPaused => _state == WorkoutSessionState.paused;
  bool get isCompleted => _state == WorkoutSessionState.completed;
  bool get isAbandoned => _state == WorkoutSessionState.abandoned;

  /// Initializes or restores an active workout session.
  void initializeSession({
    required String workoutName,
    String? workoutId,
    List<Map<String, dynamic>>? initialExercises,
  }) {
    _workoutName = workoutName;
    _workoutId =
        workoutId ??
        'workout_${workoutName.toLowerCase().replaceAll(' ', '_')}';
    _elapsedSeconds = 0;
    _currentExerciseIndex = 0;
    _currentSetIndex = 0;
    _isSetActive = false;
    _state = WorkoutSessionState.notStarted;

    final saved = _workoutService.getActiveSession();
    final bool matchesIdentity =
        saved != null &&
        ((workoutId != null && saved.workoutId == workoutId) ||
            (saved.workoutName == workoutName));

    final List<Map<String, dynamic>> rawExercises;
    if (initialExercises != null && initialExercises.isNotEmpty) {
      rawExercises = initialExercises;
    } else {
      final isDefaultLegId =
          _workoutId == 'leg_day_hypertrophy_01' &&
          workoutName != 'Leg Day - Hypertrophy';
      rawExercises = WorkoutGeneratorEngine().generateExercisesForWorkout(
        workoutName: workoutName,
        focus: isDefaultLegId ? null : workoutId,
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
      _state = saved.isPaused
          ? WorkoutSessionState.paused
          : WorkoutSessionState.active;

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
            }
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

      if (_state == WorkoutSessionState.active) {
        _startTicker();
      }
    } else {
      _startTime = DateTime.now();
      _calibrateProgressiveOverload();
    }

    _updateNotifiers();
  }

  void _calibrateProgressiveOverload() {
    final pastSessions = _workoutService.getWorkoutSessions();

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
          (sets.isNotEmpty ? (sets.first['reps'] as num?)?.toInt() : 10) ?? 10;

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

      final suggestion = _overloadService.getSuggestedProgression(
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

  /// State Machine Transition: Start / Resume Workout
  void startWorkout() {
    if (_state == WorkoutSessionState.completed ||
        _state == WorkoutSessionState.abandoned) {
      return;
    }
    _state = WorkoutSessionState.active;
    _startTicker();
    _saveActiveSessionState();
    _updateNotifiers();
  }

  /// State Machine Transition: Pause Workout
  void pauseWorkout() {
    if (_state != WorkoutSessionState.active) return;
    _state = WorkoutSessionState.paused;
    _ticker?.cancel();
    _restTimerService.pause();
    _saveActiveSessionState();
    _updateNotifiers();
  }

  /// State Machine Transition: Toggle Pause / Resume
  void togglePause() {
    if (_state == WorkoutSessionState.active) {
      pauseWorkout();
    } else if (_state == WorkoutSessionState.paused ||
        _state == WorkoutSessionState.notStarted) {
      startWorkout();
    }
  }

  /// Start an active set
  void startSet() {
    _isSetActive = true;
    _restTimerService.skip();
    if (_state != WorkoutSessionState.active) {
      startWorkout();
    }
    _saveActiveSessionState();
    _updateNotifiers();
  }

  /// Complete currently active set and automatically trigger rest timer
  bool completeSet({double? weight, int? reps, double? rpe}) {
    if (_exercises.isEmpty) return false;
    final currentEx = _exercises[_currentExerciseIndex];
    final sets = currentEx['sets'] as List;
    if (_currentSetIndex >= sets.length) return false;

    final currentSet = sets[_currentSetIndex];
    if (weight != null) currentSet['weight'] = weight;
    if (reps != null) currentSet['reps'] = reps;
    if (rpe != null) currentSet['rpe'] = rpe;

    currentSet['completed'] = true;
    currentSet['completedAt'] = DateTime.now().toIso8601String();
    _isSetActive = false;

    final recommendedRest = _restTimerService.calculateRecommendedRestSeconds(
      currentEx['name'],
    );

    bool isWorkoutFinished = false;

    if (_currentSetIndex < sets.length - 1) {
      _currentSetIndex++;
      _restTimerService.startRest(
        durationSeconds: recommendedRest,
        exerciseName: currentEx['name'] as String?,
      );
    } else if (_currentExerciseIndex < _exercises.length - 1) {
      _currentExerciseIndex++;
      _currentSetIndex = 0;
      _restTimerService.startRest(
        durationSeconds: recommendedRest,
        exerciseName: _exercises[_currentExerciseIndex]['name'] as String?,
      );
    } else {
      isWorkoutFinished = true;
    }

    _saveActiveSessionState();
    _updateNotifiers();
    return isWorkoutFinished;
  }

  /// Adjust reps for the target set
  void adjustReps(int delta) {
    if (_exercises.isEmpty) return;
    final currentEx = _exercises[_currentExerciseIndex];
    final sets = currentEx['sets'] as List;
    final setBounded = _currentSetIndex.clamp(0, sets.length - 1);
    final currentSet = sets[setBounded];

    final currentReps = (currentSet['reps'] as num).toInt();
    currentSet['reps'] = (currentReps + delta).clamp(1, 100);
    _saveActiveSessionState();
    _updateNotifiers();
  }

  /// Adjust weight for the target set
  void adjustWeight(double delta) {
    if (_exercises.isEmpty) return;
    final currentEx = _exercises[_currentExerciseIndex];
    final sets = currentEx['sets'] as List;
    final setBounded = _currentSetIndex.clamp(0, sets.length - 1);
    final currentSet = sets[setBounded];

    final currentWeight = (currentSet['weight'] as num).toDouble();
    currentSet['weight'] = (currentWeight + delta).clamp(0.0, 500.0);
    _saveActiveSessionState();
    _updateNotifiers();
  }

  /// Add set to current exercise
  void addSetToCurrentExercise() {
    if (_exercises.isEmpty) return;
    final currentEx = _exercises[_currentExerciseIndex];
    final sets = currentEx['sets'] as List;
    final lastSet = sets.isNotEmpty
        ? sets.last
        : {'reps': 10, 'weight': 50.0, 'completed': false};

    sets.add({
      'reps': lastSet['reps'],
      'weight': lastSet['weight'],
      'completed': false,
    });
    _saveActiveSessionState();
    _updateNotifiers();
  }

  /// Remove last set from current exercise
  void removeSetFromCurrentExercise() {
    if (_exercises.isEmpty) return;
    final currentEx = _exercises[_currentExerciseIndex];
    final sets = currentEx['sets'] as List;
    if (sets.length <= 1) return;

    sets.removeLast();
    if (_currentSetIndex >= sets.length) {
      _currentSetIndex = sets.length - 1;
    }
    _saveActiveSessionState();
    _updateNotifiers();
  }

  /// Complete & finalize active workout session model
  WorkoutSession finalizeSession({String? notes}) {
    _ticker?.cancel();
    _restTimerService.skip();
    _state = WorkoutSessionState.completed;

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
            completedAt: s['completedAt'] != null
                ? DateTime.tryParse(s['completedAt'].toString())
                : null,
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

    final prResults = _overloadService.evaluatePersonalRecords(
      exercises: sessionExercises,
      workoutId: _workoutId,
    );
    final List<String> personalRecords = prResults
        .map((p) => p.displayText)
        .toList();

    final double caloriesBurned = _overloadService.calculateCaloriesBurned(
      durationSeconds: _elapsedSeconds.toDouble(),
      totalVolumeKg: totalVolumeKg,
      completedSets: totalCompletedSets,
    );

    final int xpEarned =
        ((100 * completionPercentage) +
                (totalCompletedSets * 15) +
                (totalVolumeKg / 100) +
                (personalRecords.length * 250))
            .toInt()
            .clamp(10, 10000);

    final workoutSession = WorkoutSession(
      id: 'session_${DateTime.now().millisecondsSinceEpoch}',
      workoutId: _workoutId,
      workoutName: _workoutName,
      startTime: _startTime,
      endTime: DateTime.now(),
      exercises: sessionExercises,
      completedExercises: completedExercisesCount,
      totalVolume: totalVolumeKg,
      caloriesBurned: caloriesBurned,
      duration: Duration(seconds: _elapsedSeconds),
      state: WorkoutSessionState.completed,
      notes: notes,
      personalRecords: personalRecords,
      xpEarned: xpEarned,
    );

    _updateNotifiers();
    return workoutSession;
  }

  /// State Machine Transition: Abandon Workout
  Future<void> abandonWorkout() async {
    _ticker?.cancel();
    _restTimerService.skip();
    _state = WorkoutSessionState.abandoned;
    await _workoutService.clearActiveSession();
    _updateNotifiers();
  }

  // Statistical Helpers
  int get completedExercisesCount {
    int count = 0;
    for (final ex in _exercises) {
      final sets = ex['sets'] as List;
      if (sets.any((s) => s['completed'] == true)) {
        count++;
      }
    }
    return count;
  }

  int get totalSetsCount {
    int total = 0;
    for (final ex in _exercises) {
      total += (ex['sets'] as List).length;
    }
    return total;
  }

  int get completedSetsCount {
    int completed = 0;
    for (final ex in _exercises) {
      final sets = ex['sets'] as List;
      completed += sets.where((s) => s['completed'] == true).length;
    }
    return completed;
  }

  double get completionPercentage {
    final total = totalSetsCount;
    if (total == 0) return 0.0;
    return (completedSetsCount / total) * 100.0;
  }

  double get totalVolume {
    double vol = 0.0;
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

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_state == WorkoutSessionState.active) {
        _elapsedSeconds++;
        elapsedNotifier.value = _elapsedSeconds;
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
        workoutName: _workoutName,
        workoutId: _workoutId,
        currentIndex: _currentExerciseIndex,
        currentSetIndex: _currentSetIndex,
        seconds: _elapsedSeconds,
        isPaused: _state == WorkoutSessionState.paused,
        completedSets: completedSets,
        exercisesData: _exercises,
        startTime: _startTime,
      ),
    );
  }

  void _updateNotifiers() {
    stateNotifier.value = _state;
    elapsedNotifier.value = _elapsedSeconds;
    currentExerciseIndexNotifier.value = _currentExerciseIndex;
    currentSetIndexNotifier.value = _currentSetIndex;
    isSetActiveNotifier.value = _isSetActive;
  }

  void dispose() {
    _ticker?.cancel();
    stateNotifier.dispose();
    elapsedNotifier.dispose();
    currentExerciseIndexNotifier.dispose();
    currentSetIndexNotifier.dispose();
    isSetActiveNotifier.dispose();
  }
}
