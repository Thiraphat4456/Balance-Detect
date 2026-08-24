import 'package:balance_detect/core/database/app_database.dart';
import 'package:balance_detect/features/assessment/domain/assessment_repository.dart';
import 'package:balance_detect/features/assessment/domain/assessment_session.dart';
import 'package:balance_detect/features/assessment/domain/calibration_record.dart';
import 'package:balance_detect/features/fullerton/domain/fullerton_result.dart';
import 'package:balance_detect/features/functional_reach/domain/functional_reach_result.dart';
import 'package:balance_detect/features/profile/domain/patient_profile.dart';
import 'package:balance_detect/features/tug/domain/tug_result.dart';
import 'package:sqflite/sqflite.dart';

class LocalAssessmentRepository implements AssessmentRepository {
  LocalAssessmentRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  @override
  Future<List<AssessmentSession>> getSessions() async {
    final database = await _appDatabase.instance;
    final rows = await database.query(
      'assessment_sessions',
      orderBy: 'timestamp_ms DESC',
    );
    final sessions = <AssessmentSession>[];
    for (final row in rows) {
      sessions.add(await _hydrateSession(database, row));
    }
    return sessions;
  }

  @override
  Future<AssessmentSession?> getSession(String id) async {
    final database = await _appDatabase.instance;
    final rows = await database.query(
      'assessment_sessions',
      where: 'id = ?',
      whereArgs: <Object>[id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _hydrateSession(database, rows.single);
  }

  Future<AssessmentSession> _hydrateSession(
    DatabaseExecutor database,
    Map<String, Object?> row,
  ) async {
    final id = row['id']! as String;
    final reachRows = await database.query(
      'functional_reach_results',
      where: 'session_id = ?',
      whereArgs: <Object>[id],
      limit: 1,
    );
    final fullertonRows = await database.query(
      'fullerton_results',
      where: 'session_id = ?',
      whereArgs: <Object>[id],
      limit: 1,
    );
    final tugRows = await database.query(
      'tug_results',
      where: 'session_id = ?',
      whereArgs: <Object>[id],
      limit: 1,
    );
    return AssessmentSession.fromMap(
      row,
      functionalReach: reachRows.isEmpty
          ? null
          : FunctionalReachResult.fromMap(reachRows.single),
      fullerton: fullertonRows.isEmpty
          ? null
          : FullertonResult.fromMap(fullertonRows.single),
      tug: tugRows.isEmpty ? null : TugResult.fromMap(tugRows.single),
    );
  }

  @override
  Future<void> saveFunctionalReach(
    AssessmentSession session,
    CalibrationRecord calibration,
    FunctionalReachResult result,
  ) async {
    final database = await _appDatabase.instance;
    await database.transaction((transaction) async {
      await _insertSession(transaction, session);
      await transaction.insert(
        'calibration_records',
        calibration.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await transaction.insert(
        'functional_reach_results',
        result.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  @override
  Future<void> saveFullerton(
    AssessmentSession session,
    FullertonResult result,
  ) async {
    final database = await _appDatabase.instance;
    await database.transaction((transaction) async {
      await _insertSession(transaction, session);
      await transaction.insert(
        'fullerton_results',
        result.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  @override
  Future<void> saveTug(AssessmentSession session, TugResult result) async {
    final database = await _appDatabase.instance;
    await database.transaction((transaction) async {
      await _insertSession(transaction, session);
      await transaction.insert(
        'tug_results',
        result.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<void> _insertSession(
    DatabaseExecutor database,
    AssessmentSession session,
  ) async {
    await database.insert(
      'assessment_sessions',
      session.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  @override
  Future<PatientProfile?> getProfile() async {
    final database = await _appDatabase.instance;
    final rows = await database.query(
      'patient_profiles',
      orderBy: 'updated_at_ms DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : PatientProfile.fromMap(rows.single);
  }

  @override
  Future<void> saveProfile(PatientProfile profile) async {
    final database = await _appDatabase.instance;
    await database.insert(
      'patient_profiles',
      profile.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<FunctionalReachResult>> getFunctionalReachTrend() async {
    final database = await _appDatabase.instance;
    final rows = await database.query(
      'functional_reach_results',
      where: 'valid = 1',
      orderBy: 'timestamp_ms ASC',
    );
    return rows.map(FunctionalReachResult.fromMap).toList(growable: false);
  }

  @override
  Future<List<FullertonResult>> getFullertonTrend() async {
    final database = await _appDatabase.instance;
    final rows = await database.query(
      'fullerton_results',
      where: 'valid = 1',
      orderBy: 'timestamp_ms ASC',
    );
    return rows.map(FullertonResult.fromMap).toList(growable: false);
  }

  @override
  Future<List<TugResult>> getTugTrend() async {
    final database = await _appDatabase.instance;
    final rows = await database.query(
      'tug_results',
      where: 'valid = 1',
      orderBy: 'timestamp_ms ASC',
    );
    return rows.map(TugResult.fromMap).toList(growable: false);
  }

  @override
  Future<void> close() => _appDatabase.close();
}
