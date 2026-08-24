import 'package:balance_detect/core/widgets/assessment_intro_layout.dart';
import 'package:balance_detect/core/widgets/body_illustrations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class FullertonIntroScreen extends StatelessWidget {
  const FullertonIntroScreen({super.key});

  @override
  Widget build(BuildContext context) => AssessmentIntroLayout(
    title: 'ทดสอบเอื้อมหยิบ',
    standardName: 'Fullerton Advanced Balance Scale',
    subtitle: 'ประเมินการเอื้อมหยิบ พร้อมตรวจว่ามีการก้าวหรือไม่',
    illustration: const SideReachIllustration(),
    instructions: const <String>[
      'วางของที่จะหยิบไว้ด้านหน้า ในระยะที่เอื้อมถึงอย่างปลอดภัย',
      'ตั้งมือถือให้กล้องหน้าเห็นร่างกายและเท้าทั้งสองข้างครบ',
      'ยืนตามตำแหน่ง แล้วเตรียมเอื้อมหยิบ ระบบจะนับถอยหลังและเริ่มเอง',
    ],
    notice:
        'ผู้ประเมินควรยืนใกล้เพื่อช่วยพยุงได้ทันที หากเสียการทรงตัวให้หยุดทดสอบ',
    buttonLabel: 'จัดตำแหน่งกล้อง',
    onContinue: () => context.push('/fullerton/test'),
  );
}
