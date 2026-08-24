import 'package:balance_detect/features/assessment/domain/assessment_session.dart';
import 'package:balance_detect/features/assessment/domain/calibration_record.dart';
import 'package:balance_detect/features/fullerton/domain/fullerton_result.dart';
import 'package:balance_detect/features/functional_reach/domain/functional_reach_result.dart';
import 'package:balance_detect/features/profile/domain/patient_profile.dart';
import 'package:balance_detect/features/tug/domain/tug_result.dart';

abstract interface class AssessmentRepository {
  Future<List<AssessmentSession>> getSessions();
  Future<AssessmentSession?> getSession(String id);
  Future<void> saveFunctionalReach(
    AssessmentSession session,
    CalibrationRecord calibration,
    FunctionalReachResult result,
  );
  Future<void> saveFullerton(AssessmentSession session, FullertonResult result);
  Future<void> saveTug(AssessmentSession session, TugResult result);
  Future<PatientProfile?> getProfile();
  Future<void> saveProfile(PatientProfile profile);
  Future<List<FunctionalReachResult>> getFunctionalReachTrend();
  Future<List<FullertonResult>> getFullertonTrend();
  Future<List<TugResult>> getTugTrend();
  Future<void> close();
}
