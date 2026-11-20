import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_theme.dart';
import '../providers/fitness_provider.dart';
import '../models/activity_record.dart';
import '../data/profile_provider.dart';
import '../models/exercise.dart';
import '../services/cardio/cardio_tracker.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/app_header.dart';

/// Interactive Live Cardio Workout Tracker with real-time MET calorie calculations.
class CardioSessionScreen extends StatefulWidget {
  final Exercise exercise;

  /// Body weight for the calorie estimate. When null the profile weight is
  /// used, and with no weight there is no calorie figure.
  final double? userWeightKg;

  const CardioSessionScreen({
    super.key,
    required this.exercise,
    this.userWeightKg,
  });

  @override
  State<CardioSessionScreen> createState() => _CardioSessionScreenState();
}

class _CardioSessionScreenState extends State<CardioSessionScreen>
    with SingleTickerProviderStateMixin {
  late Timer _timer;
  int _secondsElapsed = 0;
  bool _isActive = true;
  late DateTime _startTime;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isActive) {
        // Distance is never guessed here: without GPS this timer only
        // measures time. Outdoor runs and rides use the GPS tracker.
        setState(() => _secondsElapsed++);
      }
    });
  }

  bool get _isDistanceSport {
    final cat = widget.exercise.cardioCategory?.toLowerCase() ?? '';
    return cat.contains('run') || cat.contains('cycl') || cat.contains('row');
  }

  @override
  void dispose() {
    _timer.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _togglePause() {
    HapticFeedback.lightImpact();
    setState(() {
      _isActive = !_isActive;
    });
  }

  double? get _weightKg =>
      widget.userWeightKg ?? parseProfileWeightKg(ProfileProvider().weight);

  /// An estimate from the exercise's MET value and body weight, or null when
  /// no body weight is known.
  double? get _caloriesOrNull {
    final w = _weightKg;
    if (w == null) return null;
    final met = widget.exercise.metValue ?? 8.0;
    final minutes = _secondsElapsed / 60.0;
    // Standard MET Caloric Expenditure Formula: (MET * 3.5 * weightKg / 200) * minutes
    final kcal = (met * 3.5 * w / 200.0) * minutes;
    return double.parse(kcal.toStringAsFixed(1));
  }

  double get _currentCalories => _caloriesOrNull ?? 0;

  String get _formattedTime {
    final minutes = _secondsElapsed ~/ 60;
    final seconds = _secondsElapsed % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  bool _isFinishing = false;

  /// Fixed on the first try, so finishing again after a failure refers to the
  /// same session instead of creating a second one.
  String? _sessionId;

  Future<void> _finishSession() async {
    if (_isFinishing) return;
    _isFinishing = true;
    HapticFeedback.mediumImpact();
    setState(() => _isActive = false);
    try {
      await _saveFinishedSession();
    } catch (_) {
      // Let the athlete try again; nothing is repeated if it was saved.
      _isFinishing = false;
      if (mounted) {
        setState(() => _isActive = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not save your session. Please tap Finish Session again.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _saveFinishedSession() async {
    final session = CardioSession(
      id: _sessionId ??= 'cardio_${DateTime.now().millisecondsSinceEpoch}',
      exerciseId: widget.exercise.id,
      exerciseName: widget.exercise.name,
      category: widget.exercise.cardioCategory ?? 'General Cardio',
      durationSeconds: _secondsElapsed,
      distanceKm: 0,
      caloriesBurned: _currentCalories,
      caloriesKnown: _caloriesOrNull != null,
      startTime: _startTime,
      endTime: DateTime.now(),
      metValue: widget.exercise.metValue ?? 8.0,
      isCompleted: true,
    );

    // Log Activity Record
    final activityRecord = ActivityRecord(
      id: 'act_${session.id}',
      date: DateTime.now(),
      activeMinutes: (_secondsElapsed / 60).round(),
      caloriesBurned: _currentCalories,
      distanceKm: 0,
      type: ActivityType.cardio,
      title: widget.exercise.name,
    );

    // Save the session and activity and award the XP in one place; showcase
    // mode keeps all of it in memory.
    await FitnessProvider.instance.recordCardioCompletion(
      session,
      activityRecord,
    );

    if (!mounted) return;

    // 4. Show Completion Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: context.appSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Text('🎉', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Cardio Completed!',
                  style: AppTheme.headlineMd.copyWith(
                    color: context.appTextPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Great job finishing your ${widget.exercise.name} session!',
                style: AppTheme.bodySm.copyWith(
                  color: context.appTextSecondary,
                ),
              ),
              const SizedBox(height: 16),
              AppCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryMetric(
                      'DURATION',
                      _formattedTime,
                      AppColors.primary,
                    ),
                    _buildSummaryMetric(
                      'CALORIES',
                      _caloriesOrNull == null
                          ? '– kcal'
                          : '${_currentCalories.toStringAsFixed(0)} kcal',
                      const Color(0xFFF59E0B),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop(); // dismiss dialog
                Navigator.of(context).pop(true); // exit session screen
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'View Activity Hub',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryMetric(String title, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: AppTheme.headlineMd.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: AppTheme.labelCaps.copyWith(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: context.appTextSecondary,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppHeader.back(
          title: widget.exercise.name.toUpperCase(),
          subtitle: widget.exercise.cardioCategory ?? 'Cardio Workout',
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: _isActive
                  ? const Color(0xFF10B981).withValues(alpha: 0.2)
                  : const Color(0xFFF59E0B).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _isActive
                    ? const Color(0xFF10B981)
                    : const Color(0xFFF59E0B),
                width: 1,
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isActive ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    size: 13,
                    color: _isActive
                        ? const Color(0xFF10B981)
                        : const Color(0xFFF59E0B),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    _isActive ? 'ACTIVE' : 'PAUSED',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: _isActive
                          ? const Color(0xFF10B981)
                          : const Color(0xFFF59E0B),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              // 1. Live Stopwatch Timer Hero Card
              AppCard(
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 16,
                ),
                child: Column(
                  children: [
                    Text(
                      'SESSION DURATION',
                      style: AppTheme.labelCaps.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: context.appTextSecondary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _formattedTime,
                        style: AppTheme.displayMetrics.copyWith(
                          fontSize: 52,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'MET Intensity: ${widget.exercise.metValue?.toStringAsFixed(1) ?? '8.0'}',
                      style: AppTheme.bodySm.copyWith(
                        fontSize: 12,
                        color: context.appTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 2. Metrics Grid: Distance & Calories
              Row(
                children: [
                  Expanded(
                    child: AppCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 14,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.local_fire_department_rounded,
                                color: Color(0xFFF59E0B),
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'CALORIES',
                                  style: AppTheme.labelCaps.copyWith(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: context.appTextSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _caloriesOrNull == null
                                  ? '–'
                                  : _currentCalories.toStringAsFixed(0),
                              style: AppTheme.headlineLg.copyWith(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: context.appTextPrimary,
                              ),
                            ),
                          ),
                          Text(
                            _caloriesOrNull == null
                                ? 'add weight in profile'
                                : 'kcal (estimate)',
                            style: AppTheme.bodySm.copyWith(
                              fontSize: 11,
                              color: context.appTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 14,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.straighten_rounded,
                                color: Color(0xFF10B981),
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'DISTANCE',
                                  style: AppTheme.labelCaps.copyWith(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: context.appTextSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '–',
                              style: AppTheme.headlineLg.copyWith(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: context.appTextPrimary,
                              ),
                            ),
                          ),
                          Text(
                            _isDistanceSport
                                ? 'not tracked (use Outdoor for GPS)'
                                : 'kilometers',
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
              const SizedBox(height: 14),

              // 3. Heart Rate Zone Card
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: 1.0 + (_pulseController.value * 0.18),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFFEF4444,
                              ).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.favorite_rounded,
                              color: Color(0xFFEF4444),
                              size: 22,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Target Heart Rate Zone',
                            style: AppTheme.headlineMd.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: context.appTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Aerobic Conditioning • Sensor Sync Coming Soon',
                            style: AppTheme.bodySm.copyWith(
                              fontSize: 11,
                              color: context.appTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // 4. Session Controls (Pause/Resume & Finish)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _togglePause,
                      icon: Icon(
                        _isActive
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                      label: Text(_isActive ? 'Pause' : 'Resume'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: context.appOutlineVariant),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _secondsElapsed > 2 && !_isFinishing
                          ? _finishSession
                          : null,
                      icon: const Icon(Icons.check_circle_rounded),
                      label: const Text('Finish Session'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
