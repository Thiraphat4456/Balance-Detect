import 'package:balance_detect/core/domain/assessment_enums.dart';
import 'package:balance_detect/features/assessment/domain/calibration_record.dart';
import 'package:balance_detect/features/fullerton/domain/fullerton_reach_calibration_service.dart';
import 'package:balance_detect/features/pose/domain/pose_frame.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const geometry = FullertonTargetGeometry();
  final calibration = CalibrationRecord(
    id: 'calibration',
    sessionId: 'session',
    timestamp: DateTime(2026),
    scaleCmPerNormalizedUnit: 100,
    method: CalibrationMethod.anthropometricBodyHeight,
    referenceDistanceCm: 170,
    confidence: .9,
  );

  group('Fullerton target geometry', () {
    test('one-foot variant places the target exactly 30.48 cm ahead', () {
      final target = geometry.create(
        fingertip: _point(.40, .40),
        shoulder: _point(.20, .40),
        calibration: calibration,
        imageAspectRatio: .75,
        protocolVariant: FullertonProtocolVariant.oneFoot,
      );

      expect(target.targetDistanceCm, 30.48);
      expect(target.targetPoint.x, closeTo(.7048, 1e-6));
      expect(target.targetPoint.y, closeTo(.40, 1e-6));
      expect(
        geometry.metricDistanceCm(
          target.startFingertip,
          target.targetPoint,
          calibration: calibration,
          imageAspectRatio: .75,
        ),
        closeTo(30.48, 1e-6),
      );
      expect(target.isStandardProtocol, isFalse);
    });

    test('standard FAB variant remains 10 inches, not a 12-inch ruler', () {
      final target = geometry.create(
        fingertip: _point(.40, .40),
        shoulder: _point(.20, .40),
        calibration: calibration,
        imageAspectRatio: .75,
        protocolVariant: FullertonProtocolVariant.standardTenInches,
      );

      expect(target.targetDistanceCm, 25.4);
      expect(target.targetPoint.x, closeTo(.654, 1e-6));
      expect(target.isStandardProtocol, isTrue);
    });

    test(
      'front-camera mirroring mirrors the target without double flipping',
      () {
        final forward = geometry.create(
          fingertip: _point(.40, .40),
          shoulder: _point(.20, .40),
          calibration: calibration,
          imageAspectRatio: .75,
          protocolVariant: FullertonProtocolVariant.standardTenInches,
        );
        final mirrored = geometry.create(
          fingertip: _point(.60, .40),
          shoulder: _point(.80, .40),
          calibration: calibration,
          imageAspectRatio: .75,
          protocolVariant: FullertonProtocolVariant.standardTenInches,
        );

        expect(
          mirrored.targetPoint.x,
          closeTo(1 - forward.targetPoint.x, 1e-6),
        );
        expect(mirrored.targetPoint.y, closeTo(forward.targetPoint.y, 1e-6));
      },
    );

    test(
      'diagonal direction is aspect-correct and preserves metric distance',
      () {
        final target = geometry.create(
          fingertip: _point(.55, .30),
          shoulder: _point(.35, .45),
          calibration: calibration,
          imageAspectRatio: .75,
          protocolVariant: FullertonProtocolVariant.standardTenInches,
        );

        expect(
          geometry.metricDistanceCm(
            target.startFingertip,
            target.targetPoint,
            calibration: calibration,
            imageAspectRatio: .75,
          ),
          closeTo(25.4, 1e-6),
        );
      },
    );

    test(
      'rejects a target outside the camera viewport instead of clamping it',
      () {
        expect(
          () => geometry.create(
            fingertip: _point(.85, .40),
            shoulder: _point(.65, .40),
            calibration: calibration,
            imageAspectRatio: .75,
            protocolVariant: FullertonProtocolVariant.oneFoot,
          ),
          throwsFormatException,
        );
      },
    );
  });

  group('Fullerton arm and fingertip calibration', () {
    test('uses the index landmark and accepts a stable 90-degree arm', () {
      final service = FullertonArmCalibrationService();
      FullertonArmCalibrationStatus? status;
      for (var index = 0; index < 12; index += 1) {
        status = service.addFrame(
          _armFrame(timestampMs: index * 100),
          PrimaryBodySide.left,
        );
      }

      expect(status!.canCalibrate, isTrue);
      final target = service.finalize(
        calibration: calibration,
        protocolVariant: FullertonProtocolVariant.oneFoot,
      );
      expect(target.startFingertip.x, closeTo(.55, 1e-6));
      expect(target.targetPoint.x, closeTo(.8548, 1e-6));
      expect(target.trackedSide, PrimaryBodySide.left);
    });

    test('does not silently substitute the wrist when index is missing', () {
      final service = FullertonArmCalibrationService();
      final source = _armFrame(timestampMs: 0);
      final withoutIndex = PoseFrame(
        timestamp: source.timestamp,
        imageAspectRatio: source.imageAspectRatio,
        landmarks: Map<BodyLandmark, NormalizedPoint>.of(source.landmarks)
          ..remove(BodyLandmark.leftIndex),
      );

      final status = service.addFrame(withoutIndex, PrimaryBodySide.left);

      expect(status.fingertipVisible, isFalse);
      expect(status.acceptedFrameCount, 0);
      expect(
        () => service.finalize(
          calibration: calibration,
          protocolVariant: FullertonProtocolVariant.standardTenInches,
        ),
        throwsFormatException,
      );
    });

    test('rejects an index landmark that falls behind the wrist', () {
      final service = FullertonArmCalibrationService();

      final status = service.addFrame(
        _armFrame(timestampMs: 0, fingertipX: .45),
        PrimaryBodySide.left,
      );

      expect(status.fingertipVisible, isTrue);
      expect(status.acceptedFrameCount, 0);
      expect(status.guidance, contains('เหยียดนิ้ว'));
    });

    test('rejects sustained fingertip jitter during calibration', () {
      final service = FullertonArmCalibrationService();
      for (var index = 0; index < 12; index += 1) {
        service.addFrame(
          _armFrame(
            timestampMs: index * 100,
            fingertipX: index.isEven ? .49 : .61,
          ),
          PrimaryBodySide.left,
        );
      }

      expect(
        () => service.finalize(
          calibration: calibration,
          protocolVariant: FullertonProtocolVariant.standardTenInches,
        ),
        throwsFormatException,
      );
    });
  });
}

NormalizedPoint _point(double x, double y, [double confidence = .95]) =>
    NormalizedPoint(x: x, y: y, confidence: confidence);

PoseFrame _armFrame({required int timestampMs, double fingertipX = .55}) =>
    PoseFrame(
      timestamp: Duration(milliseconds: timestampMs),
      imageAspectRatio: .75,
      landmarks: <BodyLandmark, NormalizedPoint>{
        BodyLandmark.leftShoulder: _point(.25, .40),
        BodyLandmark.leftElbow: _point(.40, .40),
        BodyLandmark.leftWrist: _point(.50, .40),
        BodyLandmark.leftIndex: _point(fingertipX, .40),
        BodyLandmark.leftHip: _point(.25, .65),
      },
    );
