import 'package:balance_detect/core/domain/assessment_enums.dart';

abstract final class FullertonScoring {
  static int calculate({
    required int stepCount,
    required bool? supervisionRequired,
  }) {
    if (stepCount < 0) {
      throw ArgumentError.value(stepCount, 'stepCount', 'must not be negative');
    }
    if (stepCount == 0) {
      if (supervisionRequired == null) {
        throw ArgumentError(
          'supervisionRequired is required when no step is detected',
        );
      }
      return supervisionRequired ? 3 : 4;
    }
    if (stepCount == 1) return 2;
    if (stepCount == 2) return 1;
    return 0;
  }
}

class FullertonStateMachine {
  FullertonStateMachine([this._state = FullertonState.idle]);

  FullertonState _state;
  FullertonState get state => _state;

  static const _allowed = <FullertonState, Set<FullertonState>>{
    FullertonState.idle: {FullertonState.positioning},
    FullertonState.positioning: {
      FullertonState.footBaseline,
      FullertonState.invalid,
      FullertonState.error,
    },
    FullertonState.footBaseline: {
      FullertonState.armCalibration,
      FullertonState.invalid,
      FullertonState.error,
    },
    FullertonState.armCalibration: {
      FullertonState.ready,
      FullertonState.footBaseline,
      FullertonState.invalid,
      FullertonState.error,
    },
    FullertonState.ready: {
      FullertonState.armCalibration,
      FullertonState.reaching,
      FullertonState.invalid,
      FullertonState.error,
    },
    FullertonState.reaching: {
      FullertonState.supervisionQuestion,
      FullertonState.completed,
      FullertonState.invalid,
      FullertonState.error,
    },
    FullertonState.supervisionQuestion: {
      FullertonState.completed,
      FullertonState.invalid,
      FullertonState.error,
    },
    FullertonState.completed: {FullertonState.positioning},
    FullertonState.invalid: {FullertonState.positioning},
    FullertonState.error: {FullertonState.positioning},
  };

  bool canTransitionTo(FullertonState next) =>
      _allowed[_state]?.contains(next) ?? false;

  void transitionTo(FullertonState next) {
    if (!canTransitionTo(next)) {
      throw StateError('Invalid Fullerton transition: $_state -> $next');
    }
    _state = next;
  }
}
