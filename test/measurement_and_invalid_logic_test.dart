import 'package:balance_detect/core/constants/assessment_config.dart';
import 'package:balance_detect/core/domain/assessment_enums.dart';
import 'package:balance_detect/features/assessment/domain/assessment_session.dart';
import 'package:balance_detect/features/assessment/domain/calibration_record.dart';
import 'package:balance_detect/features/assessment/domain/session_summary.dart';
import 'package:balance_detect/features/fullerton/domain/step_detection_service.dart';
import 'package:balance_detect/features/functional_reach/domain/distance_calibration_service.dart';
import 'package:balance_detect/features/functional_reach/domain/reach_measurement_service.dart';
import 'package:balance_detect/features/pose/domain/pose_frame.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('explicit calibration uses the horizontal reach axis', () {
    final record = const ExplicitDistanceCalibrationService().calibrate(
      sessionId: 'session',
      firstPoint: const NormalizedPoint(x: .2, y: .5, confidence: 1),
      secondPoint: const NormalizedPoint(x: .6, y: .51, confidence: 1),
      referenceDistanceCm: 40,
    );
    expect(record.scaleCmPerNormalizedUnit, closeTo(100, .001));
  });

  test('explicit calibration rejects a vertical reference', () {
    expect(
      () => const ExplicitDistanceCalibrationService().calibrate(
        sessionId: 'session',
        firstPoint: const NormalizedPoint(x: .2, y: .2, confidence: 1),
        secondPoint: const NormalizedPoint(x: .6, y: .7, confidence: 1),
        referenceDistanceCm: 40,
      ),
      throwsFormatException,
    );
  });

  test(
    'anthropometric calibration converts entered height into image scale',
    () {
      final record = const AnthropometricHeightCalibrationService().calibrate(
        sessionId: 'session',
        heightCm: 170,
        imageAspectRatio: .75,
        visibleSpanSamples: <double>[
          .779,
          .780,
          .780,
          .781,
          .779,
          .780,
          .780,
          .781,
          .779,
          .780,
          .780,
          .779,
        ],
      );

      expect(record.method, CalibrationMethod.anthropometricBodyHeight);
      expect(record.referenceDistanceCm, 170);
      expect(
        record.scaleCmPerNormalizedUnit,
        closeTo(
          170 *
              AssessmentConfig.anthropometricVisibleHeightFraction *
              .75 /
              .780,
          .2,
        ),
      );
      expect(record.confidence, greaterThanOrEqualTo(.9));
    },
  );

  test('anthropometric calibration rejects a moving pose', () {
    expect(
      () => const AnthropometricHeightCalibrationService().calibrate(
        sessionId: 'session',
        heightCm: 170,
        imageAspectRatio: .75,
        visibleSpanSamples: List<double>.generate(
          12,
          (index) => .70 + index * .003,
        ),
      ),
      throwsFormatException,
    );
  });

  test('Reach uses a stable multi-frame baseline and flags moved feet', () {
    final calibration = CalibrationRecord(
      id: 'calibration',
      sessionId: 'session',
      timestamp: DateTime(2026),
      scaleCmPerNormalizedUnit: 100,
      method: CalibrationMethod.explicitKnownReference,
      referenceDistanceCm: 50,
      confidence: 1,
    );
    final service = ReachMeasurementService(calibration: calibration);
    for (var index = 0; index < 12; index += 1) {
      service.addBaselineFrame(
        _poseFrame(
          timestamp: Duration(milliseconds: index * 100),
          wristX: .40,
          leftFootX: .30,
          rightFootX: .60,
        ),
        PrimaryBodySide.left,
      );
    }
    expect(service.finalizeStableBaseline(), isTrue);

    var snapshot = service.snapshot;
    for (var index = 0; index < 8; index += 1) {
      snapshot = service.addReachFrame(
        _poseFrame(
          timestamp: Duration(milliseconds: 2000 + index * 100),
          wristX: .48,
          leftFootX: .33,
          rightFootX: .60,
        ),
        PrimaryBodySide.left,
      );
    }

    expect(snapshot.maximumDistanceCm, closeTo(8, 0.001));
    expect(snapshot.footMovementDetected, isTrue);
  });

  test('Reach flags sustained movement of the right camera-side foot', () {
    final calibration = CalibrationRecord(
      id: 'calibration',
      sessionId: 'session',
      timestamp: DateTime(2026),
      scaleCmPerNormalizedUnit: 100,
      method: CalibrationMethod.explicitKnownReference,
      referenceDistanceCm: 50,
      confidence: 1,
    );
    final service = ReachMeasurementService(calibration: calibration);
    for (var index = 0; index < 12; index += 1) {
      service.addBaselineFrame(
        _poseFrame(
          timestamp: Duration(milliseconds: index * 100),
          wristX: .40,
          leftFootX: .30,
          rightFootX: .60,
        ),
        PrimaryBodySide.right,
      );
    }
    expect(service.finalizeStableBaseline(), isTrue);

    var snapshot = service.snapshot;
    for (var index = 0; index < 8; index += 1) {
      snapshot = service.addReachFrame(
        _poseFrame(
          timestamp: Duration(milliseconds: 2000 + index * 100),
          wristX: .48,
          leftFootX: .30,
          rightFootX: .63,
        ),
        PrimaryBodySide.right,
      );
    }

    expect(snapshot.trackedFootSide, PrimaryBodySide.right);
    expect(snapshot.footMovementDetected, isTrue);
  });

  test('Reach ignores small landmark drift while feet stay planted', () {
    final calibration = CalibrationRecord(
      id: 'height-calibration',
      sessionId: 'session',
      timestamp: DateTime(2026),
      scaleCmPerNormalizedUnit: 204,
      method: CalibrationMethod.anthropometricBodyHeight,
      referenceDistanceCm: 170,
      confidence: .9,
    );
    final service = ReachMeasurementService(calibration: calibration);
    for (var index = 0; index < 12; index += 1) {
      service.addBaselineFrame(
        _poseFrame(
          timestamp: Duration(milliseconds: index * 100),
          wristX: .40,
          leftFootX: .30,
          rightFootX: .60,
        ),
        PrimaryBodySide.left,
      );
    }
    expect(service.finalizeStableBaseline(), isTrue);

    var snapshot = service.snapshot;
    for (var index = 0; index < 8; index += 1) {
      snapshot = service.addReachFrame(
        _poseFrame(
          timestamp: Duration(milliseconds: 1500 + index * 100),
          wristX: .40,
          leftFootX: .311,
          rightFootX: .60,
        ),
        PrimaryBodySide.left,
      );
    }

    expect(snapshot.footMovementDetected, isFalse);
  });

  test('Reach rejects an unstable camera-side foot baseline', () {
    final calibration = CalibrationRecord(
      id: 'height-calibration',
      sessionId: 'session',
      timestamp: DateTime(2026),
      scaleCmPerNormalizedUnit: 136,
      method: CalibrationMethod.anthropometricBodyHeight,
      referenceDistanceCm: 170,
      confidence: .9,
    );
    final service = ReachMeasurementService(calibration: calibration);
    for (var index = 0; index < 12; index += 1) {
      service.addBaselineFrame(
        _poseFrame(
          timestamp: Duration(milliseconds: index * 100),
          wristX: .40,
          leftFootX: index.isEven ? .28 : .32,
          rightFootX: .60,
          imageAspectRatio: 2 / 3,
        ),
        PrimaryBodySide.left,
      );
    }

    expect(service.finalizeStableBaseline(), isFalse);
  });

  test('Reach ignores one large foot-landmark spike', () {
    final calibration = CalibrationRecord(
      id: 'height-calibration',
      sessionId: 'session',
      timestamp: DateTime(2026),
      scaleCmPerNormalizedUnit: 136,
      method: CalibrationMethod.anthropometricBodyHeight,
      referenceDistanceCm: 170,
      confidence: .9,
    );
    final service = ReachMeasurementService(calibration: calibration);
    for (var index = 0; index < 12; index += 1) {
      service.addBaselineFrame(
        _poseFrame(
          timestamp: Duration(milliseconds: index * 100),
          wristX: .40,
          leftFootX: .30,
          rightFootX: .60,
          imageAspectRatio: 2 / 3,
        ),
        PrimaryBodySide.left,
      );
    }
    expect(service.finalizeStableBaseline(), isTrue);

    service.addReachFrame(
      _poseFrame(
        timestamp: const Duration(milliseconds: 1500),
        wristX: .40,
        leftFootX: .35,
        rightFootX: .60,
        imageAspectRatio: 2 / 3,
      ),
      PrimaryBodySide.left,
    );
    final snapshot = service.addReachFrame(
      _poseFrame(
        timestamp: const Duration(milliseconds: 1600),
        wristX: .40,
        leftFootX: .30,
        rightFootX: .60,
        imageAspectRatio: 2 / 3,
      ),
      PrimaryBodySide.left,
    );

    expect(snapshot.footMovementDetected, isFalse);
  });

  test(
    'Reach ignores occluded-side foot drift when the camera-side foot is planted',
    () {
      final calibration = CalibrationRecord(
        id: 'height-calibration',
        sessionId: 'session',
        timestamp: DateTime(2026),
        scaleCmPerNormalizedUnit: 136,
        method: CalibrationMethod.anthropometricBodyHeight,
        referenceDistanceCm: 170,
        confidence: .9,
      );
      final service = ReachMeasurementService(calibration: calibration);
      for (var index = 0; index < 12; index += 1) {
        service.addBaselineFrame(
          _poseFrame(
            timestamp: Duration(milliseconds: index * 100),
            wristX: .40,
            leftFootX: .30,
            rightFootX: .60,
            imageAspectRatio: 2 / 3,
          ),
          PrimaryBodySide.left,
        );
      }
      expect(service.finalizeStableBaseline(), isTrue);

      var snapshot = service.snapshot;
      for (var index = 0; index < 8; index += 1) {
        snapshot = service.addReachFrame(
          _poseFrame(
            timestamp: Duration(milliseconds: 1500 + index * 100),
            wristX: .48,
            leftFootX: .30,
            // The far foot is occluded in a side view. Pose estimators can
            // drift this inferred landmark even when the real foot is still.
            rightFootX: .65,
            imageAspectRatio: 2 / 3,
          ),
          PrimaryBodySide.left,
        );
      }

      expect(snapshot.leftFootMovementCm, lessThan(.1));
      expect(snapshot.rightFootMovementCm, greaterThan(5));
      expect(snapshot.footMovementDetected, isFalse);
    },
  );

  test('Reach does not treat ankle strategy as planted-foot movement', () {
    final calibration = CalibrationRecord(
      id: 'height-calibration',
      sessionId: 'session',
      timestamp: DateTime(2026),
      scaleCmPerNormalizedUnit: 136,
      method: CalibrationMethod.anthropometricBodyHeight,
      referenceDistanceCm: 170,
      confidence: .9,
    );
    final service = ReachMeasurementService(calibration: calibration);
    for (var index = 0; index < 12; index += 1) {
      service.addBaselineFrame(
        _poseFrame(
          timestamp: Duration(milliseconds: index * 100),
          wristX: .40,
          leftFootX: .30,
          rightFootX: .60,
          imageAspectRatio: 2 / 3,
        ),
        PrimaryBodySide.left,
      );
    }
    expect(service.finalizeStableBaseline(), isTrue);

    var snapshot = service.snapshot;
    for (var index = 0; index < 6; index += 1) {
      snapshot = service.addReachFrame(
        _poseFrame(
          timestamp: Duration(milliseconds: 1500 + index * 100),
          wristX: .48,
          leftFootX: .30,
          leftAnkleX: .36,
          rightFootX: .60,
          imageAspectRatio: 2 / 3,
        ),
        PrimaryBodySide.left,
      );
    }

    expect(snapshot.footMovementDetected, isFalse);
  });

  test('Step detector needs multiple frames before counting a step', () {
    final detector = StepDetectionService();
    for (var index = 0; index < 10; index += 1) {
      detector.addBaselineFrame(
        _poseFrame(
          timestamp: Duration(milliseconds: index * 100),
          wristX: .4,
          leftFootX: .3,
          rightFootX: .6,
        ),
      );
    }
    expect(detector.finalizeBaseline(), isTrue);
    for (var index = 0; index < 3; index += 1) {
      detector.addFrame(
        _poseFrame(
          timestamp: Duration(milliseconds: 1200 + index * 100),
          wristX: .4,
          leftFootX: .38,
          rightFootX: .6,
        ),
      );
    }
    expect(detector.snapshot.stepCount, 0);
    detector.addFrame(
      _poseFrame(
        timestamp: const Duration(milliseconds: 1500),
        wristX: .4,
        leftFootX: .38,
        rightFootX: .6,
      ),
    );
    expect(detector.snapshot.stepCount, 1);
  });

  test('an invalid session is never summarized as normal', () {
    final session = AssessmentSession(
      id: 'invalid',
      timestamp: DateTime(2026),
      valid: false,
      invalidReason: InvalidReason.interrupted,
    );
    expect(SessionSummary.status(session), AssessmentStatus.invalid);
    expect(SessionSummary.label(session), 'การทดสอบไม่สมบูรณ์');
  });
}

PoseFrame _poseFrame({
  required Duration timestamp,
  required double wristX,
  required double leftFootX,
  required double rightFootX,
  double? leftAnkleX,
  double imageAspectRatio = 1,
}) {
  NormalizedPoint point(double x, double y) =>
      NormalizedPoint(x: x, y: y, confidence: .95);
  return PoseFrame(
    timestamp: timestamp,
    imageAspectRatio: imageAspectRatio,
    landmarks: <BodyLandmark, NormalizedPoint>{
      BodyLandmark.leftWrist: point(wristX, .35),
      BodyLandmark.rightWrist: point(wristX, .35),
      BodyLandmark.leftAnkle: point(leftAnkleX ?? leftFootX, .85),
      BodyLandmark.leftHeel: point(leftFootX, .88),
      BodyLandmark.leftFootIndex: point(leftFootX + .01, .88),
      BodyLandmark.rightAnkle: point(rightFootX, .85),
      BodyLandmark.rightHeel: point(rightFootX, .88),
      BodyLandmark.rightFootIndex: point(rightFootX + .01, .88),
    },
  );
}
