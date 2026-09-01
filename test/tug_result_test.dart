import 'package:balance_detect/core/domain/assessment_enums.dart';
import 'package:balance_detect/features/assessment/domain/assessment_session.dart';
import 'package:balance_detect/features/assessment/domain/session_summary.dart';
import 'package:balance_detect/features/tug/domain/sensor_models.dart';
import 'package:balance_detect/features/tug/domain/tug_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TUG result preserves accelerometer-only provenance', () {
    final result = TugResult(
      id: 'tug-1',
      sessionId: 'session-1',
      timestamp: DateTime.utc(2026, 9),
      totalSeconds: 14.2,
      thresholdSeconds: 13.5,
      riskStatus: AssessmentStatus.risk,
      measurementMode: TugMeasurementMode.accelerometerOnly,
      turnVerified: false,
      confidence: 0.7,
      valid: true,
    );

    final restored = TugResult.fromMap(result.toMap());

    expect(restored.measurementMode, TugMeasurementMode.accelerometerOnly);
    expect(restored.turnVerified, isFalse);
    expect(restored.turnDuration, isNull);
  });

  test('legacy rows remain distinguishable from a full IMU result', () {
    final restored = TugResult.fromMap(<String, Object?>{
      'id': 'legacy',
      'session_id': 'session',
      'timestamp_ms': 0,
      'total_seconds': 10.0,
      'threshold_seconds': 13.5,
      'risk_status': 'normal',
      'stand_duration': null,
      'outbound_walk_duration': null,
      'turn_duration': null,
      'return_walk_duration': null,
      'sit_duration': null,
      'confidence': 0.8,
      'valid': 1,
      'invalid_reason': null,
    });

    expect(restored.measurementMode, TugMeasurementMode.legacyUnspecified);
    expect(restored.turnVerified, isFalse);
  });

  test(
    'accelerometer-only result is not summarized as full normal evidence',
    () {
      final tug = TugResult(
        id: 'tug-basic',
        sessionId: 'session-basic',
        timestamp: DateTime.utc(2026, 9),
        totalSeconds: 10,
        thresholdSeconds: 13.5,
        riskStatus: AssessmentStatus.normal,
        measurementMode: TugMeasurementMode.accelerometerOnly,
        turnVerified: false,
        confidence: 0.7,
        valid: true,
      );
      final session = AssessmentSession(
        id: tug.sessionId,
        timestamp: tug.timestamp,
        valid: true,
        tug: tug,
      );

      expect(SessionSummary.status(session), AssessmentStatus.warning);
      expect(SessionSummary.label(session), 'ผลจากโหมดพื้นฐาน');
    },
  );
}
