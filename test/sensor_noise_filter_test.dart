import 'package:balance_detect/features/tug/domain/sensor_models.dart';
import 'package:balance_detect/features/tug/domain/sensor_noise_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'accelerometer-only filter does not treat a new static angle as motion forever',
    () {
      final filter = SensorNoiseFilter(
        mode: TugMeasurementMode.accelerometerOnly,
        initialGravity: const Vector3Sample(0, 9.81, 0),
        gravityAlpha: 0.2,
      );

      CalibratedSensorSample? filtered;
      for (var index = 0; index < 80; index += 1) {
        filtered = filter.filter(
          CalibratedSensorSample(
            elapsed: Duration(milliseconds: index * 20),
            dynamicAcceleration: const Vector3Sample(9.81, -9.81, 0),
            correctedGyroscope: null,
            rawAcceleration: const Vector3Sample(9.81, 0, 0),
          ),
        );
      }

      expect(filtered!.dynamicAccelerationMagnitude, lessThan(0.05));
      expect(filtered.correctedGyroscope, isNull);
    },
  );
}
