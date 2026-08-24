import 'dart:math' as math;

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
    required this.gyroscope,
  });

  final Duration elapsed;
  final Vector3Sample accelerometer;
  final Vector3Sample gyroscope;
}

class SensorAvailability {
  const SensorAvailability({
    required this.accelerometerAvailable,
    required this.gyroscopeAvailable,
  });

  final bool accelerometerAvailable;
  final bool gyroscopeAvailable;

  bool get ready => accelerometerAvailable && gyroscopeAvailable;
}

class SensorCalibration {
  const SensorCalibration({
    required this.gravityVector,
    required this.gyroscopeBias,
    required this.accelerometerNoise,
    required this.gyroscopeNoise,
    required this.sampleCount,
    required this.confidence,
  });

  final Vector3Sample gravityVector;
  final Vector3Sample gyroscopeBias;
  final double accelerometerNoise;
  final double gyroscopeNoise;
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
  final Vector3Sample correctedGyroscope;
  final Vector3Sample rawAcceleration;

  double get dynamicAccelerationMagnitude => dynamicAcceleration.magnitude;
  double get angularVelocityMagnitude => correctedGyroscope.magnitude;
}
