import 'package:balance_detect/core/domain/assessment_enums.dart';
import 'package:balance_detect/features/tug/domain/sensor_models.dart';
import 'package:balance_detect/features/tug/domain/tug_logic.dart';
import 'package:balance_detect/features/tug/domain/tug_motion_analyzer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TugMotionAnalyzer seated completion', () {
    test('completes when the phone returns to its calibrated orientation', () {
      final harness = _TugHarness()..driveUntilSittingDown();

      harness.pushFor(
        const Duration(seconds: 1),
        rawAcceleration: const Vector3Sample(0, 9.81, 0),
        dynamicAcceleration: const Vector3Sample(0, 0, 0),
        gyroscope: const Vector3Sample(0, 0, 0),
      );

      expect(harness.state, TugState.completed);
    });

    test('completes when seated still after the phone changes orientation', () {
      final harness = _TugHarness()..driveUntilSittingDown();

      // A waist-mounted phone can rotate relative to gravity as the hip bends.
      // Its acceleration magnitude still reads 1 g, but subtracting the
      // calibration vector makes a stationary phone look highly dynamic.
      harness.pushFor(
        const Duration(seconds: 1),
        rawAcceleration: const Vector3Sample(9.81, 0, 0),
        dynamicAcceleration: const Vector3Sample(9.81, -9.81, 0),
        gyroscope: const Vector3Sample(0, 0, 0),
      );

      expect(harness.state, TugState.completed);
    });

    test('does not complete while the tilted phone is still rotating', () {
      final harness = _TugHarness()..driveUntilSittingDown();

      harness.pushFor(
        const Duration(seconds: 1),
        rawAcceleration: const Vector3Sample(9.81, 0, 0),
        dynamicAcceleration: const Vector3Sample(9.81, -9.81, 0),
        gyroscope: const Vector3Sample(0, 0.2, 0),
      );

      expect(harness.state, TugState.sittingDown);
    });
  });
}

class _TugHarness {
  _TugHarness() : stateMachine = TugStateMachine(TugState.ready) {
    analyzer = TugMotionAnalyzer(
      calibration: const SensorCalibration(
        gravityVector: Vector3Sample(0, 9.81, 0),
        gyroscopeBias: Vector3Sample(0, 0, 0),
        accelerometerNoise: 0.02,
        gyroscopeNoise: 0.01,
        sampleCount: 150,
        confidence: 1,
      ),
      stateMachine: stateMachine,
    )..start(Duration.zero);
  }

  final TugStateMachine stateMachine;
  late TugMotionAnalyzer analyzer;
  Duration elapsed = Duration.zero;

  TugState get state => stateMachine.state;

  void driveUntilSittingDown() {
    pushFor(
      const Duration(seconds: 1),
      rawAcceleration: const Vector3Sample(0, 9.81, 0),
      dynamicAcceleration: const Vector3Sample(1, 0, 0),
      gyroscope: const Vector3Sample(0, 0.25, 0),
    );
    expect(state, TugState.walkingOut);

    pushFor(
      const Duration(milliseconds: 1200),
      rawAcceleration: const Vector3Sample(0, 9.81, 0),
      dynamicAcceleration: const Vector3Sample(0.45, 0, 0),
      gyroscope: const Vector3Sample(0, 0.05, 0),
    );
    pushFor(
      const Duration(milliseconds: 40),
      rawAcceleration: const Vector3Sample(0, 9.81, 0),
      dynamicAcceleration: const Vector3Sample(0.45, 0, 0),
      gyroscope: const Vector3Sample(0, 1.2, 0),
    );
    expect(state, TugState.turning);

    pushFor(
      const Duration(seconds: 2),
      rawAcceleration: const Vector3Sample(0, 9.81, 0),
      dynamicAcceleration: const Vector3Sample(0.45, 0, 0),
      gyroscope: const Vector3Sample(0, 1.2, 0),
    );
    expect(state, TugState.walkingBack);

    pushFor(
      const Duration(milliseconds: 1400),
      rawAcceleration: const Vector3Sample(0, 9.81, 0),
      dynamicAcceleration: const Vector3Sample(0.8, 0, 0),
      gyroscope: const Vector3Sample(0, 0.25, 0),
    );
    expect(state, TugState.sittingDown);
  }

  void pushFor(
    Duration duration, {
    required Vector3Sample rawAcceleration,
    required Vector3Sample dynamicAcceleration,
    required Vector3Sample gyroscope,
  }) {
    final samples = duration.inMilliseconds ~/ 20;
    for (var index = 0; index < samples; index += 1) {
      elapsed += const Duration(milliseconds: 20);
      analyzer.process(
        CalibratedSensorSample(
          elapsed: elapsed,
          dynamicAcceleration: dynamicAcceleration,
          correctedGyroscope: gyroscope,
          rawAcceleration: rawAcceleration,
        ),
      );
    }
  }
}
