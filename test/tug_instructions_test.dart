import 'package:balance_detect/core/domain/assessment_enums.dart';
import 'package:balance_detect/features/tug/domain/tug_instructions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TUG provides a spoken cue for every active movement phase', () {
    const activePhases = <TugState>[
      TugState.sitting,
      TugState.standingUp,
      TugState.walkingOut,
      TugState.turning,
      TugState.walkingBack,
      TugState.sittingDown,
      TugState.completed,
    ];

    for (final phase in activePhases) {
      expect(
        TugInstructions.promptForState(phase),
        isNotEmpty,
        reason: 'Missing spoken prompt for ${phase.name}',
      );
    }
  });

  test('TUG countdown uses short Thai speech cues', () {
    expect(TugInstructions.countdownWord(3), 'สาม');
    expect(TugInstructions.countdownWord(2), 'สอง');
    expect(TugInstructions.countdownWord(1), 'หนึ่ง');
  });

  test('TUG result speech includes measured time and threshold status', () {
    expect(
      TugInstructions.result(seconds: 12.4, overThreshold: false),
      allOf(contains('12.4'), contains('ไม่เกินเกณฑ์คัดกรอง')),
    );
    expect(
      TugInstructions.result(seconds: 15.8, overThreshold: true),
      allOf(contains('15.8'), contains('มากกว่าเกณฑ์คัดกรอง')),
    );
  });

  test('TUG ready prompt explains the hands-free start', () {
    expect(TugInstructions.sensorReady, contains('กดปรับเทียบหนึ่งครั้ง'));
    expect(
      TugInstructions.automaticStartDetail,
      contains('ไม่ต้องกดปุ่มเพิ่ม'),
    );
  });
}
