import 'dart:async';

import 'package:balance_detect/core/logging/app_logger.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

abstract interface class ScreenAwakePlatform {
  Future<void> setEnabled(bool enabled);
}

class WakelockPlusScreenAwakePlatform implements ScreenAwakePlatform {
  @override
  Future<void> setEnabled(bool enabled) => WakelockPlus.toggle(enable: enabled);
}

/// Coordinates screen-awake ownership across assessment routes.
///
/// A lease avoids a route-transition race where the replacement assessment
/// enables the wakelock before the previous assessment disposes and disables
/// it. The platform state changes only when the first owner arrives or the last
/// owner leaves.
class ScreenAwakeService {
  ScreenAwakeService({ScreenAwakePlatform? platform})
    : _platform = platform ?? WakelockPlusScreenAwakePlatform();

  static final ScreenAwakeService instance = ScreenAwakeService();

  final ScreenAwakePlatform _platform;
  final Set<Object> _owners = <Object>{};
  Future<void> _pending = Future<void>.value();
  bool? _appliedState;

  ScreenAwakeLease createLease() => ScreenAwakeLease._(this);

  Future<void> _setOwner(Object owner, {required bool active}) {
    final changed = active ? _owners.add(owner) : _owners.remove(owner);
    if (!changed && _appliedState == _owners.isNotEmpty) return _pending;

    _pending = _pending.then((_) => _synchronize());
    return _pending;
  }

  Future<void> _synchronize() async {
    final shouldEnable = _owners.isNotEmpty;
    if (_appliedState == shouldEnable) return;
    try {
      await _platform.setEnabled(shouldEnable);
      _appliedState = shouldEnable;
      AppLogger.event(
        shouldEnable ? 'screen_awake_enabled' : 'screen_awake_disabled',
      );
    } catch (error) {
      AppLogger.error('screen_awake_toggle_failed', error);
    }
  }
}

class ScreenAwakeLease {
  ScreenAwakeLease._(this._service);

  final ScreenAwakeService _service;
  final Object _owner = Object();
  bool _active = false;

  bool get isActive => _active;

  Future<void> acquire() {
    _active = true;
    return _service._setOwner(_owner, active: true);
  }

  Future<void> release() {
    _active = false;
    return _service._setOwner(_owner, active: false);
  }
}
