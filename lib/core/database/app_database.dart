import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  Database? _database;

  Future<Database> get instance async => _database ??= await _open();

  Future<Database> _open() async {
    final databaseDirectory = await getDatabasesPath();
    return openDatabase(
      path.join(databaseDirectory, 'balance_detect.db'),
      version: 1,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (database, version) async {
        final batch = database.batch();
        batch.execute('''
          CREATE TABLE patient_profiles (
            id TEXT PRIMARY KEY,
            display_name TEXT NOT NULL,
            age INTEGER,
            notes TEXT NOT NULL,
            updated_at_ms INTEGER NOT NULL
          )
        ''');
        batch.execute('''
          CREATE TABLE assessment_sessions (
            id TEXT PRIMARY KEY,
            profile_id TEXT,
            timestamp_ms INTEGER NOT NULL,
            valid INTEGER NOT NULL,
            invalid_reason TEXT,
            FOREIGN KEY(profile_id) REFERENCES patient_profiles(id)
          )
        ''');
        batch.execute('''
          CREATE TABLE calibration_records (
            id TEXT PRIMARY KEY,
            session_id TEXT NOT NULL,
            timestamp_ms INTEGER NOT NULL,
            scale_cm_per_unit REAL NOT NULL,
            method TEXT NOT NULL,
            reference_distance_cm REAL NOT NULL,
            confidence REAL NOT NULL,
            FOREIGN KEY(session_id) REFERENCES assessment_sessions(id) ON DELETE CASCADE
          )
        ''');
        batch.execute('''
          CREATE TABLE functional_reach_results (
            id TEXT PRIMARY KEY,
            session_id TEXT NOT NULL UNIQUE,
            timestamp_ms INTEGER NOT NULL,
            distance_cm REAL NOT NULL,
            distance_inch REAL NOT NULL,
            threshold_inch REAL NOT NULL,
            status TEXT NOT NULL,
            foot_movement_detected INTEGER NOT NULL,
            calibration_method TEXT NOT NULL,
            confidence REAL NOT NULL,
            valid INTEGER NOT NULL,
            invalid_reason TEXT,
            FOREIGN KEY(session_id) REFERENCES assessment_sessions(id) ON DELETE CASCADE
          )
        ''');
        batch.execute('''
          CREATE TABLE fullerton_results (
            id TEXT PRIMARY KEY,
            session_id TEXT NOT NULL UNIQUE,
            timestamp_ms INTEGER NOT NULL,
            score INTEGER NOT NULL,
            step_count INTEGER NOT NULL,
            supervision_required INTEGER,
            confidence REAL NOT NULL,
            valid INTEGER NOT NULL,
            invalid_reason TEXT,
            FOREIGN KEY(session_id) REFERENCES assessment_sessions(id) ON DELETE CASCADE
          )
        ''');
        batch.execute('''
          CREATE TABLE tug_results (
            id TEXT PRIMARY KEY,
            session_id TEXT NOT NULL UNIQUE,
            timestamp_ms INTEGER NOT NULL,
            total_seconds REAL NOT NULL,
            threshold_seconds REAL NOT NULL,
            risk_status TEXT NOT NULL,
            stand_duration REAL,
            outbound_walk_duration REAL,
            turn_duration REAL,
            return_walk_duration REAL,
            sit_duration REAL,
            confidence REAL NOT NULL,
            valid INTEGER NOT NULL,
            invalid_reason TEXT,
            FOREIGN KEY(session_id) REFERENCES assessment_sessions(id) ON DELETE CASCADE
          )
        ''');
        batch.execute(
          'CREATE INDEX session_timestamp_idx '
          'ON assessment_sessions(timestamp_ms DESC)',
        );
        await batch.commit(noResult: true);
      },
    );
  }

  Future<void> close() async {
    final database = _database;
    _database = null;
    await database?.close();
  }
}
