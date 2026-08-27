import 'dart:math' as math;

import 'package:balance_detect/core/constants/assessment_config.dart';
import 'package:balance_detect/features/pose/domain/pose_frame.dart';

class FunctionalReachPostureValidation {
  const FunctionalReachPostureValidation({
    required this.landmarksReliable,
    required this.shoulderReady,
    required this.elbowExtended,
    required this.shoulderAngleDegrees,
    required this.elbowAngleDegrees,
  });

  final bool landmarksReliable;
  final bool shoulderReady;
  final bool elbowExtended;
  final double? shoulderAngleDegrees;
  final double? elbowAngleDegrees;

  bool get canMeasure => landmarksReliable && shoulderReady && elbowExtended;

  String get guidance {
    if (!landmarksReliable) {
      return 'จัดให้กล้องเห็นหัวไหล่ ข้อศอก ข้อมือ และสะโพกครบ';
    }
    final shoulderAngle = shoulderAngleDegrees!;
    if (shoulderAngle <
        AssessmentConfig.functionalReachShoulderAngleMinDegrees) {
      return 'ยกแขนขึ้นอีกเล็กน้อย ให้ต้นแขนขนานกับพื้น';
    }
    if (shoulderAngle >
        AssessmentConfig.functionalReachShoulderAngleMaxDegrees) {
      return 'ลดแขนลงอีกเล็กน้อย ให้ต้นแขนขนานกับพื้น';
    }
    if (!elbowExtended) {
      return 'เหยียดข้อศอกให้ตรง แล้วอยู่นิ่ง';
    }
    return 'ท่าแขนพร้อมแล้ว อยู่นิ่ง ระบบกำลังเก็บตำแหน่งเริ่มต้น';
  }
}

class FunctionalReachPostureService {
  const FunctionalReachPostureService();

  FunctionalReachPostureValidation validate(
    PoseFrame frame,
    PrimaryBodySide side,
  ) {
    final hip = frame[side.hip];
    final shoulder = frame[side.shoulder];
    final elbow = frame[side.elbow];
    final wrist = frame[side.wrist];
    final points = <NormalizedPoint?>[hip, shoulder, elbow, wrist];
    final landmarksReliable = points.every(
      (point) =>
          point != null &&
          point.confidence >= AssessmentConfig.poseConfidenceThreshold,
    );
    if (!landmarksReliable) {
      return const FunctionalReachPostureValidation(
        landmarksReliable: false,
        shoulderReady: false,
        elbowExtended: false,
        shoulderAngleDegrees: null,
        elbowAngleDegrees: null,
      );
    }

    final shoulderAngle = _jointAngleDegrees(
      hip!,
      shoulder!,
      elbow!,
      frame.imageAspectRatio,
    );
    final elbowAngle = _jointAngleDegrees(
      shoulder,
      elbow,
      wrist!,
      frame.imageAspectRatio,
    );
    final geometryReliable = shoulderAngle != null && elbowAngle != null;
    return FunctionalReachPostureValidation(
      landmarksReliable: geometryReliable,
      shoulderReady:
          geometryReliable &&
          shoulderAngle >=
              AssessmentConfig.functionalReachShoulderAngleMinDegrees &&
          shoulderAngle <=
              AssessmentConfig.functionalReachShoulderAngleMaxDegrees,
      elbowExtended:
          geometryReliable &&
          elbowAngle >= AssessmentConfig.functionalReachElbowAngleMinDegrees,
      shoulderAngleDegrees: shoulderAngle,
      elbowAngleDegrees: elbowAngle,
    );
  }

  double? _jointAngleDegrees(
    NormalizedPoint first,
    NormalizedPoint vertex,
    NormalizedPoint third,
    double imageAspectRatio,
  ) {
    final aspectRatio = imageAspectRatio.isFinite && imageAspectRatio > 0
        ? imageAspectRatio
        : 1.0;
    final firstX = (first.x - vertex.x) * aspectRatio;
    final firstY = first.y - vertex.y;
    final thirdX = (third.x - vertex.x) * aspectRatio;
    final thirdY = third.y - vertex.y;
    final firstLength = math.sqrt(firstX * firstX + firstY * firstY);
    final thirdLength = math.sqrt(thirdX * thirdX + thirdY * thirdY);
    if (firstLength == 0 || thirdLength == 0) return null;
    final cosine =
        ((firstX * thirdX + firstY * thirdY) / (firstLength * thirdLength))
            .clamp(-1.0, 1.0);
    return math.acos(cosine) * 180 / math.pi;
  }
}
