import 'package:balance_detect/core/services/screen_awake_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'first lease enables and last lease disables the screen wakelock',
    () async {
      final platform = _FakeScreenAwakePlatform();
      final service = ScreenAwakeService(platform: platform);
      final first = service.createLease();
      final second = service.createLease();

      await first.acquire();
      await first.acquire();
      await second.acquire();

      expect(platform.states, <bool>[true]);
      expect(first.isActive, isTrue);
      expect(second.isActive, isTrue);

      await first.release();
      await first.release();
      expect(platform.states, <bool>[true]);

      await second.release();
      expect(platform.states, <bool>[true, false]);
    },
  );

  test(
    'a new route lease prevents an old route from disabling the screen',
    () async {
      final platform = _FakeScreenAwakePlatform();
      final service = ScreenAwakeService(platform: platform);
      final previousRoute = service.createLease();
      final replacementRoute = service.createLease();

      await previousRoute.acquire();
      await replacementRoute.acquire();
      await previousRoute.release();

      expect(platform.states, <bool>[true]);

      await replacementRoute.release();
      expect(platform.states, <bool>[true, false]);
    },
  );

  test('platform failures do not escape into the assessment flow', () async {
    final platform = _FakeScreenAwakePlatform(throwOnCall: true);
    final service = ScreenAwakeService(platform: platform);
    final lease = service.createLease();

    await expectLater(lease.acquire(), completes);
    await expectLater(lease.release(), completes);
  });
}

class _FakeScreenAwakePlatform implements ScreenAwakePlatform {
  _FakeScreenAwakePlatform({this.throwOnCall = false});

  final bool throwOnCall;
  final List<bool> states = <bool>[];

  @override
  Future<void> setEnabled(bool enabled) async {
    states.add(enabled);
    if (throwOnCall) throw StateError('wakelock unavailable');
  }
}
