import 'package:balance_detect/core/domain/assessment_enums.dart';
import 'package:balance_detect/features/fullerton/domain/fullerton_logic.dart';
import 'package:balance_detect/features/functional_reach/domain/functional_reach_logic.dart';
import 'package:balance_detect/features/tug/domain/tug_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Functional Reach accepts its complete protocol sequence', () {
    final machine = FunctionalReachStateMachine();
    for (final state in <FunctionalReachState>[
      FunctionalReachState.positioning,
      FunctionalReachState.calibrating,
      FunctionalReachState.baseline,
      FunctionalReachState.ready,
      FunctionalReachState.reaching,
      FunctionalReachState.completed,
    ]) {
      machine.transitionTo(state);
    }
    expect(machine.state, FunctionalReachState.completed);
  });

  test('Functional Reach rejects an invalid transition', () {
    final machine = FunctionalReachStateMachine();
    expect(
      () => machine.transitionTo(FunctionalReachState.completed),
      throwsStateError,
    );
  });

  test('Fullerton accepts supervision branch', () {
    final machine = FullertonStateMachine();
    for (final state in <FullertonState>[
      FullertonState.positioning,
      FullertonState.footBaseline,
      FullertonState.ready,
      FullertonState.reaching,
      FullertonState.supervisionQuestion,
      FullertonState.completed,
    ]) {
      machine.transitionTo(state);
    }
    expect(machine.state, FullertonState.completed);
  });

  test('TUG accepts its complete protocol sequence', () {
    final machine = TugStateMachine();
    for (final state in <TugState>[
      TugState.calibrating,
      TugState.ready,
      TugState.sitting,
      TugState.standingUp,
      TugState.walkingOut,
      TugState.turning,
      TugState.walkingBack,
      TugState.sittingDown,
      TugState.completed,
    ]) {
      machine.transitionTo(state);
    }
    expect(machine.state, TugState.completed);
  });

  test('TUG safely rejects skipping the turn state', () {
    final machine = TugStateMachine()
      ..transitionTo(TugState.calibrating)
      ..transitionTo(TugState.ready)
      ..transitionTo(TugState.sitting)
      ..transitionTo(TugState.standingUp)
      ..transitionTo(TugState.walkingOut);
    expect(() => machine.transitionTo(TugState.walkingBack), throwsStateError);
  });
}
