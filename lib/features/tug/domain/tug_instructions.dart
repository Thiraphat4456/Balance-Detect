import 'package:balance_detect/core/domain/assessment_enums.dart';

/// Centralized Thai instructions for the hands-free TUG workflow.
///
/// Keeping screen text and spoken prompts together prevents the visible flow
/// from drifting away from what a participant hears while the phone is fixed
/// at their waist.
abstract final class TugInstructions {
  static const sensorReady =
      'เซนเซอร์พร้อม คาดโทรศัพท์ให้แน่นบริเวณเอว นั่งชิดพนักเก้าอี้ '
      'แล้วกดปรับเทียบหนึ่งครั้ง หลังจากนั้นระบบจะเริ่มให้อัตโนมัติ';

  static const calibration =
      'เริ่มปรับเทียบ กรุณานั่งชิดพนัก วางเท้าบนพื้น และอยู่นิ่งสามวินาที';

  static const calibrated =
      'ปรับเทียบสำเร็จ เตรียมลุกจากเก้าอี้ เดินตรงไปยังเครื่องหมายสามเมตร '
      'หมุนตัว เดินกลับ และนั่งลง ระบบจะเริ่มนับถอยหลังอัตโนมัติ';

  static const start = 'เริ่ม ลุกจากเก้าอี้ แล้วเดินไปยังเครื่องหมายสามเมตร';

  static const automaticStartDetail =
      'ไม่ต้องกดปุ่มเพิ่ม ระบบกำลังอธิบายและจะนับถอยหลังให้อัตโนมัติ';

  static const preCountdownDelay = Duration(seconds: 7);

  static const completed = 'ทดสอบเสร็จสิ้น กรุณานั่งพัก';

  static const phasePrompts = <TugState, String>{
    TugState.sitting: start,
    TugState.standingUp: 'ตรวจพบการลุก เดินต่อไปยังเครื่องหมายสามเมตร',
    TugState.walkingOut: 'เดินต่อไป เมื่อถึงเครื่องหมายสามเมตรให้หมุนตัวกลับ',
    TugState.turning: 'ตรวจพบการหมุนตัว หมุนให้ครบแล้วเดินกลับไปที่เก้าอี้',
    TugState.walkingBack: 'เดินกลับไปที่เก้าอี้ แล้วหันตัวเตรียมนั่งลง',
    TugState.sittingDown: 'กำลังนั่งลง กรุณานั่งให้มั่นคง',
    TugState.completed: completed,
  };

  static String? promptForState(TugState state) => phasePrompts[state];

  static String countdownWord(int seconds) => switch (seconds) {
    3 => 'สาม',
    2 => 'สอง',
    1 => 'หนึ่ง',
    _ => '$seconds',
  };

  static String result({required double seconds, required bool overThreshold}) {
    final duration = seconds.toStringAsFixed(1);
    return overThreshold
        ? 'ทดสอบเสร็จสิ้น ใช้เวลา $duration วินาที มากกว่าเกณฑ์คัดกรอง '
              'กรุณานั่งพักและดูรายละเอียดบนหน้าจอ'
        : 'ทดสอบเสร็จสิ้น ใช้เวลา $duration วินาที ไม่เกินเกณฑ์คัดกรอง '
              'กรุณานั่งพัก';
  }
}
