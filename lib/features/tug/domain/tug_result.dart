import 'package:balance_detect/core/domain/assessment_enums.dart';

class TugResult {
  const TugResult({
    required this.id,
    required this.sessionId,
    required this.timestamp,
    required this.totalSeconds,
    required this.thresholdSeconds,
    required this.riskStatus,
    required this.confidence,
    required this.valid,
    this.standDuration,
    this.outboundWalkDuration,
    this.turnDuration,
    this.returnWalkDuration,
    this.sitDuration,
    this.invalidReason,
  });

  final String id;
  final String sessionId;
  final DateTime timestamp;
  final double totalSeconds;
  final double thresholdSeconds;
  final AssessmentStatus riskStatus;
  final double? standDuration;
  final double? outboundWalkDuration;
  final double? turnDuration;
  final double? returnWalkDuration;
  final double? sitDuration;
  final double confidence;
  final bool valid;
  final InvalidReason? invalidReason;

  Map<String, Object?> toMap() => <String, Object?>{
    'id': id,
    'session_id': sessionId,
    'timestamp_ms': timestamp.millisecondsSinceEpoch,
    'total_seconds': totalSeconds,
    'threshold_seconds': thresholdSeconds,
    'risk_status': riskStatus.name,
    'stand_duration': standDuration,
    'outbound_walk_duration': outboundWalkDuration,
    'turn_duration': turnDuration,
    'return_walk_duration': returnWalkDuration,
    'sit_duration': sitDuration,
    'confidence': confidence,
    'valid': valid ? 1 : 0,
    'invalid_reason': invalidReason?.name,
  };

  factory TugResult.fromMap(Map<String, Object?> map) => TugResult(
    id: map['id']! as String,
    sessionId: map['session_id']! as String,
    timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp_ms']! as int),
    totalSeconds: (map['total_seconds']! as num).toDouble(),
    thresholdSeconds: (map['threshold_seconds']! as num).toDouble(),
    riskStatus: assessmentStatusFromName(map['risk_status']! as String),
    standDuration: (map['stand_duration'] as num?)?.toDouble(),
    outboundWalkDuration: (map['outbound_walk_duration'] as num?)?.toDouble(),
    turnDuration: (map['turn_duration'] as num?)?.toDouble(),
    returnWalkDuration: (map['return_walk_duration'] as num?)?.toDouble(),
    sitDuration: (map['sit_duration'] as num?)?.toDouble(),
    confidence: (map['confidence']! as num).toDouble(),
    valid: map['valid'] == 1,
    invalidReason: invalidReasonFromName(map['invalid_reason'] as String?),
  );
}
