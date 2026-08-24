import 'dart:math' as math;

import 'package:balance_detect/core/constants/assessment_config.dart';
import 'package:balance_detect/features/assessment/domain/calibration_record.dart';
import 'package:balance_detect/features/functional_reach/domain/distance_calibration_service.dart';
import 'package:balance_detect/features/pose/domain/pose_frame.dart';

class ReachMeasurementSnapshot {
  const ReachMeasurementSnapshot({
    required this.maximumDistanceCm,
    required this.footMovementDetected,
    required this.confidence,
    this.leftFootMovementCm = 0,
    this.rightFootMovementCm = 0,
    this.footMovementThresholdCm = 0,
  });

  final double maximumDistanceCm;
  final bool footMovementDetected;
  final double confidence;
  final double leftFootMovementCm;
  final double rightFootMovementCm;
  final double footMovementThresholdCm;
}

class ReachMeasurementService {
  ReachMeasurementService({
    required this.calibration,
    this._calibrationService = const ExplicitDistanceCalibrationService(),
  });

  final CalibrationRecord calibration;
  final DistanceCalibrationService _calibrationService;
  final List<NormalizedPoint> _wristBaseline = <NormalizedPoint>[];
  final List<NormalizedPoint> _leftFootBaseline = <NormalizedPoint>[];
  final List<NormalizedPoint> _rightFootBaseline = <NormalizedPoint>[];
  final List<NormalizedPoint> _wristSmoothing = <NormalizedPoint>[];
  final List<NormalizedPoint> _leftFootSmoothing = <NormalizedPoint>[];
  final List<NormalizedPoint> _rightFootSmoothing = <NormalizedPoint>[];
  final List<double> _poseConfidences = <double>[];

  NormalizedPoint? _baselineWrist;
  NormalizedPoint? _baselineLeftFoot;
  NormalizedPoint? _baselineRightFoot;
  double _maximumDistanceCm = 0;
  bool _footMovementDetected = false;
  int _leftFootCandidateFrames = 0;
  int _rightFootCandidateFrames = 0;
  double _leftFootMovementCm = 0;
  double _rightFootMovementCm = 0;
  double _footMovementThresholdCm = 0;

  bool get hasBaseline => _baselineWrist != null;
  double get maximumDistanceCm => _maximumDistanceCm;
  bool get footMovementDetected => _footMovementDetected;

  void addBaselineFrame(PoseFrame frame, PrimaryBodySide primarySide) {
    final wrist = frame[primarySide.wrist];
    final leftFoot = _plantedFootAnchor(frame, PrimaryBodySide.left);
    final rightFoot = _plantedFootAnchor(frame, PrimaryBodySide.right);
    if (wrist == null || leftFoot == null || rightFoot == null) return;
    _wristBaseline.add(wrist);
    _leftFootBaseline.add(leftFoot);
    _rightFootBaseline.add(rightFoot);
  }

  bool finalizeStableBaseline() {
    if (_wristBaseline.length < AssessmentConfig.reachBaselineMinFrames ||
        _leftFootBaseline.length < AssessmentConfig.reachBaselineMinFrames ||
        _rightFootBaseline.length < AssessmentConfig.reachBaselineMinFrames) {
      return false;
    }
    final wrist = NormalizedPoint.average(_wristBaseline);
    if (_maximumDeviation(_wristBaseline, wrist) >
        AssessmentConfig.reachBaselineMaxJitterNormalized) {
      return false;
    }
    _baselineWrist = wrist;
    _baselineLeftFoot = NormalizedPoint.average(_leftFootBaseline);
    _baselineRightFoot = NormalizedPoint.average(_rightFootBaseline);
    for (
      var index = 0;
      index < AssessmentConfig.footMovementSmoothingWindow;
      index += 1
    ) {
      _leftFootSmoothing.add(_baselineLeftFoot!);
      _rightFootSmoothing.add(_baselineRightFoot!);
    }
    return true;
  }

  ReachMeasurementSnapshot addReachFrame(
    PoseFrame frame,
    PrimaryBodySide primarySide,
  ) {
    final baselineWrist = _baselineWrist;
    final baselineLeftFoot = _baselineLeftFoot;
    final baselineRightFoot = _baselineRightFoot;
    if (baselineWrist == null ||
        baselineLeftFoot == null ||
        baselineRightFoot == null) {
      throw StateError('Reach baseline has not been finalized');
    }
    final wrist = frame[primarySide.wrist];
    final leftFoot = _plantedFootAnchor(frame, PrimaryBodySide.left);
    final rightFoot = _plantedFootAnchor(frame, PrimaryBodySide.right);
    if (wrist == null || leftFoot == null || rightFoot == null) {
      _leftFootCandidateFrames = 0;
      _rightFootCandidateFrames = 0;
      return snapshot;
    }

    _wristSmoothing.add(wrist);
    if (_wristSmoothing.length > AssessmentConfig.reachSmoothingWindow) {
      _wristSmoothing.removeAt(0);
    }
    final smoothedWrist = NormalizedPoint.average(_wristSmoothing);
    final horizontalDisplacement = (smoothedWrist.x - baselineWrist.x).abs();
    final distanceCm = _calibrationService.normalizedDistanceToCentimeters(
      horizontalDisplacement,
      calibration,
    );
    _maximumDistanceCm = math.max(_maximumDistanceCm, distanceCm);

    _addSmoothedPoint(_leftFootSmoothing, leftFoot);
    _addSmoothedPoint(_rightFootSmoothing, rightFoot);
    final smoothedLeftFoot = NormalizedPoint.average(_leftFootSmoothing);
    final smoothedRightFoot = NormalizedPoint.average(_rightFootSmoothing);
    _leftFootMovementCm = _pointDistanceCm(
      smoothedLeftFoot,
      baselineLeftFoot,
      frame.imageAspectRatio,
    );
    _rightFootMovementCm = _pointDistanceCm(
      smoothedRightFoot,
      baselineRightFoot,
      frame.imageAspectRatio,
    );
    final normalizedNoiseFloorCm =
        _calibrationService.normalizedDistanceToCentimeters(
          AssessmentConfig.footMovementNoiseFloorNormalized,
          calibration,
        );
    _footMovementThresholdCm = math.max(
      AssessmentConfig.footMovementToleranceCm,
      normalizedNoiseFloorCm,
    );
    _leftFootCandidateFrames =
        _leftFootMovementCm > _footMovementThresholdCm
        ? _leftFootCandidateFrames + 1
        : 0;
    _rightFootCandidateFrames =
        _rightFootMovementCm > _footMovementThresholdCm
        ? _rightFootCandidateFrames + 1
        : 0;
    if (_leftFootCandidateFrames >=
            AssessmentConfig.footMovementConfirmationFrames ||
        _rightFootCandidateFrames >=
            AssessmentConfig.footMovementConfirmationFrames) {
      _footMovementDetected = true;
    }
    _poseConfidences.add(
      <double>[
            wrist.confidence,
            leftFoot.confidence,
            rightFoot.confidence,
          ].reduce((a, b) => a + b) /
          3,
    );
    return snapshot;
  }

  ReachMeasurementSnapshot get snapshot {
    final poseConfidence = _poseConfidences.isEmpty
        ? 0.0
        : _poseConfidences.reduce((a, b) => a + b) / _poseConfidences.length;
    return ReachMeasurementSnapshot(
      maximumDistanceCm: _maximumDistanceCm,
      footMovementDetected: _footMovementDetected,
      confidence: (poseConfidence * calibration.confidence).clamp(0.0, 1.0),
      leftFootMovementCm: _leftFootMovementCm,
      rightFootMovementCm: _rightFootMovementCm,
      footMovementThresholdCm: _footMovementThresholdCm,
    );
  }

  NormalizedPoint? _plantedFootAnchor(
    PoseFrame frame,
    PrimaryBodySide side,
  ) {
    final heel = frame[side.heel];
    final toe = frame[side.footIndex];
    if (heel == null ||
        toe == null ||
        heel.confidence < AssessmentConfig.poseConfidenceThreshold ||
        toe.confidence < AssessmentConfig.poseConfidenceThreshold) {
      return null;
    }

    // The ankle joint naturally translates during an ankle-strategy reach
    // even while the plantar contact area remains fixed. Tracking a stable,
    // fixed-composition heel/toe midpoint avoids treating that joint motion as
    // a step and also avoids center shifts when landmark availability changes.
    return NormalizedPoint.average(<NormalizedPoint>[heel, toe]);
  }

  void _addSmoothedPoint(
    List<NormalizedPoint> values,
    NormalizedPoint point,
  ) {
    values.add(point);
    if (values.length > AssessmentConfig.footMovementSmoothingWindow) {
      values.removeAt(0);
    }
  }

  double _pointDistanceCm(
    NormalizedPoint point,
    NormalizedPoint baseline,
    double imageAspectRatio,
  ) {
    final safeAspectRatio = imageAspectRatio.isFinite && imageAspectRatio > 0
        ? imageAspectRatio
        : 1.0;
    final horizontalCm =
        (point.x - baseline.x).abs() * calibration.scaleCmPerNormalizedUnit;
    final verticalCm =
        (point.y - baseline.y).abs() *
        calibration.scaleCmPerNormalizedUnit /
        safeAspectRatio;
    return math.sqrt(horizontalCm * horizontalCm + verticalCm * verticalCm);
  }

  double _maximumDeviation(
    List<NormalizedPoint> values,
    NormalizedPoint mean,
  ) => values.map((point) => point.distanceTo(mean)).fold(0.0, math.max);
}
