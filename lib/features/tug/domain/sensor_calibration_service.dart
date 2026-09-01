import 'dart:math' as math;

import 'package:balance_detect/core/constants/assessment_config.dart';
import 'package:balance_detect/features/tug/domain/sensor_models.dart';

class SensorCalibrationService {
  const SensorCalibrationService();

  SensorCalibration calibrate(
    List<SensorSample> samples, {
    TugMeasurementMode mode = TugMeasurementMode.fullImu,
  }) {
    if (samples.length < AssessmentConfig.sensorCalibrationMinSamples) {
      throw const FormatException('ข้อมูลเซนเซอร์ไม่เพียงพอสำหรับการปรับเทียบ');
    }
    final gravity = _mean(samples.map((sample) => sample.accelerometer));
    final gyroscopeSamples = samples
        .map((sample) => sample.gyroscope)
        .whereType<Vector3Sample>()
        .toList(growable: false);
    if (mode.usesGyroscope && gyroscopeSamples.length != samples.length) {
      throw const FormatException(
        'ข้อมูล Gyroscope ไม่เพียงพอสำหรับการปรับเทียบ',
      );
    }
    final gyroBias = mode.usesGyroscope ? _mean(gyroscopeSamples) : null;
    final accelerometerNoise = _rootMeanSquare(
      samples.map((sample) => (sample.accelerometer - gravity).magnitude),
    );
    final gyroscopeNoise = mode.usesGyroscope
        ? _rootMeanSquare(
            gyroscopeSamples.map((sample) => (sample - gyroBias!).magnitude),
          )
        : null;
    if (gravity.magnitude < 7 || gravity.magnitude > 12.5) {
      throw const FormatException(
        'ค่าความโน้มถ่วงผิดปกติ กรุณาตรวจตำแหน่งโทรศัพท์',
      );
    }
    if (accelerometerNoise > AssessmentConfig.sensorRestingNoiseLimit ||
        (gyroscopeNoise != null &&
            gyroscopeNoise > AssessmentConfig.sensorRestingGyroLimit)) {
      throw const FormatException(
        'มีการเคลื่อนไหวระหว่างปรับเทียบ กรุณานั่งนิ่ง',
      );
    }
    final normalizedAccelerometerNoise =
        accelerometerNoise / AssessmentConfig.sensorRestingNoiseLimit;
    final normalizedNoise = gyroscopeNoise == null
        ? normalizedAccelerometerNoise
        : math.max(
            normalizedAccelerometerNoise,
            gyroscopeNoise / AssessmentConfig.sensorRestingGyroLimit,
          );
    final noiseScore = 1 - normalizedNoise;
    final sampleScore = math.min(1.0, samples.length / 120);
    final rawConfidence = (0.55 + noiseScore * 0.3 + sampleScore * 0.15).clamp(
      0.0,
      1.0,
    );
    return SensorCalibration(
      mode: mode,
      gravityVector: gravity,
      gyroscopeBias: gyroBias,
      accelerometerNoise: accelerometerNoise,
      gyroscopeNoise: gyroscopeNoise,
      sampleCount: samples.length,
      confidence: mode == TugMeasurementMode.accelerometerOnly
          ? math.min(0.72, rawConfidence)
          : rawConfidence,
    );
  }

  CalibratedSensorSample apply(
    SensorSample sample,
    SensorCalibration calibration,
  ) {
    final gyroscope = sample.gyroscope;
    final gyroscopeBias = calibration.gyroscopeBias;
    return CalibratedSensorSample(
      elapsed: sample.elapsed,
      dynamicAcceleration: sample.accelerometer - calibration.gravityVector,
      correctedGyroscope: gyroscope == null || gyroscopeBias == null
          ? null
          : gyroscope - gyroscopeBias,
      rawAcceleration: sample.accelerometer,
    );
  }

  Vector3Sample _mean(Iterable<Vector3Sample> values) {
    final list = values.toList(growable: false);
    final sum = list.fold(
      const Vector3Sample(0, 0, 0),
      (total, value) => total + value,
    );
    return sum / list.length.toDouble();
  }

  double _rootMeanSquare(Iterable<double> values) {
    final list = values.toList(growable: false);
    final squares = list.fold(0.0, (sum, value) => sum + value * value);
    return math.sqrt(squares / list.length);
  }
}
