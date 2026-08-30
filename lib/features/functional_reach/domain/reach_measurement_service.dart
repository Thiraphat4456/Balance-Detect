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
    this.trackedFootSide,
    this.trackedFootRawMovementCm = 0,
    this.trackedFootRelativeMovementCm = 0,
    this.trackedFootAnkleMovementCm = 0,
  });

  final double maximumDistanceCm;
  final bool footMovementDetected;
  final double confidence;
  final double leftFootMovementCm;
  final double rightFootMovementCm;
  final double footMovementThresholdCm;
  final PrimaryBodySide? trackedFootSide;
  final double trackedFootRawMovementCm;
  final double trackedFootRelativeMovementCm;
  final double trackedFootAnkleMovementCm;

  double get trackedFootMovementCm => switch (trackedFootSide) {
    PrimaryBodySide.left => leftFootMovementCm,
    PrimaryBodySide.right => rightFootMovementCm,
    null => 0,
  };
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
  final List<NormalizedPoint> _trackedAnkleBaselineSamples =
      <NormalizedPoint>[];
  final List<NormalizedPoint> _trackedHipBaselineSamples =
      <NormalizedPoint>[];
  final List<NormalizedPoint> _trackedAnkleSmoothing = <NormalizedPoint>[];
  final List<NormalizedPoint> _trackedHipSmoothing = <NormalizedPoint>[];
  final List<double> _trackedFootBaselineAspectRatios = <double>[];
  final List<double> _poseConfidences = <double>[];

  PrimaryBodySide? _trackedFootSide;
  NormalizedPoint? _baselineWrist;
  NormalizedPoint? _baselineLeftFoot;
  NormalizedPoint? _baselineRightFoot;
  NormalizedPoint? _baselineTrackedAnkle;
  NormalizedPoint? _baselineTrackedHip;
  double _maximumDistanceCm = 0;
  bool _footMovementDetected = false;
  int _trackedFootCandidateFrames = 0;
  double _leftFootMovementCm = 0;
  double _rightFootMovementCm = 0;
  double _footMovementThresholdCm = 0;
  double _baselineFootJitterNormalized = 0;
  double _baselineFootJitterCm = 0;
  double _trackedFootRawMovementCm = 0;
  double _trackedFootRelativeMovementCm = 0;
  double _trackedFootAnkleMovementCm = 0;

  bool get hasBaseline =>
      _baselineWrist != null && _baselineForSide(_trackedFootSide) != null;
  double get maximumDistanceCm => _maximumDistanceCm;
  bool get footMovementDetected => _footMovementDetected;
  PrimaryBodySide? get trackedFootSide => _trackedFootSide;
  double get baselineFootJitterNormalized => _baselineFootJitterNormalized;
  double get baselineFootJitterCm => _baselineFootJitterCm;

  void addBaselineFrame(PoseFrame frame, PrimaryBodySide primarySide) {
    final trackedSide = _trackedFootSide;
    if (trackedSide != null && trackedSide != primarySide) {
      throw StateError('Reach baseline side changed during capture');
    }
    _trackedFootSide ??= primarySide;

    final wrist = frame[primarySide.wrist];
    final trackedFoot = _plantedFootAnchor(frame, primarySide);
    final trackedAnkle = frame[primarySide.ankle];
    final trackedHip = frame[primarySide.hip];
    if (wrist == null ||
        trackedFoot == null ||
        !_isReliable(trackedAnkle) ||
        !_isReliable(trackedHip)) {
      return;
    }

    final otherSide = primarySide == PrimaryBodySide.left
        ? PrimaryBodySide.right
        : PrimaryBodySide.left;
    final otherFoot = _plantedFootAnchor(frame, otherSide);
    _wristBaseline.add(wrist);
    _baselineValuesForSide(primarySide).add(trackedFoot);
    _trackedAnkleBaselineSamples.add(trackedAnkle!);
    _trackedHipBaselineSamples.add(trackedHip!);
    if (otherFoot != null) {
      _baselineValuesForSide(otherSide).add(otherFoot);
    }
    _trackedFootBaselineAspectRatios.add(_safeAspectRatio(frame));
  }

  bool finalizeStableBaseline() {
    final trackedSide = _trackedFootSide;
    if (trackedSide == null) return false;
    final trackedFootBaseline = _baselineValuesForSide(trackedSide);
    if (_wristBaseline.length < AssessmentConfig.reachBaselineMinFrames ||
        trackedFootBaseline.length < AssessmentConfig.reachBaselineMinFrames ||
        _trackedAnkleBaselineSamples.length <
            AssessmentConfig.reachBaselineMinFrames ||
        _trackedHipBaselineSamples.length <
            AssessmentConfig.reachBaselineMinFrames) {
      return false;
    }
    final wrist = NormalizedPoint.average(_wristBaseline);
    if (_maximumDeviation(_wristBaseline, wrist) >
        AssessmentConfig.reachBaselineMaxJitterNormalized) {
      return false;
    }
    final trackedFoot = _medianPoint(trackedFootBaseline);
    _baselineFootJitterNormalized = _robustDeviation(
      trackedFootBaseline,
      trackedFoot,
    );
    final baselineAspectRatio = _median(_trackedFootBaselineAspectRatios);
    _baselineFootJitterCm = _robustDeviationCm(
      trackedFootBaseline,
      trackedFoot,
      baselineAspectRatio,
    );
    if (_baselineFootJitterNormalized >
        AssessmentConfig.reachFootBaselineMaxJitterNormalized) {
      return false;
    }

    _baselineWrist = wrist;
    _baselineTrackedAnkle = _medianPoint(_trackedAnkleBaselineSamples);
    _baselineTrackedHip = _medianPoint(_trackedHipBaselineSamples);
    if (trackedSide == PrimaryBodySide.left) {
      _baselineLeftFoot = trackedFoot;
    } else {
      _baselineRightFoot = trackedFoot;
    }
    final otherSide = trackedSide == PrimaryBodySide.left
        ? PrimaryBodySide.right
        : PrimaryBodySide.left;
    final otherFootBaseline = _baselineValuesForSide(otherSide);
    if (otherFootBaseline.length >= AssessmentConfig.reachBaselineMinFrames) {
      final otherFoot = _medianPoint(otherFootBaseline);
      if (otherSide == PrimaryBodySide.left) {
        _baselineLeftFoot = otherFoot;
      } else {
        _baselineRightFoot = otherFoot;
      }
    }
    for (
      var index = 0;
      index < AssessmentConfig.footMovementSmoothingWindow;
      index += 1
    ) {
      final leftBaseline = _baselineLeftFoot;
      final rightBaseline = _baselineRightFoot;
      if (leftBaseline != null) _leftFootSmoothing.add(leftBaseline);
      if (rightBaseline != null) _rightFootSmoothing.add(rightBaseline);
      _trackedAnkleSmoothing.add(_baselineTrackedAnkle!);
      _trackedHipSmoothing.add(_baselineTrackedHip!);
    }
    return true;
  }

  ReachMeasurementSnapshot addReachFrame(
    PoseFrame frame,
    PrimaryBodySide primarySide,
  ) {
    final trackedSide = _trackedFootSide;
    final baselineWrist = _baselineWrist;
    final trackedFootBaseline = _baselineForSide(trackedSide);
    if (baselineWrist == null ||
        trackedSide == null ||
        trackedFootBaseline == null) {
      throw StateError('Reach baseline has not been finalized');
    }
    if (trackedSide != primarySide) {
      throw StateError('Reach tracking side changed after baseline');
    }
    final wrist = frame[primarySide.wrist];
    final leftFoot = _plantedFootAnchor(frame, PrimaryBodySide.left);
    final rightFoot = _plantedFootAnchor(frame, PrimaryBodySide.right);
    final trackedAnklePoint = frame[trackedSide.ankle];
    final trackedHipPoint = frame[trackedSide.hip];
    final trackedFoot = trackedSide == PrimaryBodySide.left
        ? leftFoot
        : rightFoot;
    if (wrist == null ||
        trackedFoot == null ||
        !_isReliable(trackedAnklePoint) ||
        !_isReliable(trackedHipPoint)) {
      _trackedFootCandidateFrames = 0;
      return snapshot;
    }

    final baselineTrackedAnkle = _baselineTrackedAnkle;
    final baselineTrackedHip = _baselineTrackedHip;
    if (baselineTrackedAnkle == null || baselineTrackedHip == null) {
      _trackedFootCandidateFrames = 0;
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

    final smoothedLeftFoot = _smoothPoint(_leftFootSmoothing, leftFoot);
    final smoothedRightFoot = _smoothPoint(_rightFootSmoothing, rightFoot);
    final leftFootMovement = _movementFromBaseline(
      smoothedLeftFoot,
      _baselineLeftFoot,
      frame.imageAspectRatio,
    );
    final rightFootMovement = _movementFromBaseline(
      smoothedRightFoot,
      _baselineRightFoot,
      frame.imageAspectRatio,
    );
    final normalizedNoiseFloorCm = _calibrationService
        .normalizedDistanceToCentimeters(
          AssessmentConfig.footMovementNoiseFloorNormalized,
          calibration,
        );
    final baselineNoiseThresholdCm =
        _baselineFootJitterCm *
            AssessmentConfig.footMovementBaselineNoiseMultiplier +
        AssessmentConfig.footMovementBaselineNoiseMarginCm;
    _footMovementThresholdCm = math.max(
      AssessmentConfig.footMovementToleranceCm,
      math.max(normalizedNoiseFloorCm, baselineNoiseThresholdCm),
    );
    final smoothedTrackedFoot = trackedSide == PrimaryBodySide.left
        ? smoothedLeftFoot
        : smoothedRightFoot;
    final smoothedTrackedAnkle = _smoothPoint(
      _trackedAnkleSmoothing,
      trackedAnklePoint,
    );
    final smoothedTrackedHip = _smoothPoint(
      _trackedHipSmoothing,
      trackedHipPoint,
    );
    final baselineTrackedFoot = _baselineForSide(trackedSide);
    final rawTrackedMovement = _movementFromBaseline(
      smoothedTrackedFoot,
      baselineTrackedFoot,
      frame.imageAspectRatio,
    );
    final relativeTrackedMovement = _relativeMovementFromBaseline(
      point: smoothedTrackedFoot,
      body: smoothedTrackedHip,
      baselinePoint: baselineTrackedFoot,
      baselineBody: baselineTrackedHip,
      imageAspectRatio: frame.imageAspectRatio,
    );
    final ankleTrackedMovement = _movementFromBaseline(
      smoothedTrackedAnkle,
      baselineTrackedAnkle,
      frame.imageAspectRatio,
    );
    final acceptedTrackedMovement = _acceptedFootMovement(
      rawMovementCm: rawTrackedMovement,
      relativeMovementCm: relativeTrackedMovement,
      ankleMovementCm: ankleTrackedMovement,
      thresholdCm: _footMovementThresholdCm,
    );
    _trackedFootRawMovementCm = rawTrackedMovement;
    _trackedFootRelativeMovementCm = relativeTrackedMovement;
    _trackedFootAnkleMovementCm = ankleTrackedMovement;
    _leftFootMovementCm = trackedSide == PrimaryBodySide.left
        ? acceptedTrackedMovement
        : leftFootMovement;
    _rightFootMovementCm = trackedSide == PrimaryBodySide.right
        ? acceptedTrackedMovement
        : rightFootMovement;
    final trackedFootMovementCm = trackedSide == PrimaryBodySide.left
        ? _leftFootMovementCm
        : _rightFootMovementCm;
    _trackedFootCandidateFrames =
        trackedFootMovementCm > _footMovementThresholdCm
        ? _trackedFootCandidateFrames + 1
        : 0;
    if (_trackedFootCandidateFrames >=
        AssessmentConfig.footMovementConfirmationFrames) {
      _footMovementDetected = true;
    }
    _poseConfidences.add((wrist.confidence + trackedFoot.confidence) / 2);
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
      trackedFootSide: _trackedFootSide,
      trackedFootRawMovementCm: _trackedFootRawMovementCm,
      trackedFootRelativeMovementCm: _trackedFootRelativeMovementCm,
      trackedFootAnkleMovementCm: _trackedFootAnkleMovementCm,
    );
  }

  NormalizedPoint? _smoothPoint(
    List<NormalizedPoint> smoothing,
    NormalizedPoint? point,
  ) {
    if (point == null) return null;
    _addSmoothedPoint(smoothing, point);
    return NormalizedPoint.average(smoothing);
  }

  double _movementFromBaseline(
    NormalizedPoint? point,
    NormalizedPoint? baseline,
    double imageAspectRatio,
  ) => point == null || baseline == null
      ? 0
      : _pointDistanceCm(point, baseline, imageAspectRatio);

  double _relativeMovementFromBaseline({
    required NormalizedPoint? point,
    required NormalizedPoint? body,
    required NormalizedPoint? baselinePoint,
    required NormalizedPoint? baselineBody,
    required double imageAspectRatio,
  }) {
    if (point == null ||
        body == null ||
        baselinePoint == null ||
        baselineBody == null) {
      return 0;
    }
    return _distanceCmFromDelta(
      dx: (point.x - body.x) - (baselinePoint.x - baselineBody.x),
      dy: (point.y - body.y) - (baselinePoint.y - baselineBody.y),
      imageAspectRatio: imageAspectRatio,
    );
  }

  double _acceptedFootMovement({
    required double rawMovementCm,
    required double relativeMovementCm,
    required double ankleMovementCm,
    required double thresholdCm,
  }) {
    // Absolute displacement alone is not enough: a global pose translation
    // can move every landmark in the image while the feet remain planted.
    if (rawMovementCm <= thresholdCm || relativeMovementCm <= thresholdCm) {
      return 0;
    }
    final ankleSupportThreshold = math.max(
      AssessmentConfig.footMovementAnkleSupportFloorCm,
      rawMovementCm * AssessmentConfig.footMovementAnkleSupportRatio,
    );
    // Heel/toe-only drift with a stable ankle is a model artifact. A real
    // step should carry the ankle in the same direction as the contact
    // anchor, so require independent support from that landmark as well.
    if (ankleMovementCm < ankleSupportThreshold) return 0;
    return relativeMovementCm;
  }

  NormalizedPoint? _plantedFootAnchor(PoseFrame frame, PrimaryBodySide side) {
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

  void _addSmoothedPoint(List<NormalizedPoint> values, NormalizedPoint point) {
    values.add(point);
    if (values.length > AssessmentConfig.footMovementSmoothingWindow) {
      values.removeAt(0);
    }
  }

  double _pointDistanceCm(
    NormalizedPoint point,
    NormalizedPoint baseline,
    double imageAspectRatio,
  ) => _distanceCmFromDelta(
    dx: point.x - baseline.x,
    dy: point.y - baseline.y,
    imageAspectRatio: imageAspectRatio,
  );

  double _distanceCmFromDelta({
    required double dx,
    required double dy,
    required double imageAspectRatio,
  }) {
    final safeAspectRatio = imageAspectRatio.isFinite && imageAspectRatio > 0
        ? imageAspectRatio
        : 1.0;
    final horizontalCm = dx.abs() * calibration.scaleCmPerNormalizedUnit;
    final verticalCm =
        dy.abs() * calibration.scaleCmPerNormalizedUnit / safeAspectRatio;
    return math.sqrt(horizontalCm * horizontalCm + verticalCm * verticalCm);
  }

  bool _isReliable(NormalizedPoint? point) =>
      point != null &&
      point.confidence >= AssessmentConfig.poseConfidenceThreshold;

  List<NormalizedPoint> _baselineValuesForSide(PrimaryBodySide side) =>
      side == PrimaryBodySide.left ? _leftFootBaseline : _rightFootBaseline;

  NormalizedPoint? _baselineForSide(PrimaryBodySide? side) => switch (side) {
    PrimaryBodySide.left => _baselineLeftFoot,
    PrimaryBodySide.right => _baselineRightFoot,
    null => null,
  };

  NormalizedPoint _medianPoint(List<NormalizedPoint> values) => NormalizedPoint(
    x: _median(values.map((point) => point.x)),
    y: _median(values.map((point) => point.y)),
    confidence: _median(values.map((point) => point.confidence)),
  );

  double _median(Iterable<double> values) {
    final sorted = values.toList()..sort();
    if (sorted.isEmpty) return 0;
    final middle = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[middle]
        : (sorted[middle - 1] + sorted[middle]) / 2;
  }

  double _robustDeviation(
    List<NormalizedPoint> values,
    NormalizedPoint center,
  ) => _percentile90(values.map((point) => point.distanceTo(center)));

  double _robustDeviationCm(
    List<NormalizedPoint> values,
    NormalizedPoint center,
    double imageAspectRatio,
  ) => _percentile90(
    values.map((point) => _pointDistanceCm(point, center, imageAspectRatio)),
  );

  double _percentile90(Iterable<double> values) {
    final sorted = values.toList()..sort();
    if (sorted.isEmpty) return 0;
    final index = (sorted.length * .9).ceil() - 1;
    return sorted[index.clamp(0, sorted.length - 1)];
  }

  double _safeAspectRatio(PoseFrame frame) =>
      frame.imageAspectRatio.isFinite && frame.imageAspectRatio > 0
      ? frame.imageAspectRatio
      : 1;

  double _maximumDeviation(
    List<NormalizedPoint> values,
    NormalizedPoint mean,
  ) => values.map((point) => point.distanceTo(mean)).fold(0.0, math.max);
}
