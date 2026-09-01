import 'package:balance_detect/core/domain/assessment_enums.dart';
import 'package:balance_detect/features/fullerton/domain/fullerton_reach_calibration_service.dart';

class FullertonResult {
  const FullertonResult({
    required this.id,
    required this.sessionId,
    required this.timestamp,
    required this.score,
    required this.stepCount,
    required this.supervisionRequired,
    required this.confidence,
    required this.valid,
    this.protocolVariant = FullertonProtocolVariant.legacyUnspecified,
    this.targetDistanceCm,
    this.heightCm,
    this.invalidReason,
  });

  final String id;
  final String sessionId;
  final DateTime timestamp;
  final int score;
  final int stepCount;
  final bool? supervisionRequired;
  final double confidence;
  final bool valid;
  final FullertonProtocolVariant protocolVariant;
  final double? targetDistanceCm;
  final double? heightCm;
  final InvalidReason? invalidReason;

  Map<String, Object?> toMap() => <String, Object?>{
    'id': id,
    'session_id': sessionId,
    'timestamp_ms': timestamp.millisecondsSinceEpoch,
    'score': score,
    'step_count': stepCount,
    'supervision_required': supervisionRequired == null
        ? null
        : supervisionRequired!
        ? 1
        : 0,
    'confidence': confidence,
    'valid': valid ? 1 : 0,
    'protocol_variant': protocolVariant.name,
    'target_distance_cm': targetDistanceCm,
    'height_cm': heightCm,
    'invalid_reason': invalidReason?.name,
  };

  factory FullertonResult.fromMap(Map<String, Object?> map) => FullertonResult(
    id: map['id']! as String,
    sessionId: map['session_id']! as String,
    timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp_ms']! as int),
    score: map['score']! as int,
    stepCount: map['step_count']! as int,
    supervisionRequired: map['supervision_required'] == null
        ? null
        : map['supervision_required'] == 1,
    confidence: (map['confidence']! as num).toDouble(),
    valid: map['valid'] == 1,
    protocolVariant: FullertonProtocolVariantDetails.fromStored(
      map['protocol_variant'] as String?,
    ),
    targetDistanceCm: (map['target_distance_cm'] as num?)?.toDouble(),
    heightCm: (map['height_cm'] as num?)?.toDouble(),
    invalidReason: invalidReasonFromName(map['invalid_reason'] as String?),
  );
}
