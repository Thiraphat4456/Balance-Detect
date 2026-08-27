import 'package:balance_detect/features/functional_reach/domain/functional_reach_posture_service.dart';
import 'package:balance_detect/features/pose/domain/pose_frame.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = FunctionalReachPostureService();

  test('accepts a horizontal upper arm with an extended elbow', () {
    final result = service.validate(
      _frame(
        hip: const NormalizedPoint(x: .40, y: .70, confidence: .95),
        shoulder: const NormalizedPoint(x: .40, y: .45, confidence: .95),
        elbow: const NormalizedPoint(x: .60, y: .45, confidence: .95),
        wrist: const NormalizedPoint(x: .78, y: .45, confidence: .95),
      ),
      PrimaryBodySide.left,
    );

    expect(result.shoulderAngleDegrees, closeTo(90, .001));
    expect(result.elbowAngleDegrees, closeTo(180, .001));
    expect(result.canMeasure, isTrue);
  });

  test('asks the user to raise an arm that is too low', () {
    final result = service.validate(
      _frame(
        hip: const NormalizedPoint(x: .40, y: .70, confidence: .95),
        shoulder: const NormalizedPoint(x: .40, y: .45, confidence: .95),
        elbow: const NormalizedPoint(x: .50, y: .62, confidence: .95),
        wrist: const NormalizedPoint(x: .60, y: .70, confidence: .95),
      ),
      PrimaryBodySide.left,
    );

    expect(result.shoulderReady, isFalse);
    expect(result.guidance, contains('ยกแขนขึ้น'));
    expect(result.canMeasure, isFalse);
  });

  test('rejects a bent elbow even when the upper arm is horizontal', () {
    final result = service.validate(
      _frame(
        hip: const NormalizedPoint(x: .40, y: .70, confidence: .95),
        shoulder: const NormalizedPoint(x: .40, y: .45, confidence: .95),
        elbow: const NormalizedPoint(x: .60, y: .45, confidence: .95),
        wrist: const NormalizedPoint(x: .60, y: .62, confidence: .95),
      ),
      PrimaryBodySide.left,
    );

    expect(result.shoulderReady, isTrue);
    expect(result.elbowExtended, isFalse);
    expect(result.guidance, contains('เหยียดข้อศอก'));
    expect(result.canMeasure, isFalse);
  });

  test('does not approve low-confidence landmarks', () {
    final result = service.validate(
      _frame(
        hip: const NormalizedPoint(x: .40, y: .70, confidence: .95),
        shoulder: const NormalizedPoint(x: .40, y: .45, confidence: .95),
        elbow: const NormalizedPoint(x: .60, y: .45, confidence: .40),
        wrist: const NormalizedPoint(x: .78, y: .45, confidence: .95),
      ),
      PrimaryBodySide.left,
    );

    expect(result.landmarksReliable, isFalse);
    expect(result.canMeasure, isFalse);
  });
}

PoseFrame _frame({
  required NormalizedPoint hip,
  required NormalizedPoint shoulder,
  required NormalizedPoint elbow,
  required NormalizedPoint wrist,
}) => PoseFrame(
  timestamp: Duration.zero,
  imageAspectRatio: 2 / 3,
  landmarks: <BodyLandmark, NormalizedPoint>{
    BodyLandmark.leftHip: hip,
    BodyLandmark.leftShoulder: shoulder,
    BodyLandmark.leftElbow: elbow,
    BodyLandmark.leftWrist: wrist,
  },
);
