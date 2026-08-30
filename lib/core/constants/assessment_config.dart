abstract final class AssessmentConfig {
  static const functionalReachThresholdInches = 7.0;
  static const tugRiskThresholdSeconds = 13.5;

  static const poseConfidenceThreshold = 0.65;
  static const poseLostFrameLimit = 8;
  static const sideViewMaxShoulderToTorsoRatio = 0.55;
  static const sideViewMaxHipToTorsoRatio = 0.45;
  static const cameraFrameInterval = Duration(milliseconds: 100);

  static const calibrationMinReferenceCm = 10.0;
  static const calibrationMaxReferenceCm = 200.0;
  static const calibrationMinNormalizedSpan = 0.08;
  static const calibrationMinConfidence = 0.55;
  static const calibrationMaxVerticalDrift = 0.06;

  // The pose model exposes shoulder and ankle landmarks, not the top of the
  // head. This prior estimates the visible shoulder-to-ankle span as a
  // fraction of the entered stature. It is intentionally isolated here so it
  // can be validated and tuned with real participants later.
  static const anthropometricMinHeightCm = 100.0;
  static const anthropometricMaxHeightCm = 230.0;
  static const anthropometricVisibleHeightFraction = 0.78;
  static const anthropometricCalibrationDuration = Duration(seconds: 2);
  static const anthropometricCalibrationMinFrames = 12;
  static const anthropometricMaxSpanJitter = 0.025;

  static const reachBaselineDuration = Duration(milliseconds: 2200);
  static const reachBaselineMinFrames = 12;
  static const reachBaselineMaxJitterNormalized = 0.012;
  static const reachFootBaselineMaxJitterNormalized = 0.018;
  // The Functional Reach protocol starts with the upper arm close to 90
  // degrees from the same-side shoulder-to-hip torso axis. This deliberately
  // avoids any absolute image-horizontal or floor reference, so camera tilt
  // does not change the target posture. These wider implementation tolerances
  // account for 2D pose jitter and must be validated on real participants
  // before clinical use.
  static const functionalReachArmToTorsoAngleMinDegrees = 75.0;
  static const functionalReachArmToTorsoAngleMaxDegrees = 105.0;
  static const functionalReachElbowAngleMinDegrees = 150.0;
  static const reachWindow = Duration(seconds: 10);
  static const reachSmoothingWindow = 5;
  static const footMovementToleranceCm = 2.0;
  static const footMovementNoiseFloorNormalized = 0.018;
  static const footMovementBaselineNoiseMultiplier = 2.0;
  static const footMovementBaselineNoiseMarginCm = 0.5;
  static const footMovementSmoothingWindow = 5;
  static const footMovementConfirmationFrames = 5;

  static const stepMinNormalizedDisplacement = 0.035;
  static const stepFootLengthMultiplier = 0.60;
  static const stepConfirmationFrames = 4;
  static const stepRefractoryPeriod = Duration(milliseconds: 800);
  static const stepMinimumResultConfidence = 0.45;
  static const fullertonBaselineDuration = Duration(seconds: 2);
  static const fullertonBaselineMinFrames = 10;

  static const sensorSamplingPeriod = Duration(milliseconds: 20);
  static const sensorProbeTimeout = Duration(seconds: 2);
  static const sensorCalibrationDuration = Duration(seconds: 3);
  static const sensorCalibrationMinSamples = 60;
  static const sensorRestingNoiseLimit = 0.55;
  static const sensorRestingGyroLimit = 0.22;

  static const tugMaximumDuration = Duration(seconds: 60);
  static const tugMinWalkingBeforeTurn = Duration(seconds: 1);
  static const tugMinReturnWalking = Duration(milliseconds: 1200);
  static const tugMotionWindow = Duration(milliseconds: 650);
  static const tugQuietWindow = Duration(milliseconds: 750);
  static const tugStandAcceleration = 0.55;
  static const tugStandAngularVelocity = 0.12;
  static const tugWalkingDynamicAcceleration = 0.30;
  static const tugTurnAngularVelocity = 0.55;
  static const tugTurnMinimumRadians = 2.10;
  static const tugSittingDynamicAcceleration = 0.24;
  static const tugSittingAngularVelocity = 0.14;
  static const tugPhaseConfidence = 0.60;
}
