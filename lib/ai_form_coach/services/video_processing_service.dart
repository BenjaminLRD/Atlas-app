import 'dart:async';
import 'dart:io';
import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail.dart';
import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../models/exercise_analysis.dart';
import '../models/pose_landmark.dart';
import 'form_analysis_service.dart';
import 'pose_detection_service.dart';

/// Progress information emitted during video frame extraction and pose analysis.
class VideoProcessingProgress {
  final int currentFrame;
  final int totalFrames;
  final String status;

  const VideoProcessingProgress({
    required this.currentFrame,
    required this.totalFrames,
    required this.status,
  });

  double get progressFraction =>
      totalFrames > 0 ? (currentFrame / totalFrames).clamp(0.0, 1.0) : 0.0;

  int get percentage => (progressFraction * 100).round();
}

/// User-facing exception describing real-world video processing errors.
class VideoProcessingException implements Exception {
  final String message;
  final String? technicalDetails;

  const VideoProcessingException(this.message, [this.technicalDetails]);

  @override
  String toString() => message;
}

/// Service managing video file ingestion, frame extraction, and sequential pose analysis.
class VideoProcessingService {
  static VideoProcessingService? _instance;
  static VideoProcessingService get instance =>
      _instance ??= VideoProcessingService();

  final ImagePicker _picker = ImagePicker();
  final PoseDetectionService _poseService = PoseDetectionService.instance;
  final FormAnalysisService _formService = FormAnalysisService.instance;
  final FcNativeVideoThumbnail _thumbnailPlugin = FcNativeVideoThumbnail();

  /// Optional hook for overriding native thumbnail extraction in unit tests.
  Future<bool> Function({
    required String srcFile,
    required String destFile,
    required int width,
    required int height,
    bool? srcFileUri,
    FcVideoThumbnailTime? at,
  })?
  thumbnailExtractorOverride;

  /// Optional hook for overriding video selection in widget tests.
  Future<XFile?> Function()? videoPickerOverride;

  /// Prompts camera video recording using the device camera.
  Future<XFile?> recordVideo() async {
    if (videoPickerOverride != null) {
      return videoPickerOverride!();
    }
    try {
      return await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(seconds: 45),
      );
    } catch (_) {
      return null;
    }
  }

  /// Prompts gallery video file selection.
  Future<XFile?> pickVideoFromGallery() async {
    if (videoPickerOverride != null) {
      return videoPickerOverride!();
    }
    try {
      return await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 60),
      );
    } catch (_) {
      return null;
    }
  }

  /// Inspects video duration using VideoPlayerController when supported.
  Future<Duration?> inspectVideoDuration(String videoPath) async {
    VideoPlayerController? controller;
    try {
      final file = File(videoPath);
      if (!file.existsSync()) {
        throw const VideoProcessingException(
          'The selected video file could not be found. Please try picking it again.',
        );
      }

      controller = VideoPlayerController.file(file);
      await controller.initialize();
      return controller.value.duration;
    } catch (e) {
      if (e is VideoProcessingException) rethrow;
      debugPrint('Video duration inspection notice: $e');
      return null;
    } finally {
      await controller?.dispose();
    }
  }

  /// Validates video duration against AI Form Coach limits (2s - 60s).
  void validateDuration(Duration duration) {
    if (duration.inSeconds < 2) {
      throw const VideoProcessingException(
        'Video is too short (under 2 seconds). Please upload a video showing at least 1-2 complete repetitions (minimum 3 seconds).',
      );
    }
    if (duration.inSeconds > 60) {
      throw const VideoProcessingException(
        'Video is too long (over 60 seconds). Please upload a clip under 60 seconds focused on your squat set.',
      );
    }
  }

  /// Calculates target sample timestamps (in milliseconds) at a controlled rate (default 3.5 fps).
  List<int> calculateSampleTimestamps(
    Duration duration, {
    double fps = 3.5,
    int maxFrames = 120,
  }) {
    final totalMs = duration.inMilliseconds;
    if (totalMs <= 0) return [];

    final intervalMs = (1000.0 / fps).round();
    final timestamps = <int>[];

    for (int ms = 0; ms < totalMs; ms += intervalMs) {
      timestamps.add(ms);
      if (timestamps.length >= maxFrames) break;
    }

    if (timestamps.isNotEmpty && timestamps.last < totalMs - 250) {
      timestamps.add(totalMs - 100);
    }

    return timestamps;
  }

  /// Processes video input into biomechanical landmark frames and produces complete ExerciseAnalysis.
  Future<ExerciseAnalysis> processVideo({
    required String exerciseName,
    XFile? videoFile,
    List<List<PoseLandmark>>? injectedFrames,
    Function(VideoProcessingProgress progress)? onProgress,
  }) async {
    List<List<PoseLandmark>> validFrames = [];
    Duration setDuration = const Duration(seconds: 15);

    // 1. Direct injected frames (e.g. from unit tests)
    if (injectedFrames != null && injectedFrames.isNotEmpty) {
      validFrames = injectedFrames;
      onProgress?.call(
        VideoProcessingProgress(
          currentFrame: validFrames.length,
          totalFrames: validFrames.length,
          status: 'Evaluating $exerciseName form...',
        ),
      );
    } else if (videoFile != null) {
      // 2. Real uploaded video file pipeline
      Directory? tempDir;
      try {
        final videoPath = videoFile.path;
        final file = File(videoPath);
        if (!file.existsSync()) {
          throw const VideoProcessingException(
            'The selected video file was not found on your device.',
          );
        }

        onProgress?.call(
          const VideoProcessingProgress(
            currentFrame: 0,
            totalFrames: 1,
            status: 'Inspecting video format and length...',
          ),
        );

        final duration = await inspectVideoDuration(videoPath);
        if (duration != null) {
          validateDuration(duration);
          setDuration = duration;
        }

        final timestamps = calculateSampleTimestamps(
          setDuration,
          fps: 3.5,
          maxFrames: 120,
        );

        if (timestamps.isEmpty) {
          throw const VideoProcessingException(
            'Could not extract frames from the selected video.',
          );
        }

        tempDir = await Directory.systemTemp.createTemp('squat_frames_');
        final isAndroid = !kIsWeb && Platform.isAndroid;
        final srcUriOrPath = isAndroid
            ? Uri.file(videoPath).toString()
            : videoPath;
        final totalFrames = timestamps.length;

        for (int i = 0; i < totalFrames; i++) {
          final timeMs = timestamps[i];
          final frameFilePath = '${tempDir.path}/frame_$i.jpg';

          onProgress?.call(
            VideoProcessingProgress(
              currentFrame: i + 1,
              totalFrames: totalFrames,
              status: 'Analyzing frame ${i + 1} of $totalFrames...',
            ),
          );

          bool frameExtracted = false;
          try {
            if (thumbnailExtractorOverride != null) {
              frameExtracted = await thumbnailExtractorOverride!(
                srcFile: srcUriOrPath,
                destFile: frameFilePath,
                width: 640,
                height: 640,
                srcFileUri: isAndroid,
                at: FcVideoThumbnailTime(
                  timeMs,
                  FcVideoThumbnailTimeUnit.milliseconds,
                ),
              );
            } else {
              frameExtracted = await _thumbnailPlugin.saveThumbnailToFile(
                srcFile: srcUriOrPath,
                destFile: frameFilePath,
                width: 640,
                height: 640,
                quality: 80,
                srcFileUri: isAndroid,
                at: FcVideoThumbnailTime(
                  timeMs,
                  FcVideoThumbnailTimeUnit.milliseconds,
                ),
              );
            }
          } catch (e) {
            debugPrint('Frame $i extraction error: $e');
            frameExtracted = false;
          }

          if (frameExtracted) {
            final frameFile = File(frameFilePath);
            if (await frameFile.exists()) {
              try {
                final landmarks = await _poseService.processImageFile(
                  frameFilePath,
                );
                final confidence = _poseService.calculateAverageConfidence(
                  landmarks,
                );

                // Filter out low confidence frames (< 0.35) or frames where no body is detected
                if (landmarks.isNotEmpty && confidence >= 0.35) {
                  validFrames.add(landmarks);
                }
              } catch (e) {
                debugPrint('Pose detection notice on frame $i: $e');
              } finally {
                // Keep storage and RAM clean by immediately removing the processed frame image
                try {
                  await frameFile.delete();
                } catch (_) {}
              }
            }
          }

          // Small yield to allow UI frame scheduling and prevent freezing
          await Future.delayed(const Duration(milliseconds: 10));
        }

        // Validate that a detectable person was present in the video
        if (validFrames.length < 5) {
          throw const VideoProcessingException(
            'No person was clearly detected in the video. Please ensure your entire body (head to feet) is in frame with adequate lighting.',
          );
        }
      } on VideoProcessingException {
        rethrow;
      } catch (e) {
        throw VideoProcessingException(
          'We encountered an issue reading your video. Please ensure it is a standard video clip (such as MP4 or MOV).',
          e.toString(),
        );
      } finally {
        if (tempDir != null) {
          try {
            await tempDir.delete(recursive: true);
          } catch (_) {}
        }
      }
    }

    // 3. Nothing to analyse: never invent frames.
    if (validFrames.isEmpty) {
      throw const VideoProcessingException(
        'No video to analyse. Record or choose a clip of your set.',
      );
    }

    onProgress?.call(
      VideoProcessingProgress(
        currentFrame: validFrames.length,
        totalFrames: validFrames.length,
        status: 'Finalizing $exerciseName report...',
      ),
    );

    return _formService.analyzeSet(
      exerciseName: exerciseName,
      frames: validFrames,
      duration: setDuration,
    );
  }
}
