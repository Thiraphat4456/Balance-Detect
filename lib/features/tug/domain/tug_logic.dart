import 'package:balance_detect/core/constants/assessment_config.dart';
import 'package:balance_detect/core/domain/assessment_enums.dart';

abstract final class TugRiskClassifier {
  static AssessmentStatus classifySeconds(double seconds) =>
      seconds > AssessmentConfig.tugRiskThresholdSeconds
      ? AssessmentStatus.risk
      : AssessmentStatus.normal;
}

class TugStateMachine {
  TugStateMachine([this._state = TugState.idle]);

  TugState _state;
  TugState get state => _state;

  static const _allowed = <TugState, Set<TugState>>{
    TugState.idle: {TugState.calibrating},
    TugState.calibrating: {TugState.ready, TugState.invalid, TugState.error},
    TugState.ready: {TugState.sitting, TugState.invalid, TugState.error},
    TugState.sitting: {TugState.standingUp, TugState.invalid, TugState.error},
    TugState.standingUp: {
      TugState.walkingOut,
      TugState.invalid,
      TugState.error,
    },
    TugState.walkingOut: {TugState.turning, TugState.invalid, TugState.error},
    TugState.turning: {TugState.walkingBack, TugState.invalid, TugState.error},
    TugState.walkingBack: {
      TugState.sittingDown,
      TugState.invalid,
      TugState.error,
    },
    TugState.sittingDown: {
      TugState.completed,
      TugState.invalid,
      TugState.error,
    },
    TugState.completed: {TugState.calibrating},
    TugState.invalid: {TugState.calibrating},
    TugState.error: {TugState.calibrating},
  };

  bool canTransitionTo(TugState next) =>
      _allowed[_state]?.contains(next) ?? false;

  void transitionTo(TugState next) {
    if (!canTransitionTo(next)) {
      throw StateError('Invalid TUG transition: $_state -> $next');
    }
    _state = next;
  }
}
