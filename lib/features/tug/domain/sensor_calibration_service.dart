import 'dart:math' as math;

import 'package:balance_detect/core/constants/assessment_config.dart';
import 'package:balance_detect/features/tug/domain/sensor_models.dart';

class SensorCalibrationService {
  const SensorCalibrationService();

  SensorCalibration calibrate(List<SensorSample> samples) {
    if (samples.length < AssessmentConfig.sensorCalibrationMinSamples) {
      throw const FormatException('ข้อมูลเซนเซอร์ไม่เพียงพอสำหรับการปรับเทียบ');
    }
    final gravity = _mean(samples.map((sample) => sample.accelerometer));
    final gyroBias = _mean(samples.map((sample) => sample.gyroscope));
    final accelerometerNoise = _rootMeanSquare(
      samples.map((sample) => (sample.accelerometer - gravity).magnitude),
    );
    final gyroscopeNoise = _rootMeanSquare(
      samples.map((sample) => (sample.gyroscope - gyroBias).magnitude),
    );
    if (gravity.magnitude < 7 || gravity.magnitude > 12.5) {
      throw const FormatException(
        'ค่าความโน้มถ่วงผิดปกติ กรุณาตรวจตำแหน่งโทรศัพท์',
      );
    }
    if (accelerometerNoise > AssessmentConfig.sensorRestingNoiseLimit ||
        gyroscopeNoise > AssessmentConfig.sensorRestingGyroLimit) {
      throw const FormatException(
        'มีการเคลื่อนไหวระหว่างปรับเทียบ กรุณานั่งนิ่ง',
      );
    }
    final noiseScore =
        1 -
        math.max(
          accelerometerNoise / AssessmentConfig.sensorRestingNoiseLimit,
          gyroscopeNoise / AssessmentConfig.sensorRestingGyroLimit,
        );
    final sampleScore = math.min(1.0, samples.length / 120);
    return SensorCalibration(
      gravityVector: gravity,
      gyroscopeBias: gyroBias,
      accelerometerNoise: accelerometerNoise,
      gyroscopeNoise: gyroscopeNoise,
      sampleCount: samples.length,
      confidence: (0.55 + noiseScore * 0.3 + sampleScore * 0.15).clamp(
        0.0,
        1.0,
      ),
    );
  }

  CalibratedSensorSample apply(
    SensorSample sample,
    SensorCalibration calibration,
  ) => CalibratedSensorSample(
    elapsed: sample.elapsed,
    dynamicAcceleration: sample.accelerometer - calibration.gravityVector,
    correctedGyroscope: sample.gyroscope - calibration.gyroscopeBias,
    rawAcceleration: sample.accelerometer,
  );

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
