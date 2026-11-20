import '../models/exercise.dart';
import '../models/exercise_media.dart';

/// Service responsible for managing exercise video playback URLs,
/// animation fallback assets, and deterministic media resolution.
class ExerciseMediaService {
  static final ExerciseMediaService _instance =
      ExerciseMediaService._internal();
  factory ExerciseMediaService() => _instance;
  ExerciseMediaService._internal();

  /// In-memory cache of resolved exercise media
  final Map<String, ExerciseMedia> _mediaCache = {};

  /// Retrieves the video URL for a given exercise, or null if unavailable.
  String? getExerciseVideo(Exercise exercise) {
    if (exercise.videoUrl != null && exercise.videoUrl!.trim().isNotEmpty) {
      return exercise.videoUrl!.trim();
    }
    return null;
  }

  /// Retrieves the animation or animated asset path for an exercise.
  String? getAnimation(Exercise exercise) {
    if (exercise.animationAsset != null &&
        exercise.animationAsset!.trim().isNotEmpty) {
      return exercise.animationAsset!.trim();
    }
    // Fallback to image if provided
    if (exercise.imageUrl != null && exercise.imageUrl!.trim().isNotEmpty) {
      return exercise.imageUrl!.trim();
    }
    return null;
  }

  /// Checks if any visual demonstration media (video, GIF, animation, or image) exists.
  bool hasMedia(Exercise exercise) {
    return (exercise.videoUrl != null &&
            exercise.videoUrl!.trim().isNotEmpty) ||
        (exercise.animationAsset != null &&
            exercise.animationAsset!.trim().isNotEmpty) ||
        (exercise.imageUrl != null && exercise.imageUrl!.trim().isNotEmpty);
  }

  /// Resolves the highest fidelity media object for an exercise following the priority chain:
  /// Video -> Animation -> Image -> Placeholder
  /// Never randomly selects an image from another exercise or uses an unrelated image as fallback.
  ExerciseMedia resolveMedia(Exercise exercise) {
    final cached = _mediaCache[exercise.id];
    if (cached != null) return cached;

    ExerciseMedia resolved;
    if (exercise.videoUrl != null && exercise.videoUrl!.trim().isNotEmpty) {
      resolved = ExerciseMedia(
        id: 'media_${exercise.id}_video',
        exerciseId: exercise.id,
        mediaType: 'video',
        url: exercise.videoUrl!.trim(),
        thumbnail: exercise.imageUrl,
        createdAt: DateTime.now(),
      );
    } else if (exercise.animationAsset != null &&
        exercise.animationAsset!.trim().isNotEmpty) {
      resolved = ExerciseMedia(
        id: 'media_${exercise.id}_anim',
        exerciseId: exercise.id,
        mediaType: 'gif',
        url: exercise.animationAsset!.trim(),
        thumbnail: exercise.imageUrl,
        createdAt: DateTime.now(),
      );
    } else if (exercise.imageUrl != null &&
        exercise.imageUrl!.trim().isNotEmpty) {
      resolved = ExerciseMedia(
        id: 'media_${exercise.id}_img',
        exerciseId: exercise.id,
        mediaType: 'image',
        url: exercise.imageUrl!.trim(),
        thumbnail: exercise.imageUrl,
        createdAt: DateTime.now(),
      );
    } else {
      resolved = ExerciseMedia(
        id: 'media_${exercise.id}_placeholder',
        exerciseId: exercise.id,
        mediaType: 'placeholder',
        url: '',
        thumbnail: null,
        createdAt: DateTime.now(),
      );
    }

    _mediaCache[exercise.id] = resolved;
    return resolved;
  }

  /// Resolves media by exercise ID or name, returning a clean placeholder if exact media is unavailable.
  ExerciseMedia resolveMediaById(String exerciseId) {
    final ex = Exercise.getById(exerciseId) ?? Exercise.findByName(exerciseId);
    if (ex != null) {
      return resolveMedia(ex);
    }
    return ExerciseMedia(
      id: 'media_${exerciseId}_placeholder',
      exerciseId: exerciseId,
      mediaType: 'placeholder',
      url: '',
      thumbnail: null,
      createdAt: DateTime.now(),
    );
  }

  /// Clears in-memory media cache.
  void clearCache() {
    _mediaCache.clear();
  }
}
