import 'package:balance_detect/core/domain/assessment_enums.dart';
import 'package:balance_detect/features/assessment/domain/assessment_session.dart';
import 'package:balance_detect/features/assessment/domain/session_summary.dart';
import 'package:balance_detect/features/fullerton/domain/fullerton_logic.dart';
import 'package:balance_detect/features/fullerton/domain/fullerton_reach_calibration_service.dart';
import 'package:balance_detect/features/fullerton/domain/fullerton_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Fullerton scoring', () {
    final cases = <({int steps, bool? supervision, int score})>[
      (steps: 0, supervision: false, score: 4),
      (steps: 0, supervision: true, score: 3),
      (steps: 1, supervision: null, score: 2),
      (steps: 2, supervision: null, score: 1),
      (steps: 3, supervision: null, score: 0),
      (steps: 5, supervision: null, score: 0),
    ];

    for (final value in cases) {
      test('${value.steps} steps produces ${value.score}', () {
        expect(
          FullertonScoring.calculate(
            stepCount: value.steps,
            supervisionRequired: value.supervision,
          ),
          value.score,
        );
      });
    }

    test('zero steps requires the evaluator answer', () {
      expect(
        () =>
            FullertonScoring.calculate(stepCount: 0, supervisionRequired: null),
        throwsArgumentError,
      );
    });
  });

  test('Fullerton result preserves target protocol metadata', () {
    final result = FullertonResult(
      id: 'result',
      sessionId: 'session',
      timestamp: DateTime(2026),
      score: 2,
      stepCount: 1,
      supervisionRequired: null,
      confidence: .8,
      valid: true,
      protocolVariant: FullertonProtocolVariant.oneFoot,
      targetDistanceCm: 30.48,
      heightCm: 170,
    );

    final restored = FullertonResult.fromMap(result.toMap());

    expect(restored.protocolVariant, FullertonProtocolVariant.oneFoot);
    expect(restored.targetDistanceCm, 30.48);
    expect(restored.heightCm, 170);
  });

  test('Modified FAB is labelled experimental instead of normal', () {
    final result = FullertonResult(
      id: 'result',
      sessionId: 'session',
      timestamp: DateTime(2026),
      score: 4,
      stepCount: 0,
      supervisionRequired: false,
      confidence: .8,
      valid: true,
      protocolVariant: FullertonProtocolVariant.oneFoot,
      targetDistanceCm: 30.48,
      heightCm: 170,
    );
    final session = AssessmentSession(
      id: 'session',
      timestamp: DateTime(2026),
      valid: true,
      fullerton: result,
    );

    expect(SessionSummary.status(session), AssessmentStatus.warning);
    expect(SessionSummary.label(session), 'ผลแบบทดลอง');
  });
}
