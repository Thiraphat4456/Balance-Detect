import 'package:balance_detect/core/constants/assessment_config.dart';
import 'package:balance_detect/core/domain/assessment_enums.dart';

abstract final class FunctionalReachClassifier {
  static AssessmentStatus classifyInches(double distanceInches) =>
      distanceInches < AssessmentConfig.functionalReachThresholdInches
      ? AssessmentStatus.warning
      : AssessmentStatus.normal;
}

class FunctionalReachStateMachine {
  FunctionalReachStateMachine([this._state = FunctionalReachState.idle]);

  FunctionalReachState _state;
  FunctionalReachState get state => _state;

  static const _allowed = <FunctionalReachState, Set<FunctionalReachState>>{
    FunctionalReachState.idle: {FunctionalReachState.positioning},
    FunctionalReachState.positioning: {
      FunctionalReachState.calibrating,
      FunctionalReachState.invalid,
      FunctionalReachState.error,
    },
    FunctionalReachState.calibrating: {
      FunctionalReachState.baseline,
      FunctionalReachState.invalid,
      FunctionalReachState.error,
    },
    FunctionalReachState.baseline: {
      FunctionalReachState.ready,
      FunctionalReachState.invalid,
      FunctionalReachState.error,
    },
    FunctionalReachState.ready: {
      FunctionalReachState.reaching,
      FunctionalReachState.invalid,
      FunctionalReachState.error,
    },
    FunctionalReachState.reaching: {
      FunctionalReachState.completed,
      FunctionalReachState.invalid,
      FunctionalReachState.error,
    },
    FunctionalReachState.completed: {FunctionalReachState.positioning},
    FunctionalReachState.invalid: {FunctionalReachState.positioning},
    FunctionalReachState.error: {FunctionalReachState.positioning},
  };

  bool canTransitionTo(FunctionalReachState next) =>
      _allowed[_state]?.contains(next) ?? false;

  void transitionTo(FunctionalReachState next) {
    if (!canTransitionTo(next)) {
      throw StateError('Invalid Functional Reach transition: $_state -> $next');
    }
    _state = next;
  }
}
