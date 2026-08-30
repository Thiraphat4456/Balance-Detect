import 'package:balance_detect/core/constants/assessment_config.dart';
import 'package:balance_detect/features/pose/domain/pose_frame.dart';

/// Reduces single-frame landmark jitter without hiding a genuine movement.
///
/// ML Kit can move a landmark by a few pixels even when a person is standing
/// still. That noise is especially visible on the heel, toe, wrist and elbow
/// and can make the overlay look detached from the body. A short, confidence-
/// aware exponential smoother keeps the current frame responsive while
/// damping small changes. Large jumps are treated as a new observation so a
/// temporary bad detection is not allowed to drag the skeleton across the
/// screen.
final class PoseFrameSmoother {
  PoseFrame? _previous;

  static const _maximumPlausibleJump = 0.18;
  static const _minimumCurrentWeight = 0.58;
  static const _reliableCurrentWeight = 0.74;
  static const _maximumFrameGap = Duration(milliseconds: 350);

  PoseFrame smooth(PoseFrame frame) {
    final previous = _previous;
    if (frame.landmarks.isEmpty ||
        previous == null ||
        frame.timestamp - previous.timestamp > _maximumFrameGap ||
        (frame.imageAspectRatio - previous.imageAspectRatio).abs() > .01) {
      _previous = frame.landmarks.isEmpty ? null : frame;
      return frame;
    }

    final smoothed = <BodyLandmark, NormalizedPoint>{};
    for (final entry in frame.landmarks.entries) {
      final current = entry.value;
      final old = previous.landmarks[entry.key];
      if (old == null) {
        smoothed[entry.key] = current;
        continue;
      }

      final displacement = current.distanceTo(old);
      if (displacement > _maximumPlausibleJump) {
        smoothed[entry.key] = current;
        continue;
      }

      final baseWeight = current.confidence >=
              AssessmentConfig.poseConfidenceThreshold
          ? _reliableCurrentWeight
          : _minimumCurrentWeight;
      // Respond a little faster to a real movement while retaining most of
      // the jitter reduction for nearly stationary joints.
      final currentWeight =
          (baseWeight + displacement * 1.5).clamp(baseWeight, .94);
      smoothed[entry.key] = NormalizedPoint(
        x: _blend(old.x, current.x, currentWeight),
        y: _blend(old.y, current.y, currentWeight),
        confidence: current.confidence,
      );
    }

    final result = PoseFrame(
      timestamp: frame.timestamp,
      landmarks: smoothed,
      imageAspectRatio: frame.imageAspectRatio,
    );
    _previous = result;
    return result;
  }

  void reset() => _previous = null;

  double _blend(double old, double current, double currentWeight) =>
      old + (current - old) * currentWeight;
}
