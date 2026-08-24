import 'package:balance_detect/core/domain/assessment_enums.dart';

class FunctionalReachResult {
  const FunctionalReachResult({
    required this.id,
    required this.sessionId,
    required this.timestamp,
    required this.distanceCm,
    required this.distanceInch,
    required this.thresholdInch,
    required this.status,
    required this.footMovementDetected,
    required this.calibrationMethod,
    required this.confidence,
    required this.valid,
    this.invalidReason,
  });

  final String id;
  final String sessionId;
  final DateTime timestamp;
  final double distanceCm;
  final double distanceInch;
  final double thresholdInch;
  final AssessmentStatus status;
  final bool footMovementDetected;
  final CalibrationMethod calibrationMethod;
  final double confidence;
  final bool valid;
  final InvalidReason? invalidReason;

  Map<String, Object?> toMap() => <String, Object?>{
    'id': id,
    'session_id': sessionId,
    'timestamp_ms': timestamp.millisecondsSinceEpoch,
    'distance_cm': distanceCm,
    'distance_inch': distanceInch,
    'threshold_inch': thresholdInch,
    'status': status.name,
    'foot_movement_detected': footMovementDetected ? 1 : 0,
    'calibration_method': calibrationMethod.name,
    'confidence': confidence,
    'valid': valid ? 1 : 0,
    'invalid_reason': invalidReason?.name,
  };

  factory FunctionalReachResult.fromMap(Map<String, Object?> map) =>
      FunctionalReachResult(
        id: map['id']! as String,
        sessionId: map['session_id']! as String,
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          map['timestamp_ms']! as int,
        ),
        distanceCm: (map['distance_cm']! as num).toDouble(),
        distanceInch: (map['distance_inch']! as num).toDouble(),
        thresholdInch: (map['threshold_inch']! as num).toDouble(),
        status: assessmentStatusFromName(map['status']! as String),
        footMovementDetected: map['foot_movement_detected'] == 1,
        calibrationMethod: CalibrationMethod.values.firstWhere(
          (item) => item.name == map['calibration_method'],
        ),
        confidence: (map['confidence']! as num).toDouble(),
        valid: map['valid'] == 1,
        invalidReason: invalidReasonFromName(map['invalid_reason'] as String?),
      );
}
