import 'dart:io';

import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Converts an ML Kit landmark coordinate to the same normalized space used
/// by [CameraPreview].
///
/// Camera image buffers are usually landscape-oriented even while the phone is
/// held upright. ML Kit applies the [InputImageRotation] metadata before it
/// returns landmark coordinates, while the camera preview applies its own
/// rotation and front-camera mirror. Treating every frame as simply
/// `x = 1 - x` therefore works for one orientation but offsets or mirrors
/// points in another orientation. This mapper follows the coordinate rules
/// used by the official google_ml_kit_flutter example.
final class PoseCoordinateMapper {
  const PoseCoordinateMapper();

  ({double x, double y, double width, double height}) map({
    required double x,
    required double y,
    required double imageWidth,
    required double imageHeight,
    required InputImageRotation rotation,
    required CameraLensDirection lensDirection,
  }) {
    final isIos = Platform.isIOS;
    final swapsAxes =
        rotation == InputImageRotation.rotation90deg ||
        rotation == InputImageRotation.rotation270deg;
    final width = swapsAxes && !isIos ? imageHeight : imageWidth;
    final height = swapsAxes && !isIos ? imageWidth : imageHeight;

    final normalizedX = switch (rotation) {
      InputImageRotation.rotation90deg =>
        x / (isIos ? imageWidth : imageHeight),
      InputImageRotation.rotation270deg =>
        1 - x / (isIos ? imageWidth : imageHeight),
      InputImageRotation.rotation0deg || InputImageRotation.rotation180deg =>
        lensDirection == CameraLensDirection.front
            ? 1 - x / imageWidth
            : x / imageWidth,
    };
    final normalizedY = switch (rotation) {
      InputImageRotation.rotation90deg || InputImageRotation.rotation270deg =>
        y / (isIos ? imageHeight : imageWidth),
      InputImageRotation.rotation0deg || InputImageRotation.rotation180deg =>
        y / imageHeight,
    };

    return (
      x: _clampNormalized(normalizedX),
      y: _clampNormalized(normalizedY),
      width: width,
      height: height,
    );
  }

  double _clampNormalized(double value) {
    if (!value.isFinite) return 0;
    return value.clamp(0.0, 1.0);
  }
}
