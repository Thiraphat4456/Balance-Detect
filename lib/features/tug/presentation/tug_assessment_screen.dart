import 'dart:async';

import 'package:balance_detect/core/constants/assessment_config.dart';
import 'package:balance_detect/core/domain/assessment_enums.dart';
import 'package:balance_detect/core/logging/app_logger.dart';
import 'package:balance_detect/core/providers/app_providers.dart';
import 'package:balance_detect/core/services/voice_guidance_service.dart';
import 'package:balance_detect/core/theme/app_theme.dart';
import 'package:balance_detect/core/utils/id_generator.dart';
import 'package:balance_detect/core/widgets/app_scaffold_body.dart';
import 'package:balance_detect/core/widgets/assessment_progress_header.dart';
import 'package:balance_detect/core/widgets/checklist_tile.dart';
import 'package:balance_detect/core/widgets/error_screens.dart';
import 'package:balance_detect/core/widgets/status_banner.dart';
import 'package:balance_detect/features/assessment/domain/assessment_session.dart';
import 'package:balance_detect/features/tug/domain/sensor_calibration_service.dart';
import 'package:balance_detect/features/tug/domain/sensor_models.dart';
import 'package:balance_detect/features/tug/domain/sensor_noise_filter.dart';
import 'package:balance_detect/features/tug/domain/tug_logic.dart';
import 'package:balance_detect/features/tug/domain/tug_motion_analyzer.dart';
import 'package:balance_detect/features/tug/domain/tug_result.dart';
import 'package:balance_detect/features/tug/domain/tug_instructions.dart';
import 'package:balance_detect/features/tug/services/sensor_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class TugAssessmentScreen extends ConsumerStatefulWidget {
  const TugAssessmentScreen({super.key});

  @override
  ConsumerState<TugAssessmentScreen> createState() =>
      _TugAssessmentScreenState();
}

class _TugAssessmentScreenState extends ConsumerState<TugAssessmentScreen>
    with WidgetsBindingObserver {
  final String _sessionId = IdGenerator.generate('session');
  final _stateMachine = TugStateMachine();
  final _sensorService = SensorsPlusService();
  final _calibrationService = const SensorCalibrationService();
  final _voiceGuidance = VoiceGuidanceService();
  final List<SensorSample> _calibrationSamples = <SensorSample>[];
  StreamSubscription<SensorSample>? _sampleSubscription;
  StreamSubscription<Object>? _errorSubscription;
  SensorAvailability? _availability;
  SensorCalibration? _calibration;
  SensorNoiseFilter? _noiseFilter;
  TugMotionAnalyzer? _analyzer;
  TugAnalysisSnapshot? _analysis;
  TugResult? _result;
  SensorSample? _latestRaw;
  Duration? _calibrationStart;
  InvalidReason? _invalidReason;
  String? _setupError;
  bool _probing = true;
  bool _calibrationFinalizing = false;
  bool _pendingTestStart = false;
  bool _automaticCountdownScheduled = false;
  bool _finished = false;
  bool _saving = false;
  bool _voiceEnabled = true;
  int? _countdown;
  double _calibrationProgress = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_voiceGuidance.initialize());
    _sampleSubscription = _sensorService.samples.listen(_onSample);
    _errorSubscription = _sensorService.errors.listen((error) {
      if (_stateMachine.state != TugState.idle) {
        _invalidate(InvalidReason.sensorUnavailable);
      }
    });
    unawaited(_probeSensors());
  }

  Future<void> _probeSensors() async {
    setState(() {
      _probing = true;
      _setupError = null;
    });
    try {
      final availability = await _sensorService.probe();
      if (!mounted) return;
      setState(() {
        _availability = availability;
        _probing = false;
        if (!availability.ready) {
          _setupError = !availability.accelerometerAvailable
              ? 'ไม่พบ Accelerometer บนอุปกรณ์นี้'
              : 'ไม่พบ Gyroscope บนอุปกรณ์นี้';
        }
      });
      unawaited(
        _voiceGuidance.announce(
          availability.ready
              ? TugInstructions.sensorReady
              : _setupError ?? 'เซนเซอร์ไม่พร้อม กรุณาตรวจสอบอุปกรณ์',
          force: true,
        ),
      );
    } catch (error) {
      AppLogger.error('sensor_probe_failed', error);
      if (mounted) {
        setState(() {
          _probing = false;
          _setupError = 'ตรวจสอบเซนเซอร์ไม่สำเร็จ กรุณาลองอีกครั้ง';
        });
        unawaited(_voiceGuidance.announce(_setupError!, force: true));
      }
    }
  }

  Future<void> _startCalibration() async {
    if (!(_availability?.ready ?? false)) return;
    _stateMachine.transitionTo(TugState.calibrating);
    _calibrationSamples.clear();
    _calibrationStart = null;
    _calibrationProgress = 0;
    _calibrationFinalizing = false;
    _automaticCountdownScheduled = false;
    _pendingTestStart = false;
    _countdown = null;
    unawaited(
      _voiceGuidance.announce(TugInstructions.calibration, force: true),
    );
    try {
      await _sensorService.start();
      if (mounted) setState(() {});
    } catch (error) {
      AppLogger.error('sensor_start_failed', error);
      _invalidate(InvalidReason.sensorUnavailable);
    }
  }

  void _onSample(SensorSample sample) {
    if (!mounted) return;
    _latestRaw = sample;
    if (_stateMachine.state == TugState.calibrating) {
      _calibrationStart ??= sample.elapsed;
      _calibrationSamples.add(sample);
      final elapsed = sample.elapsed - _calibrationStart!;
      _calibrationProgress =
          elapsed.inMilliseconds /
          AssessmentConfig.sensorCalibrationDuration.inMilliseconds;
      if (elapsed >= AssessmentConfig.sensorCalibrationDuration &&
          !_calibrationFinalizing) {
        _calibrationFinalizing = true;
        unawaited(_finishCalibration());
      }
      setState(() {});
      return;
    }
    if (_pendingTestStart && _stateMachine.state == TugState.ready) {
      _pendingTestStart = false;
      _noiseFilter = SensorNoiseFilter();
      _analyzer = TugMotionAnalyzer(
        calibration: _calibration!,
        stateMachine: _stateMachine,
      )..start(sample.elapsed);
      AppLogger.event('tug_started');
    }
    final analyzer = _analyzer;
    if (analyzer == null ||
        _stateMachine.state == TugState.ready ||
        _stateMachine.state == TugState.completed ||
        _stateMachine.state == TugState.invalid ||
        _stateMachine.state == TugState.error) {
      return;
    }
    final calibrated = _calibrationService.apply(sample, _calibration!);
    final filtered = _noiseFilter!.filter(calibrated);
    final previousState = _stateMachine.state;
    final analysis = analyzer.process(filtered);
    _analysis = analysis;
    if (analysis.state != previousState) {
      AppLogger.event('tug_${analysis.state.name}_detected', <String, Object?>{
        'elapsedMs': analysis.elapsed.inMilliseconds,
        'confidence': analysis.confidence,
      });
      final prompt = TugInstructions.promptForState(analysis.state);
      if (prompt != null && analysis.state != TugState.completed) {
        unawaited(_voiceGuidance.announce(prompt, force: true));
      }
    }
    if (analysis.elapsed > AssessmentConfig.tugMaximumDuration) {
      _invalidate(InvalidReason.timeout);
      return;
    }
    if (analysis.state == TugState.completed && !_finished) {
      _finished = true;
      _finishTest(analysis);
      return;
    }
    setState(() {});
  }

  Future<void> _finishCalibration() async {
    await _sensorService.stop();
    try {
      final calibration = _calibrationService.calibrate(_calibrationSamples);
      _calibration = calibration;
      _stateMachine.transitionTo(TugState.ready);
      AppLogger.event('tug_calibration_success', <String, Object?>{
        'samples': calibration.sampleCount,
        'confidence': calibration.confidence,
      });
      if (mounted) {
        setState(() {});
        unawaited(_scheduleAutomaticCountdown());
      }
    } on FormatException catch (error) {
      AppLogger.event('tug_calibration_failed');
      _setupError = error.message.toString();
      _invalidate(InvalidReason.calibrationFailed);
    }
  }

  Future<void> _scheduleAutomaticCountdown() async {
    if (_stateMachine.state != TugState.ready || _automaticCountdownScheduled) {
      return;
    }
    _automaticCountdownScheduled = true;
    unawaited(_voiceGuidance.announce(TugInstructions.calibrated, force: true));
    if (mounted) setState(() {});
    await Future<void>.delayed(
      _voiceEnabled
          ? TugInstructions.preCountdownDelay
          : const Duration(seconds: 1),
    );
    if (!mounted || _stateMachine.state != TugState.ready) return;
    await _countdownAndStart();
  }

  Future<void> _countdownAndStart() async {
    if (_stateMachine.state != TugState.ready || _countdown != null) return;
    for (var count = 3; count >= 1; count -= 1) {
      if (!mounted || _stateMachine.state != TugState.ready) return;
      setState(() => _countdown = count);
      unawaited(
        _voiceGuidance.announce(
          TugInstructions.countdownWord(count),
          force: true,
        ),
      );
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    if (!mounted || _stateMachine.state != TugState.ready) return;
    try {
      await _sensorService.start();
      if (!mounted || _stateMachine.state != TugState.ready) return;
      setState(() => _countdown = 0);
      _pendingTestStart = true;
      unawaited(_voiceGuidance.announce(TugInstructions.start, force: true));
    } catch (error) {
      _invalidate(InvalidReason.sensorUnavailable);
    }
  }

  void _finishTest(TugAnalysisSnapshot analysis) {
    final timeline = analysis.timeline!;
    final includePhases =
        analysis.confidence >= AssessmentConfig.tugPhaseConfidence;
    final seconds = timeline.totalSeconds;
    _result = TugResult(
      id: IdGenerator.generate('tug'),
      sessionId: _sessionId,
      timestamp: DateTime.now(),
      totalSeconds: seconds,
      thresholdSeconds: AssessmentConfig.tugRiskThresholdSeconds,
      riskStatus: TugRiskClassifier.classifySeconds(seconds),
      standDuration: includePhases ? timeline.standDuration : null,
      outboundWalkDuration: includePhases
          ? timeline.outboundWalkDuration
          : null,
      turnDuration: includePhases ? timeline.turnDuration : null,
      returnWalkDuration: includePhases ? timeline.returnWalkDuration : null,
      sitDuration: includePhases ? timeline.sitDuration : null,
      confidence: analysis.confidence,
      valid: true,
    );
    unawaited(_sensorService.stop());
    unawaited(
      _replaceVoicePrompt(
        TugInstructions.result(
          seconds: seconds,
          overThreshold: _result!.riskStatus == AssessmentStatus.risk,
        ),
      ),
    );
    setState(() {});
  }

  void _invalidate(InvalidReason reason) {
    if (!_stateMachine.canTransitionTo(TugState.invalid)) return;
    _invalidReason = reason;
    _stateMachine.transitionTo(TugState.invalid);
    unawaited(_sensorService.stop());
    unawaited(_replaceVoicePrompt('หยุดการทดสอบ $_invalidMessage'));
    if (mounted) setState(() {});
  }

  Future<void> _replaceVoicePrompt(String message) async {
    await _voiceGuidance.stop();
    await _voiceGuidance.announce(message, force: true);
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
        tug: result,
      );
      await repository.saveTug(session, result);
      ref.read(historyRevisionProvider.notifier).bump();
      if (mounted) context.go('/history');
    } catch (error) {
      AppLogger.error('save_tug_failed', error);
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
      MaterialPageRoute<void>(builder: (_) => const TugAssessmentScreen()),
    );
  }

  void _toggleVoice() {
    final enabled = !_voiceEnabled;
    setState(() => _voiceEnabled = enabled);
    unawaited(_voiceGuidance.setEnabled(enabled));
    if (enabled) {
      unawaited(_voiceGuidance.announce(_currentVoicePrompt, force: true));
    }
  }

  String get _currentVoicePrompt {
    final state = _stateMachine.state;
    if (state == TugState.completed && _result != null) {
      return TugInstructions.result(
        seconds: _result!.totalSeconds,
        overThreshold: _result!.riskStatus == AssessmentStatus.risk,
      );
    }
    if (state == TugState.invalid) return _invalidMessage;
    if (state == TugState.idle) {
      return _availability?.ready == true
          ? TugInstructions.sensorReady
          : 'กำลังตรวจสอบเซนเซอร์';
    }
    if (state == TugState.calibrating) return TugInstructions.calibration;
    if (state == TugState.ready) {
      final countdown = _countdown;
      return countdown == null
          ? TugInstructions.calibrated
          : countdown == 0
          ? TugInstructions.start
          : TugInstructions.countdownWord(countdown);
    }
    return TugInstructions.promptForState(state) ??
        'กำลังวิเคราะห์การเคลื่อนไหว';
  }

  Widget _voiceButton() => IconButton(
    onPressed: _toggleVoice,
    tooltip: _voiceEnabled ? 'ปิดเสียงคำแนะนำ' : 'เปิดเสียงคำแนะนำ',
    icon: Icon(
      _voiceEnabled ? Icons.volume_up_outlined : Icons.volume_off_outlined,
    ),
  );

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) return;
    if (_stateMachine.state != TugState.idle &&
        _stateMachine.state != TugState.completed &&
        _stateMachine.state != TugState.invalid &&
        _stateMachine.state != TugState.error) {
      _invalidate(InvalidReason.interrupted);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_sampleSubscription?.cancel());
    unawaited(_errorSubscription?.cancel());
    unawaited(_sensorService.dispose());
    unawaited(_voiceGuidance.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_stateMachine.state == TugState.invalid) {
      return InvalidTestScreen(reason: _invalidMessage, onRetry: _retry);
    }
    if (_stateMachine.state == TugState.completed && _result != null) {
      return _buildResult();
    }
    if (_stateMachine.state == TugState.idle) return _buildSensorSetup();
    if (_stateMachine.state == TugState.calibrating) return _buildCalibration();
    if (_stateMachine.state == TugState.ready) return _buildReady();
    return _buildLiveTest();
  }

  String get _invalidMessage => switch (_invalidReason) {
    InvalidReason.sensorUnavailable =>
      'เซนเซอร์หยุดส่งข้อมูลหรือไม่พร้อมใช้งานระหว่างการทดสอบ',
    InvalidReason.calibrationFailed =>
      _setupError ?? 'การปรับเทียบไม่สำเร็จ กรุณานั่งนิ่งแล้วลองอีกครั้ง',
    InvalidReason.interrupted => 'แอปถูกพักหรือหน้าจอถูกล็อกระหว่างการทดสอบ',
    InvalidReason.timeout =>
      'การทดสอบใช้เวลานานเกิน 60 วินาที ระบบจึงหยุดเพื่อป้องกันผลผิดพลาด',
    InvalidReason.unexpectedMotion =>
      'ยกเลิกการทดสอบเพื่อความปลอดภัย ผลจะไม่ถูกบันทึก',
    _ => 'ตรวจพบลำดับการเคลื่อนไหวที่ไม่สมบูรณ์ กรุณาลองอีกครั้ง',
  };

  Widget _buildSensorSetup() => Scaffold(
    appBar: AppBar(
      title: const Text('ทดสอบลุก–เดิน–นั่ง'),
      actions: [_voiceButton()],
    ),
    body: AppScaffoldBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AssessmentProgressHeader(
            currentStep: 1,
            totalSteps: 4,
            title: 'ตรวจความพร้อม',
            detail:
                'ระบบตรวจเซนเซอร์ให้อัตโนมัติ ส่วนอุปกรณ์ให้ผู้ดูแลตรวจอีกครั้ง',
          ),
          const SizedBox(height: 16),
          ChecklistTile(
            label: 'Accelerometer พร้อม',
            passed: _availability?.accelerometerAvailable ?? false,
            pending: _probing,
          ),
          ChecklistTile(
            label: 'Gyroscope พร้อม',
            passed: _availability?.gyroscopeAvailable ?? false,
            pending: _probing,
          ),
          const PreparationItem(
            label: 'คาดโทรศัพท์ให้แน่นบริเวณเอว',
            icon: Icons.phone_android_rounded,
          ),
          const PreparationItem(
            label: 'ทำเครื่องหมายระยะเดิน 3 เมตร',
            icon: Icons.straighten_rounded,
          ),
          const PreparationItem(
            label: 'ใช้เก้าอี้มั่นคงและมีผู้ดูแลใกล้ ๆ',
            icon: Icons.health_and_safety_outlined,
          ),
          const PreparationItem(
            label:
                'กดปรับเทียบครั้งเดียว แล้วฟังเสียงสั่งเริ่มโดยไม่ต้องแตะจออีก',
            icon: Icons.record_voice_over_outlined,
          ),
          if (_setupError != null) ...[
            const SizedBox(height: 12),
            StatusBanner(
              status: AssessmentStatus.invalid,
              label: 'เซนเซอร์ไม่พร้อม',
              detail: _setupError,
            ),
          ],
          const SizedBox(height: 22),
          FilledButton(
            onPressed: _availability?.ready == true ? _startCalibration : null,
            child: const Text('เริ่มปรับเทียบและทดสอบ'),
          ),
          if (!_probing && !(_availability?.ready ?? false)) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _probeSensors,
              child: const Text('ตรวจอีกครั้ง'),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _buildCalibration() => Scaffold(
    appBar: AppBar(
      title: const Text('ทดสอบลุก–เดิน–นั่ง'),
      actions: [_voiceButton()],
    ),
    body: AppScaffoldBody(
      child: Column(
        children: [
          const AssessmentProgressHeader(
            currentStep: 2,
            totalSteps: 4,
            title: 'เตรียมเซนเซอร์',
            detail: 'นั่งในท่าเริ่มต้นและอยู่นิ่งจนแถบเต็ม',
          ),
          const SizedBox(height: 28),
          const Icon(
            Icons.event_seat_outlined,
            size: 80,
            color: AppColors.primary,
          ),
          const SizedBox(height: 20),
          Text(
            'กรุณานั่งนิ่ง 3 วินาที',
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          const Text(
            'ระบบกำลังปรับเซนเซอร์ให้เหมาะกับมือถือเครื่องนี้',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          LinearProgressIndicator(value: _calibrationProgress.clamp(0.0, 1.0)),
        ],
      ),
    ),
  );

  Widget _buildReady() => Scaffold(
    appBar: AppBar(
      title: const Text('ทดสอบลุก–เดิน–นั่ง'),
      actions: [_voiceButton()],
    ),
    body: AppScaffoldBody(
      child: Column(
        children: [
          const AssessmentProgressHeader(
            currentStep: 3,
            totalSteps: 4,
            title: 'พร้อมเริ่ม',
            detail: 'นั่งชิดพนัก วางเท้าให้มั่นคง และรอสัญญาณนับถอยหลัง',
          ),
          const SizedBox(height: 24),
          if (_countdown == null) ...[
            const StatusBanner(
              status: AssessmentStatus.normal,
              label: 'เซนเซอร์พร้อม · เริ่มอัตโนมัติ',
              detail: TugInstructions.automaticStartDetail,
            ),
            const SizedBox(height: 28),
            const SizedBox(
              width: 42,
              height: 42,
              child: CircularProgressIndicator(strokeWidth: 4),
            ),
            const SizedBox(height: 16),
            const Text(
              'ฟังคำอธิบายและคงท่านั่งไว้',
              textAlign: TextAlign.center,
            ),
          ] else ...[
            Text(
              _countdown == 0 ? 'เริ่ม' : '$_countdown',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontSize: 84,
                color: AppColors.primary,
              ),
              semanticsLabel: _countdown == 0 ? 'เริ่ม' : '$_countdown',
            ),
            const SizedBox(height: 18),
            const Text('ลุก เดิน 3 เมตร หมุนตัว เดินกลับ และนั่งลง'),
          ],
        ],
      ),
    ),
  );

  Widget _buildLiveTest() {
    final seconds = _analysis?.elapsed.inMilliseconds == null
        ? 0.0
        : _analysis!.elapsed.inMilliseconds / 1000;
    return Scaffold(
      appBar: AppBar(
        title: const Text('ทดสอบลุก–เดิน–นั่ง'),
        automaticallyImplyLeading: false,
        actions: [_voiceButton()],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const AssessmentProgressHeader(
                currentStep: 4,
                totalSteps: 4,
                title: 'กำลังจับเวลา',
                detail: 'ทำตามลำดับจนกลับมานั่ง ระบบจะหยุดเวลาให้อัตโนมัติ',
              ),
              const Spacer(),
              Text(
                _stateLabel,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 14),
              Text(
                '${seconds.toStringAsFixed(1)} วินาที',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 18),
              const Text(
                'ระบบจะหยุดเวลาอัตโนมัติเมื่อตรวจพบนั่งลง',
                textAlign: TextAlign.center,
              ),
              if (ref.watch(debugOverlayProvider)) ...[
                const SizedBox(height: 22),
                _debugCard(),
              ],
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () => _invalidate(InvalidReason.unexpectedMotion),
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('หยุดการทดสอบ'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.risk,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _stateLabel => switch (_stateMachine.state) {
    TugState.sitting => 'เริ่มลุกขึ้น',
    TugState.standingUp => 'ตรวจพบการลุก',
    TugState.walkingOut => 'กำลังเดินไป',
    TugState.turning => 'ตรวจพบการหมุนตัว',
    TugState.walkingBack => 'กำลังเดินกลับ',
    TugState.sittingDown => 'กำลังตรวจการนั่งลง',
    _ => 'กำลังวิเคราะห์การเคลื่อนไหว',
  };

  Widget _debugCard() {
    final raw = _latestRaw;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: Colors.black87,
      child: Text(
        'state ${_stateMachine.state.name}\n'
        'acc ${raw == null ? '-' : '${raw.accelerometer.x.toStringAsFixed(2)}, ${raw.accelerometer.y.toStringAsFixed(2)}, ${raw.accelerometer.z.toStringAsFixed(2)}'}\n'
        'gyro ${raw == null ? '-' : '${raw.gyroscope.x.toStringAsFixed(2)}, ${raw.gyroscope.y.toStringAsFixed(2)}, ${raw.gyroscope.z.toStringAsFixed(2)}'}\n'
        'dynamic ${_analysis?.dynamicAcceleration.toStringAsFixed(2) ?? '-'} '
        'angular ${_analysis?.angularVelocity.toStringAsFixed(2) ?? '-'}',
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }

  Widget _buildResult() {
    final result = _result!;
    final risk = result.riskStatus == AssessmentStatus.risk;
    final phases = <(String, double?)>[
      ('ลุกขึ้น', result.standDuration),
      ('เดินไป', result.outboundWalkDuration),
      ('หมุนตัว', result.turnDuration),
      ('เดินกลับ', result.returnWalkDuration),
      ('นั่งลง', result.sitDuration),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('ผล Timed Up and Go'),
        actions: [_voiceButton()],
      ),
      body: AppScaffoldBody(
        child: Column(
          children: [
            Text(
              '${result.totalSeconds.toStringAsFixed(1)} วินาที',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 20),
            StatusBanner(
              status: result.riskStatus,
              label: risk ? 'พบความเสี่ยง' : 'อยู่ในเกณฑ์',
              detail: risk
                  ? 'ใช้เวลามากกว่า 13.5 วินาที ควรได้รับการประเมินเพิ่มเติม'
                  : 'ใช้เวลาไม่เกิน 13.5 วินาที',
            ),
            const SizedBox(height: 22),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Expanded(child: Text('เกณฑ์คัดกรอง')),
                        Text(
                          '> ${result.thresholdSeconds.toStringAsFixed(1)} วินาที',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    if (result.standDuration != null) ...[
                      const Divider(height: 28),
                      for (final phase in phases)
                        if (phase.$2 != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(child: Text(phase.$1)),
                                Text('${phase.$2!.toStringAsFixed(1)} วินาที'),
                              ],
                            ),
                          ),
                    ] else ...[
                      const Divider(height: 28),
                      const Text(
                        'ความเชื่อมั่นของช่วงย่อยไม่เพียงพอ จึงแสดงเฉพาะเวลารวม',
                      ),
                    ],
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
