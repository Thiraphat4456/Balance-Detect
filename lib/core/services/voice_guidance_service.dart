import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

/// Speaks short, actionable prompts without interrupting the pose pipeline.
///
/// Pose frames arrive many times per second, so callers can safely forward the
/// current guidance on every frame. Repeated messages are coalesced and a
/// minimum interval keeps the phone from talking over itself. The service is
/// deliberately best-effort: a device without an installed Thai voice must
/// not prevent a camera assessment from running.
class VoiceGuidanceService {
  VoiceGuidanceService({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  static const _minimumInterval = Duration(milliseconds: 2400);

  final FlutterTts _tts;
  Future<void>? _initialization;
  Future<void> _speechQueue = Future<void>.value();
  DateTime _lastScheduledAt = DateTime.fromMillisecondsSinceEpoch(0);
  String? _lastMessage;
  bool _available = true;
  bool _disposed = false;
  bool _enabled = true;
  int _speechGeneration = 0;

  bool get enabled => _enabled;

  Future<void> initialize() {
    return _initialization ??= _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _tts.setLanguage('th-TH');
      await _tts.setSpeechRate(0.48);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      await _tts.awaitSpeakCompletion(false);
    } catch (_) {
      _available = false;
    }
  }

  /// Queues a prompt for speech. Use [force] for one-off state changes such as
  /// a countdown tick; normal frame guidance remains throttled.
  Future<void> announce(String message, {bool force = false}) {
    final normalized = message.trim();
    if (_disposed || !_enabled || normalized.isEmpty) {
      return Future<void>.value();
    }

    final now = DateTime.now();
    if (!force &&
        (normalized == _lastMessage ||
            now.difference(_lastScheduledAt) < _minimumInterval)) {
      return Future<void>.value();
    }
    _lastMessage = normalized;
    _lastScheduledAt = now;
    final generation = _speechGeneration;

    _speechQueue = _speechQueue.then((_) async {
      if (_disposed || !_enabled || generation != _speechGeneration) return;
      await initialize();
      if (_disposed ||
          !_enabled ||
          generation != _speechGeneration ||
          !_available) {
        return;
      }
      try {
        await _tts.stop();
        await _tts.speak(normalized);
      } catch (_) {
        // Speech is an enhancement; keep the visual flow usable if the TTS
        // engine is unavailable or reports a device-specific error.
      }
    });
    return _speechQueue;
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
      await _tts.stop();
    } catch (_) {
      // Ignore shutdown errors from an unavailable platform TTS engine.
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _speechGeneration += 1;
    try {
      await _tts.stop();
    } catch (_) {
      // Ignore shutdown errors from an unavailable platform TTS engine.
    }
  }
}
