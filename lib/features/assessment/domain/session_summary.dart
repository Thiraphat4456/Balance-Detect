import 'package:balance_detect/core/domain/assessment_enums.dart';
import 'package:balance_detect/features/assessment/domain/assessment_session.dart';
import 'package:balance_detect/features/fullerton/domain/fullerton_reach_calibration_service.dart';

abstract final class SessionSummary {
  static AssessmentStatus status(AssessmentSession session) {
    if (!session.valid) return AssessmentStatus.invalid;
    if (session.tug?.riskStatus == AssessmentStatus.risk) {
      return AssessmentStatus.risk;
    }
    final fullerton = session.fullerton;
    if (session.functionalReach?.status == AssessmentStatus.warning ||
        (fullerton != null &&
            (!fullerton.protocolVariant.isStandard || fullerton.score <= 2))) {
      return AssessmentStatus.warning;
    }
    return AssessmentStatus.normal;
  }

  static String label(AssessmentSession session) {
    final resolvedStatus = status(session);
    final fullerton = session.fullerton;
    final onlyNonstandardFullertonWarning =
        resolvedStatus == AssessmentStatus.warning &&
        session.functionalReach?.status != AssessmentStatus.warning &&
        fullerton != null &&
        !fullerton.protocolVariant.isStandard;
    if (onlyNonstandardFullertonWarning) {
      return fullerton.protocolVariant.isExperimental
          ? 'ผลแบบทดลอง'
          : 'ผลเดิมไม่ระบุโปรโตคอล';
    }
    return switch (resolvedStatus) {
      AssessmentStatus.normal => 'อยู่ในเกณฑ์',
      AssessmentStatus.warning => 'ควรเฝ้าระวัง',
      AssessmentStatus.risk => 'พบความเสี่ยง',
      AssessmentStatus.invalid => 'การทดสอบไม่สมบูรณ์',
    };
  }
}
