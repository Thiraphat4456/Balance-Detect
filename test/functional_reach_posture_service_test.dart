import 'package:balance_detect/features/functional_reach/domain/functional_reach_instructions.dart';
import 'package:balance_detect/features/functional_reach/domain/functional_reach_posture_service.dart';
import 'package:balance_detect/features/pose/domain/pose_frame.dart';
import 'package:balance_detect/features/pose/domain/pose_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = FunctionalReachPostureService();

  test('all Functional Reach prompts consistently require one arm', () {
    for (final prompt in FunctionalReachInstructions.allSingleArmPrompts) {
      expect(prompt, isNot(contains('แขนทั้งสองข้าง')));
    }
    expect(
      FunctionalReachInstructions.positioningVoice,
      contains('ยกเฉพาะแขนฝั่งที่หันเข้ากล้อง'),
    );
    expect(
      FunctionalReachInstructions.positioningVoice,
      contains('ปล่อยแขนอีกข้างไว้ข้างลำตัว'),
    );
  });

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
    expect(result.reachPointVisible, isTrue);
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
    expect(result.reachPointVisible, isTrue);
    expect(result.canMeasure, isTrue);
  });

  test('accepts shoulder-elbow geometry when the wrist is not in frame', () {
    final result = service.validate(
      _frameWithoutWrist(
        hip: const NormalizedPoint(x: .40, y: .70, confidence: .95),
        shoulder: const NormalizedPoint(x: .40, y: .45, confidence: .95),
        elbow: const NormalizedPoint(x: .60, y: .45, confidence: .95),
      ),
      PrimaryBodySide.left,
    );

    expect(result.landmarksReliable, isTrue);
    expect(result.armPerpendicularToTorso, isTrue);
    expect(result.reachPointVisible, isFalse);
    expect(result.canMeasure, isTrue);
    expect(result.guidance, contains('ข้อมือ'));
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
    expect(result.guidance, contains('ยกแขนฝั่งกล้องไปด้านหน้า'));
    expect(result.guidance, isNot(contains('ทั้งสองข้าง')));
    expect(result.guidance, contains('ตั้งฉากกับลำตัว'));
    expect(result.guidance, contains('ไม่ต้องยกสูงกว่าระดับไหล่'));
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
    expect(result.guidance, contains('เหยียดข้อศอกฝั่งกล้อง'));
    expect(result.guidance, isNot(contains('ทั้งสองข้าง')));
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

  test('validates only the tracked arm when the hidden arm is distorted', () {
    final frame = _frameWithDistortedHiddenArm();

    final tracked = service.validate(frame, PrimaryBodySide.right);
    final hidden = service.validate(frame, PrimaryBodySide.left);

    expect(tracked.armToTorsoAngleDegrees, closeTo(90, .001));
    expect(tracked.canMeasure, isTrue);
    expect(hidden.armToTorsoAngleDegrees, greaterThan(105));
    expect(hidden.canMeasure, isFalse);
  });

  test('pose validation keeps an explicitly locked camera-side arm', () {
    final frame = _bothSidesFrame();
    const poseValidationService = PoseValidationService();

    final automatic = poseValidationService.validate(
      frame,
      requireSideView: false,
    );
    final locked = poseValidationService.validate(
      frame,
      requireSideView: false,
      trackedSide: PrimaryBodySide.left,
    );

    expect(automatic.primarySide, PrimaryBodySide.right);
    expect(locked.primarySide, PrimaryBodySide.left);
  });

  test('pose positioning can use shoulder and elbow without a wrist', () {
    final source = _bothSidesFrame();
    final landmarks = Map<BodyLandmark, NormalizedPoint>.of(source.landmarks)
      ..remove(BodyLandmark.leftWrist);
    final frame = PoseFrame(
      timestamp: source.timestamp,
      imageAspectRatio: source.imageAspectRatio,
      landmarks: landmarks,
    );
    const poseValidationService = PoseValidationService();

    final validation = poseValidationService.validate(
      frame,
      requireSideView: false,
      trackedSide: PrimaryBodySide.left,
      requireWristForArm: false,
    );

    expect(validation.armVisible, isTrue);
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

PoseFrame _frameWithoutWrist({
  required NormalizedPoint hip,
  required NormalizedPoint shoulder,
  required NormalizedPoint elbow,
}) => PoseFrame(
  timestamp: Duration.zero,
  imageAspectRatio: 2 / 3,
  landmarks: <BodyLandmark, NormalizedPoint>{
    BodyLandmark.leftHip: hip,
    BodyLandmark.leftShoulder: shoulder,
    BodyLandmark.leftElbow: elbow,
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

PoseFrame _frameWithDistortedHiddenArm() => const PoseFrame(
  timestamp: Duration.zero,
  imageAspectRatio: 2 / 3,
  landmarks: <BodyLandmark, NormalizedPoint>{
    // The left arm is behind the torso. ML Kit can report a high in-frame
    // likelihood while placing its elbow and wrist above the shoulder.
    BodyLandmark.leftHip: NormalizedPoint(x: .40, y: .70, confidence: .90),
    BodyLandmark.leftShoulder: NormalizedPoint(x: .40, y: .40, confidence: .90),
    BodyLandmark.leftElbow: NormalizedPoint(x: .60, y: .20, confidence: .90),
    BodyLandmark.leftWrist: NormalizedPoint(x: .75, y: .05, confidence: .90),
    // The right arm is the camera-side arm and is correctly horizontal.
    BodyLandmark.rightHip: NormalizedPoint(x: .42, y: .70, confidence: .95),
    BodyLandmark.rightShoulder: NormalizedPoint(
      x: .42,
      y: .40,
      confidence: .95,
    ),
    BodyLandmark.rightElbow: NormalizedPoint(x: .70, y: .40, confidence: .95),
    BodyLandmark.rightWrist: NormalizedPoint(x: .90, y: .40, confidence: .95),
  },
);
