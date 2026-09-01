import 'dart:math' as math;

enum BodyLandmark {
  leftShoulder,
  rightShoulder,
  leftElbow,
  rightElbow,
  leftWrist,
  rightWrist,
  leftIndex,
  rightIndex,
  leftHip,
  rightHip,
  leftKnee,
  rightKnee,
  leftAnkle,
  rightAnkle,
  leftHeel,
  rightHeel,
  leftFootIndex,
  rightFootIndex,
}

class NormalizedPoint {
  const NormalizedPoint({
    required this.x,
    required this.y,
    required this.confidence,
  });

  final double x;
  final double y;
  final double confidence;

  double distanceTo(NormalizedPoint other) => math.sqrt(
    math.pow(x - other.x, 2).toDouble() + math.pow(y - other.y, 2).toDouble(),
  );

  static NormalizedPoint average(Iterable<NormalizedPoint> points) {
    final values = points.toList(growable: false);
    if (values.isEmpty) {
      throw ArgumentError.value(points, 'points', 'ต้องมีอย่างน้อยหนึ่งจุด');
    }
    return NormalizedPoint(
      x: values.fold(0.0, (sum, point) => sum + point.x) / values.length,
      y: values.fold(0.0, (sum, point) => sum + point.y) / values.length,
      confidence:
          values.fold(0.0, (sum, point) => sum + point.confidence) /
          values.length,
    );
  }
}

class PoseFrame {
  const PoseFrame({
    required this.timestamp,
    required this.landmarks,
    this.imageAspectRatio = 1.0,
  });

  final Duration timestamp;
  final Map<BodyLandmark, NormalizedPoint> landmarks;

  /// Width divided by height after applying the camera rotation.
  ///
  /// Coordinates are normalized independently by width and height, so metric
  /// calculations must retain this value to avoid mixing the two axes.
  final double imageAspectRatio;

  NormalizedPoint? operator [](BodyLandmark landmark) => landmarks[landmark];
}

enum PrimaryBodySide { left, right }

extension PrimaryBodySideLandmarks on PrimaryBodySide {
  BodyLandmark get shoulder => this == PrimaryBodySide.left
      ? BodyLandmark.leftShoulder
      : BodyLandmark.rightShoulder;
  BodyLandmark get elbow => this == PrimaryBodySide.left
      ? BodyLandmark.leftElbow
      : BodyLandmark.rightElbow;
  BodyLandmark get wrist => this == PrimaryBodySide.left
      ? BodyLandmark.leftWrist
      : BodyLandmark.rightWrist;
  BodyLandmark get indexFinger => this == PrimaryBodySide.left
      ? BodyLandmark.leftIndex
      : BodyLandmark.rightIndex;
  BodyLandmark get hip => this == PrimaryBodySide.left
      ? BodyLandmark.leftHip
      : BodyLandmark.rightHip;
  BodyLandmark get knee => this == PrimaryBodySide.left
      ? BodyLandmark.leftKnee
      : BodyLandmark.rightKnee;
  BodyLandmark get ankle => this == PrimaryBodySide.left
      ? BodyLandmark.leftAnkle
      : BodyLandmark.rightAnkle;
  BodyLandmark get heel => this == PrimaryBodySide.left
      ? BodyLandmark.leftHeel
      : BodyLandmark.rightHeel;
  BodyLandmark get footIndex => this == PrimaryBodySide.left
      ? BodyLandmark.leftFootIndex
      : BodyLandmark.rightFootIndex;
}
