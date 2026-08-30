import 'dart:async';

import 'package:balance_detect/core/constants/assessment_config.dart';
import 'package:balance_detect/core/domain/assessment_enums.dart';
import 'package:balance_detect/core/errors/user_facing_exception.dart';
import 'package:balance_detect/core/logging/app_logger.dart';
import 'package:balance_detect/core/providers/app_providers.dart';
import 'package:balance_detect/core/services/voice_guidance_service.dart';
import 'package:balance_detect/core/utils/id_generator.dart';
import 'package:balance_detect/core/utils/unit_conversion.dart';
import 'package:balance_detect/core/widgets/app_scaffold_body.dart';
import 'package:balance_detect/core/widgets/assessment_progress_header.dart';
import 'package:balance_detect/core/widgets/auto_start_countdown_banner.dart';
import 'package:balance_detect/core/widgets/checklist_tile.dart';
import 'package:balance_detect/core/widgets/error_screens.dart';
import 'package:balance_detect/core/widgets/loading_view.dart';
import 'package:balance_detect/core/widgets/status_banner.dart';
import 'package:balance_detect/features/assessment/domain/assessment_session.dart';
import 'package:balance_detect/features/assessment/domain/calibration_record.dart';
import 'package:balance_detect/features/functional_reach/domain/distance_calibration_service.dart';
import 'package:balance_detect/features/functional_reach/domain/functional_reach_logic.dart';
import 'package:balance_detect/features/functional_reach/domain/functional_reach_posture_service.dart';
import 'package:balance_detect/features/functional_reach/domain/functional_reach_result.dart';
import 'package:balance_detect/features/functional_reach/domain/reach_measurement_service.dart';
import 'package:balance_detect/features/functional_reach/presentation/reach_threshold_bar.dart';
import 'package:balance_detect/features/pose/domain/pose_frame.dart';
import 'package:balance_detect/features/pose/domain/pose_validation.dart';
import 'package:balance_detect/features/pose/presentation/pose_skeleton_overlay.dart';
import 'package:balance_detect/features/pose/services/camera_pose_service.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class FunctionalReachAssessmentScreen extends ConsumerStatefulWidget {
  const FunctionalReachAssessmentScreen({required this.heightCm, super.key});

  final double heightCm;

  @override
  ConsumerState<FunctionalReachAssessmentScreen> createState() =>
      _FunctionalReachAssessmentScreenState();
}

class _FunctionalReachAssessmentScreenState
    extends ConsumerState<FunctionalReachAssessmentScreen>
    with WidgetsBindingObserver {
  final _stateMachine = FunctionalReachStateMachine();
  final _poseValidationService = const PoseValidationService();
  final _postureService = const FunctionalReachPostureService();
  final _anthropometricCalibrationService =
      const AnthropometricHeightCalibrationService();
  final _heightSpanSamples = <double>[];
  final String _sessionId = IdGenerator.generate('session');
  late final MlKitCameraPoseService _cameraService;
  StreamSubscription<PoseFrame>? _frameSubscription;
  StreamSubscription<Object>? _errorSubscription;
  StreamSubscription<PoseDebugMetrics>? _metricsSubscription;
  PoseValidation? _validation;
  FunctionalReachPostureValidation? _postureValidation;
  PrimaryBodySide? _activeArmSide;
  PrimaryBodySide? _measurementSide;
  PoseFrame? _lastFrame;
  PoseDebugMetrics? _debugMetrics;
  CalibrationRecord? _calibration;
  ReachMeasurementService? _measurement;
  FunctionalReachResult? _result;
  Duration? _baselineStartedAt;
  Duration? _reachStartedAt;
  Duration? _heightCalibrationStartedAt;
  InvalidReason? _invalidReason;
  Object? _initializationError;
  bool _initialized = false;
  bool _saving = false;
  bool _saved = false;
  int _poseLostFrames = 0;
  int _processingErrors = 0;
  double _baselineProgress = 0;
  double _reachProgress = 0;
  double _heightCalibrationProgress = 0;
  String _heightCalibrationMessage = 'อยู่นิ่ง ให้เห็นหัวไหล่และเท้าครบ';
  bool _poseAcquiredLogged = false;
  final _voiceGuidance = VoiceGuidanceService();
  Timer? _positioningCountdownTimer;
  Timer? _readyCountdownTimer;
  int? _positioningCountdown;
  int? _readyCountdown;
  bool _voiceEnabled = true;
  bool _showPoseSkeleton = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cameraService = MlKitCameraPoseService();
    _stateMachine.transitionTo(FunctionalReachState.positioning);
    unawaited(_voiceGuidance.initialize());
    unawaited(
      _voiceGuidance.announce(
        'ตั้งโทรศัพท์ให้เห็นร่างกายตั้งแต่ศีรษะถึงเท้าทั้งสองข้าง '
        'แล้วหันลำตัวด้านข้างเข้าหากล้อง',
        force: true,
      ),
    );
    _frameSubscription = _cameraService.frames.listen(_onFrame);
    _errorSubscription = _cameraService.errors.listen(_onProcessingError);
    _metricsSubscription = _cameraService.debugMetrics.listen((metrics) {
      if (mounted) setState(() => _debugMetrics = metrics);
    });
    unawaited(_initializeCamera());
  }

  Future<void> _initializeCamera() async {
    try {
      await _cameraService.initialize();
      if (mounted) setState(() => _initialized = true);
    } catch (error) {
      AppLogger.error('camera_initialization_failed', error);
      if (_stateMachine.canTransitionTo(FunctionalReachState.error)) {
        _stateMachine.transitionTo(FunctionalReachState.error);
      }
      if (mounted) setState(() => _initializationError = error);
    }
  }

  void _onProcessingError(Object error) {
    _processingErrors += 1;
    if (_processingErrors < 5) return;
    if (_stateMachine.canTransitionTo(FunctionalReachState.error)) {
      _stateMachine.transitionTo(FunctionalReachState.error);
      if (mounted) setState(() => _initializationError = error);
    }
  }

  void _onFrame(PoseFrame frame) {
    if (!mounted) return;
    _lastFrame = frame;
    final validation = _poseValidationService.validate(
      frame,
      requireSideView: true,
    );
    _validation = validation;
    final postureSide =
        _measurementSide ??
        _postureService.selectRaisedArmSide(
          frame,
          fallback: _activeArmSide ?? validation.primarySide,
        );
    final posture = _postureService.validate(frame, postureSide);
    if (_measurementSide == null && _activeArmSide != postureSide) {
      AppLogger.event('reach_active_arm_selected', <String, Object?>{
        'side': postureSide.name,
        'pose_primary_side': validation.primarySide.name,
        'arm_to_torso_angle': posture.armToTorsoAngleDegrees,
      });
      _activeArmSide = postureSide;
    }
    _postureValidation = posture;
    if (validation.canStart && !_poseAcquiredLogged) {
      _poseAcquiredLogged = true;
      AppLogger.event('pose_acquired', <String, Object?>{
        'confidence': validation.confidence,
      });
    }

    final activeState = _stateMachine.state;
    if (activeState == FunctionalReachState.positioning) {
      if (validation.canStart) {
        unawaited(_voiceGuidance.announce(validation.guidance));
        _schedulePositioningStart();
      } else {
        _cancelPositioningCountdown();
        unawaited(_voiceGuidance.announce(validation.guidance));
      }
    } else if (activeState == FunctionalReachState.ready) {
      if (validation.canStart && posture.canMeasure) {
        _scheduleReachStart();
      } else {
        _cancelReadyCountdown();
        unawaited(
          _voiceGuidance.announce(
            validation.canStart ? posture.guidance : validation.guidance,
          ),
        );
      }
    } else if (activeState == FunctionalReachState.calibrating) {
      _processHeightCalibration(frame, validation);
    }
    if (activeState == FunctionalReachState.baseline ||
        activeState == FunctionalReachState.reaching) {
      if (!validation.canStart) {
        _poseLostFrames += 1;
        if (_poseLostFrames >= AssessmentConfig.poseLostFrameLimit) {
          _invalidate(InvalidReason.poseLost);
          return;
        }
      } else {
        _poseLostFrames = 0;
      }
    }

    if (activeState == FunctionalReachState.baseline) {
      if (!validation.canStart) {
        _resetBaselineCapture();
        unawaited(_voiceGuidance.announce(validation.guidance));
      } else if (!posture.canMeasure) {
        _resetBaselineCapture();
        unawaited(_voiceGuidance.announce(posture.guidance));
      } else {
        if (_measurementSide == null) {
          _measurementSide = postureSide;
          AppLogger.event('reach_measurement_side_locked', <String, Object?>{
            'side': postureSide.name,
          });
        }
        _baselineStartedAt ??= frame.timestamp;
        _measurement?.addBaselineFrame(frame, _measurementSide!);
        final elapsed = frame.timestamp - _baselineStartedAt!;
        _baselineProgress =
            elapsed.inMilliseconds /
            AssessmentConfig.reachBaselineDuration.inMilliseconds;
        if (elapsed >= AssessmentConfig.reachBaselineDuration) {
          if (_measurement?.finalizeStableBaseline() ?? false) {
            _stateMachine.transitionTo(FunctionalReachState.ready);
            _scheduleReachStart();
            AppLogger.event('reach_baseline_ready', <String, Object?>{
              'arm_to_torso_angle': posture.armToTorsoAngleDegrees,
              'elbow_angle': posture.elbowAngleDegrees,
            });
          } else {
            _measurement = ReachMeasurementService(calibration: _calibration!);
            _baselineStartedAt = frame.timestamp;
            _baselineProgress = 0;
          }
        }
      }
    } else if (activeState == FunctionalReachState.reaching &&
        validation.canStart) {
      final snapshot = _measurement!.addReachFrame(frame, _measurementSide!);
      if (snapshot.footMovementDetected) {
        AppLogger.event('foot_movement_detected', <String, Object?>{
          'left_cm': snapshot.leftFootMovementCm,
          'right_cm': snapshot.rightFootMovementCm,
          'threshold_cm': snapshot.footMovementThresholdCm,
        });
        _invalidate(InvalidReason.footMoved);
        return;
      }
      final elapsed = frame.timestamp - _reachStartedAt!;
      _reachProgress =
          elapsed.inMilliseconds / AssessmentConfig.reachWindow.inMilliseconds;
      if (elapsed >= AssessmentConfig.reachWindow) _completeReach();
    }
    setState(() {});
  }

  void _beginCalibration() {
    if (_stateMachine.state != FunctionalReachState.positioning ||
        !(_validation?.canStart ?? false)) {
      return;
    }
    _heightSpanSamples.clear();
    _heightCalibrationStartedAt = null;
    _heightCalibrationProgress = 0;
    _heightCalibrationMessage = 'อยู่นิ่ง ให้เห็นหัวไหล่และเท้าครบ';
    _stateMachine.transitionTo(FunctionalReachState.calibrating);
    unawaited(
      _voiceGuidance.announce(
        'กำลังคำนวณสเกลจากส่วนสูง กรุณาอยู่นิ่ง',
        force: true,
      ),
    );
    setState(() {});
  }

  void _processHeightCalibration(PoseFrame frame, PoseValidation validation) {
    if (!validation.canStart) {
      _heightSpanSamples.clear();
      _heightCalibrationStartedAt = null;
      _heightCalibrationProgress = 0;
      _heightCalibrationMessage = validation.guidance;
      unawaited(_voiceGuidance.announce(validation.guidance));
      return;
    }
    final bodySpan = _shoulderToAnkleSpan(frame, validation.primarySide);
    if (bodySpan == null) {
      _heightSpanSamples.clear();
      _heightCalibrationStartedAt = null;
      _heightCalibrationProgress = 0;
      _heightCalibrationMessage = 'กรุณาจัดให้เห็นหัวไหล่และเท้าครบ';
      unawaited(_voiceGuidance.announce(_heightCalibrationMessage));
      return;
    }
    _heightCalibrationStartedAt ??= frame.timestamp;
    _heightSpanSamples.add(bodySpan);
    final elapsed = frame.timestamp - _heightCalibrationStartedAt!;
    _heightCalibrationProgress =
        (elapsed.inMilliseconds /
                AssessmentConfig
                    .anthropometricCalibrationDuration
                    .inMilliseconds)
            .clamp(0.0, 1.0);
    if (elapsed < AssessmentConfig.anthropometricCalibrationDuration ||
        _heightSpanSamples.length <
            AssessmentConfig.anthropometricCalibrationMinFrames) {
      return;
    }
    try {
      final calibration = _anthropometricCalibrationService.calibrate(
        sessionId: _sessionId,
        heightCm: widget.heightCm,
        visibleSpanSamples: _heightSpanSamples,
        imageAspectRatio: frame.imageAspectRatio,
      );
      _calibration = calibration;
      _measurement = ReachMeasurementService(calibration: calibration);
      _stateMachine.transitionTo(FunctionalReachState.baseline);
      _baselineStartedAt = null;
      _heightCalibrationMessage = '';
      unawaited(
        _voiceGuidance.announce(
          'คำนวณสเกลแล้ว เหยียดแขนข้างที่เห็นไปด้านหน้า '
          'ให้ต้นแขนตั้งฉากกับลำตัว '
          'เหยียดข้อศอก และอยู่นิ่ง',
          force: true,
        ),
      );
      AppLogger.event('anthropometric_calibration_success', <String, Object?>{
        'height_cm': widget.heightCm,
        'confidence': calibration.confidence,
      });
    } on FormatException catch (error) {
      _heightSpanSamples.clear();
      _heightCalibrationStartedAt = frame.timestamp;
      _heightCalibrationProgress = 0;
      _heightCalibrationMessage = error.message;
      unawaited(_voiceGuidance.announce(error.message, force: true));
    }
  }

  double? _shoulderToAnkleSpan(PoseFrame frame, PrimaryBodySide side) {
    final shoulder = frame[side.shoulder];
    final ankle = frame[side.ankle];
    if (shoulder == null || ankle == null) return null;
    final span = (ankle.y - shoulder.y).abs();
    return span > AssessmentConfig.calibrationMinNormalizedSpan ? span : null;
  }

  void _resetBaselineCapture() {
    if (_calibration == null) return;
    if (_baselineStartedAt != null || _baselineProgress > 0) {
      _measurement = ReachMeasurementService(calibration: _calibration!);
    }
    _baselineStartedAt = null;
    _baselineProgress = 0;
  }

  void _schedulePositioningStart() {
    if (_stateMachine.state != FunctionalReachState.positioning ||
        _positioningCountdownTimer != null ||
        !(_validation?.canStart ?? false)) {
      return;
    }
    _positioningCountdown = 3;
    unawaited(_voiceGuidance.announce('ตำแหน่งพร้อม สาม', force: true));
    if (mounted) setState(() {});
    _positioningCountdownTimer = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) {
      if (!mounted ||
          _stateMachine.state != FunctionalReachState.positioning ||
          !(_validation?.canStart ?? false)) {
        timer.cancel();
        _positioningCountdownTimer = null;
        _positioningCountdown = null;
        unawaited(_voiceGuidance.stop());
        if (mounted) setState(() {});
        return;
      }
      final next = (_positioningCountdown ?? 0) - 1;
      if (next <= 0) {
        timer.cancel();
        _positioningCountdownTimer = null;
        _positioningCountdown = null;
        _beginCalibration();
      } else {
        _positioningCountdown = next;
        unawaited(_voiceGuidance.announce(_countdownWord(next), force: true));
      }
      if (mounted) setState(() {});
    });
  }

  void _scheduleReachStart() {
    if (_stateMachine.state != FunctionalReachState.ready ||
        _readyCountdownTimer != null ||
        _lastFrame == null ||
        !(_validation?.canStart ?? false) ||
        !(_postureValidation?.canMeasure ?? false)) {
      return;
    }
    _readyCountdown = 3;
    unawaited(_voiceGuidance.announce('พร้อมเอื้อม สาม', force: true));
    if (mounted) setState(() {});
    _readyCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted ||
          _stateMachine.state != FunctionalReachState.ready ||
          !(_validation?.canStart ?? false) ||
          !(_postureValidation?.canMeasure ?? false)) {
        timer.cancel();
        _readyCountdownTimer = null;
        _readyCountdown = null;
        unawaited(_voiceGuidance.stop());
        if (mounted) setState(() {});
        return;
      }
      final next = (_readyCountdown ?? 0) - 1;
      if (next <= 0) {
        timer.cancel();
        _readyCountdownTimer = null;
        _readyCountdown = null;
        unawaited(_voiceGuidance.announce('เริ่มเอื้อม', force: true));
        _startReach();
      } else {
        _readyCountdown = next;
        unawaited(_voiceGuidance.announce(_countdownWord(next), force: true));
      }
      if (mounted) setState(() {});
    });
  }

  void _cancelPositioningCountdown() {
    final wasActive =
        _positioningCountdownTimer != null || _positioningCountdown != null;
    _positioningCountdownTimer?.cancel();
    _positioningCountdownTimer = null;
    _positioningCountdown = null;
    if (wasActive) unawaited(_voiceGuidance.stop());
    if (wasActive && mounted) setState(() {});
  }

  void _cancelReadyCountdown() {
    final wasActive = _readyCountdownTimer != null || _readyCountdown != null;
    _readyCountdownTimer?.cancel();
    _readyCountdownTimer = null;
    _readyCountdown = null;
    if (wasActive) unawaited(_voiceGuidance.stop());
    if (wasActive && mounted) setState(() {});
  }

  String _countdownWord(int seconds) => switch (seconds) {
    3 => 'สาม',
    2 => 'สอง',
    1 => 'หนึ่ง',
    _ => '$seconds',
  };

  void _startReach() {
    if (_stateMachine.state != FunctionalReachState.ready ||
        _lastFrame == null ||
        !(_validation?.canStart ?? false) ||
        !(_postureValidation?.canMeasure ?? false)) {
      return;
    }
    _stateMachine.transitionTo(FunctionalReachState.reaching);
    _readyCountdownTimer?.cancel();
    _readyCountdownTimer = null;
    _readyCountdown = null;
    _reachStartedAt = _lastFrame!.timestamp;
    _reachProgress = 0;
    AppLogger.event('reach_started');
    setState(() {});
  }

  void _completeReach() {
    if (_stateMachine.state != FunctionalReachState.reaching) return;
    final snapshot = _measurement!.snapshot;
    final inches = UnitConversion.centimetersToInches(
      snapshot.maximumDistanceCm,
    );
    final status = FunctionalReachClassifier.classifyInches(inches);
    _result = FunctionalReachResult(
      id: IdGenerator.generate('reach'),
      sessionId: _sessionId,
      timestamp: DateTime.now(),
      distanceCm: snapshot.maximumDistanceCm,
      distanceInch: inches,
      thresholdInch: AssessmentConfig.functionalReachThresholdInches,
      status: status,
      footMovementDetected: false,
      calibrationMethod: _calibration!.method,
      confidence: snapshot.confidence,
      valid: true,
    );
    _stateMachine.transitionTo(FunctionalReachState.completed);
    unawaited(_cameraService.dispose());
    AppLogger.event('reach_peak', <String, Object?>{
      'distanceCm': snapshot.maximumDistanceCm,
      'confidence': snapshot.confidence,
    });
    setState(() {});
  }

  void _invalidate(InvalidReason reason) {
    if (!_stateMachine.canTransitionTo(FunctionalReachState.invalid)) return;
    final previousState = _stateMachine.state;
    _cancelPositioningCountdown();
    _cancelReadyCountdown();
    _invalidReason = reason;
    _stateMachine.transitionTo(FunctionalReachState.invalid);
    unawaited(_cameraService.dispose());
    AppLogger.event('reach_invalidated', <String, Object?>{
      'reason': reason.name,
      'from_state': previousState.name,
    });
    if (mounted) setState(() {});
  }

  String get _invalidMessage => switch (_invalidReason) {
    InvalidReason.footMoved =>
      'ตรวจพบการขยับเท้า ผลระยะเอื้อมจึงไม่ถือว่าเป็นการทดสอบที่ใช้ได้',
    InvalidReason.poseLost =>
      'ระบบมองไม่เห็นร่างกายครบระหว่างทดสอบ กรุณาจัดตำแหน่งกล้องใหม่',
    InvalidReason.interrupted =>
      'แอปถูกพักหรือหน้าจอถูกล็อกระหว่างทดสอบ เพื่อความถูกต้องจึงต้องเริ่มใหม่',
    _ => 'การทดสอบไม่เป็นไปตามขั้นตอน กรุณาลองอีกครั้ง',
  };

  Future<void> _saveResult() async {
    final result = _result;
    final calibration = _calibration;
    if (result == null || calibration == null || _saved) return;
    setState(() => _saving = true);
    try {
      final repository = ref.read(assessmentRepositoryProvider);
      final profile = await repository.getProfile();
      final session = AssessmentSession(
        id: _sessionId,
        profileId: profile?.id,
        timestamp: result.timestamp,
        valid: true,
        functionalReach: result,
      );
      await repository.saveFunctionalReach(session, calibration, result);
      ref.read(historyRevisionProvider.notifier).bump();
      _saved = true;
      if (mounted) context.go('/history');
    } catch (error) {
      AppLogger.error('save_functional_reach_failed', error);
      if (mounted) _showMessage('บันทึกผลไม่สำเร็จ กรุณาลองอีกครั้ง');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _retry() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) =>
            FunctionalReachAssessmentScreen(heightCm: widget.heightCm),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _toggleVoice() {
    final enabled = !_voiceEnabled;
    setState(() => _voiceEnabled = enabled);
    unawaited(_voiceGuidance.setEnabled(enabled));
    if (enabled) {
      final state = _stateMachine.state;
      final message =
          state == FunctionalReachState.baseline ||
              state == FunctionalReachState.ready
          ? _postureValidation?.guidance
          : _validation?.guidance;
      unawaited(
        _voiceGuidance.announce(message ?? 'เปิดเสียงคำแนะนำแล้ว', force: true),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) return;
    final current = _stateMachine.state;
    if (current == FunctionalReachState.positioning ||
        current == FunctionalReachState.calibrating ||
        current == FunctionalReachState.baseline ||
        current == FunctionalReachState.ready ||
        current == FunctionalReachState.reaching) {
      _invalidate(InvalidReason.interrupted);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_frameSubscription?.cancel());
    unawaited(_errorSubscription?.cancel());
    unawaited(_metricsSubscription?.cancel());
    unawaited(_cameraService.dispose());
    _positioningCountdownTimer?.cancel();
    _readyCountdownTimer?.cancel();
    unawaited(_voiceGuidance.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_stateMachine.state == FunctionalReachState.invalid) {
      return InvalidTestScreen(reason: _invalidMessage, onRetry: _retry);
    }
    if (_stateMachine.state == FunctionalReachState.error) {
      final error = _initializationError;
      return PermissionErrorScreen(
        message: error is UserFacingException
            ? error.message
            : 'เปิดกล้องหรือตรวจจับท่าทางไม่สำเร็จ กรุณาลองอีกครั้ง',
        canOpenSettings: error is UserFacingException && error.canOpenSettings,
        onRetry: _retry,
      );
    }
    if (_stateMachine.state == FunctionalReachState.completed) {
      return _buildResult();
    }
    if (!_initialized) {
      return const Scaffold(
        body: LoadingView(label: 'กำลังเปิดกล้องและเตรียมระบบตรวจจับท่าทาง'),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('วัดระยะเอื้อม'),
        actions: [
          IconButton(
            onPressed: () {
              setState(() => _showPoseSkeleton = !_showPoseSkeleton);
            },
            tooltip: _showPoseSkeleton ? 'ซ่อนโครงกระดูก' : 'แสดงโครงกระดูก',
            icon: Icon(
              Icons.accessibility_new_rounded,
              color: _showPoseSkeleton
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
          ),
          IconButton(
            onPressed: _toggleVoice,
            tooltip: _voiceEnabled ? 'ปิดเสียงคำแนะนำ' : 'เปิดเสียงคำแนะนำ',
            icon: Icon(
              _voiceEnabled
                  ? Icons.volume_up_outlined
                  : Icons.volume_off_outlined,
            ),
          ),
        ],
      ),
      body: AppScaffoldBody(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AssessmentProgressHeader(
              currentStep: _currentStep,
              totalSteps: 5,
              title: _screenTitle,
              detail: _screenDetail,
            ),
            const SizedBox(height: 16),
            _buildCameraPanel(),
            const SizedBox(height: 18),
            _buildStageContent(),
          ],
        ),
      ),
    );
  }

  String get _screenTitle => switch (_stateMachine.state) {
    FunctionalReachState.positioning => 'จัดตำแหน่งกล้อง',
    FunctionalReachState.calibrating => 'ปรับเทียบระยะ',
    FunctionalReachState.baseline => 'เก็บตำแหน่งเริ่มต้น',
    FunctionalReachState.ready => 'พร้อมทดสอบ',
    FunctionalReachState.reaching => 'กำลังวัดระยะเอื้อม',
    _ => 'Functional Reach Test',
  };

  int get _currentStep => switch (_stateMachine.state) {
    FunctionalReachState.positioning => 1,
    FunctionalReachState.calibrating => 2,
    FunctionalReachState.baseline => 3,
    FunctionalReachState.ready => 4,
    FunctionalReachState.reaching => 5,
    _ => 1,
  };

  String get _screenDetail => switch (_stateMachine.state) {
    FunctionalReachState.positioning =>
      'ขยับมือถือหรือผู้ทดสอบจนทุกรายการขึ้นว่าพร้อม',
    FunctionalReachState.calibrating =>
      'อยู่นิ่ง ระบบกำลังใช้ส่วนสูง ${widget.heightCm.toStringAsFixed(0)} ซม. คำนวณสเกล',
    FunctionalReachState.baseline => 'เหยียดแขนไปด้านหน้าและอยู่นิ่งจนแถบเต็ม',
    FunctionalReachState.ready =>
      'เตรียมตัวให้พร้อม ระบบจะเริ่มเองหลังนับถอยหลัง',
    FunctionalReachState.reaching => 'เอื้อมไปข้างหน้าโดยไม่ขยับเท้า',
    _ => '',
  };

  Widget _buildCameraPanel() {
    final controller = _cameraService.cameraController!;
    final portrait = MediaQuery.orientationOf(context) == Orientation.portrait;
    final aspectRatio = portrait
        ? 1 / controller.value.aspectRatio
        : controller.value.aspectRatio;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 480),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: AspectRatio(
            aspectRatio: aspectRatio,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(controller),
                if (_showPoseSkeleton)
                  PoseSkeletonOverlay(
                    frame: _lastFrame,
                    highlightedSide: _trackedSide,
                  ),
                IgnorePointer(
                  child: CustomPaint(painter: _CameraGuidePainter()),
                ),
                if (_showPoseSkeleton) _buildPoseDiagnostics(),
                if (ref.watch(debugOverlayProvider)) _buildDebugOverlay(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PrimaryBodySide? get _trackedSide =>
      _measurementSide ?? _activeArmSide ?? _validation?.primarySide;

  Widget _buildPoseDiagnostics() {
    final frame = _lastFrame;
    if (frame == null) {
      return _buildPoseDiagnosticCard(
        statusColor: Colors.white,
        status: 'กำลังค้นหาร่างกาย',
        lines: const ['จุดแดง = ความมั่นใจต่ำ'],
      );
    }

    final left = _postureService.validate(frame, PrimaryBodySide.left);
    final right = _postureService.validate(frame, PrimaryBodySide.right);
    final trackedSide = _trackedSide ?? PrimaryBodySide.left;
    final tracked = trackedSide == PrimaryBodySide.left ? left : right;
    final sideLabel = trackedSide == PrimaryBodySide.left ? 'ซ้าย' : 'ขวา';
    final (statusColor, status) = _poseDiagnosticStatus(tracked);
    return _buildPoseDiagnosticCard(
      statusColor: statusColor,
      status: status,
      lines: [
        'เส้นเหลือง: แขน$sideLabelของผู้ทดสอบ',
        'แขน–ลำตัว  ซ้าย ${_formatAngle(left.armToTorsoAngleDegrees)}  '
            'ขวา ${_formatAngle(right.armToTorsoAngleDegrees)}',
        'ข้อศอกแขน$sideLabel ${_formatAngle(tracked.elbowAngleDegrees)}',
        'จุดแดง = ความมั่นใจต่ำ',
      ],
    );
  }

  Widget _buildPoseDiagnosticCard({
    required Color statusColor,
    required String status,
    required List<String> lines,
  }) {
    return Align(
      alignment: Alignment.topRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 230),
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.74),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: .24)),
        ),
        child: DefaultTextStyle(
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            height: 1.35,
            fontWeight: FontWeight.w500,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      status,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              for (final line in lines) Text(line),
            ],
          ),
        ),
      ),
    );
  }

  (Color, String) _poseDiagnosticStatus(
    FunctionalReachPostureValidation posture,
  ) {
    if (!posture.landmarksReliable) {
      return (const Color(0xFFFF6259), 'จุดแขนยังไม่ชัด');
    }
    final angle = posture.armToTorsoAngleDegrees!;
    if (angle < AssessmentConfig.functionalReachArmToTorsoAngleMinDegrees) {
      return (const Color(0xFFFFC247), 'แขนยังไม่ตั้งฉาก');
    }
    if (angle > AssessmentConfig.functionalReachArmToTorsoAngleMaxDegrees) {
      return (const Color(0xFFFFC247), 'แขนสูงเกินมุมตั้งฉาก');
    }
    if (!posture.elbowExtended) {
      return (const Color(0xFFFFC247), 'เหยียดข้อศอกให้ตรง');
    }
    return (const Color(0xFF55D982), 'ท่าแขนพร้อม');
  }

  String _formatAngle(double? angle) =>
      angle == null ? '—' : '${angle.toStringAsFixed(0)}°';

  Widget _buildDebugOverlay() {
    final metrics = _debugMetrics;
    final wrist = _validation == null || _lastFrame == null
        ? null
        : _lastFrame![_validation!.primarySide.wrist];
    return Align(
      alignment: Alignment.topLeft,
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(8),
        color: Colors.black.withValues(alpha: 0.72),
        child: Text(
          'FPS ${metrics?.framesPerSecond.toStringAsFixed(1) ?? '-'}\n'
          'pose ${metrics?.poseConfidence.toStringAsFixed(2) ?? '-'}\n'
          'wrist ${wrist == null ? '-' : '${wrist.x.toStringAsFixed(3)}, ${wrist.y.toStringAsFixed(3)}'}\n'
          'reach ${_measurement?.maximumDistanceCm.toStringAsFixed(1) ?? '-'} cm',
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildStageContent() => switch (_stateMachine.state) {
    FunctionalReachState.positioning => _buildPositioning(),
    FunctionalReachState.calibrating => _buildCalibration(),
    FunctionalReachState.baseline => _buildBaseline(),
    FunctionalReachState.ready => _buildReady(),
    FunctionalReachState.reaching => _buildReaching(),
    _ => const SizedBox.shrink(),
  };

  Widget _buildPositioning() {
    final validation = _validation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          validation?.guidance ?? 'กำลังค้นหาร่างกาย',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        ChecklistTile(
          label: 'เห็นร่างกายครบ',
          passed: validation?.bodyVisible ?? false,
          pending: validation == null,
        ),
        ChecklistTile(
          label: 'เห็นแขน',
          passed: validation?.armVisible ?? false,
          pending: validation == null,
        ),
        ChecklistTile(
          label: 'เห็นเท้าทั้งสองข้าง',
          passed: validation?.feetVisible ?? false,
          pending: validation == null,
        ),
        ChecklistTile(
          label: 'หันด้านข้าง',
          passed: validation?.sideView ?? false,
          pending: validation == null,
        ),
        const SizedBox(height: 14),
        AutoStartCountdownBanner(
          seconds: _positioningCountdown,
          readyMessage: validation?.canStart == true
              ? 'จัดตำแหน่งครบแล้ว'
              : 'ทำตามคำแนะนำเพื่อจัดตำแหน่ง',
          countdownMessage: 'ไม่ต้องกดปุ่ม ระบบจะไปขั้นตอนปรับเทียบเอง',
        ),
      ],
    );
  }

  Widget _buildCalibration() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'กำลังคำนวณสเกลจากส่วนสูง',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      Text(
        'ส่วนสูงที่กรอก: ${widget.heightCm.toStringAsFixed(0)} ซม.',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      const SizedBox(height: 14),
      LinearProgressIndicator(value: _heightCalibrationProgress),
      const SizedBox(height: 10),
      Text(
        _heightCalibrationMessage.isEmpty
            ? 'คำนวณสำเร็จ ระบบกำลังเตรียมขั้นตอนถัดไป'
            : _heightCalibrationMessage,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    ],
  );

  Widget _buildBaseline() {
    final posture = _postureValidation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          posture?.guidance ??
              'เหยียดแขนไปด้านหน้าให้ต้นแขนตั้งฉากกับลำตัว '
                  'เหยียดข้อศอก และอยู่นิ่ง',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        ChecklistTile(
          label: 'ต้นแขนตั้งฉากกับลำตัวประมาณ 90°',
          passed: posture?.armPerpendicularToTorso ?? false,
          pending: posture == null,
        ),
        ChecklistTile(
          label: 'เหยียดข้อศอกให้ตรง',
          passed: posture?.elbowExtended ?? false,
          pending: posture == null,
        ),
        const SizedBox(height: 14),
        LinearProgressIndicator(value: _baselineProgress.clamp(0.0, 1.0)),
        const SizedBox(height: 10),
        const Text('ท่าถูกและอยู่นิ่งจนแถบเต็ม ระบบจะไปขั้นถัดไปเอง'),
      ],
    );
  }

  Widget _buildReady() {
    final postureReady = _postureValidation?.canMeasure ?? false;
    return Column(
      children: [
        StatusBanner(
          status: postureReady
              ? AssessmentStatus.normal
              : AssessmentStatus.warning,
          label: postureReady ? 'พร้อมเริ่ม' : 'จัดท่าแขนอีกครั้ง',
          detail: postureReady
              ? 'เอื้อมไปข้างหน้าให้ไกลที่สุด ห้ามขยับเท้า'
              : _postureValidation?.guidance ?? 'กำลังตรวจท่าแขน',
        ),
        const SizedBox(height: 18),
        AutoStartCountdownBanner(
          seconds: _readyCountdown,
          readyMessage: postureReady
              ? 'เตรียมตัวได้เลย'
              : 'เหยียดแขนไปด้านหน้าให้ตั้งฉากกับลำตัวและเหยียดข้อศอก',
          countdownMessage: 'ระบบจะเริ่มวัดเอง ไม่ต้องกดปุ่ม',
        ),
      ],
    );
  }

  Widget _buildReaching() => Column(
    children: [
      Text('กำลังวัด', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 6),
      Text(
        '${_measurement?.maximumDistanceCm.toStringAsFixed(1) ?? '0.0'} ซม.',
        style: Theme.of(context).textTheme.displaySmall,
      ),
      const SizedBox(height: 14),
      LinearProgressIndicator(value: _reachProgress.clamp(0.0, 1.0)),
      const SizedBox(height: 10),
      const Text('ระบบจะเก็บระยะสูงสุดตลอดช่วงทดสอบ'),
    ],
  );

  Widget _buildResult() {
    final result = _result!;
    final normal = result.status == AssessmentStatus.normal;
    return Scaffold(
      appBar: AppBar(title: const Text('ผลการทดสอบ')),
      body: AppScaffoldBody(
        child: Column(
          children: [
            Text(
              'ระยะที่เอื้อมได้',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Text(
              '${result.distanceInch.toStringAsFixed(1)} นิ้ว',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            Text('(${result.distanceCm.toStringAsFixed(1)} ซม.)'),
            const SizedBox(height: 20),
            StatusBanner(
              status: result.status,
              label: normal ? 'อยู่ในเกณฑ์' : 'ควรเฝ้าระวัง',
              detail: normal ? 'ระยะไม่น้อยกว่า 7 นิ้ว' : 'ระยะน้อยกว่า 7 นิ้ว',
            ),
            const SizedBox(height: 24),
            ReachThresholdBar(distanceInches: result.distanceInch),
            const SizedBox(height: 28),
            OutlinedButton(
              onPressed: _retry,
              child: const Text('ทดสอบอีกครั้ง'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _saving ? null : _saveResult,
              icon: const Icon(Icons.save_outlined),
              label: Text(_saving ? 'กำลังบันทึก' : 'บันทึกผล'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * .18,
          size.height * .05,
          size.width * .64,
          size.height * .90,
        ),
        const Radius.circular(70),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
