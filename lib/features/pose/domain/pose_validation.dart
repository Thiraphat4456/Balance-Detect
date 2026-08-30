import 'package:balance_detect/core/constants/assessment_config.dart';
import 'package:balance_detect/features/pose/domain/pose_frame.dart';

class PoseValidation {
  const PoseValidation({
    required this.bodyVisible,
    required this.armVisible,
    required this.feetVisible,
    required this.sideView,
    required this.confidence,
    required this.primarySide,
    required this.guidance,
  });

  final bool bodyVisible;
  final bool armVisible;
  final bool feetVisible;
  final bool sideView;
  final double confidence;
  final PrimaryBodySide primarySide;
  final String guidance;

  bool get canStart =>
      bodyVisible &&
      armVisible &&
      feetVisible &&
      sideView &&
      confidence >= AssessmentConfig.poseConfidenceThreshold;
}

class PoseValidationService {
  const PoseValidationService();

  PoseValidation validate(
    PoseFrame frame, {
    required bool requireSideView,
    PrimaryBodySide? trackedSide,
    bool requireWristForArm = true,
  }) {
    late final PrimaryBodySide primarySide;
    late final double sideScore;
    if (trackedSide != null) {
      // Once Functional Reach locks the camera-side arm, do not evaluate the
      // occluded limb again. ML Kit still returns it, but it cannot affect
      // visibility, confidence, posture, or measurement decisions.
      primarySide = trackedSide;
      sideScore = _sideConfidence(
        frame,
        trackedSide,
        includeWrist: requireWristForArm,
      );
    } else {
      final leftScore = _sideConfidence(
        frame,
        PrimaryBodySide.left,
        includeWrist: requireWristForArm,
      );
      final rightScore = _sideConfidence(
        frame,
        PrimaryBodySide.right,
        includeWrist: requireWristForArm,
      );
      primarySide = leftScore >= rightScore
          ? PrimaryBodySide.left
          : PrimaryBodySide.right;
      sideScore = leftScore >= rightScore ? leftScore : rightScore;
    }
    final bodyVisible = _areVisible(frame, <BodyLandmark>[
      primarySide.shoulder,
      primarySide.hip,
      primarySide.knee,
      primarySide.ankle,
    ]);
    final armVisible = _areVisible(frame, <BodyLandmark>[
      primarySide.shoulder,
      primarySide.elbow,
      if (requireWristForArm) primarySide.wrist,
    ]);
    final feetVisible = _areVisible(frame, <BodyLandmark>[
      BodyLandmark.leftAnkle,
      BodyLandmark.rightAnkle,
      BodyLandmark.leftHeel,
      BodyLandmark.rightHeel,
      BodyLandmark.leftFootIndex,
      BodyLandmark.rightFootIndex,
    ], minimumFraction: 0.66);
    final shoulderSeparation = _horizontalSeparation(
      frame[BodyLandmark.leftShoulder],
      frame[BodyLandmark.rightShoulder],
    );
    final hipSeparation = _horizontalSeparation(
      frame[BodyLandmark.leftHip],
      frame[BodyLandmark.rightHip],
    );
    final torsoLength = _torsoLength(frame);
    final shoulderToTorsoRatio = torsoLength == 0
        ? double.infinity
        : shoulderSeparation / torsoLength;
    final hipToTorsoRatio = torsoLength == 0
        ? double.infinity
        : hipSeparation / torsoLength;
    final sideView =
        !requireSideView ||
        (shoulderToTorsoRatio <=
                AssessmentConfig.sideViewMaxShoulderToTorsoRatio &&
            hipToTorsoRatio <= AssessmentConfig.sideViewMaxHipToTorsoRatio);

    final guidance = !bodyVisible
        ? 'กรุณาถอยออกจากกล้อง จัดให้เห็นตั้งแต่ศีรษะถึงเท้า'
        : !armVisible
        ? requireWristForArm
              ? 'กรุณาจัดให้เห็นหัวไหล่ ข้อศอก และข้อมือฝั่งที่หันเข้ากล้องครบ'
              : 'กรุณาจัดให้เห็นหัวไหล่และข้อศอกฝั่งที่หันเข้ากล้องครบ'
        : !feetVisible
        ? 'กรุณาขยับกล้องลงหรือถอยออก ให้เห็นเท้าทั้งสองข้าง'
        : !sideView
        ? 'กรุณาหันลำตัวด้านข้างเข้าหากล้อง'
        : sideScore < AssessmentConfig.poseConfidenceThreshold
        ? 'ภาพยังไม่ชัด กรุณาเพิ่มแสงและอยู่นิ่ง'
        : 'ตำแหน่งพร้อมแล้ว อยู่นิ่ง ระบบกำลังเริ่มอัตโนมัติ';

    return PoseValidation(
      bodyVisible: bodyVisible,
      armVisible: armVisible,
      feetVisible: feetVisible,
      sideView: sideView,
      confidence: sideScore,
      primarySide: primarySide,
      guidance: guidance,
    );
  }

  double _sideConfidence(
    PoseFrame frame,
    PrimaryBodySide side, {
    required bool includeWrist,
  }) {
    final points = <NormalizedPoint?>[
      frame[side.shoulder],
      frame[side.elbow],
      if (includeWrist) frame[side.wrist],
      frame[side.hip],
      frame[side.knee],
      frame[side.ankle],
      frame[side.heel],
      frame[side.footIndex],
    ].whereType<NormalizedPoint>().toList(growable: false);
    if (points.isEmpty) return 0;
    return points.fold(0.0, (sum, point) => sum + point.confidence) /
        points.length;
  }

  bool _areVisible(
    PoseFrame frame,
    List<BodyLandmark> landmarks, {
    double minimumFraction = 1,
  }) {
    final visible = landmarks.where((landmark) {
      final point = frame[landmark];
      return point != null &&
          point.confidence >= AssessmentConfig.poseConfidenceThreshold;
    }).length;
    return visible / landmarks.length >= minimumFraction;
  }

  double _horizontalSeparation(NormalizedPoint? a, NormalizedPoint? b) {
    if (a == null || b == null) return 1;
    return (a.x - b.x).abs();
  }

  double _torsoLength(PoseFrame frame) {
    final lengths = <double>[];
    final leftShoulder = frame[BodyLandmark.leftShoulder];
    final leftHip = frame[BodyLandmark.leftHip];
    final rightShoulder = frame[BodyLandmark.rightShoulder];
    final rightHip = frame[BodyLandmark.rightHip];
    if (leftShoulder != null && leftHip != null) {
      lengths.add(leftShoulder.distanceTo(leftHip));
    }
    if (rightShoulder != null && rightHip != null) {
      lengths.add(rightShoulder.distanceTo(rightHip));
    }
    return lengths.isEmpty
        ? 0
        : lengths.reduce((a, b) => a + b) / lengths.length;
  }
}
