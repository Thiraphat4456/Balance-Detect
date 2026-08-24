import 'package:balance_detect/features/tug/domain/sensor_calibration_service.dart';
import 'package:balance_detect/features/tug/domain/sensor_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'calibration estimates gravity and gyroscope bias from resting data',
    () {
      final samples = List<SensorSample>.generate(100, (index) {
        final smallNoise = index.isEven ? .01 : -.01;
        return SensorSample(
          elapsed: Duration(milliseconds: index * 20),
          accelerometer: Vector3Sample(smallNoise, 9.81, 0),
          gyroscope: Vector3Sample(.02, -.01, .005),
        );
      });

      final calibration = const SensorCalibrationService().calibrate(samples);

      expect(calibration.gravityVector.y, closeTo(9.81, .001));
      expect(calibration.gyroscopeBias.x, closeTo(.02, .001));
      expect(calibration.sampleCount, 100);
      expect(calibration.confidence, greaterThan(.8));
    },
  );

  test('calibration rejects too few samples', () {
    expect(
      () => const SensorCalibrationService().calibrate(const <SensorSample>[]),
      throwsFormatException,
    );
  });
}
