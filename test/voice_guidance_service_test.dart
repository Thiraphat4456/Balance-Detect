import 'dart:async';

import 'package:balance_detect/core/services/voice_guidance_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VoiceGuidanceService', () {
    test('throttles a repeated prompt but reminds again later', () async {
      final tts = _FakeFlutterTts();
      var now = DateTime(2026, 8, 30);
      final service = VoiceGuidanceService(
        tts: tts,
        now: () => now,
        isAndroid: false,
        minimumInterval: const Duration(seconds: 2),
        reminderInterval: const Duration(seconds: 7),
      );

      await service.announce('ถอยห่างจากกล้องอีกเล็กน้อย');
      now = now.add(const Duration(seconds: 6));
      await service.announce('ถอยห่างจากกล้องอีกเล็กน้อย');
      expect(tts.spoken, hasLength(1));

      now = now.add(const Duration(seconds: 1));
      await service.announce('ถอยห่างจากกล้องอีกเล็กน้อย');

      expect(tts.spoken, <String>[
        'ถอยห่างจากกล้องอีกเล็กน้อย',
        'ถอยห่างจากกล้องอีกเล็กน้อย',
      ]);
      await service.dispose();
    });

    test('times out a stale speak, rebinds, and retries once', () async {
      final tts = _FakeFlutterTts()..hangFirstSpeak = true;
      final service = VoiceGuidanceService(
        tts: tts,
        isAndroid: true,
        speechTimeout: const Duration(milliseconds: 10),
        initializationTimeout: const Duration(milliseconds: 100),
      );

      await service.announce('ยกแขนให้ขนานกับพื้น', force: true);

      expect(tts.setEngineCalls, 2);
      expect(tts.speakCalls, 2);
      expect(tts.spoken, <String>[
        'ยกแขนให้ขนานกับพื้น',
        'ยกแขนให้ขนานกับพื้น',
      ]);
      expect(tts.focusValues, everyElement(isTrue));
      expect(service.available, isTrue);
      await service.dispose();
    });

    test('recovers when the first initialization fails', () async {
      final tts = _FakeFlutterTts()..languageFailuresRemaining = 1;
      final service = VoiceGuidanceService(
        tts: tts,
        isAndroid: true,
        initializationTimeout: const Duration(milliseconds: 100),
      );

      await service.initialize();
      expect(service.available, isFalse);

      await service.announce('เหยียดข้อศอกให้ตรง', force: true);

      expect(tts.setEngineCalls, 2);
      expect(tts.setLanguageCalls, 2);
      expect(tts.spoken, <String>['เหยียดข้อศอกให้ตรง']);
      expect(service.available, isTrue);
      await service.dispose();
    });

    test('finishes cleanly when Thai language remains unavailable', () async {
      final tts = _FakeFlutterTts()..languageResult = 0;
      final service = VoiceGuidanceService(
        tts: tts,
        isAndroid: true,
        initializationTimeout: const Duration(milliseconds: 100),
      );

      await service.announce('ทดสอบเสียง', force: true);

      expect(tts.setEngineCalls, 2);
      expect(tts.spoken, isEmpty);
      expect(service.available, isFalse);
      await service.dispose();
    });

    test('stop invalidates speech queued behind initialization', () async {
      final tts = _FakeFlutterTts();
      final engineReady = Completer<void>();
      tts.engineReady = engineReady;
      final service = VoiceGuidanceService(
        tts: tts,
        isAndroid: true,
        initializationTimeout: const Duration(seconds: 1),
      );

      final pending = service.announce('ข้อความที่ต้องยกเลิก', force: true);
      await Future<void>.delayed(Duration.zero);
      await service.stop();
      engineReady.complete();
      await pending;

      expect(tts.spoken, isEmpty);
      await service.dispose();
    });
  });
}

class _FakeFlutterTts extends FlutterTts {
  int setEngineCalls = 0;
  int setLanguageCalls = 0;
  int speakCalls = 0;
  int languageFailuresRemaining = 0;
  dynamic languageResult = 1;
  bool hangFirstSpeak = false;
  Completer<void>? engineReady;
  final List<String> spoken = <String>[];
  final List<bool> focusValues = <bool>[];

  @override
  Future<dynamic> get getEngines async => <String>['fake.tts'];

  @override
  Future<dynamic> get getDefaultEngine async => 'fake.tts';

  @override
  Future<dynamic> setEngine(String engine) async {
    setEngineCalls += 1;
    await engineReady?.future;
  }

  @override
  Future<dynamic> setLanguage(String language) async {
    setLanguageCalls += 1;
    if (languageFailuresRemaining > 0) {
      languageFailuresRemaining -= 1;
      throw StateError('temporary language failure');
    }
    return languageResult;
  }

  @override
  Future<dynamic> setSpeechRate(double rate) async => 1;

  @override
  Future<dynamic> setPitch(double pitch) async => 1;

  @override
  Future<dynamic> setVolume(double volume) async => 1;

  @override
  Future<dynamic> awaitSpeakCompletion(bool awaitCompletion) async => 1;

  @override
  Future<void> setAudioAttributesForNavigation() async {}

  @override
  Future<dynamic> stop() async => 1;

  @override
  Future<dynamic> speak(String text, {bool focus = false}) {
    speakCalls += 1;
    spoken.add(text);
    focusValues.add(focus);
    if (hangFirstSpeak && speakCalls == 1) {
      return Completer<dynamic>().future;
    }
    return Future<dynamic>.value(1);
  }
}
