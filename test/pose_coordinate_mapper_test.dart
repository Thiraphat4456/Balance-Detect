import 'package:balance_detect/features/pose/domain/pose_coordinate_mapper.dart';
import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

void main() {
  const mapper = PoseCoordinateMapper();

  test('maps a 270-degree Android frame with the preview mirror', () {
    final point = mapper.map(
      x: 120,
      y: 60,
      imageWidth: 720,
      imageHeight: 480,
      rotation: InputImageRotation.rotation270deg,
      lensDirection: CameraLensDirection.front,
    );

    // ML Kit returns the rotated coordinate space (480 x 720) on Android.
    expect(point.x, closeTo(.75, .0001));
    expect(point.y, closeTo(60 / 720, .0001));
    expect(point.width, 480);
    expect(point.height, 720);
  });

  test('does not mirror a 90-degree Android frame twice', () {
    final point = mapper.map(
      x: 120,
      y: 60,
      imageWidth: 720,
      imageHeight: 480,
      rotation: InputImageRotation.rotation90deg,
      lensDirection: CameraLensDirection.front,
    );

    expect(point.x, closeTo(120 / 480, .0001));
    expect(point.y, closeTo(60 / 720, .0001));
  });

  test('mirrors a zero-degree front frame but not a back frame', () {
    final front = mapper.map(
      x: 120,
      y: 60,
      imageWidth: 720,
      imageHeight: 480,
      rotation: InputImageRotation.rotation0deg,
      lensDirection: CameraLensDirection.front,
    );
    final back = mapper.map(
      x: 120,
      y: 60,
      imageWidth: 720,
      imageHeight: 480,
      rotation: InputImageRotation.rotation0deg,
      lensDirection: CameraLensDirection.back,
    );

    expect(front.x, closeTo(1 - 120 / 720, .0001));
    expect(back.x, closeTo(120 / 720, .0001));
    expect(front.y, closeTo(60 / 480, .0001));
    expect(back.y, closeTo(60 / 480, .0001));
  });
}
