import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../../services/exercise/exercise_thumbnails.dart';

/// The illustration for one exercise, at a fixed size.
///
/// Shows the exercise's own thumbnail asset. If the exercise has none, or the
/// file cannot be read, it shows a plain icon tile with the exercise name's
/// first letters: never a photo or a picture belonging to another exercise.
class ExerciseThumbnail extends StatelessWidget {
  final String exerciseId;
  final String? exerciseName;
  final double size;
  final IconData fallbackIcon;
  final double? borderRadius;

  const ExerciseThumbnail({
    super.key,
    required this.exerciseId,
    this.exerciseName,
    this.size = 76,
    this.fallbackIcon = Icons.fitness_center_rounded,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius ?? AppRadii.lg);
    final asset = ExerciseThumbnails.assetFor(exerciseId);
    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: size,
        height: size,
        child: asset == null
            ? _fallback(context)
            : Semantics(
                image: true,
                label: exerciseName == null
                    ? 'Exercise illustration'
                    : '$exerciseName illustration',
                child: Image.asset(
                  asset,
                  key: Key('exercise_thumb_$exerciseId'),
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                  cacheWidth: (size * 3).round(),
                  errorBuilder: (context, error, stack) => _fallback(context),
                ),
              ),
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    return Container(
      color: context.appCardBg,
      alignment: Alignment.center,
      child: Icon(
        fallbackIcon,
        color: AppColors.primaryContainer,
        size: size * 0.42,
      ),
    );
  }
}
