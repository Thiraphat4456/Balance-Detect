import 'package:balance_detect/core/constants/assessment_config.dart';
import 'package:balance_detect/features/pose/domain/pose_frame.dart';
import 'package:flutter/material.dart';

/// Draws the pose landmarks in the same normalized coordinate space as the
/// camera preview.
///
/// Reliable joints are cyan, unreliable joints are red, and the single arm
/// selected for measurement is amber. The opposite arm is deliberately not
/// drawn because its landmarks are commonly inferred incorrectly when it is
/// occluded in a side view.
class PoseSkeletonOverlay extends StatelessWidget {
  const PoseSkeletonOverlay({required this.frame, this.trackedSide, super.key});

  final PoseFrame? frame;
  final PrimaryBodySide? trackedSide;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: frame == null
          ? 'กำลังค้นหาจุดข้อต่อของร่างกาย'
          : 'แสดงโครงกระดูกโดยติดตามแขนฝั่งกล้องเพียงข้างเดียว',
      child: IgnorePointer(
        child: CustomPaint(
          painter: PoseSkeletonPainter(frame: frame, trackedSide: trackedSide),
        ),
      ),
    );
  }
}

class PoseSkeletonPainter extends CustomPainter {
  const PoseSkeletonPainter({required this.frame, this.trackedSide});

  final PoseFrame? frame;
  final PrimaryBodySide? trackedSide;

  static const _jointColor = Color(0xFF39D4C8);
  static const _boneColor = Color(0xFFF2FFFF);
  static const _highlightColor = Color(0xFFFFC247);
  static const _lowConfidenceColor = Color(0xFFFF6259);

  static const _bones = <_PoseBone>[
    _PoseBone(BodyLandmark.leftShoulder, BodyLandmark.rightShoulder),
    _PoseBone(BodyLandmark.leftShoulder, BodyLandmark.leftElbow),
    _PoseBone(BodyLandmark.leftElbow, BodyLandmark.leftWrist),
    _PoseBone(BodyLandmark.leftWrist, BodyLandmark.leftIndex),
    _PoseBone(BodyLandmark.rightShoulder, BodyLandmark.rightElbow),
    _PoseBone(BodyLandmark.rightElbow, BodyLandmark.rightWrist),
    _PoseBone(BodyLandmark.rightWrist, BodyLandmark.rightIndex),
    _PoseBone(BodyLandmark.leftShoulder, BodyLandmark.leftHip),
    _PoseBone(BodyLandmark.rightShoulder, BodyLandmark.rightHip),
    _PoseBone(BodyLandmark.leftHip, BodyLandmark.rightHip),
    _PoseBone(BodyLandmark.leftHip, BodyLandmark.leftKnee),
    _PoseBone(BodyLandmark.leftKnee, BodyLandmark.leftAnkle),
    _PoseBone(BodyLandmark.rightHip, BodyLandmark.rightKnee),
    _PoseBone(BodyLandmark.rightKnee, BodyLandmark.rightAnkle),
    _PoseBone(BodyLandmark.leftAnkle, BodyLandmark.leftHeel),
    _PoseBone(BodyLandmark.leftHeel, BodyLandmark.leftFootIndex),
    _PoseBone(BodyLandmark.leftAnkle, BodyLandmark.leftFootIndex),
    _PoseBone(BodyLandmark.rightAnkle, BodyLandmark.rightHeel),
    _PoseBone(BodyLandmark.rightHeel, BodyLandmark.rightFootIndex),
    _PoseBone(BodyLandmark.rightAnkle, BodyLandmark.rightFootIndex),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final currentFrame = frame;
    if (currentFrame == null || size.isEmpty) return;

    final outlinePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.68)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final bonePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final bone in _bones) {
      final armSide = _armSideForBone(bone);
      if (armSide != null && !drawsArm(armSide)) continue;
      final start = currentFrame[bone.start];
      final end = currentFrame[bone.end];
      if (start == null || end == null) continue;

      final highlighted = armSide == trackedSide;
      final reliable = _isReliable(start) && _isReliable(end);
      final width = highlighted ? 5.5 : 3.5;
      final startOffset = _toOffset(start, size);
      final endOffset = _toOffset(end, size);

      outlinePaint.strokeWidth = width + 3;
      canvas.drawLine(startOffset, endOffset, outlinePaint);
      bonePaint
        ..strokeWidth = width
        ..color = !reliable
            ? _lowConfidenceColor.withValues(alpha: 0.78)
            : highlighted
            ? _highlightColor
            : _boneColor.withValues(alpha: 0.92);
      canvas.drawLine(startOffset, endOffset, bonePaint);
    }

    final nodeOutlinePaint = Paint()
      ..color = Colors.black.withValues(alpha: .8);
    final nodePaint = Paint();
    for (final entry in currentFrame.landmarks.entries) {
      if (!drawsLandmark(entry.key)) continue;
      final point = entry.value;
      final highlighted = _isTrackedArmJoint(entry.key);
      final radius = highlighted ? 5.2 : 3.8;
      final offset = _toOffset(point, size);
      canvas.drawCircle(offset, radius + 2.2, nodeOutlinePaint);
      nodePaint.color = !_isReliable(point)
          ? _lowConfidenceColor
          : highlighted
          ? _highlightColor
          : _jointColor;
      canvas.drawCircle(offset, radius, nodePaint);
    }
  }

  bool _isReliable(NormalizedPoint point) =>
      point.confidence >= AssessmentConfig.poseConfidenceThreshold;

  /// Exposed for deterministic tests of the one-arm rendering rule.
  bool drawsArm(PrimaryBodySide side) => trackedSide == side;

  /// Keeps both shoulders for the torso outline, but hides the elbow and wrist
  /// belonging to the occluded arm.
  bool drawsLandmark(BodyLandmark landmark) {
    if (landmark == BodyLandmark.leftElbow ||
        landmark == BodyLandmark.leftWrist ||
        landmark == BodyLandmark.leftIndex) {
      return drawsArm(PrimaryBodySide.left);
    }
    if (landmark == BodyLandmark.rightElbow ||
        landmark == BodyLandmark.rightWrist ||
        landmark == BodyLandmark.rightIndex) {
      return drawsArm(PrimaryBodySide.right);
    }
    return true;
  }

  PrimaryBodySide? _armSideForBone(_PoseBone bone) {
    for (final side in PrimaryBodySide.values) {
      if ((bone.start == side.shoulder && bone.end == side.elbow) ||
          (bone.start == side.elbow && bone.end == side.wrist) ||
          (bone.start == side.wrist && bone.end == side.indexFinger)) {
        return side;
      }
    }
    return null;
  }

  bool _isTrackedArmJoint(BodyLandmark landmark) {
    final side = trackedSide;
    return side != null &&
        (landmark == side.shoulder ||
            landmark == side.elbow ||
            landmark == side.wrist ||
            landmark == side.indexFinger);
  }

  Offset _toOffset(NormalizedPoint point, Size size) => Offset(
    point.x.clamp(0.0, 1.0) * size.width,
    point.y.clamp(0.0, 1.0) * size.height,
  );

  @override
  bool shouldRepaint(covariant PoseSkeletonPainter oldDelegate) =>
      oldDelegate.frame != frame || oldDelegate.trackedSide != trackedSide;
}

class _PoseBone {
  const _PoseBone(this.start, this.end);

  final BodyLandmark start;
  final BodyLandmark end;
}
