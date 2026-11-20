import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../models/exercise_analysis.dart';
import '../models/form_feedback.dart';
import '../models/pose_landmark.dart';
import '../services/feedback_throttle.dart';
import '../services/form_analysis_service.dart';
import '../services/live_pose_camera.dart';
import '../services/video_processing_service.dart';
import '../widgets/feedback_card.dart';
import '../widgets/form_score_widget.dart';
import '../widgets/skeleton_overlay.dart';

/// Interactive AI Form Coach Screen.
/// Live camera tracking (ML Kit on the device), video recording and video
/// upload, with form checks for squat, bench press, deadlift, overhead press,
/// push-up and bicep curl.
class AIFormCoachScreen extends StatefulWidget {
  final String initialExercise;

  const AIFormCoachScreen({super.key, this.initialExercise = 'Squat'});

  @override
  State<AIFormCoachScreen> createState() => _AIFormCoachScreenState();
}

class _AIFormCoachScreenState extends State<AIFormCoachScreen> {
  late String _activeExercise;
  bool _isLiveTracking = false;
  bool _isProcessingVideo = false;
  final LivePoseCamera _camera = LivePoseCamera();
  bool _useFrontCamera = false;
  String? _cameraMessage;

  // Analysis State
  List<PoseLandmark> _currentLandmarks = [];
  int _reps = 0;
  FormFeedback _liveFeedback = _waitingFeedback();
  String? _repNote;
  String? _coachCue;
  final FormCueThrottle _cueThrottle = FormCueThrottle();
  ExerciseAnalysis? _completedAnalysis;

  final FormAnalysisService _analysisService = FormAnalysisService.instance;
  final VideoProcessingService _videoService = VideoProcessingService.instance;

  static FormFeedback _waitingFeedback() => FormFeedback(
    score: 0,
    warnings: const [],
    corrections: const [],
    bodyVisible: false,
  );

  @override
  void initState() {
    super.initState();
    _activeExercise = SupportedMvpExercises.normalize(widget.initialExercise);
    _analysisService.reset(exercise: _activeExercise);
    _startLiveTracking();
  }

  @override
  void dispose() {
    _isLiveTracking = false;
    _camera.stop();
    super.dispose();
  }

  void _switchExercise(String newExercise) {
    setState(() {
      _activeExercise = SupportedMvpExercises.normalize(newExercise);
      _reps = 0;
      _repNote = null;
      _completedAnalysis = null;
      _liveFeedback = _waitingFeedback();
      _coachCue = null;
    });
    _cueThrottle.reset();
    _analysisService.reset(exercise: _activeExercise);
  }

  Future<void> _startLiveTracking() async {
    _isLiveTracking = true;
    if (!LivePoseCamera.isSupported) {
      setState(() {
        _cameraMessage =
            'Live tracking needs a phone camera. Record or upload a video instead.';
      });
      return;
    }
    try {
      await _camera.start(front: _useFrontCamera, onLandmarks: _onLandmarks);
      if (mounted) setState(() => _cameraMessage = null);
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() {
        _cameraMessage = e.code.contains('Denied')
            ? 'Camera access is off. Allow it in Settings, or upload a video instead.'
            : 'The camera could not start. Record or upload a video instead.';
      });
    }
  }

  /// One processed camera frame: count reps, check form, and judge range of
  /// motion when a rep finishes.
  void _onLandmarks(List<PoseLandmark> landmarks) {
    if (!mounted || !_isLiveTracking || _completedAnalysis != null) return;

    final repsBefore = _analysisService.completedReps;
    final partialsBefore = _analysisService.partialRepAngles.length;
    _analysisService.updateRepCounter(_activeExercise, landmarks, smooth: true);
    final feedback = _analysisService.analyzeFrame(
      exerciseName: _activeExercise,
      landmarks: landmarks,
      judgeDepth: false,
    );

    var note = _repNote;
    final partials = _analysisService.partialRepAngles;
    if (partials.length > partialsBefore) {
      note = _analysisService.depthFeedbackForRep(
        _activeExercise,
        partials.last,
      );
      note = note == null ? null : 'Not counted: $note';
    } else if (_analysisService.completedReps > repsBefore) {
      note = 'Rep ${_analysisService.completedReps}: full range of motion.';
    }

    // Faults (warnings) show at once; other guidance is throttled.
    final cue = _cueThrottle.update(feedback);

    setState(() {
      _currentLandmarks = landmarks;
      _liveFeedback = feedback;
      _coachCue = cue;
      _reps = _analysisService.completedReps;
      _repNote = note;
    });
  }

  Future<void> _stopLiveTracking() async {
    setState(() => _isLiveTracking = false);
    await _camera.stop();
  }

  Future<void> _flipCamera() async {
    _useFrontCamera = !_useFrontCamera;
    await _camera.stop();
    await _startLiveTracking();
  }

  VideoProcessingProgress? _processingProgress;

  Future<void> _recordVideo() async {
    await _stopLiveTracking();
    final video = await _videoService.recordVideo();
    if (video == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video recording cancelled.'),
            backgroundColor: Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _startLiveTracking();
      }
      return;
    }

    setState(() {
      _isProcessingVideo = true;
      _processingProgress = const VideoProcessingProgress(
        currentFrame: 0,
        totalFrames: 1,
        status: 'Preparing recorded clip...',
      );
    });

    try {
      final analysis = await _videoService.processVideo(
        exerciseName: _activeExercise,
        videoFile: video,
        onProgress: (progress) {
          if (mounted) {
            setState(() => _processingProgress = progress);
          }
        },
      );

      if (mounted) {
        setState(() {
          _isProcessingVideo = false;
          _processingProgress = null;
          _completedAnalysis = analysis;
          _reps = analysis.repCount;
        });
      }
    } on VideoProcessingException catch (e) {
      if (mounted) {
        setState(() {
          _isProcessingVideo = false;
          _processingProgress = null;
        });
        _showErrorDialog(e.message);
        _startLiveTracking();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessingVideo = false;
          _processingProgress = null;
        });
        _showErrorDialog(
          'An unexpected error occurred while analyzing your video. Please ensure the clip is well-lit and standard MP4/MOV.',
        );
        _startLiveTracking();
      }
    }
  }

  Future<void> _uploadVideo() async {
    await _stopLiveTracking();
    final video = await _videoService.pickVideoFromGallery();
    if (video == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No video was selected.'),
            backgroundColor: Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _startLiveTracking();
      }
      return;
    }

    setState(() {
      _isProcessingVideo = true;
      _processingProgress = const VideoProcessingProgress(
        currentFrame: 0,
        totalFrames: 1,
        status: 'Preparing video file...',
      );
    });

    try {
      final analysis = await _videoService.processVideo(
        exerciseName: _activeExercise,
        videoFile: video,
        onProgress: (progress) {
          if (mounted) {
            setState(() => _processingProgress = progress);
          }
        },
      );

      if (mounted) {
        setState(() {
          _isProcessingVideo = false;
          _processingProgress = null;
          _completedAnalysis = analysis;
          _reps = analysis.repCount;
        });
      }
    } on VideoProcessingException catch (e) {
      if (mounted) {
        setState(() {
          _isProcessingVideo = false;
          _processingProgress = null;
        });
        _showErrorDialog(e.message);
        _startLiveTracking();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessingVideo = false;
          _processingProgress = null;
        });
        _showErrorDialog(
          'An unexpected error occurred while analyzing the video. Please verify your video is an MP4 or MOV clip and try again.',
        );
        _startLiveTracking();
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: const Color(0xFFEF4444).withValues(alpha: 0.5),
          ),
        ),
        title: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444)),
            const SizedBox(width: 8),
            Text(
              'Video Analysis Notice',
              style: AppTheme.headlineMd.copyWith(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: AppTheme.bodySm.copyWith(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Dismiss',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _uploadVideo();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  void _resetSession() {
    setState(() {
      _completedAnalysis = null;
      _reps = 0;
      _repNote = null;
      _liveFeedback = _waitingFeedback();
      _coachCue = null;
    });
    _cueThrottle.reset();
    _analysisService.reset(exercise: _activeExercise);
    _startLiveTracking();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      body: SafeArea(
        child: Stack(
          children: [
            // 1. Camera / Skeleton Viewport
            Positioned.fill(
              child: Container(
                color: const Color(0xFF0B1120),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_cameraPreviewReady) _buildCameraPreview(context),
                    // Grid background
                    Opacity(
                      opacity: 0.15,
                      child: GridPaper(
                        color: AppColors.primary,
                        divisions: 2,
                        subdivisions: 2,
                      ),
                    ),

                    // Center Guide Frame (no camera: placeholder and message)
                    if (!_cameraPreviewReady)
                      Center(
                        child: Container(
                          width: MediaQuery.of(context).size.width * 0.85,
                          height: MediaQuery.of(context).size.height * 0.65,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Stack(
                            children: [
                              // Corner Crosshairs
                              Positioned(
                                top: 12,
                                left: 12,
                                child: _buildCrosshair(),
                              ),
                              Positioned(
                                top: 12,
                                right: 12,
                                child: _buildCrosshair(),
                              ),
                              Positioned(
                                bottom: 12,
                                left: 12,
                                child: _buildCrosshair(),
                              ),
                              Positioned(
                                bottom: 12,
                                right: 12,
                                child: _buildCrosshair(),
                              ),

                              // Skeleton Custom Painter
                              SkeletonOverlay(
                                landmarks: _currentLandmarks,
                                hasWarnings: _liveFeedback.warnings.isNotEmpty,
                                isGoodForm: _liveFeedback.isGoodForm,
                              ),
                              if (_cameraMessage != null)
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Text(
                                      _cameraMessage!,
                                      textAlign: TextAlign.center,
                                      style: AppTheme.bodySm.copyWith(
                                        color: Colors.white70,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                    // Processing Loading Indicator
                    if (_isProcessingVideo)
                      Container(
                        color: Colors.black87,
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(
                                value:
                                    _processingProgress != null &&
                                        _processingProgress!.totalFrames > 0
                                    ? _processingProgress!.progressFraction
                                    : null,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppColors.primary,
                                ),
                                strokeWidth: 3.5,
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Analyzing your $_activeExercise...',
                                style: AppTheme.headlineMd.copyWith(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (_processingProgress != null &&
                                  _processingProgress!.totalFrames > 0)
                                Text(
                                  'Frame ${_processingProgress!.currentFrame} / ${_processingProgress!.totalFrames}',
                                  style: AppTheme.labelCaps.copyWith(
                                    fontSize: 13,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              const SizedBox(height: 6),
                              Text(
                                _processingProgress?.status ??
                                    'Extracting frames and tracking 33 joint angles',
                                textAlign: TextAlign.center,
                                style: AppTheme.bodySm.copyWith(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  width: 220,
                                  child: LinearProgressIndicator(
                                    value:
                                        _processingProgress?.progressFraction,
                                    backgroundColor: Colors.white12,
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                          AppColors.primary,
                                        ),
                                    minHeight: 6,
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
            ),

            // 2. Top Header Navigation & Exercise Selector
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                      padding: const EdgeInsets.all(10),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Dropdown Exercise Selector (5 MVP Exercises)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B).withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.6),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _activeExercise,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF1E293B),
                          icon: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppColors.primary,
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          items: SupportedMvpExercises.list.map((ex) {
                            return DropdownMenuItem(
                              value: ex,
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.fitness_center_rounded,
                                    size: 16,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(ex),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) _switchExercise(val);
                          },
                        ),
                      ),
                    ),
                  ),
                  if (_cameraPreviewReady) ...[
                    const SizedBox(width: 12),
                    IconButton(
                      tooltip: 'Switch camera',
                      onPressed: _flipCamera,
                      icon: const Icon(
                        Icons.cameraswitch_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black54,
                        padding: const EdgeInsets.all(10),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // 3. Live Stats Bar (Reps & Live Form Score)
            if (_completedAnalysis == null)
              Positioned(
                top: 80,
                left: 16,
                right: 16,
                child: Row(
                  children: [
                    // Rep Counter Widget
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'REPS COUNT',
                              style: AppTheme.labelCaps.copyWith(
                                color: Colors.white54,
                                fontSize: 10,
                              ),
                            ),
                            Text(
                              '$_reps',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Live Form Score
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _liveFeedback.isGoodForm
                                ? const Color(0xFF10B981).withValues(alpha: 0.5)
                                : const Color(
                                    0xFFEF4444,
                                  ).withValues(alpha: 0.5),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'FORM SCORE',
                              style: AppTheme.labelCaps.copyWith(
                                color: Colors.white54,
                                fontSize: 10,
                              ),
                            ),
                            Text(
                              _liveFeedback.bodyVisible
                                  ? '${_liveFeedback.score}%'
                                  : '--',
                              style: TextStyle(
                                color: _liveFeedback.isGoodForm
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFEF4444),
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Live coaching strip
            if (_completedAnalysis == null && _isLiveTracking)
              Positioned(
                top: 168,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _repNote ??
                            (_liveFeedback.bodyVisible
                                ? (_coachCue ?? 'Looking good. Keep going.')
                                : SupportedMvpExercises.cameraTip(
                                    _activeExercise,
                                  )),
                        style: AppTheme.bodySm.copyWith(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Form feedback is guidance, not medical advice. Stop if you feel pain.',
                        style: AppTheme.bodySm.copyWith(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // 4. Completed Analysis Results Modal / Sheet
            if (_completedAnalysis != null)
              Positioned(
                bottom: 96,
                left: 16,
                right: 16,
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.45,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Radial Score Header Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            children: [
                              FormScoreWidget(
                                score: _completedAnalysis!.formScore,
                                size: 84,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _completedAnalysis!.exerciseName,
                                      style: AppTheme.headlineMd.copyWith(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_completedAnalysis!.repCount} Reps Completed',
                                      style: AppTheme.bodySm.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _completedAnalysis!.feedback.gradeLabel,
                                      style: AppTheme.bodySm.copyWith(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Detailed Feedback Card
                        FeedbackCard(feedback: _completedAnalysis!.feedback),
                      ],
                    ),
                  ),
                ),
              ),

            // 5. Bottom Action Controls
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: _completedAnalysis == null
                  ? Row(
                      children: [
                        // Upload Video CTA (Primary)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _uploadVideo,
                            icon: const Icon(
                              Icons.file_upload_outlined,
                              size: 20,
                            ),
                            label: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('Upload Video'),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Record Video CTA (Secondary)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _recordVideo,
                            icon: const Icon(Icons.videocam_rounded, size: 20),
                            label: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('Record Video'),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white38),
                              backgroundColor: Colors.black45,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _resetSession,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Analyze Another Set'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _cameraPreviewReady =>
      _camera.controller?.value.isInitialized == true && _isLiveTracking;

  /// Full-screen camera preview with the skeleton drawn in the same box, so
  /// landmark coordinates (0–1 of the upright image) line up with the video.
  Widget _buildCameraPreview(BuildContext context) {
    final controller = _camera.controller!;
    final preview = controller.value.previewSize ?? const Size(720, 1280);
    final portrait = MediaQuery.of(context).orientation == Orientation.portrait;
    final width = portrait ? preview.shortestSide : preview.longestSide;
    final height = portrait ? preview.longestSide : preview.shortestSide;
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CameraPreview(controller),
              Transform.flip(
                // The front camera preview is mirrored; ML Kit's coordinates
                // are not.
                flipX: _camera.isFrontCamera,
                child: SkeletonOverlay(
                  landmarks: _currentLandmarks,
                  hasWarnings: _liveFeedback.warnings.isNotEmpty,
                  isGoodForm: _liveFeedback.isGoodForm,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCrosshair() {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: AppColors.primary.withValues(alpha: 0.7),
            width: 2,
          ),
          left: BorderSide(
            color: AppColors.primary.withValues(alpha: 0.7),
            width: 2,
          ),
        ),
      ),
    );
  }
}
