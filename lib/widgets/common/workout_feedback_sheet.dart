import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/workout_feedback.dart';
import 'app_button.dart';

/// Modal bottom sheet widget collecting subjective user feedback ("Too Easy", "Perfect", "Too Hard") post-workout.
class WorkoutFeedbackSheet extends StatefulWidget {
  final String workoutId;
  final double volumeAchieved;
  final double targetVolume;
  final Function(WorkoutFeedback feedback) onSubmit;

  const WorkoutFeedbackSheet({
    super.key,
    required this.workoutId,
    this.volumeAchieved = 0.0,
    this.targetVolume = 0.0,
    required this.onSubmit,
  });

  /// Static helper to display the sheet in modal bottom sheet overlay.
  static Future<void> show(
    BuildContext context, {
    required String workoutId,
    double volumeAchieved = 0.0,
    double targetVolume = 0.0,
    required Function(WorkoutFeedback feedback) onSubmit,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => WorkoutFeedbackSheet(
        workoutId: workoutId,
        volumeAchieved: volumeAchieved,
        targetVolume: targetVolume,
        onSubmit: onSubmit,
      ),
    );
  }

  @override
  State<WorkoutFeedbackSheet> createState() => _WorkoutFeedbackSheetState();
}

class _WorkoutFeedbackSheetState extends State<WorkoutFeedbackSheet> {
  String _selectedRating = 'perfect'; // 'too_easy', 'perfect', 'too_hard'
  final TextEditingController _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'How was this workout?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your feedback trains the Adaptive Planner to calibrate optimal volume and intensity for future workouts.',
            style: TextStyle(
              fontSize: 12,
              color: context.appTextSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildRatingChip(
                  ratingKey: 'too_easy',
                  label: 'Too Easy',
                  icon: Icons.sentiment_satisfied_alt_rounded,
                  activeColor: Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildRatingChip(
                  ratingKey: 'perfect',
                  label: 'Perfect',
                  icon: Icons.thumb_up_alt_rounded,
                  activeColor: AppColors.primaryContainer,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildRatingChip(
                  ratingKey: 'too_hard',
                  label: 'Too Hard',
                  icon: Icons.local_fire_department_rounded,
                  activeColor: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _notesController,
            maxLines: 2,
            style: TextStyle(fontSize: 13, color: context.appTextPrimary),
            decoration: InputDecoration(
              hintText: 'Add optional notes for your AI Coach (e.g. felt light on bench)...',
              hintStyle: TextStyle(fontSize: 12, color: context.appTextSecondary),
              filled: true,
              fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: AppButton.primary(
              label: 'SUBMIT FEEDBACK',
              icon: Icons.check_circle_rounded,
              onPressed: () {
                final feedback = WorkoutFeedback(
                  id: 'fb_${DateTime.now().millisecondsSinceEpoch}',
                  workoutId: widget.workoutId,
                  difficultyRating: _selectedRating,
                  completionQuality: 1.0,
                  volumeAchieved: widget.volumeAchieved,
                  targetVolume: widget.targetVolume,
                  notes: _notesController.text.trim(),
                  createdAt: DateTime.now(),
                );
                widget.onSubmit(feedback);
                Navigator.of(context).pop();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingChip({
    required String ratingKey,
    required String label,
    required IconData icon,
    required Color activeColor,
  }) {
    final isSelected = _selectedRating == ratingKey;
    final isDark = context.isDarkMode;

    return InkWell(
      onTap: () => setState(() => _selectedRating = ratingKey),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.15)
              : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? activeColor : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? activeColor : context.appTextSecondary,
              size: 24,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                color: isSelected ? activeColor : context.appTextPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
