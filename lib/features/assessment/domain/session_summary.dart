import 'package:balance_detect/core/domain/assessment_enums.dart';
import 'package:balance_detect/features/assessment/domain/assessment_session.dart';

abstract final class SessionSummary {
  static AssessmentStatus status(AssessmentSession session) {
    if (!session.valid) return AssessmentStatus.invalid;
    if (session.tug?.riskStatus == AssessmentStatus.risk) {
      return AssessmentStatus.risk;
    }
    if (session.functionalReach?.status == AssessmentStatus.warning ||
        (session.fullerton != null && session.fullerton!.score <= 2)) {
      return AssessmentStatus.warning;
    }
    return AssessmentStatus.normal;
  }

  static String label(AssessmentSession session) => switch (status(session)) {
    AssessmentStatus.normal => 'อยู่ในเกณฑ์',
    AssessmentStatus.warning => 'ควรเฝ้าระวัง',
    AssessmentStatus.risk => 'พบความเสี่ยง',
    AssessmentStatus.invalid => 'การทดสอบไม่สมบูรณ์',
  };
}
