import 'package:balance_detect/features/fullerton/domain/fullerton_logic.dart';
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
}
