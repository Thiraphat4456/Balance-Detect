import 'dart:math' as math;

import 'package:balance_detect/core/constants/assessment_config.dart';
import 'package:balance_detect/features/functional_reach/domain/functional_reach_instructions.dart';
import 'package:balance_detect/features/pose/domain/pose_frame.dart';

class FunctionalReachPostureValidation {
  const FunctionalReachPostureValidation({
    required this.landmarksReliable,
    required this.armPerpendicularToTorso,
    required this.elbowExtended,
    required this.armToTorsoAngleDegrees,
    required this.elbowAngleDegrees,
  });

  final bool landmarksReliable;
  final bool armPerpendicularToTorso;
  final bool elbowExtended;
  final double? armToTorsoAngleDegrees;
  final double? elbowAngleDegrees;

  bool get canMeasure =>
      landmarksReliable && armPerpendicularToTorso && elbowExtended;

  String get guidance {
    if (!landmarksReliable) {
      return 'จัดให้กล้องเห็นหัวไหล่ ข้อศอก ข้อมือ และสะโพกฝั่งกล้องครบ';
    }
    final armToTorsoAngle = armToTorsoAngleDegrees!;
    if (armToTorsoAngle <
        AssessmentConfig.functionalReachArmToTorsoAngleMinDegrees) {
      return FunctionalReachInstructions.raiseTrackedArm;
    }
    if (armToTorsoAngle >
        AssessmentConfig.functionalReachArmToTorsoAngleMaxDegrees) {
      return FunctionalReachInstructions.lowerTrackedArm;
    }
    if (!elbowExtended) {
      return FunctionalReachInstructions.extendTrackedElbow;
    }
    return FunctionalReachInstructions.trackedArmReady;
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
        armPerpendicularToTorso: false,
        elbowExtended: false,
        armToTorsoAngleDegrees: null,
        elbowAngleDegrees: null,
      );
    }

    final armToTorsoAngle = _jointAngleDegrees(
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
    final geometryReliable = armToTorsoAngle != null && elbowAngle != null;
    return FunctionalReachPostureValidation(
      landmarksReliable: geometryReliable,
      armPerpendicularToTorso:
          geometryReliable &&
          armToTorsoAngle >=
              AssessmentConfig.functionalReachArmToTorsoAngleMinDegrees &&
          armToTorsoAngle <=
              AssessmentConfig.functionalReachArmToTorsoAngleMaxDegrees,
      elbowExtended:
          geometryReliable &&
          elbowAngle >= AssessmentConfig.functionalReachElbowAngleMinDegrees,
      armToTorsoAngleDegrees: armToTorsoAngle,
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
