import 'dart:async';

import 'package:balance_detect/core/constants/assessment_config.dart';
import 'package:balance_detect/core/domain/assessment_enums.dart';
import 'package:balance_detect/core/errors/user_facing_exception.dart';
import 'package:balance_detect/core/logging/app_logger.dart';
import 'package:balance_detect/core/providers/app_providers.dart';
import 'package:balance_detect/core/services/voice_guidance_service.dart';
import 'package:balance_detect/core/theme/app_theme.dart';
import 'package:balance_detect/core/utils/id_generator.dart';
import 'package:balance_detect/core/widgets/app_scaffold_body.dart';
import 'package:balance_detect/core/widgets/assessment_progress_header.dart';
import 'package:balance_detect/core/widgets/auto_start_countdown_banner.dart';
import 'package:balance_detect/core/widgets/checklist_tile.dart';
import 'package:balance_detect/core/widgets/error_screens.dart';
import 'package:balance_detect/core/widgets/loading_view.dart';
import 'package:balance_detect/features/assessment/domain/assessment_session.dart';
import 'package:balance_detect/features/fullerton/domain/fullerton_logic.dart';
import 'package:balance_detect/features/fullerton/domain/fullerton_result.dart';
import 'package:balance_detect/features/fullerton/domain/step_detection_service.dart';
import 'package:balance_detect/features/pose/domain/pose_frame.dart';
import 'package:balance_detect/features/pose/domain/pose_validation.dart';
import 'package:balance_detect/features/pose/services/camera_pose_service.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class FullertonAssessmentScreen extends ConsumerStatefulWidget {
  const FullertonAssessmentScreen({super.key});

  @override
  ConsumerState<FullertonAssessmentScreen> createState() =>
      _FullertonAssessmentScreenState();
}

class _FullertonAssessmentScreenState
    extends ConsumerState<FullertonAssessmentScreen>
    with WidgetsBindingObserver {
  final String _sessionId = IdGenerator.generate('session');
  final _stateMachine = FullertonStateMachine();
  final _validator = const PoseValidationService();
  late final MlKitCameraPoseService _cameraService;
  StepDetectionService _stepDetector = StepDetectionService();
  StreamSubscription<PoseFrame>? _frameSubscription;
  StreamSubscription<Object>? _errorSubscription;
  StreamSubscription<PoseDebugMetrics>? _metricsSubscription;
  PoseValidation? _validation;
  PoseDebugMetrics? _metrics;
  StepDetectionSnapshot? _snapshot;
  Duration? _baselineStart;
  InvalidReason? _invalidReason;
  Object? _initializationError;
  FullertonResult? _result;
  bool _initialized = false;
  bool _saving = false;
  int _lostFrames = 0;
  int _processingErrors = 0;
  double _baselineProgress = 0;
  final _voiceGuidance = VoiceGuidanceService();
  Timer? _positioningCountdownTimer;
  Timer? _readyCountdownTimer;
  int? _positioningCountdown;
  int? _readyCountdown;
  bool _voiceEnabled = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cameraService = MlKitCameraPoseService();
    _stateMachine.transitionTo(FullertonState.positioning);
    unawaited(_voiceGuidance.initialize());
    _frameSubscription = _cameraService.frames.listen(_onFrame);
    _errorSubscription = _cameraService.errors.listen(_onError);
    _metricsSubscription = _cameraService.debugMetrics.listen((value) {
      if (mounted) setState(() => _metrics = value);
    });
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      await _cameraService.initialize();
      if (mounted) setState(() => _initialized = true);
    } catch (error) {
      _initializationError = error;
      if (_stateMachine.canTransitionTo(FullertonState.error)) {
        _stateMachine.transitionTo(FullertonState.error);
      }
      if (mounted) setState(() {});
    }
  }

  void _onError(Object error) {
    _processingErrors += 1;
    if (_processingErrors < 5) return;
    _initializationError = error;
    if (_stateMachine.canTransitionTo(FullertonState.error)) {
      _stateMachine.transitionTo(FullertonState.error);
      if (mounted) setState(() {});
    }
  }

  void _onFrame(PoseFrame frame) {
    if (!mounted) return;
    final validation = _validator.validate(frame, requireSideView: false);
    _validation = validation;
    final state = _stateMachine.state;
    if (state == FullertonState.positioning) {
      unawaited(_voiceGuidance.announce(validation.guidance));
      if (validation.canStart) {
        _schedulePositioningStart();
      } else {
        _cancelPositioningCountdown();
      }
    } else if (state == FullertonState.ready) {
      if (validation.canStart) {
        _scheduleReachStart();
      } else {
        _cancelReadyCountdown();
      }
    }
    if (state == FullertonState.footBaseline ||
        state == FullertonState.reaching) {
      if (!(validation.bodyVisible && validation.feetVisible)) {
        _lostFrames += 1;
        if (_lostFrames >= AssessmentConfig.poseLostFrameLimit) {
          _invalidate(InvalidReason.poseLost);
          return;
        }
      } else {
        _lostFrames = 0;
      }
    }
    if (state == FullertonState.footBaseline &&
        validation.bodyVisible &&
        validation.feetVisible) {
      _baselineStart ??= frame.timestamp;
      _stepDetector.addBaselineFrame(frame);
      final elapsed = frame.timestamp - _baselineStart!;
      _baselineProgress =
          elapsed.inMilliseconds /
          AssessmentConfig.fullertonBaselineDuration.inMilliseconds;
      if (elapsed >= AssessmentConfig.fullertonBaselineDuration) {
        if (_stepDetector.finalizeBaseline()) {
          _stateMachine.transitionTo(FullertonState.ready);
          _scheduleReachStart();
        } else {
          _stepDetector = StepDetectionService();
          _baselineStart = frame.timestamp;
          _baselineProgress = 0;
        }
      }
    } else if (state == FullertonState.reaching &&
        validation.bodyVisible &&
        validation.feetVisible) {
      final previousSteps = _snapshot?.stepCount ?? 0;
      _snapshot = _stepDetector.addFrame(frame);
      if (_snapshot!.stepCount > previousSteps) {
        AppLogger.event('fullerton_step_detected', <String, Object?>{
          'stepCount': _snapshot!.stepCount,
        });
      }
    }
    setState(() {});
  }

  void _startBaseline() {
    if (_stateMachine.state != FullertonState.positioning ||
        !(_validation?.canStart ?? false)) {
      return;
    }
    _stateMachine.transitionTo(FullertonState.footBaseline);
    _baselineStart = null;
    unawaited(_voiceGuidance.announce('เริ่มเก็บตำแหน่งเท้า', force: true));
    setState(() {});
  }

  void _schedulePositioningStart() {
    if (_stateMachine.state != FullertonState.positioning ||
        _positioningCountdownTimer != null ||
        !(_validation?.canStart ?? false)) {
      return;
    }
    _positioningCountdown = 3;
    unawaited(
      _voiceGuidance.announce('ตำแหน่งพร้อมแล้ว เริ่มในสามวินาที', force: true),
    );
    if (mounted) setState(() {});
    _positioningCountdownTimer = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) {
      if (!mounted ||
          _stateMachine.state != FullertonState.positioning ||
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
        _startBaseline();
      } else {
        _positioningCountdown = next;
        unawaited(_voiceGuidance.announce(_countdownWord(next), force: true));
      }
      if (mounted) setState(() {});
    });
  }

  void _scheduleReachStart() {
    if (_stateMachine.state != FullertonState.ready ||
        _readyCountdownTimer != null ||
        !(_validation?.canStart ?? false)) {
      return;
    }
    _readyCountdown = 3;
    unawaited(
      _voiceGuidance.announce('พร้อมแล้ว เริ่มเอื้อมในสามวินาที', force: true),
    );
    if (mounted) setState(() {});
    _readyCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted ||
          _stateMachine.state != FullertonState.ready ||
          !(_validation?.canStart ?? false)) {
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
        unawaited(_voiceGuidance.announce('เริ่มเอื้อมหยิบ', force: true));
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
    if (_stateMachine.state != FullertonState.ready) return;
    _stateMachine.transitionTo(FullertonState.reaching);
    AppLogger.event('fullerton_reach_started');
    setState(() {});
  }

  void _finishReach() {
    final snapshot = _stepDetector.snapshot;
    _snapshot = snapshot;
    if (snapshot.confidence < AssessmentConfig.stepMinimumResultConfidence) {
      _invalidate(InvalidReason.stepConfidenceLow);
      return;
    }
    if (snapshot.stepCount == 0) {
      _stateMachine.transitionTo(FullertonState.supervisionQuestion);
      setState(() {});
    } else {
      _complete(supervisionRequired: null);
    }
  }

  void _complete({required bool? supervisionRequired}) {
    final snapshot = _snapshot ?? _stepDetector.snapshot;
    final score = FullertonScoring.calculate(
      stepCount: snapshot.stepCount,
      supervisionRequired: supervisionRequired,
    );
    _result = FullertonResult(
      id: IdGenerator.generate('fullerton'),
      sessionId: _sessionId,
      timestamp: DateTime.now(),
      score: score,
      stepCount: snapshot.stepCount,
      supervisionRequired: supervisionRequired,
      confidence: snapshot.confidence,
      valid: true,
    );
    _stateMachine.transitionTo(FullertonState.completed);
    unawaited(_cameraService.dispose());
    setState(() {});
  }

  void _invalidate(InvalidReason reason) {
    if (!_stateMachine.canTransitionTo(FullertonState.invalid)) return;
    _cancelPositioningCountdown();
    _cancelReadyCountdown();
    _invalidReason = reason;
    _stateMachine.transitionTo(FullertonState.invalid);
    unawaited(_cameraService.dispose());
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    final result = _result;
    if (result == null) return;
    setState(() => _saving = true);
    try {
      final repository = ref.read(assessmentRepositoryProvider);
      final profile = await repository.getProfile();
      final session = AssessmentSession(
        id: _sessionId,
        profileId: profile?.id,
        timestamp: result.timestamp,
        valid: true,
        fullerton: result,
      );
      await repository.saveFullerton(session, result);
      ref.read(historyRevisionProvider.notifier).bump();
      if (mounted) context.go('/history');
    } catch (error) {
      AppLogger.error('save_fullerton_failed', error);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('บันทึกผลไม่สำเร็จ กรุณาลองอีกครั้ง')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _retry() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const FullertonAssessmentScreen(),
      ),
    );
  }

  void _toggleVoice() {
    final enabled = !_voiceEnabled;
    setState(() => _voiceEnabled = enabled);
    unawaited(_voiceGuidance.setEnabled(enabled));
    if (enabled) {
      unawaited(
        _voiceGuidance.announce(
          _validation?.guidance ?? 'เปิดเสียงคำแนะนำแล้ว',
          force: true,
        ),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) return;
    final current = _stateMachine.state;
    if (current == FullertonState.positioning ||
        current == FullertonState.footBaseline ||
        current == FullertonState.ready ||
        current == FullertonState.reaching ||
        current == FullertonState.supervisionQuestion) {
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
    if (_stateMachine.state == FullertonState.invalid) {
      return InvalidTestScreen(reason: _invalidMessage, onRetry: _retry);
    }
    if (_stateMachine.state == FullertonState.error) {
      final error = _initializationError;
      return PermissionErrorScreen(
        message: error is UserFacingException
            ? error.message
            : 'เปิดกล้องหรือตรวจจับท่าทางไม่สำเร็จ',
        canOpenSettings: error is UserFacingException && error.canOpenSettings,
        onRetry: _retry,
      );
    }
    if (_stateMachine.state == FullertonState.supervisionQuestion) {
      return _buildSupervisionQuestion();
    }
    if (_stateMachine.state == FullertonState.completed) return _buildResult();
    if (!_initialized) {
      return const Scaffold(
        body: LoadingView(label: 'กำลังเปิดกล้องและเตรียมระบบตรวจจับเท้า'),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('ทดสอบเอื้อมหยิบ'),
        actions: [
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
              totalSteps: 4,
              title: _title,
              detail: _stepDetail,
            ),
            const SizedBox(height: 16),
            _cameraPreview(),
            const SizedBox(height: 18),
            _stageContent(),
          ],
        ),
      ),
    );
  }

  String get _title => switch (_stateMachine.state) {
    FullertonState.positioning => 'จัดตำแหน่งกล้อง',
    FullertonState.footBaseline => 'เก็บตำแหน่งเท้า',
    FullertonState.ready => 'พร้อมทดสอบ',
    FullertonState.reaching => 'กำลังตรวจการก้าว',
    _ => 'Fullerton',
  };

  int get _currentStep => switch (_stateMachine.state) {
    FullertonState.positioning => 1,
    FullertonState.footBaseline => 2,
    FullertonState.ready => 3,
    FullertonState.reaching => 4,
    _ => 1,
  };

  String get _stepDetail => switch (_stateMachine.state) {
    FullertonState.positioning =>
      'ขยับมือถือหรือผู้ทดสอบจนทุกรายการขึ้นว่าพร้อม',
    FullertonState.footBaseline => 'ยืนวางเท้านิ่งจนแถบเต็ม',
    FullertonState.ready => 'เตรียมตัวให้พร้อม ระบบจะเริ่มเองหลังนับถอยหลัง',
    FullertonState.reaching => 'เอื้อมหยิบของตามปกติ ระบบจะตรวจการก้าว',
    _ => '',
  };

  String get _invalidMessage => switch (_invalidReason) {
    InvalidReason.poseLost => 'ระบบมองไม่เห็นเท้าหรือร่างกายครบระหว่างการทดสอบ',
    InvalidReason.stepConfidenceLow =>
      'ข้อมูลตำแหน่งเท้าไม่ชัดพอที่จะสรุปจำนวนก้าวอย่างน่าเชื่อถือ',
    InvalidReason.interrupted => 'แอปถูกพักหรือหน้าจอถูกล็อกระหว่างการทดสอบ',
    _ => 'ลำดับการทดสอบไม่สมบูรณ์ กรุณาลองอีกครั้ง',
  };

  Widget _cameraPreview() {
    final controller = _cameraService.cameraController!;
    final portrait = MediaQuery.orientationOf(context) == Orientation.portrait;
    final ratio = portrait
        ? 1 / controller.value.aspectRatio
        : controller.value.aspectRatio;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 480),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: AspectRatio(
            aspectRatio: ratio,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(controller),
                IgnorePointer(child: CustomPaint(painter: _FootGuidePainter())),
                if (ref.watch(debugOverlayProvider))
                  Align(
                    alignment: Alignment.topLeft,
                    child: Container(
                      margin: const EdgeInsets.all(8),
                      padding: const EdgeInsets.all(8),
                      color: Colors.black.withValues(alpha: .72),
                      child: Text(
                        'FPS ${_metrics?.framesPerSecond.toStringAsFixed(1) ?? '-'}\n'
                        'pose ${_metrics?.poseConfidence.toStringAsFixed(2) ?? '-'}\n'
                        'steps ${_snapshot?.stepCount ?? 0}\n'
                        'L ${_snapshot?.leftFootMovement.toStringAsFixed(3) ?? '-'} '
                        'R ${_snapshot?.rightFootMovement.toStringAsFixed(3) ?? '-'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stageContent() => switch (_stateMachine.state) {
    FullertonState.positioning => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _validation?.guidance ?? 'กำลังค้นหาร่างกาย',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        ChecklistTile(
          label: 'เห็นร่างกายครบ',
          passed: _validation?.bodyVisible ?? false,
          pending: _validation == null,
        ),
        ChecklistTile(
          label: 'เห็นแขนและของที่จะหยิบ',
          passed: _validation?.armVisible ?? false,
          pending: _validation == null,
        ),
        ChecklistTile(
          label: 'เห็นเท้าทั้งสองข้าง',
          passed: _validation?.feetVisible ?? false,
          pending: _validation == null,
        ),
        const SizedBox(height: 14),
        AutoStartCountdownBanner(
          seconds: _positioningCountdown,
          readyMessage: _validation?.canStart == true
              ? 'จัดตำแหน่งครบแล้ว'
              : 'ทำตามคำแนะนำเพื่อจัดตำแหน่ง',
          countdownMessage: 'ไม่ต้องกดปุ่ม ระบบจะเก็บตำแหน่งเท้าเอง',
        ),
      ],
    ),
    FullertonState.footBaseline => Column(
      children: [
        Text(
          'ยืนวางเท้านิ่งในตำแหน่งเริ่มต้น',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 14),
        LinearProgressIndicator(value: _baselineProgress.clamp(0.0, 1.0)),
        const SizedBox(height: 10),
        const Text('อยู่นิ่งจนแถบเต็ม ระบบจะไปขั้นถัดไปอัตโนมัติ'),
      ],
    ),
    FullertonState.ready => Column(
      children: [
        Text('พร้อมเอื้อมหยิบ', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text('เตรียมตัวเอื้อมหยิบ ระบบจะเริ่มเองหลังนับถอยหลัง'),
        const SizedBox(height: 18),
        AutoStartCountdownBanner(
          seconds: _readyCountdown,
          readyMessage: 'เตรียมตัวได้เลย',
          countdownMessage: 'ระบบจะเริ่มตรวจการก้าวเอง ไม่ต้องกดปุ่ม',
        ),
      ],
    ),
    FullertonState.reaching => Column(
      children: [
        Text(
          'จำนวนก้าวที่ตรวจพบ',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          '${_snapshot?.stepCount ?? 0}',
          style: Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: 8),
        const Text('เมื่อหยิบของเสร็จและยืนมั่นคงแล้ว ให้กดปุ่มด้านล่าง'),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: _finishReach,
          child: const Text('สิ้นสุดการเอื้อมหยิบ'),
        ),
      ],
    ),
    _ => const SizedBox.shrink(),
  };

  Widget _buildSupervisionQuestion() => Scaffold(
    appBar: AppBar(title: const Text('คำถามจากผู้ประเมิน')),
    body: AppScaffoldBody(
      child: Column(
        children: [
          const SizedBox(height: 36),
          const Icon(Icons.health_and_safety_outlined, size: 74),
          const SizedBox(height: 20),
          Text(
            'ระหว่างเอื้อมหยิบ ผู้ทดสอบต้องมีคนคอยช่วยดูแลหรือไม่?',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: () => _complete(supervisionRequired: true),
            child: const Text('ต้องมีผู้ดูแล'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => _complete(supervisionRequired: false),
            child: const Text('ทำได้โดยไม่ต้องช่วย'),
          ),
        ],
      ),
    ),
  );

  Widget _buildResult() {
    final result = _result!;
    const references = <(int, String)>[
      (4, 'ไม่ขยับเท้า'),
      (3, 'ไม่ขยับเท้า + ต้องเฝ้าระวัง'),
      (2, 'ขยับ 1 ก้าว'),
      (1, 'ขยับ 2 ก้าว'),
      (0, 'มากกว่า 2 ก้าว'),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('ผล Fullerton')),
      body: AppScaffoldBody(
        child: Column(
          children: [
            Text(
              '${result.score} / 4 คะแนน',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 8),
            Text(
              result.stepCount == 0
                  ? result.supervisionRequired == true
                        ? 'ไม่ขยับเท้า แต่ต้องมีผู้ดูแล'
                        : 'ไม่ขยับเท้า และไม่ต้องมีผู้ดูแล'
                  : 'ตรวจพบการขยับ ${result.stepCount} ก้าว',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    for (final reference in references)
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: reference.$1 == result.score
                              ? AppColors.primaryContainer
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 70,
                              child: Text(
                                '${reference.$1} คะแนน',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Expanded(child: Text(reference.$2)),
                            if (reference.$1 == result.score)
                              const Icon(
                                Icons.check_circle,
                                color: AppColors.primary,
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: _retry,
              child: const Text('ทดสอบอีกครั้ง'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(_saving ? 'กำลังบันทึก' : 'บันทึกผล'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FootGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: .8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * .40, size.height * .88),
        width: size.width * .22,
        height: size.height * .08,
      ),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * .60, size.height * .88),
        width: size.width * .22,
        height: size.height * .08,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
