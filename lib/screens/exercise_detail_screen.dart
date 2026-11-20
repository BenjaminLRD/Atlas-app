import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/exercise.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/app_button.dart';
import '../services/exercise/muscle_map.dart';
import '../widgets/exercise/exercise_video_player.dart';
import '../widgets/exercise/muscle_map_card.dart';
import '../ai_form_coach/screens/ai_form_coach_screen.dart';
import '../ai_form_coach/services/form_analysis_service.dart';
import 'workout_session_screen.dart';

/// Central Exercise Guidance & Form Video detail screen.
/// Displays comprehensive multimedia instructions, target muscles, equipment,
/// common mistakes, and elite coaching cues.
class ExerciseDetailScreen extends StatefulWidget {
  final Exercise exercise;
  final bool enableWorkoutStart;

  const ExerciseDetailScreen({
    super.key,
    required this.exercise,
    this.enableWorkoutStart = true,
  });

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen> {
  bool _isFavorite = false;

  void _toggleFavorite() {
    setState(() {
      _isFavorite = !_isFavorite;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isFavorite
              ? '${widget.exercise.name} added to favorites!'
              : '${widget.exercise.name} removed from favorites.',
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _shareExercise() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sharing form guide for ${widget.exercise.name}...'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _startWorkoutWithExercise() {
    final sessionExercise = {
      'id': widget.exercise.id,
      'name': widget.exercise.name,
      'primaryTarget': widget.exercise.muscleGroup,
      'imagePath': widget.exercise.imageUrl ?? widget.exercise.animationAsset,
      'imageUrl': widget.exercise.imageUrl,
      'tips': widget.exercise.tips.isNotEmpty
          ? widget.exercise.tips
          : [
              'Control the eccentric lowering phase for 2-3 seconds.',
              'Maintain full tension throughout the range of motion.',
            ],
      'sets': [
        {'reps': 10, 'weight': 60.0, 'completed': false},
        {'reps': 10, 'weight': 60.0, 'completed': false},
        {'reps': 10, 'weight': 60.0, 'completed': false},
      ],
    };

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkoutSessionScreen(
          workoutName: '${widget.exercise.name} Focus Session',
          initialExercises: [sessionExercise],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final ex = widget.exercise;

    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: context.appTextPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'Exercise Form Guide',
            style: AppTheme.headlineMd.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: context.appTextPrimary,
            ),
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(
              _isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: _isFavorite ? Colors.redAccent : context.appTextSecondary,
              size: 22,
            ),
            onPressed: _toggleFavorite,
          ),
          IconButton(
            icon: Icon(
              Icons.share_outlined,
              color: context.appTextSecondary,
              size: 22,
            ),
            onPressed: _shareExercise,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Hero Video / Animation Demonstration
                    Hero(
                      tag: 'exercise_media_${ex.id}',
                      child: ExerciseVideoPlayer(
                        exercise: ex,
                        aspectRatio: 16 / 9,
                        autoPlay: false,
                        showControls: true,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // 2. Exercise Title & Difficulty Header
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            ex.name,
                            style: AppTheme.headlineLg.copyWith(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: context.appTextPrimary,
                              height: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _buildDifficultyBadge(context, ex.difficulty),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // 3. Target Muscles & Equipment Chips
                    _buildTagsSection(context, ex),
                    const SizedBox(height: 14),
                    MuscleMapCard(
                      title: 'MUSCLES WORKED',
                      activation: MuscleMap.forExercise(ex),
                    ),
                    const SizedBox(height: 20),

                    // 4. How To Perform (Numbered Step-by-Step)
                    _buildHowToPerformSection(context, ex),
                    const SizedBox(height: 16),

                    // 5. Common Mistakes
                    if (ex.commonMistakes.isNotEmpty) ...[
                      _buildCommonMistakesSection(context, ex),
                      const SizedBox(height: 16),
                    ],

                    // 6. Practice Mode: AI Form Coach (only where it has form rules)
                    if (SupportedMvpExercises.isSupported(ex.name)) ...[
                      _buildPracticeModeSection(context, ex),
                      const SizedBox(height: 16),
                    ],

                    // 7. Coach Tips
                    if (ex.tips.isNotEmpty) ...[
                      _buildCoachTipsSection(context, ex),
                      const SizedBox(height: 16),
                    ],

                    // 8. Alternatives Section
                    if (ex.alternatives.isNotEmpty) ...[
                      _buildAlternativesSection(context, ex),
                      const SizedBox(height: 16),
                    ],

                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),

            // Sticky Bottom CTA Bar
            if (widget.enableWorkoutStart)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161F2E) : Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: isDark
                          ? AppColors.primaryContainer.withValues(alpha: 0.2)
                          : AppColors.secondary.withValues(alpha: 0.8),
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.4 : 0.06,
                      ),
                      blurRadius: 12,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: AppButton.primary(
                  label: 'Start Exercise In Workout',
                  icon: Icons.play_arrow_rounded,
                  onPressed: _startWorkoutWithExercise,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultyBadge(BuildContext context, String difficulty) {
    Color badgeColor;
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        badgeColor = const Color(0xFF10B981);
        break;
      case 'intermediate':
        badgeColor = const Color(0xFFF59E0B);
        break;
      case 'advanced':
        badgeColor = const Color(0xFFEF4444);
        break;
      default:
        badgeColor = AppColors.primary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
      ),
      child: Text(
        difficulty.toUpperCase(),
        style: AppTheme.labelCaps.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: badgeColor,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _buildTagsSection(BuildContext context, Exercise ex) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TARGET MUSCLES & EQUIPMENT',
          style: AppTheme.labelCaps.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: context.appTextSecondary,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildTagChip(
              context,
              icon: Icons.fitness_center_rounded,
              label: ex.muscleGroup,
              isHighlight: true,
            ),
            _buildTagChip(
              context,
              icon: Icons.construction_rounded,
              label: ex.equipment,
              isHighlight: false,
            ),
            if (ex.durationSeconds != null)
              _buildTagChip(
                context,
                icon: Icons.timer_outlined,
                label: '${ex.durationSeconds}s tempo',
                isHighlight: false,
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildTagChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isHighlight,
  }) {
    final isDark = context.isDarkMode;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      constraints: const BoxConstraints(maxWidth: 260),
      decoration: BoxDecoration(
        color: isHighlight
            ? AppColors.primaryContainer.withValues(alpha: isDark ? 0.2 : 0.1)
            : context.appSurfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isHighlight
              ? AppColors.primaryContainer.withValues(alpha: 0.4)
              : context.appOutlineVariant,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: isHighlight
                ? (isDark ? AppColors.primaryContainer : AppColors.primary)
                : context.appTextSecondary,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.bodySm.copyWith(
                fontSize: 12,
                fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w500,
                color: isHighlight
                    ? (isDark ? AppColors.primaryContainer : AppColors.primary)
                    : context.appTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHowToPerformSection(BuildContext context, Exercise ex) {
    final instructions = ex.instructions.isNotEmpty
        ? ex.instructions
        : [
            'Set up in proper athletic stance with a braced core.',
            'Initiate the movement under control through the active range of motion.',
            'Squeeze the target muscle at peak contraction.',
            'Lower smoothly during the eccentric phase.',
          ];

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.format_list_numbered_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'How To Perform',
                  style: AppTheme.headlineMd.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: context.appTextPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (int i = 0; i < instructions.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${i + 1}',
                      style: AppTheme.labelCaps.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    instructions[i],
                    style: AppTheme.bodySm.copyWith(
                      fontSize: 13,
                      height: 1.4,
                      color: context.appTextPrimary,
                    ),
                  ),
                ),
              ],
            ),
            if (i < instructions.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildCommonMistakesSection(BuildContext context, Exercise ex) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      borderColor: const Color(0xFFEF4444).withValues(alpha: 0.25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: Color(0xFFEF4444),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Common Mistakes To Avoid',
                  style: AppTheme.headlineMd.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFEF4444),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final mistake in ex.commonMistakes) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      mistake,
                      style: AppTheme.bodySm.copyWith(
                        fontSize: 13,
                        height: 1.35,
                        color: context.appTextPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPracticeModeSection(BuildContext context, Exercise ex) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      borderColor: AppColors.primary.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Form Practice Mode',
                      style: AppTheme.headlineMd.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: context.appTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Real-time pose tracking, joint angles & rep counts.',
                      style: AppTheme.bodySm.copyWith(
                        fontSize: 12,
                        color: context.appTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AIFormCoachScreen(initialExercise: ex.name),
                  ),
                );
              },
              icon: const Icon(Icons.videocam_rounded, size: 16),
              label: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('Start AI Form Check'),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoachTipsSection(BuildContext context, Exercise ex) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      borderColor: AppColors.primaryContainer.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'AI Coach Form Cues',
                  style: AppTheme.headlineMd.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: context.isDarkMode
                        ? AppColors.primaryContainer
                        : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final tip in ex.tips) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.check_circle_outline_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tip,
                      style: AppTheme.bodySm.copyWith(
                        fontSize: 13,
                        height: 1.35,
                        color: context.appTextPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAlternativesSection(BuildContext context, Exercise ex) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.swap_horiz_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Available Substitutions',
                  style: AppTheme.headlineMd.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: context.appTextPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ex.alternatives.map((altId) {
              final altEx =
                  Exercise.getById(altId) ?? Exercise.findByName(altId);
              final displayName =
                  altEx?.name ??
                  altId
                      .split('_')
                      .map(
                        (w) => w.isNotEmpty
                            ? '${w[0].toUpperCase()}${w.substring(1)}'
                            : '',
                      )
                      .join(' ');
              return InkWell(
                onTap: altEx != null
                    ? () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ExerciseDetailScreen(
                              exercise: altEx,
                              enableWorkoutStart: widget.enableWorkoutStart,
                            ),
                          ),
                        );
                      }
                    : null,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: context.appSurfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.appOutlineVariant),
                  ),
                  child: Text(
                    '→ $displayName',
                    style: AppTheme.bodySm.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.appTextSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
