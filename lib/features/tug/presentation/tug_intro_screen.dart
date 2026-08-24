import 'package:balance_detect/core/widgets/assessment_intro_layout.dart';
import 'package:balance_detect/core/widgets/body_illustrations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class TugIntroScreen extends StatelessWidget {
  const TugIntroScreen({super.key});

  @override
  Widget build(BuildContext context) => AssessmentIntroLayout(
    title: 'ทดสอบลุก–เดิน–นั่ง',
    standardName: 'Timed Up and Go (TUG)',
    subtitle: 'จับเวลาลุก เดิน 3 เมตร หมุนตัว แล้วกลับมานั่ง',
    illustration: const WaistPhoneIllustration(),
    instructions: const <String>[
      'คาดโทรศัพท์ให้แน่นบริเวณเอว และอย่าเปลี่ยนแนวระหว่างทดสอบ',
      'จัดเก้าอี้มั่นคงและทำเครื่องหมายระยะเดิน 3 เมตร',
      'เริ่มจากท่านั่ง ลุก เดิน หมุนตัว เดินกลับ และนั่งลงตามปกติ',
    ],
    notice:
        'ควรมีผู้ดูแลอยู่ใกล้ตลอด หากไม่ปลอดภัยให้กด “หยุดการทดสอบ” ได้ทันที',
    buttonLabel: 'ตรวจสอบเซนเซอร์',
    onContinue: () => context.push('/tug/test'),
  );
}
