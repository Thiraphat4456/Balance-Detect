import 'dart:math' as math;

import 'package:balance_detect/core/constants/assessment_config.dart';
import 'package:balance_detect/core/domain/assessment_enums.dart';
import 'package:balance_detect/features/tug/domain/sensor_models.dart';
import 'package:balance_detect/features/tug/domain/tug_logic.dart';
import 'package:balance_detect/features/tug/domain/tug_motion_analyzer.dart';

/// Basic TUG timing for devices that do not expose a gyroscope.
///
/// The analyzer deliberately does not claim to measure the 180-degree turn.
/// It uses gated outbound/return motion evidence and a participant-specific
/// seated gravity direction to prevent a standing pause from ending the test.
/// Only the total duration is exposed in the completed timeline.
class AccelerometerOnlyTugAnalyzer implements TugAnalyzer {
  AccelerometerOnlyTugAnalyzer({
    required this.calibration,
    required this.stateMachine,
  }) : assert(
         calibration.mode == TugMeasurementMode.accelerometerOnly,
         'Accelerometer-only analyzer requires matching calibration',
       );

  final SensorCalibration calibration;
  final TugStateMachine stateMachine;
  final List<CalibratedSensorSample> _window = <CalibratedSensorSample>[];
  final List<Vector3Sample> _standingGravitySamples = <Vector3Sample>[];
  final List<double> _eventConfidence = <double>[];

  Duration? _testStart;
  Duration? _standDetected;
  Duration? _outboundWalkStart;
  Duration? _turnWindowStart;
  Duration? _returnWalkStart;
  Duration? _lastReturnMotionAt;
  Duration? _sitDownStart;
  Duration? _sitDetected;
  Vector3Sample? _standingGravityVector;

  @override
  TugMeasurementMode get measurementMode =>
      TugMeasurementMode.accelerometerOnly;

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
    if (_testStart == null) {
      throw StateError('TUG analyzer has not started');
    }
    _window.add(sample);
    _trimWindow(
      sample.elapsed,
      AssessmentConfig.tugAccelerometerOnlyQuietWindow,
    );

    final meanAcceleration = _mean(
      _window.map((value) => value.dynamicAccelerationMagnitude),
    );
    final meanRawAcceleration = _meanVector(
      _window.map((value) => value.rawAcceleration),
    );
    final gravityMagnitudeDeviation =
        (meanRawAcceleration.magnitude - calibration.gravityVector.magnitude)
            .abs();

    if (stateMachine.state == TugState.walkingBack &&
        sample.dynamicAccelerationMagnitude >=
            AssessmentConfig.tugAccelerometerOnlyMotionEvidence) {
      _lastReturnMotionAt = sample.elapsed;
    }

    switch (stateMachine.state) {
      case TugState.sitting:
        if (_windowSpan >= const Duration(milliseconds: 350) &&
            meanAcceleration >= AssessmentConfig.tugStandAcceleration) {
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
        final stand = _standDetected;
        if (stand != null &&
            sample.elapsed - stand >= const Duration(milliseconds: 450) &&
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
        if (_validGravity(meanRawAcceleration)) {
          _standingGravitySamples.add(meanRawAcceleration.normalized);
        }
        final outbound = _outboundWalkStart;
        if (outbound != null &&
            sample.elapsed - outbound >=
                AssessmentConfig.tugAccelerometerOnlyMinOutbound &&
            meanAcceleration >=
                AssessmentConfig.tugWalkingDynamicAcceleration) {
          _standingGravityVector = _meanVector(_standingGravitySamples);
          _turnWindowStart = sample.elapsed;
          _eventConfidence.add(
            _ratioConfidence(
                  meanAcceleration,
                  AssessmentConfig.tugWalkingDynamicAcceleration,
                ) *
                0.75,
          );
          stateMachine.transitionTo(TugState.turning);
          _window.clear();
        }
      case TugState.turning:
        final turnStart = _turnWindowStart;
        if (turnStart != null &&
            sample.elapsed - turnStart >=
                AssessmentConfig.tugAccelerometerOnlyTurnWindow &&
            meanAcceleration >=
                AssessmentConfig.tugWalkingDynamicAcceleration) {
          _returnWalkStart = sample.elapsed;
          _eventConfidence.add(0.55);
          stateMachine.transitionTo(TugState.walkingBack);
          _window.clear();
        }
      case TugState.walkingBack:
        final returnStart = _returnWalkStart;
        final recentMotion = _lastReturnMotionAt;
        if (returnStart != null &&
            recentMotion != null &&
            sample.elapsed - returnStart >=
                AssessmentConfig.tugAccelerometerOnlyMinReturn &&
            sample.elapsed - recentMotion <=
                const Duration(milliseconds: 1500) &&
            _orientationSuggestsSeated(meanRawAcceleration)) {
          _sitDownStart = recentMotion;
          stateMachine.transitionTo(TugState.sittingDown);
          _window.clear();
        }
      case TugState.sittingDown:
        if (_windowSpan >= AssessmentConfig.tugAccelerometerOnlyQuietWindow &&
            meanAcceleration <=
                AssessmentConfig.tugAccelerometerOnlyQuietAcceleration &&
            gravityMagnitudeDeviation <=
                AssessmentConfig.tugSittingGravityMagnitudeTolerance &&
            _orientationSuggestsSeated(meanRawAcceleration)) {
          _sitDetected = _sitDownStart ?? sample.elapsed;
          _eventConfidence.add(
            (1 -
                        gravityMagnitudeDeviation /
                            AssessmentConfig
                                .tugSittingGravityMagnitudeTolerance)
                    .clamp(0.0, 1.0) *
                0.75,
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

    return _snapshot(sample, meanAcceleration, gravityMagnitudeDeviation);
  }

  TugAnalysisSnapshot _snapshot(
    CalibratedSensorSample sample,
    double acceleration,
    double gravityMagnitudeDeviation,
  ) {
    final eventScore = _eventConfidence.isEmpty
        ? 0.5
        : _eventConfidence.reduce((a, b) => a + b) / _eventConfidence.length;
    final confidence = math.min(
      AssessmentConfig.tugAccelerometerOnlyConfidenceCap,
      eventScore * calibration.confidence,
    );
    final completed = stateMachine.state == TugState.completed;
    return TugAnalysisSnapshot(
      state: stateMachine.state,
      elapsed: sample.elapsed,
      dynamicAcceleration: acceleration,
      gravityMagnitudeDeviation: gravityMagnitudeDeviation,
      angularVelocity: 0,
      confidence: confidence,
      measurementMode: measurementMode,
      turnVerified: false,
      timeline: completed
          ? TugTimeline(
              testStart: _testStart!,
              testEnd: _sitDetected ?? sample.elapsed,
            )
          : null,
    );
  }

  bool _orientationSuggestsSeated(Vector3Sample candidate) {
    final standing = _standingGravityVector;
    if (standing == null || !_validGravity(candidate)) return false;
    final seated = calibration.gravityVector.normalized;
    final normalizedCandidate = candidate.normalized;
    final seatedSimilarity = normalizedCandidate.dot(seated);
    final standingSimilarity = normalizedCandidate.dot(standing.normalized);
    final minimumSimilarity = math.cos(
      AssessmentConfig.tugAccelerometerOnlySeatedAngleDegrees * math.pi / 180,
    );
    return seatedSimilarity >= minimumSimilarity &&
        seatedSimilarity >=
            standingSimilarity +
                AssessmentConfig.tugAccelerometerOnlyPostureMargin;
  }

  bool _validGravity(Vector3Sample value) =>
      value.magnitude >= 7 && value.magnitude <= 12.5;

  void _trimWindow(Duration now, Duration duration) {
    _window.removeWhere((sample) => now - sample.elapsed > duration);
  }

  Duration get _windowSpan => _window.length < 2
      ? Duration.zero
      : _window.last.elapsed - _window.first.elapsed;

  double _mean(Iterable<double> values) {
    final list = values.toList(growable: false);
    return list.isEmpty ? 0 : list.reduce((a, b) => a + b) / list.length;
  }

  Vector3Sample _meanVector(Iterable<Vector3Sample> values) {
    final list = values.toList(growable: false);
    if (list.isEmpty) return const Vector3Sample(0, 0, 0);
    final sum = list.fold(
      const Vector3Sample(0, 0, 0),
      (total, value) => total + value,
    );
    return sum / list.length.toDouble();
  }

  double _ratioConfidence(double value, double threshold) =>
      (value / (threshold * 1.8)).clamp(0.45, 1.0);
}
