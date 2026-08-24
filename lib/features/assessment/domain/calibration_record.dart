import 'package:balance_detect/core/domain/assessment_enums.dart';

class CalibrationRecord {
  const CalibrationRecord({
    required this.id,
    required this.sessionId,
    required this.timestamp,
    required this.scaleCmPerNormalizedUnit,
    required this.method,
    required this.referenceDistanceCm,
    required this.confidence,
  });

  final String id;
  final String sessionId;
  final DateTime timestamp;
  final double scaleCmPerNormalizedUnit;
  final CalibrationMethod method;
  final double referenceDistanceCm;
  final double confidence;

  Map<String, Object?> toMap() => <String, Object?>{
    'id': id,
    'session_id': sessionId,
    'timestamp_ms': timestamp.millisecondsSinceEpoch,
    'scale_cm_per_unit': scaleCmPerNormalizedUnit,
    'method': method.name,
    'reference_distance_cm': referenceDistanceCm,
    'confidence': confidence,
  };

  factory CalibrationRecord.fromMap(Map<String, Object?> map) =>
      CalibrationRecord(
        id: map['id']! as String,
        sessionId: map['session_id']! as String,
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          map['timestamp_ms']! as int,
        ),
        scaleCmPerNormalizedUnit: (map['scale_cm_per_unit']! as num).toDouble(),
        method: CalibrationMethod.values.firstWhere(
          (item) => item.name == map['method'],
        ),
        referenceDistanceCm: (map['reference_distance_cm']! as num).toDouble(),
        confidence: (map['confidence']! as num).toDouble(),
      );
}
