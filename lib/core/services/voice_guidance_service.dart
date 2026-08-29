import 'dart:async';

import 'package:balance_detect/core/logging/app_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Speaks short, actionable prompts without interrupting the pose pipeline.
///
/// Pose frames arrive many times per second, so callers can safely forward the
/// current guidance on every frame. Repeated messages are coalesced and a
/// minimum interval keeps the phone from talking over itself. Android TTS can
/// lose its native service connection while this app process remains alive
/// (for example after the speech engine is updated), so every speech operation
/// is bounded by a timeout and gets one engine-rebind recovery attempt.
class VoiceGuidanceService {
  VoiceGuidanceService({
    FlutterTts? tts,
    DateTime Function()? now,
    bool? isAndroid,
    this.minimumInterval = const Duration(milliseconds: 2400),
    this.reminderInterval = const Duration(seconds: 7),
    this.speechTimeout = const Duration(seconds: 3),
    this.initializationTimeout = const Duration(seconds: 8),
  }) : _tts = tts ?? FlutterTts(),
       _now = now ?? DateTime.now,
       _isAndroid =
           isAndroid ??
           (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    _tts.setStartHandler(() {
      AppLogger.event('voice_guidance_started');
    });
    _tts.setErrorHandler((message) {
      AppLogger.event('voice_guidance_platform_error', <String, Object?>{
        'message': message,
      });
    });
  }

  final FlutterTts _tts;
  final DateTime Function() _now;
  final bool _isAndroid;
  final Duration minimumInterval;
  final Duration reminderInterval;
  final Duration speechTimeout;
  final Duration initializationTimeout;

  Future<void>? _initialization;
  Future<void> _speechQueue = Future<void>.value();
  DateTime _lastScheduledAt = DateTime.fromMillisecondsSinceEpoch(0);
  String? _lastMessage;
  bool _available = true;
  bool _disposed = false;
  bool _enabled = true;
  int _speechGeneration = 0;

  bool get enabled => _enabled;
  bool get available => _available;

  Future<void> initialize() {
    return _initialization ??= _initialize(forceEngineRebind: _isAndroid);
  }

  Future<void> _initialize({required bool forceEngineRebind}) async {
    _available = true;
    try {
      if (forceEngineRebind) await _rebindAndroidEngine();

      final languageResult = await _tts
          .setLanguage('th-TH')
          .timeout(initializationTimeout);
      if (_isAndroid && languageResult != 1 && languageResult != true) {
        throw StateError('Thai TTS language is unavailable');
      }
      await _tts.setSpeechRate(0.48).timeout(initializationTimeout);
      await _tts.setPitch(1.0).timeout(initializationTimeout);
      await _tts.setVolume(1.0).timeout(initializationTimeout);
      await _tts.awaitSpeakCompletion(false).timeout(initializationTimeout);
      if (_isAndroid) {
        await _tts.setAudioAttributesForNavigation().timeout(
          initializationTimeout,
        );
      }
      AppLogger.event('voice_guidance_ready');
    } catch (error) {
      _available = false;
      AppLogger.error('voice_guidance_initialization_failed', error);
    }
  }

  Future<void> _rebindAndroidEngine() async {
    final rawEngines = await _tts.getEngines.timeout(initializationTimeout);
    final engines = rawEngines is Iterable
        ? rawEngines.whereType<String>().toList(growable: false)
        : const <String>[];
    if (engines.isEmpty) throw StateError('No Android TTS engine installed');

    String? defaultEngine;
    try {
      final rawDefault = await _tts.getDefaultEngine.timeout(
        initializationTimeout,
      );
      if (rawDefault is String && engines.contains(rawDefault)) {
        defaultEngine = rawDefault;
      }
    } catch (error) {
      AppLogger.error('voice_guidance_default_engine_lookup_failed', error);
    }

    final selectedEngine = defaultEngine ?? engines.first;
    await _tts.setEngine(selectedEngine).timeout(initializationTimeout);
    AppLogger.event('voice_guidance_engine_bound', <String, Object?>{
      'engine': selectedEngine,
    });
  }

  /// Queues a prompt for speech. Use [force] for one-off state changes such as
  /// a countdown tick; normal frame guidance remains throttled.
  Future<void> announce(String message, {bool force = false}) {
    final normalized = message.trim();
    if (_disposed || !_enabled || normalized.isEmpty) {
      return Future<void>.value();
    }

    final now = _now();
    final sameMessage = normalized == _lastMessage;
    final requiredInterval = sameMessage ? reminderInterval : minimumInterval;
    if (!force && now.difference(_lastScheduledAt) < requiredInterval) {
      return Future<void>.value();
    }
    _lastMessage = normalized;
    _lastScheduledAt = now;
    final generation = _speechGeneration;

    _speechQueue = _speechQueue.then((_) async {
      if (!_canSpeak(generation)) return;
      await initialize();
      if (!_canSpeak(generation)) return;

      var accepted = false;
      if (_available) accepted = await _speakOnce(normalized);
      if (!accepted && _canSpeak(generation)) {
        accepted = await _recoverAndSpeak(normalized, generation);
      }
      if (!accepted && generation == _speechGeneration) {
        _resetReminderIfCurrent(normalized);
      }
    });
    return _speechQueue;
  }

  bool _canSpeak(int generation) =>
      !_disposed && _enabled && generation == _speechGeneration;

  Future<bool> _speakOnce(String message) async {
    try {
      await _tts.stop().timeout(speechTimeout);
      final result = await _tts
          .speak(message, focus: true)
          .timeout(speechTimeout);
      final accepted = result == 1 || result == true;
      if (!accepted) {
        AppLogger.event('voice_guidance_speak_rejected', <String, Object?>{
          'result': result?.toString() ?? 'null',
        });
      }
      return accepted;
    } on TimeoutException catch (error) {
      AppLogger.error('voice_guidance_speak_timeout', error);
      return false;
    } catch (error) {
      AppLogger.error('voice_guidance_speak_failed', error);
      return false;
    }
  }

  Future<bool> _recoverAndSpeak(String message, int generation) async {
    AppLogger.event('voice_guidance_recovery_started');
    _initialization = null;
    await initialize();
    if (!_available || !_canSpeak(generation)) {
      AppLogger.event('voice_guidance_recovery_failed');
      return false;
    }

    // flutter_tts may replay the platform call that became stuck before the
    // rebind. Flush it first, then submit exactly one fresh utterance.
    final accepted = await _speakOnce(message);
    AppLogger.event(
      accepted
          ? 'voice_guidance_recovery_succeeded'
          : 'voice_guidance_recovery_failed',
    );
    return accepted;
  }

  void _resetReminderIfCurrent(String message) {
    if (_lastMessage != message) return;
    _lastMessage = null;
    _lastScheduledAt = DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    if (!enabled) await stop();
  }

  /// Cancels queued prompts when the pose leaves a valid state.
  Future<void> stop() async {
    if (_disposed) return;
    _speechGeneration += 1;
    _lastMessage = null;
    _lastScheduledAt = DateTime.fromMillisecondsSinceEpoch(0);
    try {
      await _tts.stop().timeout(speechTimeout);
    } on TimeoutException catch (error) {
      AppLogger.error('voice_guidance_stop_timeout', error);
    } catch (error) {
      AppLogger.error('voice_guidance_stop_failed', error);
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _speechGeneration += 1;
    try {
      await _tts.stop().timeout(speechTimeout);
    } on TimeoutException catch (error) {
      AppLogger.error('voice_guidance_dispose_timeout', error);
    } catch (error) {
      AppLogger.error('voice_guidance_dispose_failed', error);
    }
  }
}
