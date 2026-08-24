import 'package:balance_detect/core/domain/assessment_enums.dart';
import 'package:balance_detect/features/fullerton/domain/fullerton_result.dart';
import 'package:balance_detect/features/functional_reach/domain/functional_reach_result.dart';
import 'package:balance_detect/features/tug/domain/tug_result.dart';

class AssessmentSession {
  const AssessmentSession({
    required this.id,
    required this.timestamp,
    required this.valid,
    this.profileId,
    this.invalidReason,
    this.functionalReach,
    this.fullerton,
    this.tug,
  });

  final String id;
  final String? profileId;
  final DateTime timestamp;
  final bool valid;
  final InvalidReason? invalidReason;
  final FunctionalReachResult? functionalReach;
  final FullertonResult? fullerton;
  final TugResult? tug;

  bool get hasAnyResult =>
      functionalReach != null || fullerton != null || tug != null;

  Map<String, Object?> toMap() => <String, Object?>{
    'id': id,
    'profile_id': profileId,
    'timestamp_ms': timestamp.millisecondsSinceEpoch,
    'valid': valid ? 1 : 0,
    'invalid_reason': invalidReason?.name,
  };

  factory AssessmentSession.fromMap(
    Map<String, Object?> map, {
    FunctionalReachResult? functionalReach,
    FullertonResult? fullerton,
    TugResult? tug,
  }) => AssessmentSession(
    id: map['id']! as String,
    profileId: map['profile_id'] as String?,
    timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp_ms']! as int),
    valid: map['valid'] == 1,
    invalidReason: invalidReasonFromName(map['invalid_reason'] as String?),
    functionalReach: functionalReach,
    fullerton: fullerton,
    tug: tug,
  );
}
