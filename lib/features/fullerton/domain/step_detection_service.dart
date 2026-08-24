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

class StepDetectionService {
  final List<NormalizedPoint> _leftBaselineSamples = <NormalizedPoint>[];
  final List<NormalizedPoint> _rightBaselineSamples = <NormalizedPoint>[];
  NormalizedPoint? _leftBaseline;
  NormalizedPoint? _rightBaseline;
  double _leftFootLength = 0;
  double _rightFootLength = 0;
  int _leftCandidateFrames = 0;
  int _rightCandidateFrames = 0;
  Duration _lastLeftStep = Duration.zero;
  Duration _lastRightStep = Duration.zero;
  int _stepCount = 0;
  double _leftMovement = 0;
  double _rightMovement = 0;
  final List<double> _confidences = <double>[];

  bool get hasBaseline => _leftBaseline != null && _rightBaseline != null;

  void addBaselineFrame(PoseFrame frame) {
    final left = _footCenter(frame, PrimaryBodySide.left);
    final right = _footCenter(frame, PrimaryBodySide.right);
    if (left != null) _leftBaselineSamples.add(left);
    if (right != null) _rightBaselineSamples.add(right);
    _leftFootLength = math.max(
      _leftFootLength,
      _footLength(frame, PrimaryBodySide.left),
    );
    _rightFootLength = math.max(
      _rightFootLength,
      _footLength(frame, PrimaryBodySide.right),
    );
  }

  bool finalizeBaseline() {
    if (_leftBaselineSamples.length <
            AssessmentConfig.fullertonBaselineMinFrames ||
        _rightBaselineSamples.length <
            AssessmentConfig.fullertonBaselineMinFrames) {
      return false;
    }
    _leftBaseline = NormalizedPoint.average(_leftBaselineSamples);
    _rightBaseline = NormalizedPoint.average(_rightBaselineSamples);
    return true;
  }

  StepDetectionSnapshot addFrame(PoseFrame frame) {
    final left = _footCenter(frame, PrimaryBodySide.left);
    final right = _footCenter(frame, PrimaryBodySide.right);
    final leftBaseline = _leftBaseline;
    final rightBaseline = _rightBaseline;
    if (left == null ||
        right == null ||
        leftBaseline == null ||
        rightBaseline == null) {
      return snapshot;
    }
    _leftMovement = left.distanceTo(leftBaseline);
    _rightMovement = right.distanceTo(rightBaseline);
    _confidences.add((left.confidence + right.confidence) / 2);

    final leftThreshold = math.max(
      AssessmentConfig.stepMinNormalizedDisplacement,
      _leftFootLength * AssessmentConfig.stepFootLengthMultiplier,
    );
    final rightThreshold = math.max(
      AssessmentConfig.stepMinNormalizedDisplacement,
      _rightFootLength * AssessmentConfig.stepFootLengthMultiplier,
    );
    _leftCandidateFrames = _leftMovement > leftThreshold
        ? _leftCandidateFrames + 1
        : 0;
    _rightCandidateFrames = _rightMovement > rightThreshold
        ? _rightCandidateFrames + 1
        : 0;

    if (_leftCandidateFrames >= AssessmentConfig.stepConfirmationFrames &&
        frame.timestamp - _lastLeftStep >=
            AssessmentConfig.stepRefractoryPeriod) {
      _stepCount += 1;
      _lastLeftStep = frame.timestamp;
      _leftBaseline = left;
      _leftCandidateFrames = 0;
    }
    if (_rightCandidateFrames >= AssessmentConfig.stepConfirmationFrames &&
        frame.timestamp - _lastRightStep >=
            AssessmentConfig.stepRefractoryPeriod) {
      _stepCount += 1;
      _lastRightStep = frame.timestamp;
      _rightBaseline = right;
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

  NormalizedPoint? _footCenter(PoseFrame frame, PrimaryBodySide side) {
    final points = <NormalizedPoint?>[
      frame[side.ankle],
      frame[side.heel],
      frame[side.footIndex],
    ].whereType<NormalizedPoint>().toList(growable: false);
    return points.length < 2 ? null : NormalizedPoint.average(points);
  }

  double _footLength(PoseFrame frame, PrimaryBodySide side) {
    final heel = frame[side.heel];
    final toe = frame[side.footIndex];
    return heel == null || toe == null ? 0 : heel.distanceTo(toe);
  }
}
