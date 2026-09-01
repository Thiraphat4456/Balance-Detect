import 'dart:async';

import 'package:balance_detect/core/constants/assessment_config.dart';
import 'package:balance_detect/core/logging/app_logger.dart';
import 'package:balance_detect/features/tug/domain/sensor_models.dart';
import 'package:sensors_plus/sensors_plus.dart';

abstract interface class SensorService {
  Stream<SensorSample> get samples;
  Stream<Object> get errors;
  Future<void> start({required TugMeasurementMode mode});
  Future<void> stop();
  Future<SensorAvailability> probe();
}

class SensorsPlusService implements SensorService {
  final StreamController<SensorSample> _sampleController =
      StreamController<SensorSample>.broadcast();
  final StreamController<Object> _errorController =
      StreamController<Object>.broadcast();
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  GyroscopeEvent? _latestGyroscope;
  Stopwatch? _stopwatch;
  TugMeasurementMode _mode = TugMeasurementMode.fullImu;

  @override
  Stream<SensorSample> get samples => _sampleController.stream;

  @override
  Stream<Object> get errors => _errorController.stream;

  @override
  Future<SensorAvailability> probe() async {
    var accelerometerAvailable = false;
    var gyroscopeAvailable = false;
    final completer = Completer<SensorAvailability>();
    late final StreamSubscription<AccelerometerEvent> accelerometer;
    late final StreamSubscription<GyroscopeEvent> gyroscope;
    Timer? timer;

    void finishIfReady() {
      if (accelerometerAvailable &&
          gyroscopeAvailable &&
          !completer.isCompleted) {
        completer.complete(
          const SensorAvailability(
            accelerometerAvailable: true,
            gyroscopeAvailable: true,
          ),
        );
      }
    }

    accelerometer =
        accelerometerEventStream(
          samplingPeriod: AssessmentConfig.sensorSamplingPeriod,
        ).listen((_) {
          accelerometerAvailable = true;
          finishIfReady();
        }, onError: (_) {});
    gyroscope =
        gyroscopeEventStream(
          samplingPeriod: AssessmentConfig.sensorSamplingPeriod,
        ).listen((_) {
          gyroscopeAvailable = true;
          finishIfReady();
        }, onError: (_) {});
    timer = Timer(AssessmentConfig.sensorProbeTimeout, () {
      if (!completer.isCompleted) {
        completer.complete(
          SensorAvailability(
            accelerometerAvailable: accelerometerAvailable,
            gyroscopeAvailable: gyroscopeAvailable,
          ),
        );
      }
    });
    final result = await completer.future;
    timer.cancel();
    await accelerometer.cancel();
    await gyroscope.cancel();
    return result;
  }

  @override
  Future<void> start({required TugMeasurementMode mode}) async {
    await stop();
    _mode = mode;
    _stopwatch = Stopwatch()..start();
    if (mode.usesGyroscope) {
      _gyroscopeSubscription =
          gyroscopeEventStream(
            samplingPeriod: AssessmentConfig.sensorSamplingPeriod,
          ).listen(
            (event) => _latestGyroscope = event,
            onError: _handleError,
            cancelOnError: false,
          );
    }
    _accelerometerSubscription = accelerometerEventStream(
      samplingPeriod: AssessmentConfig.sensorSamplingPeriod,
    ).listen(_onAccelerometer, onError: _handleError, cancelOnError: false);
  }

  void _onAccelerometer(AccelerometerEvent accelerometer) {
    final gyroscope = _latestGyroscope;
    final stopwatch = _stopwatch;
    if (stopwatch == null) return;
    if (_mode.usesGyroscope) {
      if (gyroscope == null) return;
      final timestampGap = accelerometer.timestamp
          .difference(gyroscope.timestamp)
          .abs();
      if (timestampGap > const Duration(milliseconds: 100)) return;
    }
    _sampleController.add(
      SensorSample(
        elapsed: stopwatch.elapsed,
        accelerometer: Vector3Sample(
          accelerometer.x,
          accelerometer.y,
          accelerometer.z,
        ),
        gyroscope: gyroscope == null
            ? null
            : Vector3Sample(gyroscope.x, gyroscope.y, gyroscope.z),
      ),
    );
  }

  void _handleError(Object error) {
    AppLogger.error('sensor_stream_error', error);
    _errorController.add(error);
  }

  @override
  Future<void> stop() async {
    _stopwatch?.stop();
    _stopwatch = null;
    _latestGyroscope = null;
    await _accelerometerSubscription?.cancel();
    await _gyroscopeSubscription?.cancel();
    _accelerometerSubscription = null;
    _gyroscopeSubscription = null;
  }

  Future<void> dispose() async {
    await stop();
    await _sampleController.close();
    await _errorController.close();
  }
}
