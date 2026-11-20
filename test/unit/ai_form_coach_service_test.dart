import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/ai_form_coach/models/pose_landmark.dart';
import 'package:atlas/ai_form_coach/services/form_analysis_service.dart';
import 'package:atlas/ai_form_coach/services/pose_detection_service.dart';
import 'package:atlas/ai_form_coach/services/video_processing_service.dart';

void main() {
  group('AI Form Coach — Phase 1: Biomechanical Analysis Engine Tests', () {
    late FormAnalysisService formService;
    late PoseDetectionService poseService;
    late VideoProcessingService videoService;

    setUp(() {
      formService = FormAnalysisService.instance;
      poseService = PoseDetectionService.instance;
      videoService = VideoProcessingService.instance;
    });

    test('SupportedMvpExercises correctly identifies the 5 MVP exercises', () {
      expect(SupportedMvpExercises.isSupported('Barbell Back Squat'), isTrue);
      expect(
        SupportedMvpExercises.isSupported('Flat Dumbbell Bench Press'),
        isTrue,
      );
      expect(SupportedMvpExercises.isSupported('Standing Bicep Curl'), isTrue);
      expect(SupportedMvpExercises.isSupported('Standard Push-up'), isTrue);
      expect(
        SupportedMvpExercises.isSupported('Conventional Deadlift'),
        isTrue,
      );

      expect(
        SupportedMvpExercises.normalize('Squats'),
        SupportedMvpExercises.squat,
      );
      expect(
        SupportedMvpExercises.normalize('Bench Press'),
        SupportedMvpExercises.benchPress,
      );
      expect(
        SupportedMvpExercises.normalize('Incline Curl'),
        SupportedMvpExercises.bicepCurl,
      );
      expect(
        SupportedMvpExercises.normalize('Push-ups'),
        SupportedMvpExercises.pushUp,
      );
      expect(
        SupportedMvpExercises.normalize('Romanian Deadlift'),
        SupportedMvpExercises.deadlift,
      );
    });

    test(
      'PoseDetectionService generates simulated landmarks and finds joint by name',
      () {
        final landmarks = poseService.generateSimulatedLandmarks(
          exercise: 'Squat',
          phaseProgress: 0.5,
        );

        expect(landmarks, isNotEmpty);
        final knee = poseService.findLandmark(
          landmarks,
          PoseLandmarkNames.leftKnee,
        );
        expect(knee, isNotNull);
        expect(knee!.name, PoseLandmarkNames.leftKnee);

        final angle = poseService.calculateJointAngle(
          landmarks,
          PoseLandmarkNames.leftHip,
          PoseLandmarkNames.leftKnee,
          PoseLandmarkNames.leftAnkle,
        );
        expect(angle, isNotNull);
        expect(angle!, greaterThan(0.0));
      },
    );

    test(
      'Squat rep counter accurately tracks state machine and rep increment',
      () {
        formService.reset(exercise: 'Squat');
        expect(formService.completedReps, 0);

        // Frame 1: Standing ready (knee angle ~170°)
        final standingFrame = [
          PoseLandmark(
            name: PoseLandmarkNames.leftHip,
            x: 0.50,
            y: 0.50,
            z: 0,
            confidence: 1.0,
          ),
          PoseLandmark(
            name: PoseLandmarkNames.leftKnee,
            x: 0.50,
            y: 0.72,
            z: 0,
            confidence: 1.0,
          ),
          PoseLandmark(
            name: PoseLandmarkNames.leftAnkle,
            x: 0.50,
            y: 0.92,
            z: 0,
            confidence: 1.0,
          ),
        ];
        formService.updateRepCounter('Squat', standingFrame);
        expect(formService.completedReps, 0);

        // Frame 2: Eccentric descent (knee angle ~130°)
        final descentFrame = [
          PoseLandmark(
            name: PoseLandmarkNames.leftHip,
            x: 0.50,
            y: 0.58,
            z: 0,
            confidence: 1.0,
          ),
          PoseLandmark(
            name: PoseLandmarkNames.leftKnee,
            x: 0.42,
            y: 0.72,
            z: 0,
            confidence: 1.0,
          ),
          PoseLandmark(
            name: PoseLandmarkNames.leftAnkle,
            x: 0.50,
            y: 0.92,
            z: 0,
            confidence: 1.0,
          ),
        ];
        formService.updateRepCounter('Squat', descentFrame);
        expect(formService.currentPhase, MovementPhase.eccentric);

        // Frame 3: Inflection point at bottom parallel/deep (knee angle ~90°)
        final bottomFrame = [
          PoseLandmark(
            name: PoseLandmarkNames.leftHip,
            x: 0.50,
            y: 0.72,
            z: 0,
            confidence: 1.0,
          ),
          PoseLandmark(
            name: PoseLandmarkNames.leftKnee,
            x: 0.35,
            y: 0.72,
            z: 0,
            confidence: 1.0,
          ),
          PoseLandmark(
            name: PoseLandmarkNames.leftAnkle,
            x: 0.35,
            y: 0.92,
            z: 0,
            confidence: 1.0,
          ),
        ];
        formService.updateRepCounter('Squat', bottomFrame);
        expect(formService.currentPhase, MovementPhase.inflection);

        // Frame 4: Concentric ascent (knee angle rising ~120°)
        formService.updateRepCounter('Squat', descentFrame);
        expect(formService.currentPhase, MovementPhase.concentric);

        // Frame 5: Return to lockout standing (knee angle ~170°)
        formService.updateRepCounter('Squat', standingFrame);
        expect(formService.completedReps, 1);
        expect(formService.currentPhase, MovementPhase.ready);
      },
    );

    test(
      'Good squat detection validates Great depth, Stable knees, Upright chest',
      () {
        final goodDeepSquat = [
          PoseLandmark(
            name: PoseLandmarkNames.nose,
            x: 0.50,
            y: 0.20,
            z: 0,
            confidence: 0.98,
          ),
          PoseLandmark(
            name: PoseLandmarkNames.leftShoulder,
            x: 0.50,
            y: 0.45,
            z: 0,
            confidence: 0.96,
          ),
          PoseLandmark(
            name: PoseLandmarkNames.leftHip,
            x: 0.50,
            y: 0.72,
            z: 0,
            confidence: 0.95,
          ),
          PoseLandmark(
            name: PoseLandmarkNames.leftKnee,
            x: 0.35,
            y: 0.72,
            z: 0,
            confidence: 0.96,
          ),
          PoseLandmark(
            name: PoseLandmarkNames.leftAnkle,
            x: 0.35,
            y: 0.92,
            z: 0,
            confidence: 0.97,
          ),
        ];

        final feedback = formService.analyzeFrame(
          exerciseName: 'Squat',
          landmarks: goodDeepSquat,
        );

        expect(feedback.isGoodForm, isTrue);
        expect(feedback.score, greaterThanOrEqualTo(90));
        expect(feedback.confidencePercentage, greaterThanOrEqualTo(90));
        expect(
          feedback.positiveFeedback.any((p) => p.contains('Great depth')),
          isTrue,
        );
        expect(
          feedback.positiveFeedback.any(
            (p) => p.contains('Maintain upright chest'),
          ),
          isTrue,
        );
        expect(feedback.warnings, isEmpty);
      },
    );

    test(
      'Bad squat detection catches shallow squat, knee valgus, and forward torso lean',
      () {
        // 1. Shallow squat (knee angle > 105°)
        final shallowSquat = [
          PoseLandmark(
            name: PoseLandmarkNames.leftShoulder,
            x: 0.50,
            y: 0.40,
            z: 0,
            confidence: 1.0,
          ),
          PoseLandmark(
            name: PoseLandmarkNames.leftHip,
            x: 0.50,
            y: 0.60,
            z: 0,
            confidence: 1.0,
          ),
          PoseLandmark(
            name: PoseLandmarkNames.leftKnee,
            x: 0.40,
            y: 0.70,
            z: 0,
            confidence: 1.0,
          ),
          PoseLandmark(
            name: PoseLandmarkNames.leftAnkle,
            x: 0.40,
            y: 0.92,
            z: 0,
            confidence: 1.0,
          ),
        ];
        final shallowFeedback = formService.analyzeFrame(
          exerciseName: 'Squat',
          landmarks: shallowSquat,
        );
        expect(
          shallowFeedback.warnings.any((w) => w.contains('Squat deeper')),
          isTrue,
        );

        // 2. Knee valgus: only visible front-on (both sides in view)
        final valgusSquat = [
          PoseLandmark(
            name: PoseLandmarkNames.leftShoulder,
            x: 0.4,
            y: 0.3,
            z: 0,
            confidence: 1.0,
          ),
          PoseLandmark(
            name: PoseLandmarkNames.rightShoulder,
            x: 0.6,
            y: 0.3,
            z: 0,
            confidence: 1.0,
          ),
          PoseLandmark(
            name: PoseLandmarkNames.leftHip,
            x: 0.42,
            y: 0.65,
            z: 0,
            confidence: 1.0,
          ),
          PoseLandmark(
            name: PoseLandmarkNames.rightHip,
            x: 0.58,
            y: 0.65,
            z: 0,
            confidence: 1.0,
          ),
          PoseLandmark(
            name: PoseLandmarkNames.leftKnee,
            x: 0.47,
            y: 0.75,
            z: 0,
            confidence: 1.0,
          ),
          PoseLandmark(
            name: PoseLandmarkNames.rightKnee,
            x: 0.53,
            y: 0.75,
            z: 0,
            confidence: 1.0,
          ),
          PoseLandmark(
            name: PoseLandmarkNames.leftAnkle,
            x: 0.4,
            y: 0.9,
            z: 0,
            confidence: 1.0,
          ),
          PoseLandmark(
            name: PoseLandmarkNames.rightAnkle,
            x: 0.6,
            y: 0.9,
            z: 0,
            confidence: 1.0,
          ),
        ];
        final valgusFeedback = formService.analyzeFrame(
          exerciseName: 'Squat',
          landmarks: valgusSquat,
        );
        expect(
          valgusFeedback.warnings.any((w) => w.contains('Keep knees aligned')),
          isTrue,
        );

        // 3. Excessive forward torso lean (torso angle < 55°)
        final forwardLeanSquat = [
          PoseLandmark(
            name: PoseLandmarkNames.leftShoulder,
            x: 0.15,
            y: 0.65,
            z: 0,
            confidence: 1.0,
          ),
          PoseLandmark(
            name: PoseLandmarkNames.leftHip,
            x: 0.50,
            y: 0.72,
            z: 0,
            confidence: 1.0,
          ),
          PoseLandmark(
            name: PoseLandmarkNames.leftKnee,
            x: 0.35,
            y: 0.72,
            z: 0,
            confidence: 1.0,
          ),
          PoseLandmark(
            name: PoseLandmarkNames.leftAnkle,
            x: 0.35,
            y: 0.92,
            z: 0,
            confidence: 1.0,
          ),
        ];
        final leanFeedback = formService.analyzeFrame(
          exerciseName: 'Squat',
          landmarks: forwardLeanSquat,
        );
        expect(
          leanFeedback.warnings.any(
            (w) => w.contains('Maintain upright chest'),
          ),
          isTrue,
        );
      },
    );

    test('Front-on squat with knees over toes shows stable knee tracking', () {
      final goodFrontal = [
        PoseLandmark(
          name: PoseLandmarkNames.leftShoulder,
          x: 0.4,
          y: 0.3,
          z: 0,
          confidence: 1.0,
        ),
        PoseLandmark(
          name: PoseLandmarkNames.rightShoulder,
          x: 0.6,
          y: 0.3,
          z: 0,
          confidence: 1.0,
        ),
        PoseLandmark(
          name: PoseLandmarkNames.leftHip,
          x: 0.42,
          y: 0.65,
          z: 0,
          confidence: 1.0,
        ),
        PoseLandmark(
          name: PoseLandmarkNames.rightHip,
          x: 0.58,
          y: 0.65,
          z: 0,
          confidence: 1.0,
        ),
        PoseLandmark(
          name: PoseLandmarkNames.leftKnee,
          x: 0.36,
          y: 0.75,
          z: 0,
          confidence: 1.0,
        ),
        PoseLandmark(
          name: PoseLandmarkNames.rightKnee,
          x: 0.64,
          y: 0.75,
          z: 0,
          confidence: 1.0,
        ),
        PoseLandmark(
          name: PoseLandmarkNames.leftAnkle,
          x: 0.4,
          y: 0.9,
          z: 0,
          confidence: 1.0,
        ),
        PoseLandmark(
          name: PoseLandmarkNames.rightAnkle,
          x: 0.6,
          y: 0.9,
          z: 0,
          confidence: 1.0,
        ),
      ];
      final feedback = formService.analyzeFrame(
        exerciseName: 'Squat',
        landmarks: goodFrontal,
        judgeDepth: false, // mid-descent frame; depth is judged per rep
      );
      expect(
        feedback.positiveFeedback.any(
          (p) => p.contains('Stable knee tracking'),
        ),
        isTrue,
      );
      expect(feedback.warnings, isEmpty);
    });

    test('Frames without the needed joints are not judged', () {
      final feedback = formService.analyzeFrame(
        exerciseName: 'Squat',
        landmarks: [
          PoseLandmark(
            name: PoseLandmarkNames.leftShoulder,
            x: 0.5,
            y: 0.3,
            z: 0,
            confidence: 1.0,
          ),
          PoseLandmark(
            name: PoseLandmarkNames.leftHip,
            x: 0.5,
            y: 0.55,
            z: 0,
            confidence: 1.0,
          ),
        ],
      );
      expect(feedback.bodyVisible, isFalse);
      expect(feedback.warnings, isEmpty);
      expect(feedback.corrections.single, contains('in view'));
    });

    test('2. Bench Press Analysis evaluates elbow angle and flare risk', () {
      // Flared elbows (elbow at 90 degrees out from torso)
      final flaredBench = [
        PoseLandmark(
          name: PoseLandmarkNames.leftShoulder,
          x: 0.50,
          y: 0.30,
          z: 0,
          confidence: 1.0,
        ),
        PoseLandmark(
          name: PoseLandmarkNames.leftElbow,
          x: 0.25,
          y: 0.30,
          z: 0,
          confidence: 1.0,
        ),
        PoseLandmark(
          name: PoseLandmarkNames.leftWrist,
          x: 0.25,
          y: 0.15,
          z: 0,
          confidence: 1.0,
        ),
        PoseLandmark(
          name: PoseLandmarkNames.leftHip,
          x: 0.50,
          y: 0.60,
          z: 0,
          confidence: 1.0,
        ),
      ];

      final flaredFeedback = formService.analyzeFrame(
        exerciseName: 'Bench Press',
        landmarks: flaredBench,
      );

      expect(flaredFeedback.warnings.any((w) => w.contains('flaring')), isTrue);
      expect(
        flaredFeedback.corrections.any((c) => c.contains('45-60 degrees')),
        isTrue,
      );
    });

    test('3. Bicep Curl Analysis detects momentum swinging', () {
      // Body swinging back (shoulder drifting behind hips)
      final swingingCurl = [
        PoseLandmark(
          name: PoseLandmarkNames.leftShoulder,
          x: 0.28,
          y: 0.30,
          z: 0,
          confidence: 1.0,
        ),
        PoseLandmark(
          name: PoseLandmarkNames.leftHip,
          x: 0.45,
          y: 0.60,
          z: 0,
          confidence: 1.0,
        ), // 0.17 drift
        PoseLandmark(
          name: PoseLandmarkNames.leftElbow,
          x: 0.38,
          y: 0.45,
          z: 0,
          confidence: 1.0,
        ),
        PoseLandmark(
          name: PoseLandmarkNames.leftWrist,
          x: 0.38,
          y: 0.25,
          z: 0,
          confidence: 1.0,
        ),
      ];

      final swingFeedback = formService.analyzeFrame(
        exerciseName: 'Bicep Curl',
        landmarks: swingingCurl,
      );

      expect(swingFeedback.warnings.any((w) => w.contains('swinging')), isTrue);
      expect(
        swingFeedback.corrections.any((c) => c.contains('Pin elbows')),
        isTrue,
      );
    });

    test('4. Push-up Analysis detects sagging hips', () {
      // Sagging hip alignment
      final saggingPushup = [
        PoseLandmark(
          name: PoseLandmarkNames.leftShoulder,
          x: 0.20,
          y: 0.45,
          z: 0,
          confidence: 1.0,
        ),
        PoseLandmark(
          name: PoseLandmarkNames.leftHip,
          x: 0.50,
          y: 0.68,
          z: 0,
          confidence: 1.0,
        ), // Significant sag
        PoseLandmark(
          name: PoseLandmarkNames.leftAnkle,
          x: 0.85,
          y: 0.50,
          z: 0,
          confidence: 1.0,
        ),
        PoseLandmark(
          name: PoseLandmarkNames.leftElbow,
          x: 0.30,
          y: 0.40,
          z: 0,
          confidence: 1.0,
        ),
        PoseLandmark(
          name: PoseLandmarkNames.leftWrist,
          x: 0.25,
          y: 0.55,
          z: 0,
          confidence: 1.0,
        ),
      ];

      final pushupFeedback = formService.analyzeFrame(
        exerciseName: 'Push-up',
        landmarks: saggingPushup,
      );

      expect(pushupFeedback.warnings.any((w) => w.contains('sagging')), isTrue);
      expect(
        pushupFeedback.corrections.any((c) => c.contains('straight plank')),
        isTrue,
      );
    });

    test('5. Deadlift Analysis verifies hip hinge mechanics', () {
      final deadlift = [
        PoseLandmark(
          name: PoseLandmarkNames.leftShoulder,
          x: 0.35,
          y: 0.40,
          z: 0,
          confidence: 1.0,
        ),
        PoseLandmark(
          name: PoseLandmarkNames.leftHip,
          x: 0.50,
          y: 0.52,
          z: 0,
          confidence: 1.0,
        ),
        PoseLandmark(
          name: PoseLandmarkNames.leftKnee,
          x: 0.52,
          y: 0.72,
          z: 0,
          confidence: 1.0,
        ),
        PoseLandmark(
          name: PoseLandmarkNames.leftAnkle,
          x: 0.50,
          y: 0.92,
          z: 0,
          confidence: 1.0,
        ),
      ];

      final deadliftFeedback = formService.analyzeFrame(
        exerciseName: 'Deadlift',
        landmarks: deadlift,
      );

      expect(deadliftFeedback.score, greaterThanOrEqualTo(80));
      expect(
        deadliftFeedback.positiveFeedback.any((p) => p.contains('hip-hinge')),
        isTrue,
      );
    });

    test(
      'VideoProcessingService end-to-end pipeline processes workout set',
      () async {
        // Three simulated reps, injected as frames (the service no longer
        // invents frames when given no video).
        final frames = <List<PoseLandmark>>[
          for (var f = 0; f < 36; f++)
            poseService.generateSimulatedLandmarks(
              exercise: 'Squat',
              phaseProgress: f % 12 < 6
                  ? (f % 12) / 5.0
                  : 1.0 - ((f % 12) - 6) / 5.0,
            ),
        ];
        final analysis = await videoService.processVideo(
          exerciseName: 'Squat',
          injectedFrames: frames,
        );

        expect(analysis.exerciseName, 'Squat');
        expect(analysis.formScore, greaterThan(0));
        expect(analysis.repCount, greaterThanOrEqualTo(1));
        expect(analysis.metrics['frameCount'], greaterThan(10));
      },
    );
  });

  group('AI Form Coach — Phase C.3: Real Uploaded-Video Analysis Tests', () {
    late FormAnalysisService formService;
    late PoseDetectionService poseService;
    late VideoProcessingService videoService;

    setUp(() {
      formService = FormAnalysisService.instance;
      poseService = PoseDetectionService.instance;
      videoService = VideoProcessingService.instance;
      videoService.thumbnailExtractorOverride = null;
    });

    test('1. Frame sampling strategy calculates controlled timestamps', () {
      // 10 second video sampled at 3.5 fps
      const duration = Duration(seconds: 10);
      final timestamps = videoService.calculateSampleTimestamps(
        duration,
        fps: 3.5,
      );

      expect(timestamps, isNotEmpty);
      expect(timestamps.length, greaterThanOrEqualTo(30));
      expect(timestamps.length, lessThanOrEqualTo(40));

      // Check first frame is 0 ms
      expect(timestamps.first, 0);

      // Check monotonicity
      for (int i = 1; i < timestamps.length; i++) {
        expect(timestamps[i], greaterThan(timestamps[i - 1]));
      }

      // Check empty duration returns empty list
      expect(videoService.calculateSampleTimestamps(Duration.zero), isEmpty);
    });

    test('2. Video duration validation enforces clip limits', () {
      // Too short (< 2s)
      expect(
        () => videoService.validateDuration(const Duration(seconds: 1)),
        throwsA(
          isA<VideoProcessingException>().having(
            (e) => e.message,
            'message',
            contains('too short'),
          ),
        ),
      );

      // Too long (> 60s)
      expect(
        () => videoService.validateDuration(const Duration(seconds: 65)),
        throwsA(
          isA<VideoProcessingException>().having(
            (e) => e.message,
            'message',
            contains('too long'),
          ),
        ),
      );

      // Valid clip (15s) passes cleanly
      expect(
        () => videoService.validateDuration(const Duration(seconds: 15)),
        returnsNormally,
      );
    });

    test('3. Low-confidence landmarks and no-person frames are detected', () {
      // Low confidence frame (confidence 0.20 < threshold 0.35)
      final lowConfidenceFrame = [
        PoseLandmark(
          name: PoseLandmarkNames.leftHip,
          x: 0.50,
          y: 0.50,
          z: 0.0,
          confidence: 0.20,
        ),
        PoseLandmark(
          name: PoseLandmarkNames.leftKnee,
          x: 0.48,
          y: 0.72,
          z: 0.0,
          confidence: 0.20,
        ),
        PoseLandmark(
          name: PoseLandmarkNames.leftAnkle,
          x: 0.50,
          y: 0.92,
          z: 0.0,
          confidence: 0.20,
        ),
      ];

      final avgConfidence = poseService.calculateAverageConfidence(
        lowConfidenceFrame,
      );
      expect(avgConfidence, lessThan(0.35));

      // Empty frame returns 0.0
      expect(poseService.calculateAverageConfidence([]), 0.0);
    });

    test(
      '4. Rep counting from landmark sequence accurately tracks completed reps',
      () {
        formService.reset(exercise: 'Squat');

        // Helper to construct a frame with specific knee angle
        List<PoseLandmark> makeFrame({
          required double kneeX,
          required double hipY,
          double kneeValgusX = 0.48,
          double torsoLeanX = 0.42,
        }) {
          return [
            PoseLandmark(
              name: PoseLandmarkNames.nose,
              x: 0.50,
              y: 0.18,
              z: 0.0,
              confidence: 0.95,
            ),
            PoseLandmark(
              name: PoseLandmarkNames.leftShoulder,
              x: torsoLeanX,
              y: 0.28,
              z: 0.0,
              confidence: 0.95,
            ),
            PoseLandmark(
              name: PoseLandmarkNames.leftHip,
              x: 0.50,
              y: hipY,
              z: 0.0,
              confidence: 0.95,
            ),
            PoseLandmark(
              name: PoseLandmarkNames.leftKnee,
              x: kneeX,
              y: 0.72,
              z: 0.0,
              confidence: 0.95,
            ),
            PoseLandmark(
              name: PoseLandmarkNames.leftAnkle,
              x: 0.50,
              y: 0.92,
              z: 0.0,
              confidence: 0.95,
            ),
          ];
        }

        // Simulate 2 complete reps: Standing -> Descent -> Parallel Inflection -> Ascent -> Lockout
        final frames = <List<PoseLandmark>>[];

        for (int r = 0; r < 2; r++) {
          // 1. Standing ready (~170°)
          frames.add(makeFrame(kneeX: 0.48, hipY: 0.52));
          // 2. Descent (~130°)
          frames.add(makeFrame(kneeX: 0.42, hipY: 0.60));
          // 3. Bottom parallel inflection (~70°)
          frames.add(makeFrame(kneeX: 0.35, hipY: 0.72));
          // 4. Ascent (~120°)
          frames.add(makeFrame(kneeX: 0.42, hipY: 0.60));
          // 5. Standing lockout (~170°)
          frames.add(makeFrame(kneeX: 0.48, hipY: 0.52));
        }

        final analysis = formService.analyzeSet(
          exerciseName: 'Squat',
          frames: frames,
        );

        expect(analysis.repCount, 2);
        expect(analysis.formScore, greaterThanOrEqualTo(85));
        expect(analysis.feedback.positiveFeedback, isNotEmpty);
      },
    );

    test(
      '5. Good squat sequence validates depth, stability, and upright posture',
      () {
        final goodSquatFrames = <List<PoseLandmark>>[
          // Standing setup
          [
            PoseLandmark(
              name: PoseLandmarkNames.leftShoulder,
              x: 0.45,
              y: 0.28,
              z: 0.0,
              confidence: 0.98,
            ),
            PoseLandmark(
              name: PoseLandmarkNames.leftHip,
              x: 0.50,
              y: 0.52,
              z: 0.0,
              confidence: 0.98,
            ),
            PoseLandmark(
              name: PoseLandmarkNames.leftKnee,
              x: 0.48,
              y: 0.72,
              z: 0.0,
              confidence: 0.98,
            ),
            PoseLandmark(
              name: PoseLandmarkNames.leftAnkle,
              x: 0.50,
              y: 0.92,
              z: 0.0,
              confidence: 0.98,
            ),
          ],
          // Deep inflection (knee <= 95°, torso >= 65°, knee aligned with ankle)
          [
            PoseLandmark(
              name: PoseLandmarkNames.leftShoulder,
              x: 0.48,
              y: 0.36,
              z: 0.0,
              confidence: 0.98,
            ),
            PoseLandmark(
              name: PoseLandmarkNames.leftHip,
              x: 0.50,
              y: 0.72,
              z: 0.0,
              confidence: 0.98,
            ),
            PoseLandmark(
              name: PoseLandmarkNames.leftKnee,
              x: 0.35,
              y: 0.72,
              z: 0.0,
              confidence: 0.98,
            ),
            PoseLandmark(
              name: PoseLandmarkNames.leftAnkle,
              x: 0.50,
              y: 0.92,
              z: 0.0,
              confidence: 0.98,
            ),
          ],
          // Return to lockout
          [
            PoseLandmark(
              name: PoseLandmarkNames.leftShoulder,
              x: 0.45,
              y: 0.28,
              z: 0.0,
              confidence: 0.98,
            ),
            PoseLandmark(
              name: PoseLandmarkNames.leftHip,
              x: 0.50,
              y: 0.52,
              z: 0.0,
              confidence: 0.98,
            ),
            PoseLandmark(
              name: PoseLandmarkNames.leftKnee,
              x: 0.48,
              y: 0.72,
              z: 0.0,
              confidence: 0.98,
            ),
            PoseLandmark(
              name: PoseLandmarkNames.leftAnkle,
              x: 0.50,
              y: 0.92,
              z: 0.0,
              confidence: 0.98,
            ),
          ],
        ];

        final analysis = formService.analyzeSet(
          exerciseName: 'Squat',
          frames: goodSquatFrames,
        );

        expect(analysis.formScore, greaterThanOrEqualTo(85));
        expect(
          analysis.feedback.positiveFeedback.contains('Great depth'),
          isTrue,
        );
        expect(analysis.detectedMistakes, isEmpty);
      },
    );

    test(
      '6. Bad squat sequence detects shallow depth, valgus, and forward lean',
      () {
        final badSquatFrames = <List<PoseLandmark>>[
          // A partial rep: down to ~135° only, then back up.
          [
            PoseLandmark(
              name: PoseLandmarkNames.leftShoulder,
              x: 0.45,
              y: 0.28,
              z: 0,
              confidence: 0.98,
            ),
            PoseLandmark(
              name: PoseLandmarkNames.leftHip,
              x: 0.5,
              y: 0.52,
              z: 0,
              confidence: 0.98,
            ),
            PoseLandmark(
              name: PoseLandmarkNames.leftKnee,
              x: 0.48,
              y: 0.72,
              z: 0,
              confidence: 0.98,
            ),
            PoseLandmark(
              name: PoseLandmarkNames.leftAnkle,
              x: 0.5,
              y: 0.92,
              z: 0,
              confidence: 0.98,
            ),
          ],
          [
            PoseLandmark(
              name: PoseLandmarkNames.leftShoulder,
              x: 0.5,
              y: 0.4,
              z: 0,
              confidence: 1.0,
            ),
            PoseLandmark(
              name: PoseLandmarkNames.leftHip,
              x: 0.5,
              y: 0.6,
              z: 0,
              confidence: 1.0,
            ),
            PoseLandmark(
              name: PoseLandmarkNames.leftKnee,
              x: 0.4,
              y: 0.7,
              z: 0,
              confidence: 1.0,
            ),
            PoseLandmark(
              name: PoseLandmarkNames.leftAnkle,
              x: 0.4,
              y: 0.92,
              z: 0,
              confidence: 1.0,
            ),
          ],
          [
            PoseLandmark(
              name: PoseLandmarkNames.leftShoulder,
              x: 0.45,
              y: 0.28,
              z: 0,
              confidence: 0.98,
            ),
            PoseLandmark(
              name: PoseLandmarkNames.leftHip,
              x: 0.5,
              y: 0.52,
              z: 0,
              confidence: 0.98,
            ),
            PoseLandmark(
              name: PoseLandmarkNames.leftKnee,
              x: 0.48,
              y: 0.72,
              z: 0,
              confidence: 0.98,
            ),
            PoseLandmark(
              name: PoseLandmarkNames.leftAnkle,
              x: 0.5,
              y: 0.92,
              z: 0,
              confidence: 0.98,
            ),
          ],
          // Excessive forward lean.
          [
            PoseLandmark(
              name: PoseLandmarkNames.leftShoulder,
              x: 0.15,
              y: 0.65,
              z: 0,
              confidence: 1.0,
            ),
            PoseLandmark(
              name: PoseLandmarkNames.leftHip,
              x: 0.5,
              y: 0.72,
              z: 0,
              confidence: 1.0,
            ),
            PoseLandmark(
              name: PoseLandmarkNames.leftKnee,
              x: 0.42,
              y: 0.72,
              z: 0,
              confidence: 1.0,
            ),
            PoseLandmark(
              name: PoseLandmarkNames.leftAnkle,
              x: 0.35,
              y: 0.92,
              z: 0,
              confidence: 1.0,
            ),
          ],
          // Knees caving in, seen front-on.
          [
            PoseLandmark(
              name: PoseLandmarkNames.leftShoulder,
              x: 0.4,
              y: 0.3,
              z: 0,
              confidence: 1.0,
            ),
            PoseLandmark(
              name: PoseLandmarkNames.rightShoulder,
              x: 0.6,
              y: 0.3,
              z: 0,
              confidence: 1.0,
            ),
            PoseLandmark(
              name: PoseLandmarkNames.leftHip,
              x: 0.42,
              y: 0.65,
              z: 0,
              confidence: 1.0,
            ),
            PoseLandmark(
              name: PoseLandmarkNames.rightHip,
              x: 0.58,
              y: 0.65,
              z: 0,
              confidence: 1.0,
            ),
            PoseLandmark(
              name: PoseLandmarkNames.leftKnee,
              x: 0.47,
              y: 0.75,
              z: 0,
              confidence: 1.0,
            ),
            PoseLandmark(
              name: PoseLandmarkNames.rightKnee,
              x: 0.53,
              y: 0.75,
              z: 0,
              confidence: 1.0,
            ),
            PoseLandmark(
              name: PoseLandmarkNames.leftAnkle,
              x: 0.4,
              y: 0.9,
              z: 0,
              confidence: 1.0,
            ),
            PoseLandmark(
              name: PoseLandmarkNames.rightAnkle,
              x: 0.6,
              y: 0.9,
              z: 0,
              confidence: 1.0,
            ),
          ],
        ];

        final analysis = formService.analyzeSet(
          exerciseName: 'Squat',
          frames: badSquatFrames,
        );

        expect(analysis.formScore, lessThan(80));
        expect(analysis.repCount, 0);
        expect(
          analysis.detectedMistakes.any(
            (m) => m.contains('short of full range'),
          ),
          isTrue,
        );
        expect(
          analysis.corrections.any((c) => c.contains('Squat deeper')),
          isTrue,
        );
        expect(
          analysis.detectedMistakes.any((m) => m.contains('forward lean')),
          isTrue,
        );
        expect(
          analysis.detectedMistakes.any((m) => m.contains('caving inward')),
          isTrue,
        );
        expect(analysis.corrections, isNotEmpty);
      },
    );

    test(
      '7. Video processing progress tracking and injected frames pipeline',
      () async {
        final progressUpdates = <VideoProcessingProgress>[];

        // Prepare 12 injected frames simulating 1 rep
        final testFrames = <List<PoseLandmark>>[];
        for (int i = 0; i < 12; i++) {
          final progress = i < 6 ? (i / 5.0) : (1.0 - ((i - 6) / 5.0));
          testFrames.add(
            poseService.generateSimulatedLandmarks(
              exercise: 'Squat',
              phaseProgress: progress,
            ),
          );
        }

        final analysis = await videoService.processVideo(
          exerciseName: 'Squat',
          injectedFrames: testFrames,
          onProgress: (p) => progressUpdates.add(p),
        );

        expect(analysis.exerciseName, 'Squat');
        expect(analysis.formScore, greaterThan(0));
        expect(progressUpdates, isNotEmpty);
        expect(progressUpdates.last.currentFrame, testFrames.length);
        expect(analysis.metrics['durationSeconds'], isNotNull);
        expect(analysis.metrics['confidencePercentage'], isNotNull);
      },
    );
  });
}
