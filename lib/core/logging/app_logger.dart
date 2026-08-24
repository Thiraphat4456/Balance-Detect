import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

abstract final class AppLogger {
  static void event(String name, [Map<String, Object?> fields = const {}]) {
    final payload = jsonEncode(<String, Object?>{
      'event': name,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      ...fields,
    });
    developer.log(
      payload,
      name: 'balance_detect',
    );
    if (kDebugMode) debugPrint('[BD_EVENT] $payload');
  }

  static void error(String name, Object error) {
    event(name, <String, Object?>{'errorType': error.runtimeType.toString()});
  }
}
