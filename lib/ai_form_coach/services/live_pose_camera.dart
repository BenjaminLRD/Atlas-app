import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart'
    as ml;
import '../models/pose_landmark.dart';
import 'pose_detection_service.dart';

/// Streams camera frames into ML Kit pose detection on the device.
///
/// Landmarks are reported normalised (0–1) to the upright camera image, the
/// same space the preview shows, so they can be drawn straight over it.
/// Frames that arrive while one is still being processed are dropped, which
/// keeps latency low on slower phones. Video never leaves the device.
class LivePoseCamera {
  CameraController? _controller;
  CameraDescription? _camera;
  ml.PoseDetector? _detector;
  bool _busy = false;
  void Function(List<PoseLandmark> landmarks)? _onLandmarks;

  CameraController? get controller => _controller;
  bool get isRunning => _controller?.value.isStreamingImages ?? false;
  bool get isFrontCamera => _camera?.lensDirection == CameraLensDirection.front;

  /// Live tracking needs a phone camera and ML Kit (Android or iOS).
  static bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Opens the camera and starts sending landmarks to [onLandmarks].
  /// Throws [CameraException] when no camera is available or access is
  /// denied.
  Future<void> start({
    bool front = false,
    required void Function(List<PoseLandmark> landmarks) onLandmarks,
  }) async {
    await stop();
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      throw CameraException('noCamera', 'No camera found on this device.');
    }
    final wanted = front ? CameraLensDirection.front : CameraLensDirection.back;
    final camera = cameras.firstWhere(
      (c) => c.lensDirection == wanted,
      orElse: () => cameras.first,
    );

    final controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );
    await controller.initialize();

    _camera = camera;
    _controller = controller;
    _onLandmarks = onLandmarks;
    _detector = ml.PoseDetector(
      options: ml.PoseDetectorOptions(
        mode: ml.PoseDetectionMode.stream,
        model: ml.PoseDetectionModel.base,
      ),
    );
    await controller.startImageStream(_onImage);
  }

  /// Stops the stream and releases the camera and detector.
  Future<void> stop() async {
    final controller = _controller;
    _controller = null;
    _onLandmarks = null;
    if (controller != null) {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
      await controller.dispose();
    }
    await _detector?.close();
    _detector = null;
    _busy = false;
  }

  Future<void> _onImage(CameraImage image) async {
    final detector = _detector;
    if (_busy || detector == null) return;
    final input = _toInputImage(image);
    if (input == null) return;

    _busy = true;
    try {
      final poses = await detector.processImage(input);
      final upright = _uprightSize(image, input.metadata!.rotation);
      final landmarks = poses.isEmpty
          ? <PoseLandmark>[]
          : PoseDetectionService.instance
                .selectPrimaryPose(poses)
                .landmarks
                .values
                .map(
                  (l) => PoseLandmark.fromMlKit(
                    l,
                    imageWidth: upright.width,
                    imageHeight: upright.height,
                  ),
                )
                .toList();
      _onLandmarks?.call(landmarks);
    } catch (e) {
      debugPrint('LivePoseCamera frame skipped: $e');
    } finally {
      _busy = false;
    }
  }

  static const Map<DeviceOrientation, int> _orientationDegrees = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  /// Converts a camera frame to ML Kit input, following ML Kit's guidance
  /// for rotation and pixel format per platform.
  ml.InputImage? _toInputImage(CameraImage image) {
    final camera = _camera;
    final controller = _controller;
    if (camera == null || controller == null) return null;

    final sensor = camera.sensorOrientation;
    ml.InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = ml.InputImageRotationValue.fromRawValue(sensor);
    } else {
      final device = _orientationDegrees[controller.value.deviceOrientation];
      if (device == null) return null;
      final degrees = camera.lensDirection == CameraLensDirection.front
          ? (sensor + device) % 360
          : (sensor - device + 360) % 360;
      rotation = ml.InputImageRotationValue.fromRawValue(degrees);
    }
    if (rotation == null) return null;

    final format = ml.InputImageFormatValue.fromRawValue(image.format.raw);
    final expected = Platform.isAndroid
        ? ml.InputImageFormat.nv21
        : ml.InputImageFormat.bgra8888;
    if (format != expected || image.planes.length != 1) return null;

    final plane = image.planes.first;
    return ml.InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: ml.InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format!,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  /// ML Kit reports coordinates in the upright image, whose width and height
  /// swap when the frame is rotated by 90° or 270°.
  static Size _uprightSize(CameraImage image, ml.InputImageRotation rotation) {
    final swapped =
        rotation == ml.InputImageRotation.rotation90deg ||
        rotation == ml.InputImageRotation.rotation270deg;
    return swapped
        ? Size(image.height.toDouble(), image.width.toDouble())
        : Size(image.width.toDouble(), image.height.toDouble());
  }
}
