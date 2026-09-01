import 'dart:math' as math;

import 'package:balance_detect/core/constants/assessment_config.dart';
import 'package:balance_detect/core/domain/assessment_enums.dart';
import 'package:balance_detect/features/tug/domain/sensor_models.dart';
import 'package:balance_detect/features/tug/domain/tug_logic.dart';

class TugTimeline {
  const TugTimeline({
    required this.testStart,
    required this.testEnd,
    this.standDetected,
    this.outboundWalkStart,
    this.turnStart,
    this.turnEnd,
    this.returnWalkStart,
    this.sitDownStart,
    this.sitDetected,
  });

  final Duration testStart;
  final Duration? standDetected;
  final Duration? outboundWalkStart;
  final Duration? turnStart;
  final Duration? turnEnd;
  final Duration? returnWalkStart;
  final Duration? sitDownStart;
  final Duration? sitDetected;
  final Duration testEnd;

  double get totalSeconds =>
      (testEnd - testStart).inMicroseconds / Duration.microsecondsPerSecond;
  double? get standDuration {
    final outbound = outboundWalkStart;
    return outbound == null
        ? null
        : (outbound - testStart).inMicroseconds /
              Duration.microsecondsPerSecond;
  }

  double? get outboundWalkDuration {
    final outbound = outboundWalkStart;
    final turn = turnStart;
    return outbound == null || turn == null
        ? null
        : (turn - outbound).inMicroseconds / Duration.microsecondsPerSecond;
  }

  double? get turnDuration {
    final start = turnStart;
    final end = turnEnd;
    return start == null || end == null
        ? null
        : (end - start).inMicroseconds / Duration.microsecondsPerSecond;
  }

  double? get returnWalkDuration {
    final start = returnWalkStart;
    final sit = sitDownStart;
    return start == null || sit == null
        ? null
        : (sit - start).inMicroseconds / Duration.microsecondsPerSecond;
  }

  double? get sitDuration {
    final start = sitDownStart;
    final detected = sitDetected;
    return start == null || detected == null
        ? null
        : (detected - start).inMicroseconds / Duration.microsecondsPerSecond;
  }
}

class TugAnalysisSnapshot {
  const TugAnalysisSnapshot({
    required this.state,
    required this.elapsed,
    required this.dynamicAcceleration,
    required this.gravityMagnitudeDeviation,
    required this.angularVelocity,
    required this.confidence,
    required this.measurementMode,
    required this.turnVerified,
    this.timeline,
  });

  final TugState state;
  final Duration elapsed;
  final double dynamicAcceleration;
  final double gravityMagnitudeDeviation;
  final double angularVelocity;
  final double confidence;
  final TugMeasurementMode measurementMode;
  final bool turnVerified;
  final TugTimeline? timeline;
}

abstract interface class TugAnalyzer {
  TugMeasurementMode get measurementMode;
  void start(Duration elapsed);
  TugAnalysisSnapshot process(CalibratedSensorSample sample);
}

class TugMotionAnalyzer implements TugAnalyzer {
  TugMotionAnalyzer({required this.calibration, required this.stateMachine});

  final SensorCalibration calibration;
  final TugStateMachine stateMachine;
  final List<CalibratedSensorSample> _window = <CalibratedSensorSample>[];
  final List<double> _eventConfidence = <double>[];

  Duration? _testStart;
  Duration? _standDetected;
  Duration? _outboundWalkStart;
  Duration? _turnStart;
  Duration? _turnEnd;
  Duration? _returnWalkStart;
  Duration? _sitDownStart;
  Duration? _sitDetected;
  Duration? _lastSampleElapsed;
  double _integratedTurnRadians = 0;

  @override
  TugMeasurementMode get measurementMode => TugMeasurementMode.fullImu;

  @override
  void start(Duration elapsed) {
    if (stateMachine.state != TugState.ready) {
      throw StateError('TUG analyzer must start from ready state');
    }
    stateMachine.transitionTo(TugState.sitting);
    _testStart = elapsed;
  }

  @override
  TugAnalysisSnapshot process(CalibratedSensorSample sample) {
    final start = _testStart;
    if (start == null) throw StateError('TUG analyzer has not started');
    _window.add(sample);
    _trimWindow(
      sample.elapsed,
      AssessmentConfig.tugQuietWindow + AssessmentConfig.sensorSamplingPeriod,
    );

    final meanAcceleration = _mean(
      _window.map((value) => value.dynamicAccelerationMagnitude),
    );
    final meanAngularVelocity = _mean(
      _window.map((value) => value.angularVelocityMagnitude),
    );
    final gravityMagnitude = _mean(
      _window.map((value) => value.rawAcceleration.magnitude),
    );
    final meanGravityMagnitudeDeviation = _mean(
      _window.map(
        (value) =>
            (value.rawAcceleration.magnitude -
                    calibration.gravityVector.magnitude)
                .abs(),
      ),
    );

    switch (stateMachine.state) {
      case TugState.sitting:
        if (_windowSpan >= const Duration(milliseconds: 350) &&
            meanAcceleration >= AssessmentConfig.tugStandAcceleration &&
            meanAngularVelocity >= AssessmentConfig.tugStandAngularVelocity) {
          _standDetected = sample.elapsed;
          _eventConfidence.add(
            _ratioConfidence(
              meanAcceleration,
              AssessmentConfig.tugStandAcceleration,
            ),
          );
          stateMachine.transitionTo(TugState.standingUp);
          _window.clear();
        }
      case TugState.standingUp:
        final standTime = _standDetected;
        if (standTime != null &&
            sample.elapsed - standTime >= const Duration(milliseconds: 450) &&
            _windowSpan >= const Duration(milliseconds: 300) &&
            meanAcceleration >=
                AssessmentConfig.tugWalkingDynamicAcceleration) {
          _outboundWalkStart = sample.elapsed;
          _eventConfidence.add(
            _ratioConfidence(
              meanAcceleration,
              AssessmentConfig.tugWalkingDynamicAcceleration,
            ),
          );
          stateMachine.transitionTo(TugState.walkingOut);
          _window.clear();
        }
      case TugState.walkingOut:
        final walkingStart = _outboundWalkStart;
        final turnRate = _turnRateAroundGravity(sample);
        if (walkingStart != null &&
            sample.elapsed - walkingStart >=
                AssessmentConfig.tugMinWalkingBeforeTurn &&
            turnRate >= AssessmentConfig.tugTurnAngularVelocity) {
          _turnStart = sample.elapsed;
          _integratedTurnRadians = 0;
          _eventConfidence.add(
            _ratioConfidence(turnRate, AssessmentConfig.tugTurnAngularVelocity),
          );
          stateMachine.transitionTo(TugState.turning);
          _window.clear();
        }
      case TugState.turning:
        final previous = _lastSampleElapsed;
        if (previous != null) {
          final deltaSeconds =
              (sample.elapsed - previous).inMicroseconds /
              Duration.microsecondsPerSecond;
          _integratedTurnRadians +=
              _turnRateAroundGravity(sample) * deltaSeconds;
        }
        if (_integratedTurnRadians >= AssessmentConfig.tugTurnMinimumRadians) {
          _turnEnd = sample.elapsed;
          _returnWalkStart = sample.elapsed;
          _eventConfidence.add(
            (_integratedTurnRadians / math.pi).clamp(0.0, 1.0),
          );
          stateMachine.transitionTo(TugState.walkingBack);
          _window.clear();
        }
      case TugState.walkingBack:
        final returnStart = _returnWalkStart;
        if (returnStart != null &&
            sample.elapsed - returnStart >=
                AssessmentConfig.tugMinReturnWalking &&
            _windowSpan >= const Duration(milliseconds: 300) &&
            meanAcceleration >= AssessmentConfig.tugStandAcceleration &&
            meanAngularVelocity >= AssessmentConfig.tugStandAngularVelocity) {
          _sitDownStart = sample.elapsed;
          _eventConfidence.add(
            _ratioConfidence(
              meanAcceleration,
              AssessmentConfig.tugStandAcceleration,
            ),
          );
          stateMachine.transitionTo(TugState.sittingDown);
          _window.clear();
        }
      case TugState.sittingDown:
        if (_windowSpan >= AssessmentConfig.tugQuietWindow &&
            meanGravityMagnitudeDeviation <=
                AssessmentConfig.tugSittingGravityMagnitudeTolerance &&
            meanAngularVelocity <= AssessmentConfig.tugSittingAngularVelocity &&
            gravityMagnitude >= 7 &&
            gravityMagnitude <= 12.5) {
          _sitDetected = sample.elapsed;
          _eventConfidence.add(
            (1 -
                    meanGravityMagnitudeDeviation /
                        AssessmentConfig.tugSittingGravityMagnitudeTolerance)
                .clamp(0.0, 1.0),
          );
          stateMachine.transitionTo(TugState.completed);
        }
      case TugState.completed ||
          TugState.invalid ||
          TugState.error ||
          TugState.idle ||
          TugState.calibrating ||
          TugState.ready:
        break;
    }
    _lastSampleElapsed = sample.elapsed;
    return _snapshot(
      sample,
      meanAcceleration,
      meanGravityMagnitudeDeviation,
      meanAngularVelocity,
    );
  }

  TugAnalysisSnapshot _snapshot(
    CalibratedSensorSample sample,
    double acceleration,
    double gravityMagnitudeDeviation,
    double angularVelocity,
  ) {
    final confidence = _eventConfidence.isEmpty
        ? calibration.confidence * 0.5
        : (_eventConfidence.reduce((a, b) => a + b) /
                  _eventConfidence.length *
                  calibration.confidence)
              .clamp(0.0, 1.0);
    return TugAnalysisSnapshot(
      state: stateMachine.state,
      elapsed: sample.elapsed,
      dynamicAcceleration: acceleration,
      gravityMagnitudeDeviation: gravityMagnitudeDeviation,
      angularVelocity: angularVelocity,
      confidence: confidence,
      measurementMode: measurementMode,
      turnVerified: true,
      timeline: stateMachine.state == TugState.completed
          ? _buildTimeline(sample.elapsed)
          : null,
    );
  }

  TugTimeline _buildTimeline(Duration end) => TugTimeline(
    testStart: _testStart!,
    standDetected: _standDetected!,
    outboundWalkStart: _outboundWalkStart!,
    turnStart: _turnStart!,
    turnEnd: _turnEnd!,
    returnWalkStart: _returnWalkStart!,
    sitDownStart: _sitDownStart!,
    sitDetected: _sitDetected!,
    testEnd: end,
  );

  void _trimWindow(Duration now, Duration duration) {
    _window.removeWhere((sample) => now - sample.elapsed > duration);
  }

  Duration get _windowSpan => _window.length < 2
      ? Duration.zero
      : _window.last.elapsed - _window.first.elapsed;

  double _turnRateAroundGravity(CalibratedSensorSample sample) =>
      sample.correctedGyroscope
          ?.dot(calibration.gravityVector.normalized)
          .abs() ??
      0;

  double _mean(Iterable<double> values) {
    final list = values.toList(growable: false);
    return list.isEmpty ? 0 : list.reduce((a, b) => a + b) / list.length;
  }

  double _ratioConfidence(double value, double threshold) =>
      (value / (threshold * 1.8)).clamp(0.45, 1.0);
}
