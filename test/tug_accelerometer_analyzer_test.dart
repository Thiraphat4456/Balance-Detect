import 'package:balance_detect/core/domain/assessment_enums.dart';
import 'package:balance_detect/features/tug/domain/sensor_models.dart';
import 'package:balance_detect/features/tug/domain/tug_accelerometer_analyzer.dart';
import 'package:balance_detect/features/tug/domain/tug_logic.dart';
import 'package:balance_detect/features/tug/domain/tug_motion_analyzer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AccelerometerOnlyTugAnalyzer', () {
    test('completes a full basic TUG and leaves the turn unverified', () {
      final harness = _AccelerometerHarness()..driveThroughReturnWalk();

      harness.pushFor(
        const Duration(milliseconds: 400),
        rawAcceleration: const Vector3Sample(0, 9.81, 0),
        dynamicAcceleration: const Vector3Sample(0.85, 0, 0),
      );
      harness.pushFor(
        const Duration(milliseconds: 1200),
        rawAcceleration: const Vector3Sample(0, 9.81, 0),
        dynamicAcceleration: const Vector3Sample(0, 0, 0),
      );

      expect(harness.state, TugState.completed);
      expect(harness.latest?.turnVerified, isFalse);
      expect(
        harness.latest?.measurementMode,
        TugMeasurementMode.accelerometerOnly,
      );
      expect(harness.latest?.timeline?.totalSeconds, greaterThan(0));
      expect(harness.latest?.timeline?.turnDuration, isNull);
    });

    test('does not finish when the participant only stops standing', () {
      final harness = _AccelerometerHarness()..driveThroughReturnWalk();

      harness.pushFor(
        const Duration(milliseconds: 1600),
        rawAcceleration: const Vector3Sample(9.81, 0, 0),
        dynamicAcceleration: const Vector3Sample(0, 0, 0),
      );

      expect(harness.state, isNot(TugState.completed));
    });

    test('does not finish before outbound and return motion evidence', () {
      final harness = _AccelerometerHarness();

      harness.pushFor(
        const Duration(milliseconds: 700),
        rawAcceleration: const Vector3Sample(9.81, 0, 0),
        dynamicAcceleration: const Vector3Sample(0.8, 0, 0),
      );
      harness.pushFor(
        const Duration(seconds: 2),
        rawAcceleration: const Vector3Sample(0, 9.81, 0),
        dynamicAcceleration: const Vector3Sample(0, 0, 0),
      );

      expect(harness.state, isNot(TugState.completed));
    });
  });
}

class _AccelerometerHarness {
  _AccelerometerHarness() : stateMachine = TugStateMachine(TugState.ready) {
    analyzer = AccelerometerOnlyTugAnalyzer(
      calibration: const SensorCalibration(
        mode: TugMeasurementMode.accelerometerOnly,
        gravityVector: Vector3Sample(0, 9.81, 0),
        gyroscopeBias: null,
        accelerometerNoise: 0.02,
        gyroscopeNoise: null,
        sampleCount: 150,
        confidence: 0.72,
      ),
      stateMachine: stateMachine,
    )..start(Duration.zero);
  }

  final TugStateMachine stateMachine;
  late AccelerometerOnlyTugAnalyzer analyzer;
  Duration elapsed = Duration.zero;
  TugAnalysisSnapshot? latest;

  TugState get state => stateMachine.state;

  void driveThroughReturnWalk() {
    pushFor(
      const Duration(milliseconds: 900),
      rawAcceleration: const Vector3Sample(9.81, 0, 0),
      dynamicAcceleration: const Vector3Sample(0.8, 0, 0),
    );
    expect(state, TugState.walkingOut);

    pushFor(
      const Duration(milliseconds: 2400),
      rawAcceleration: const Vector3Sample(9.81, 0, 0),
      dynamicAcceleration: const Vector3Sample(0.55, 0, 0),
    );
    expect(state, anyOf(TugState.turning, TugState.walkingBack));

    pushFor(
      const Duration(milliseconds: 1200),
      rawAcceleration: const Vector3Sample(9.81, 0, 0),
      dynamicAcceleration: const Vector3Sample(0.55, 0, 0),
    );
    expect(state, TugState.walkingBack);

    pushFor(
      const Duration(milliseconds: 1700),
      rawAcceleration: const Vector3Sample(9.81, 0, 0),
      dynamicAcceleration: const Vector3Sample(0.55, 0, 0),
    );
    expect(state, TugState.walkingBack);
  }

  void pushFor(
    Duration duration, {
    required Vector3Sample rawAcceleration,
    required Vector3Sample dynamicAcceleration,
  }) {
    final samples = duration.inMilliseconds ~/ 20;
    for (var index = 0; index < samples; index += 1) {
      elapsed += const Duration(milliseconds: 20);
      latest = analyzer.process(
        CalibratedSensorSample(
          elapsed: elapsed,
          dynamicAcceleration: dynamicAcceleration,
          correctedGyroscope: null,
          rawAcceleration: rawAcceleration,
        ),
      );
    }
  }
}
