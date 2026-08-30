import 'package:balance_detect/core/constants/assessment_config.dart';
import 'package:balance_detect/features/pose/domain/pose_frame.dart';
import 'package:flutter/material.dart';

/// Draws the pose landmarks in the same normalized coordinate space as the
/// camera preview.
///
/// Reliable joints are cyan, unreliable joints are red, and the arm currently
/// selected for measurement is amber. The dark outline keeps the skeleton
/// visible over both light and dark camera backgrounds.
class PoseSkeletonOverlay extends StatelessWidget {
  const PoseSkeletonOverlay({
    required this.frame,
    this.highlightedSide,
    super.key,
  });

  final PoseFrame? frame;
  final PrimaryBodySide? highlightedSide;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: frame == null
          ? 'กำลังค้นหาจุดข้อต่อของร่างกาย'
          : 'แสดงโครงกระดูกและจุดข้อต่อที่ตรวจจับได้',
      child: IgnorePointer(
        child: CustomPaint(
          painter: PoseSkeletonPainter(
            frame: frame,
            highlightedSide: highlightedSide,
          ),
        ),
      ),
    );
  }
}

class PoseSkeletonPainter extends CustomPainter {
  const PoseSkeletonPainter({required this.frame, this.highlightedSide});

  final PoseFrame? frame;
  final PrimaryBodySide? highlightedSide;

  static const _jointColor = Color(0xFF39D4C8);
  static const _boneColor = Color(0xFFF2FFFF);
  static const _highlightColor = Color(0xFFFFC247);
  static const _lowConfidenceColor = Color(0xFFFF6259);

  static const _bones = <_PoseBone>[
    _PoseBone(BodyLandmark.leftShoulder, BodyLandmark.rightShoulder),
    _PoseBone(BodyLandmark.leftShoulder, BodyLandmark.leftElbow),
    _PoseBone(BodyLandmark.leftElbow, BodyLandmark.leftWrist),
    _PoseBone(BodyLandmark.rightShoulder, BodyLandmark.rightElbow),
    _PoseBone(BodyLandmark.rightElbow, BodyLandmark.rightWrist),
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
      final start = currentFrame[bone.start];
      final end = currentFrame[bone.end];
      if (start == null || end == null) continue;

      final highlighted = _isHighlightedArmBone(bone);
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
      final point = entry.value;
      final highlighted = _isHighlightedArmJoint(entry.key);
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

  bool _isHighlightedArmBone(_PoseBone bone) {
    final side = highlightedSide;
    if (side == null) return false;
    return (bone.start == side.shoulder && bone.end == side.elbow) ||
        (bone.start == side.elbow && bone.end == side.wrist);
  }

  bool _isHighlightedArmJoint(BodyLandmark landmark) {
    final side = highlightedSide;
    return side != null &&
        (landmark == side.shoulder ||
            landmark == side.elbow ||
            landmark == side.wrist);
  }

  Offset _toOffset(NormalizedPoint point, Size size) => Offset(
    point.x.clamp(0.0, 1.0) * size.width,
    point.y.clamp(0.0, 1.0) * size.height,
  );

  @override
  bool shouldRepaint(covariant PoseSkeletonPainter oldDelegate) =>
      oldDelegate.frame != frame ||
      oldDelegate.highlightedSide != highlightedSide;
}

class _PoseBone {
  const _PoseBone(this.start, this.end);

  final BodyLandmark start;
  final BodyLandmark end;
}
