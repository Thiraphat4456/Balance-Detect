import 'dart:math' as math;

enum TugMeasurementMode {
  fullImu,
  accelerometerOnly,
  legacyUnspecified;

  bool get usesGyroscope => this == TugMeasurementMode.fullImu;
  bool get isExperimental => this == TugMeasurementMode.accelerometerOnly;
}

TugMeasurementMode tugMeasurementModeFromName(String? value) {
  if (value == null) return TugMeasurementMode.legacyUnspecified;
  for (final mode in TugMeasurementMode.values) {
    if (mode.name == value) return mode;
  }
  return TugMeasurementMode.legacyUnspecified;
}

class Vector3Sample {
  const Vector3Sample(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  double get magnitude => math.sqrt(x * x + y * y + z * z);

  Vector3Sample operator +(Vector3Sample other) =>
      Vector3Sample(x + other.x, y + other.y, z + other.z);
  Vector3Sample operator -(Vector3Sample other) =>
      Vector3Sample(x - other.x, y - other.y, z - other.z);
  Vector3Sample operator /(double divisor) =>
      Vector3Sample(x / divisor, y / divisor, z / divisor);

  double dot(Vector3Sample other) => x * other.x + y * other.y + z * other.z;

  Vector3Sample get normalized {
    final length = magnitude;
    return length == 0 ? const Vector3Sample(0, 0, 0) : this / length;
  }
}

class SensorSample {
  const SensorSample({
    required this.elapsed,
    required this.accelerometer,
    this.gyroscope,
  });

  final Duration elapsed;
  final Vector3Sample accelerometer;
  final Vector3Sample? gyroscope;
}

class SensorAvailability {
  const SensorAvailability({
    required this.accelerometerAvailable,
    required this.gyroscopeAvailable,
  });

  final bool accelerometerAvailable;
  final bool gyroscopeAvailable;

  TugMeasurementMode? get preferredMode {
    if (!accelerometerAvailable) return null;
    return gyroscopeAvailable
        ? TugMeasurementMode.fullImu
        : TugMeasurementMode.accelerometerOnly;
  }

  bool get ready => preferredMode != null;
}

class SensorCalibration {
  const SensorCalibration({
    this.mode = TugMeasurementMode.fullImu,
    required this.gravityVector,
    required this.gyroscopeBias,
    required this.accelerometerNoise,
    required this.gyroscopeNoise,
    required this.sampleCount,
    required this.confidence,
  });

  final TugMeasurementMode mode;
  final Vector3Sample gravityVector;
  final Vector3Sample? gyroscopeBias;
  final double accelerometerNoise;
  final double? gyroscopeNoise;
  final int sampleCount;
  final double confidence;
}

class CalibratedSensorSample {
  const CalibratedSensorSample({
    required this.elapsed,
    required this.dynamicAcceleration,
    required this.correctedGyroscope,
    required this.rawAcceleration,
  });

  final Duration elapsed;
  final Vector3Sample dynamicAcceleration;
  final Vector3Sample? correctedGyroscope;
  final Vector3Sample rawAcceleration;

  double get dynamicAccelerationMagnitude => dynamicAcceleration.magnitude;
  double get angularVelocityMagnitude => correctedGyroscope?.magnitude ?? 0;
}
