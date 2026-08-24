import 'dart:async';
import 'dart:io';

import 'package:balance_detect/core/constants/assessment_config.dart';
import 'package:balance_detect/core/errors/user_facing_exception.dart';
import 'package:balance_detect/core/logging/app_logger.dart';
import 'package:balance_detect/features/pose/domain/pose_frame.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';

class PoseDebugMetrics {
  const PoseDebugMetrics({
    required this.framesPerSecond,
    required this.poseConfidence,
    required this.processingMilliseconds,
  });

  final double framesPerSecond;
  final double poseConfidence;
  final int processingMilliseconds;
}

abstract interface class CameraPoseService {
  CameraController? get cameraController;
  Stream<PoseFrame> get frames;
  Stream<Object> get errors;
  Stream<PoseDebugMetrics> get debugMetrics;
  Future<void> initialize();
  Future<void> dispose();
}

class MlKitCameraPoseService implements CameraPoseService {
  MlKitCameraPoseService()
    : _poseDetector = PoseDetector(
        options: PoseDetectorOptions(
          model: PoseDetectionModel.base,
          mode: PoseDetectionMode.stream,
        ),
      );

  final PoseDetector _poseDetector;
  final StreamController<PoseFrame> _frameController =
      StreamController<PoseFrame>.broadcast();
  final StreamController<Object> _errorController =
      StreamController<Object>.broadcast();
  final StreamController<PoseDebugMetrics> _metricsController =
      StreamController<PoseDebugMetrics>.broadcast();
  final Stopwatch _sessionClock = Stopwatch();
  final Stopwatch _fpsClock = Stopwatch();
  CameraController? _cameraController;
  CameraDescription? _camera;
  bool _processing = false;
  bool _disposed = false;
  Duration _lastProcessedAt = Duration.zero;
  int _processedFrameCount = 0;

  static const _orientations = <DeviceOrientation, int>{
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  @override
  CameraController? get cameraController => _cameraController;

  @override
  Stream<PoseFrame> get frames => _frameController.stream;

  @override
  Stream<Object> get errors => _errorController.stream;

  @override
  Stream<PoseDebugMetrics> get debugMetrics => _metricsController.stream;

  @override
  Future<void> initialize() async {
    if (_disposed) throw StateError('Camera service has been disposed');
    final permission = await Permission.camera.request();
    if (!permission.isGranted) {
      throw UserFacingException(
        permission.isPermanentlyDenied
            ? 'ปิดสิทธิ์กล้องอยู่ กรุณาเปิดสิทธิ์ในการตั้งค่าอุปกรณ์'
            : 'ต้องอนุญาตใช้กล้องเพื่อประเมินท่าทาง',
        canOpenSettings: permission.isPermanentlyDenied,
      );
    }
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      throw const UserFacingException('ไม่พบกล้องบนอุปกรณ์นี้');
    }
    _camera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
    final controller = CameraController(
      _camera!,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );
    _cameraController = controller;
    await controller.initialize();
    _sessionClock
      ..reset()
      ..start();
    _fpsClock
      ..reset()
      ..start();
    await controller.startImageStream(_onCameraImage);
  }

  void _onCameraImage(CameraImage image) {
    final now = _sessionClock.elapsed;
    if (_processing ||
        now - _lastProcessedAt < AssessmentConfig.cameraFrameInterval) {
      return;
    }
    _processing = true;
    _lastProcessedAt = now;
    unawaited(_processImage(image));
  }

  Future<void> _processImage(CameraImage image) async {
    final processingClock = Stopwatch()..start();
    try {
      final converted = _toInputImage(image);
      if (converted == null) return;
      final poses = await _poseDetector.processImage(converted.inputImage);
      final frame = poses.isEmpty
          ? PoseFrame(
              timestamp: _sessionClock.elapsed,
              landmarks: const {},
              imageAspectRatio:
                  converted.orientedWidth / converted.orientedHeight,
            )
          : _toPoseFrame(
              poses.first,
              converted.orientedWidth,
              converted.orientedHeight,
            );
      if (!_disposed) _frameController.add(frame);
      _processedFrameCount += 1;
      final fpsSeconds = _fpsClock.elapsedMilliseconds / 1000;
      if (fpsSeconds >= 1) {
        final confidence = frame.landmarks.isEmpty
            ? 0.0
            : frame.landmarks.values
                      .map((point) => point.confidence)
                      .reduce((a, b) => a + b) /
                  frame.landmarks.length;
        if (!_disposed) {
          _metricsController.add(
            PoseDebugMetrics(
              framesPerSecond: _processedFrameCount / fpsSeconds,
              poseConfidence: confidence,
              processingMilliseconds: processingClock.elapsedMilliseconds,
            ),
          );
        }
        _processedFrameCount = 0;
        _fpsClock
          ..reset()
          ..start();
      }
    } catch (error) {
      AppLogger.error('pose_processing_error', error);
      if (!_disposed) _errorController.add(error);
    } finally {
      _processing = false;
    }
  }

  _ConvertedInputImage? _toInputImage(CameraImage image) {
    final controller = _cameraController;
    final camera = _camera;
    if (controller == null || camera == null || image.planes.length != 1) {
      return null;
    }
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else {
      var compensation = _orientations[controller.value.deviceOrientation];
      if (compensation == null) return null;
      compensation = camera.lensDirection == CameraLensDirection.front
          ? (sensorOrientation + compensation) % 360
          : (sensorOrientation - compensation + 360) % 360;
      rotation = InputImageRotationValue.fromRawValue(compensation);
    }
    if (rotation == null) return null;
    final plane = image.planes.single;
    // CameraX may label a requested NV21 stream as yuv420 while returning a
    // single NV21 plane. ML Kit requires the actual byte layout here.
    final format = Platform.isAndroid
        ? InputImageFormat.nv21
        : InputImageFormat.bgra8888;
    final input = InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
    final swapsAxes =
        rotation == InputImageRotation.rotation90deg ||
        rotation == InputImageRotation.rotation270deg;
    return _ConvertedInputImage(
      inputImage: input,
      orientedWidth: swapsAxes
          ? image.height.toDouble()
          : image.width.toDouble(),
      orientedHeight: swapsAxes
          ? image.width.toDouble()
          : image.height.toDouble(),
    );
  }

  PoseFrame _toPoseFrame(Pose pose, double width, double height) {
    final mapped = <BodyLandmark, NormalizedPoint>{};
    for (final entry in _landmarkMap.entries) {
      final landmark = pose.landmarks[entry.key];
      if (landmark == null) continue;
      var x = (landmark.x / width).clamp(0.0, 1.0);
      final y = (landmark.y / height).clamp(0.0, 1.0);
      if (_camera?.lensDirection == CameraLensDirection.front) x = 1 - x;
      mapped[entry.value] = NormalizedPoint(
        x: x,
        y: y,
        confidence: landmark.likelihood.clamp(0.0, 1.0),
      );
    }
    return PoseFrame(
      timestamp: _sessionClock.elapsed,
      landmarks: mapped,
      imageAspectRatio: width / height,
    );
  }

  static const _landmarkMap = <PoseLandmarkType, BodyLandmark>{
    PoseLandmarkType.leftShoulder: BodyLandmark.leftShoulder,
    PoseLandmarkType.rightShoulder: BodyLandmark.rightShoulder,
    PoseLandmarkType.leftElbow: BodyLandmark.leftElbow,
    PoseLandmarkType.rightElbow: BodyLandmark.rightElbow,
    PoseLandmarkType.leftWrist: BodyLandmark.leftWrist,
    PoseLandmarkType.rightWrist: BodyLandmark.rightWrist,
    PoseLandmarkType.leftHip: BodyLandmark.leftHip,
    PoseLandmarkType.rightHip: BodyLandmark.rightHip,
    PoseLandmarkType.leftKnee: BodyLandmark.leftKnee,
    PoseLandmarkType.rightKnee: BodyLandmark.rightKnee,
    PoseLandmarkType.leftAnkle: BodyLandmark.leftAnkle,
    PoseLandmarkType.rightAnkle: BodyLandmark.rightAnkle,
    PoseLandmarkType.leftHeel: BodyLandmark.leftHeel,
    PoseLandmarkType.rightHeel: BodyLandmark.rightHeel,
    PoseLandmarkType.leftFootIndex: BodyLandmark.leftFootIndex,
    PoseLandmarkType.rightFootIndex: BodyLandmark.rightFootIndex,
  };

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _sessionClock.stop();
    _fpsClock.stop();
    final controller = _cameraController;
    _cameraController = null;
    if (controller?.value.isStreamingImages ?? false) {
      await controller?.stopImageStream();
    }
    await controller?.dispose();
    await _poseDetector.close();
    await _frameController.close();
    await _errorController.close();
    await _metricsController.close();
  }
}

class _ConvertedInputImage {
  const _ConvertedInputImage({
    required this.inputImage,
    required this.orientedWidth,
    required this.orientedHeight,
  });

  final InputImage inputImage;
  final double orientedWidth;
  final double orientedHeight;
}
