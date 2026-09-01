import 'package:balance_detect/features/tug/domain/sensor_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TUG remains available when only the accelerometer is present', () {
    const availability = SensorAvailability(
      accelerometerAvailable: true,
      gyroscopeAvailable: false,
    );

    expect(availability.ready, isTrue);
    expect(availability.preferredMode, TugMeasurementMode.accelerometerOnly);
  });

  test('TUG prefers full IMU when both motion sensors are present', () {
    const availability = SensorAvailability(
      accelerometerAvailable: true,
      gyroscopeAvailable: true,
    );

    expect(availability.ready, isTrue);
    expect(availability.preferredMode, TugMeasurementMode.fullImu);
  });

  test('TUG remains unavailable without an accelerometer', () {
    const availability = SensorAvailability(
      accelerometerAvailable: false,
      gyroscopeAvailable: true,
    );

    expect(availability.ready, isFalse);
    expect(availability.preferredMode, isNull);
  });
}
