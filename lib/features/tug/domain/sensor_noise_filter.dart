import 'package:balance_detect/features/tug/domain/sensor_models.dart';

class SensorNoiseFilter {
  SensorNoiseFilter({
    this.alpha = 0.24,
    this.gravityAlpha = 0.04,
    this.mode = TugMeasurementMode.fullImu,
    Vector3Sample? initialGravity,
  }) : _gravityEstimate = initialGravity;

  final double alpha;
  final double gravityAlpha;
  final TugMeasurementMode mode;
  Vector3Sample? _dynamicAcceleration;
  Vector3Sample? _gyroscope;
  Vector3Sample? _gravityEstimate;

  CalibratedSensorSample filter(CalibratedSensorSample sample) {
    final dynamicInput = mode == TugMeasurementMode.accelerometerOnly
        ? _accelerometerOnlyDynamic(sample.rawAcceleration)
        : sample.dynamicAcceleration;
    _dynamicAcceleration = _blend(_dynamicAcceleration, dynamicInput);
    final correctedGyroscope = sample.correctedGyroscope;
    if (correctedGyroscope != null) {
      _gyroscope = _blend(_gyroscope, correctedGyroscope);
    }
    return CalibratedSensorSample(
      elapsed: sample.elapsed,
      dynamicAcceleration: _dynamicAcceleration!,
      correctedGyroscope: correctedGyroscope == null ? null : _gyroscope,
      rawAcceleration: sample.rawAcceleration,
    );
  }

  Vector3Sample _accelerometerOnlyDynamic(Vector3Sample rawAcceleration) {
    final previousGravity = _gravityEstimate;
    _gravityEstimate = previousGravity == null
        ? rawAcceleration
        : _blendWithAlpha(previousGravity, rawAcceleration, gravityAlpha);
    return rawAcceleration - _gravityEstimate!;
  }

  Vector3Sample _blend(Vector3Sample? previous, Vector3Sample current) {
    if (previous == null) return current;
    return _blendWithAlpha(previous, current, alpha);
  }

  Vector3Sample _blendWithAlpha(
    Vector3Sample previous,
    Vector3Sample current,
    double blendAlpha,
  ) {
    return Vector3Sample(
      previous.x + blendAlpha * (current.x - previous.x),
      previous.y + blendAlpha * (current.y - previous.y),
      previous.z + blendAlpha * (current.z - previous.z),
    );
  }
}
