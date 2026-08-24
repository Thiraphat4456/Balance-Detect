import 'dart:math';

abstract final class IdGenerator {
  static final Random _random = Random.secure();

  static String generate(String prefix) {
    final now = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final suffix = _random.nextInt(0x7fffffff).toRadixString(36);
    return '${prefix}_${now}_$suffix';
  }
}
