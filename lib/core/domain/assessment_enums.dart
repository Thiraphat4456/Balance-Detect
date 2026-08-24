enum AssessmentStatus { normal, warning, risk, invalid }

enum AssessmentType { functionalReach, fullerton, tug }

enum CalibrationMethod { explicitKnownReference, anthropometricBodyHeight }

enum FunctionalReachState {
  idle,
  positioning,
  calibrating,
  baseline,
  ready,
  reaching,
  completed,
  invalid,
  error,
}

enum FullertonState {
  idle,
  positioning,
  footBaseline,
  ready,
  reaching,
  supervisionQuestion,
  completed,
  invalid,
  error,
}

enum TugState {
  idle,
  calibrating,
  ready,
  sitting,
  standingUp,
  walkingOut,
  turning,
  walkingBack,
  sittingDown,
  completed,
  invalid,
  error,
}

enum InvalidReason {
  poseLost,
  calibrationFailed,
  footMoved,
  bodyOutsideFrame,
  stepConfidenceLow,
  sensorUnavailable,
  unexpectedMotion,
  interrupted,
  stateSequenceInvalid,
  timeout,
}

AssessmentStatus assessmentStatusFromName(String value) =>
    AssessmentStatus.values.firstWhere(
      (item) => item.name == value,
      orElse: () => AssessmentStatus.invalid,
    );

InvalidReason? invalidReasonFromName(String? value) {
  if (value == null) return null;
  for (final item in InvalidReason.values) {
    if (item.name == value) return item;
  }
  return null;
}
