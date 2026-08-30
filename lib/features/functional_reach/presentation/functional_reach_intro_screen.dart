import 'package:balance_detect/core/constants/assessment_config.dart';
import 'package:balance_detect/core/widgets/assessment_intro_layout.dart';
import 'package:balance_detect/core/widgets/body_illustrations.dart';
import 'package:balance_detect/core/widgets/height_input_card.dart';
import 'package:balance_detect/features/functional_reach/domain/functional_reach_instructions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class FunctionalReachIntroScreen extends StatefulWidget {
  const FunctionalReachIntroScreen({super.key});

  @override
  State<FunctionalReachIntroScreen> createState() =>
      _FunctionalReachIntroScreenState();
}

class _FunctionalReachIntroScreenState
    extends State<FunctionalReachIntroScreen> {
  final _heightController = TextEditingController();
  String? _heightError;

  @override
  void dispose() {
    _heightController.dispose();
    super.dispose();
  }

  void _continue() {
    final heightCm = double.tryParse(_heightController.text.trim());
    if (heightCm == null ||
        heightCm < AssessmentConfig.anthropometricMinHeightCm ||
        heightCm > AssessmentConfig.anthropometricMaxHeightCm) {
      setState(
        () => _heightError =
            'กรุณากรอกส่วนสูง ${AssessmentConfig.anthropometricMinHeightCm.toStringAsFixed(0)}–${AssessmentConfig.anthropometricMaxHeightCm.toStringAsFixed(0)} ซม.',
      );
      return;
    }
    FocusScope.of(context).unfocus();
    context.push(
      '/functional-reach/test?height=${heightCm.toStringAsFixed(1)}',
      extra: heightCm,
    );
  }

  @override
  Widget build(BuildContext context) => AssessmentIntroLayout(
    title: 'วัดระยะเอื้อม',
    standardName: 'Functional Reach Test',
    subtitle: 'วัดระยะที่เอื้อมไปข้างหน้าได้ โดยไม่ขยับเท้า',
    additionalContent: HeightInputCard(
      controller: _heightController,
      errorText: _heightError,
      onChanged: (_) {
        if (_heightError != null) setState(() => _heightError = null);
      },
    ),
    illustration: const SideReachIllustration(),
    instructions: const <String>[
      'ตั้งมือถือให้มั่นคง แล้วตรวจว่ากล้องหน้าเห็นร่างกายเต็มตัว',
      FunctionalReachInstructions.introSetup,
      'เอื้อมไปข้างหน้าให้ไกลที่สุด โดยไม่ก้าวหรือขยับเท้า',
    ],
    notice:
        'ควรมีผู้ดูแลยืนใกล้ตลอดการทดสอบ ระบบจะใช้ส่วนสูงคำนวณสเกลเบื้องต้น และจะเริ่มเมื่อเห็นท่าทางครบ',
    buttonLabel: 'จัดตำแหน่งกล้อง',
    onContinue: _continue,
  );
}
