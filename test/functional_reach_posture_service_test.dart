import 'package:balance_detect/features/functional_reach/domain/functional_reach_posture_service.dart';
import 'package:balance_detect/features/pose/domain/pose_frame.dart';
import 'package:balance_detect/features/pose/domain/pose_validation.dart';
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

    expect(result.armToTorsoAngleDegrees, closeTo(90, .001));
    expect(result.elbowAngleDegrees, closeTo(180, .001));
    expect(result.canMeasure, isTrue);
  });

  test('accepts an upper arm perpendicular to a tilted torso', () {
    final result = service.validate(
      _frame(
        hip: const NormalizedPoint(x: .55, y: .60, confidence: .95),
        shoulder: const NormalizedPoint(x: .40, y: .40, confidence: .95),
        elbow: const NormalizedPoint(x: .70, y: .30, confidence: .95),
        wrist: const NormalizedPoint(x: .94, y: .22, confidence: .95),
      ),
      PrimaryBodySide.left,
    );

    expect(result.armToTorsoAngleDegrees, closeTo(90, .001));
    expect(result.elbowAngleDegrees, closeTo(180, .001));
    expect(result.canMeasure, isTrue);
  });

  test('guides a low arm forward without asking above shoulder level', () {
    final result = service.validate(
      _frame(
        hip: const NormalizedPoint(x: .40, y: .70, confidence: .95),
        shoulder: const NormalizedPoint(x: .40, y: .45, confidence: .95),
        elbow: const NormalizedPoint(x: .50, y: .62, confidence: .95),
        wrist: const NormalizedPoint(x: .60, y: .70, confidence: .95),
      ),
      PrimaryBodySide.left,
    );

    expect(result.armPerpendicularToTorso, isFalse);
    expect(result.guidance, contains('เหยียดต้นแขนไปด้านหน้า'));
    expect(result.guidance, contains('ตั้งฉากกับลำตัว'));
    expect(result.guidance, contains('ไม่ต้องยกเหนือระดับไหล่'));
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

    expect(result.armPerpendicularToTorso, isTrue);
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

  test('uses the raised arm when the hanging side has higher confidence', () {
    final frame = _bothSidesFrame();
    const poseValidationService = PoseValidationService();
    final poseValidation = poseValidationService.validate(
      frame,
      requireSideView: true,
    );

    // Whole-body confidence favors the right side because its legs and feet
    // are clearer, even though the participant is intentionally raising the
    // left arm for Functional Reach.
    expect(poseValidation.primarySide, PrimaryBodySide.right);
    final raisedArm = service.validate(frame, PrimaryBodySide.left);
    expect(raisedArm.armToTorsoAngleDegrees, greaterThan(105));
    expect(raisedArm.guidance, contains('ลดต้นแขนลง'));

    final selectedSide = service.selectRaisedArmSide(
      frame,
      fallback: poseValidation.primarySide,
    );
    expect(selectedSide, PrimaryBodySide.left);
    final selectedArm = service.validate(frame, selectedSide);
    expect(selectedArm.guidance, contains('ลดต้นแขนลง'));
  });

  test('keeps the fallback side when both arm angles are nearly equal', () {
    final frame = _frameWithSimilarArmAngles();

    expect(
      service.selectRaisedArmSide(frame, fallback: PrimaryBodySide.right),
      PrimaryBodySide.right,
    );
  });

  test('does not switch sides while both arms remain low', () {
    final frame = _frameWithUnevenLowArms();

    expect(
      service.selectRaisedArmSide(frame, fallback: PrimaryBodySide.right),
      PrimaryBodySide.right,
    );
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

PoseFrame _bothSidesFrame() => const PoseFrame(
  timestamp: Duration.zero,
  imageAspectRatio: 2 / 3,
  landmarks: <BodyLandmark, NormalizedPoint>{
    BodyLandmark.leftShoulder: NormalizedPoint(x: .40, y: .40, confidence: .82),
    BodyLandmark.leftElbow: NormalizedPoint(x: .70, y: .30, confidence: .82),
    BodyLandmark.leftWrist: NormalizedPoint(x: .94, y: .22, confidence: .82),
    BodyLandmark.leftHip: NormalizedPoint(x: .42, y: .65, confidence: .82),
    BodyLandmark.leftKnee: NormalizedPoint(x: .43, y: .82, confidence: .60),
    BodyLandmark.leftAnkle: NormalizedPoint(x: .44, y: .95, confidence: .60),
    BodyLandmark.leftHeel: NormalizedPoint(x: .42, y: .96, confidence: .60),
    BodyLandmark.leftFootIndex: NormalizedPoint(
      x: .48,
      y: .97,
      confidence: .60,
    ),
    BodyLandmark.rightShoulder: NormalizedPoint(
      x: .42,
      y: .40,
      confidence: .97,
    ),
    BodyLandmark.rightElbow: NormalizedPoint(x: .46, y: .58, confidence: .97),
    BodyLandmark.rightWrist: NormalizedPoint(x: .48, y: .78, confidence: .97),
    BodyLandmark.rightHip: NormalizedPoint(x: .44, y: .65, confidence: .97),
    BodyLandmark.rightKnee: NormalizedPoint(x: .45, y: .82, confidence: .97),
    BodyLandmark.rightAnkle: NormalizedPoint(x: .46, y: .95, confidence: .97),
    BodyLandmark.rightHeel: NormalizedPoint(x: .44, y: .96, confidence: .97),
    BodyLandmark.rightFootIndex: NormalizedPoint(
      x: .50,
      y: .97,
      confidence: .97,
    ),
  },
);

PoseFrame _frameWithSimilarArmAngles() => const PoseFrame(
  timestamp: Duration.zero,
  imageAspectRatio: 2 / 3,
  landmarks: <BodyLandmark, NormalizedPoint>{
    BodyLandmark.leftShoulder: NormalizedPoint(x: .40, y: .40, confidence: .95),
    BodyLandmark.leftElbow: NormalizedPoint(x: .68, y: .40, confidence: .95),
    BodyLandmark.leftHip: NormalizedPoint(x: .40, y: .65, confidence: .95),
    BodyLandmark.rightShoulder: NormalizedPoint(
      x: .42,
      y: .40,
      confidence: .95,
    ),
    BodyLandmark.rightElbow: NormalizedPoint(x: .70, y: .38, confidence: .95),
    BodyLandmark.rightHip: NormalizedPoint(x: .42, y: .65, confidence: .95),
  },
);

PoseFrame _frameWithUnevenLowArms() => const PoseFrame(
  timestamp: Duration.zero,
  imageAspectRatio: 2 / 3,
  landmarks: <BodyLandmark, NormalizedPoint>{
    BodyLandmark.leftShoulder: NormalizedPoint(x: .40, y: .40, confidence: .95),
    BodyLandmark.leftElbow: NormalizedPoint(x: .55, y: .55, confidence: .95),
    BodyLandmark.leftHip: NormalizedPoint(x: .40, y: .65, confidence: .95),
    BodyLandmark.rightShoulder: NormalizedPoint(
      x: .42,
      y: .40,
      confidence: .95,
    ),
    BodyLandmark.rightElbow: NormalizedPoint(x: .44, y: .62, confidence: .95),
    BodyLandmark.rightHip: NormalizedPoint(x: .42, y: .65, confidence: .95),
  },
);
