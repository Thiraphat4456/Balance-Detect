import 'package:balance_detect/features/tug/domain/sensor_models.dart';

class SensorNoiseFilter {
  SensorNoiseFilter({this.alpha = 0.24});

  final double alpha;
  Vector3Sample? _dynamicAcceleration;
  Vector3Sample? _gyroscope;

  CalibratedSensorSample filter(CalibratedSensorSample sample) {
    _dynamicAcceleration = _blend(
      _dynamicAcceleration,
      sample.dynamicAcceleration,
    );
    _gyroscope = _blend(_gyroscope, sample.correctedGyroscope);
    return CalibratedSensorSample(
      elapsed: sample.elapsed,
      dynamicAcceleration: _dynamicAcceleration!,
      correctedGyroscope: _gyroscope!,
      rawAcceleration: sample.rawAcceleration,
    );
  }

  Vector3Sample _blend(Vector3Sample? previous, Vector3Sample current) {
    if (previous == null) return current;
    return Vector3Sample(
      previous.x + alpha * (current.x - previous.x),
      previous.y + alpha * (current.y - previous.y),
      previous.z + alpha * (current.z - previous.z),
    );
  }
}
