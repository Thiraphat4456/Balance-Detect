import 'dart:math' as math;

import 'package:balance_detect/core/constants/assessment_config.dart';
import 'package:balance_detect/features/pose/domain/pose_frame.dart';

class StepDetectionSnapshot {
  const StepDetectionSnapshot({
    required this.stepCount,
    required this.leftFootMovement,
    required this.rightFootMovement,
    required this.confidence,
  });

  final int stepCount;
  final double leftFootMovement;
  final double rightFootMovement;
  final double confidence;
}

class FullertonFootAnchor {
  const FullertonFootAnchor({
    required this.ankle,
    required this.heel,
    required this.toe,
    required this.center,
    required this.footLength,
    required this.jitter,
    required this.confidence,
  });

  final NormalizedPoint ankle;
  final NormalizedPoint heel;
  final NormalizedPoint toe;
  final NormalizedPoint center;
  final double footLength;
  final double jitter;
  final double confidence;
}

class FullertonFootBaseline {
  const FullertonFootBaseline({
    required this.left,
    required this.right,
    required this.confidence,
  });

  final FullertonFootAnchor left;
  final FullertonFootAnchor right;
  final double confidence;

  double get maximumJitter => math.max(left.jitter, right.jitter);
}

/// Calibrates each participant's actual starting footprint, then counts only
/// persistent foot translations supported by the ankle landmark.
///
/// A heel rise changes the heel's vertical coordinate but is explicitly not a
/// step in FAB item 2. Step candidacy therefore uses horizontal translation in
/// the required side view and requires both the contact anchor and ankle to
/// move together. This also suppresses isolated heel/toe landmark spikes.
class StepDetectionService {
  final List<_FootObservation> _leftBaselineSamples = <_FootObservation>[];
  final List<_FootObservation> _rightBaselineSamples = <_FootObservation>[];
  FullertonFootBaseline? _baseline;
  NormalizedPoint? _leftTrackingCenter;
  NormalizedPoint? _rightTrackingCenter;
  NormalizedPoint? _leftTrackingAnkle;
  NormalizedPoint? _rightTrackingAnkle;
  int _leftCandidateFrames = 0;
  int _rightCandidateFrames = 0;
  Duration _lastLeftStep = Duration.zero;
  Duration _lastRightStep = Duration.zero;
  int _stepCount = 0;
  double _leftMovement = 0;
  double _rightMovement = 0;
  final List<double> _confidences = <double>[];

  bool get hasBaseline => _baseline != null;
  FullertonFootBaseline? get baseline => _baseline;

  bool canObserveBothFeet(PoseFrame frame) =>
      _observation(frame, PrimaryBodySide.left) != null &&
      _observation(frame, PrimaryBodySide.right) != null;

  void addBaselineFrame(PoseFrame frame) {
    final left = _observation(frame, PrimaryBodySide.left);
    final right = _observation(frame, PrimaryBodySide.right);
    if (left != null) _leftBaselineSamples.add(left);
    if (right != null) _rightBaselineSamples.add(right);
  }

  bool finalizeBaseline() {
    if (_leftBaselineSamples.length <
            AssessmentConfig.fullertonBaselineMinFrames ||
        _rightBaselineSamples.length <
            AssessmentConfig.fullertonBaselineMinFrames) {
      return false;
    }
    final left = _buildAnchor(_leftBaselineSamples);
    final right = _buildAnchor(_rightBaselineSamples);
    if (left == null || right == null) return false;
    if (left.jitter >
            AssessmentConfig.fullertonFootBaselineMaxJitterNormalized ||
        right.jitter >
            AssessmentConfig.fullertonFootBaselineMaxJitterNormalized) {
      return false;
    }
    _baseline = FullertonFootBaseline(
      left: left,
      right: right,
      confidence: (left.confidence + right.confidence) / 2,
    );
    _leftTrackingCenter = left.center;
    _rightTrackingCenter = right.center;
    _leftTrackingAnkle = left.ankle;
    _rightTrackingAnkle = right.ankle;
    return true;
  }

  bool feetRemainAtBaseline(PoseFrame frame) {
    final baseline = _baseline;
    final left = _observation(frame, PrimaryBodySide.left);
    final right = _observation(frame, PrimaryBodySide.right);
    if (baseline == null || left == null || right == null) return false;
    return !_isTranslatedFrom(
          left,
          baseline.left.center,
          baseline.left.ankle,
          baseline.left.footLength,
        ) &&
        !_isTranslatedFrom(
          right,
          baseline.right.center,
          baseline.right.ankle,
          baseline.right.footLength,
        );
  }

  StepDetectionSnapshot addFrame(PoseFrame frame) {
    final baseline = _baseline;
    final left = _observation(frame, PrimaryBodySide.left);
    final right = _observation(frame, PrimaryBodySide.right);
    final leftCenter = _leftTrackingCenter;
    final rightCenter = _rightTrackingCenter;
    final leftAnkle = _leftTrackingAnkle;
    final rightAnkle = _rightTrackingAnkle;
    if (baseline == null ||
        left == null ||
        right == null ||
        leftCenter == null ||
        rightCenter == null ||
        leftAnkle == null ||
        rightAnkle == null) {
      return snapshot;
    }

    _leftMovement = (left.center.x - leftCenter.x).abs();
    _rightMovement = (right.center.x - rightCenter.x).abs();
    _confidences.add((left.confidence + right.confidence) / 2);

    final leftCandidate = _isTranslatedFrom(
      left,
      leftCenter,
      leftAnkle,
      baseline.left.footLength,
    );
    final rightCandidate = _isTranslatedFrom(
      right,
      rightCenter,
      rightAnkle,
      baseline.right.footLength,
    );
    _leftCandidateFrames = leftCandidate ? _leftCandidateFrames + 1 : 0;
    _rightCandidateFrames = rightCandidate ? _rightCandidateFrames + 1 : 0;

    if (_leftCandidateFrames >= AssessmentConfig.stepConfirmationFrames &&
        frame.timestamp - _lastLeftStep >=
            AssessmentConfig.stepRefractoryPeriod) {
      _stepCount += 1;
      _lastLeftStep = frame.timestamp;
      _leftTrackingCenter = left.center;
      _leftTrackingAnkle = left.ankle;
      _leftCandidateFrames = 0;
    }
    if (_rightCandidateFrames >= AssessmentConfig.stepConfirmationFrames &&
        frame.timestamp - _lastRightStep >=
            AssessmentConfig.stepRefractoryPeriod) {
      _stepCount += 1;
      _lastRightStep = frame.timestamp;
      _rightTrackingCenter = right.center;
      _rightTrackingAnkle = right.ankle;
      _rightCandidateFrames = 0;
    }
    return snapshot;
  }

  StepDetectionSnapshot get snapshot {
    final meanConfidence = _confidences.isEmpty
        ? 0.0
        : _confidences.reduce((a, b) => a + b) / _confidences.length;
    final temporalConfidence = math.min(1.0, _confidences.length / 15);
    return StepDetectionSnapshot(
      stepCount: _stepCount,
      leftFootMovement: _leftMovement,
      rightFootMovement: _rightMovement,
      confidence: (meanConfidence * temporalConfidence).clamp(0.0, 1.0),
    );
  }

  bool _isTranslatedFrom(
    _FootObservation observation,
    NormalizedPoint center,
    NormalizedPoint ankle,
    double footLength,
  ) {
    final threshold = math.max(
      AssessmentConfig.stepMinNormalizedDisplacement,
      footLength * AssessmentConfig.stepFootLengthMultiplier,
    );
    final centerMovement = (observation.center.x - center.x).abs();
    final ankleMovement = (observation.ankle.x - ankle.x).abs();
    final ankleSupportThreshold = math.max(threshold * .35, .010);
    return centerMovement > threshold && ankleMovement > ankleSupportThreshold;
  }

  _FootObservation? _observation(PoseFrame frame, PrimaryBodySide side) {
    final ankle = frame[side.ankle];
    final heel = frame[side.heel];
    final toe = frame[side.footIndex];
    if (!_reliable(ankle) || !_reliable(heel) || !_reliable(toe)) return null;
    final points = <NormalizedPoint>[ankle!, heel!, toe!];
    return _FootObservation(
      ankle: ankle,
      heel: heel,
      toe: toe,
      center: NormalizedPoint.average(points),
      footLength: heel.distanceTo(toe),
      confidence:
          points.fold(0.0, (sum, point) => sum + point.confidence) /
          points.length,
    );
  }

  bool _reliable(NormalizedPoint? point) =>
      point != null &&
      point.confidence >= AssessmentConfig.poseConfidenceThreshold;

  FullertonFootAnchor? _buildAnchor(List<_FootObservation> samples) {
    if (samples.length < AssessmentConfig.fullertonBaselineMinFrames) {
      return null;
    }
    final ankle = _medianPoint(samples.map((sample) => sample.ankle).toList());
    final heel = _medianPoint(samples.map((sample) => sample.heel).toList());
    final toe = _medianPoint(samples.map((sample) => sample.toe).toList());
    final center = _medianPoint(
      samples.map((sample) => sample.center).toList(),
    );
    final jitter = _percentile(
      samples.map((sample) => sample.center.distanceTo(center)).toList(),
      .90,
    );
    return FullertonFootAnchor(
      ankle: ankle,
      heel: heel,
      toe: toe,
      center: center,
      footLength: _median(samples.map((sample) => sample.footLength).toList()),
      jitter: jitter,
      confidence: _median(samples.map((sample) => sample.confidence).toList()),
    );
  }

  NormalizedPoint _medianPoint(List<NormalizedPoint> points) => NormalizedPoint(
    x: _median(points.map((point) => point.x).toList()),
    y: _median(points.map((point) => point.y).toList()),
    confidence: _median(points.map((point) => point.confidence).toList()),
  );

  double _median(List<double> values) {
    final sorted = [...values]..sort();
    final middle = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[middle]
        : (sorted[middle - 1] + sorted[middle]) / 2;
  }

  double _percentile(List<double> values, double percentile) {
    final sorted = [...values]..sort();
    final index = ((sorted.length - 1) * percentile).round();
    return sorted[index];
  }
}

class _FootObservation {
  const _FootObservation({
    required this.ankle,
    required this.heel,
    required this.toe,
    required this.center,
    required this.footLength,
    required this.confidence,
  });

  final NormalizedPoint ankle;
  final NormalizedPoint heel;
  final NormalizedPoint toe;
  final NormalizedPoint center;
  final double footLength;
  final double confidence;
}
