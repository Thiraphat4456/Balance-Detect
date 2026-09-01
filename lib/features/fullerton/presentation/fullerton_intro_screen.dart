import 'package:balance_detect/core/constants/assessment_config.dart';
import 'package:balance_detect/core/theme/app_theme.dart';
import 'package:balance_detect/core/widgets/assessment_intro_layout.dart';
import 'package:balance_detect/core/widgets/body_illustrations.dart';
import 'package:balance_detect/core/widgets/height_input_card.dart';
import 'package:balance_detect/features/fullerton/domain/fullerton_reach_calibration_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class FullertonIntroScreen extends StatefulWidget {
  const FullertonIntroScreen({super.key});

  @override
  State<FullertonIntroScreen> createState() => _FullertonIntroScreenState();
}

class _FullertonIntroScreenState extends State<FullertonIntroScreen> {
  final _heightController = TextEditingController();
  String? _heightError;

  // The requested 1-foot target stays available and is selected initially,
  // but the UI explicitly identifies it as a modified, experimental item.
  FullertonProtocolVariant _protocolVariant = FullertonProtocolVariant.oneFoot;

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
      '/fullerton/test?height=${heightCm.toStringAsFixed(1)}&protocol=${_protocolVariant.queryValue}',
      extra: heightCm,
    );
  }

  @override
  Widget build(BuildContext context) => AssessmentIntroLayout(
    title: 'เอื้อมหยิบวัตถุ',
    standardName: 'Fullerton Advanced Balance Scale — Item 2',
    subtitle: 'คาลิเบรตตำแหน่งเท้า ปลายนิ้ว และเป้าหมายเสมือนก่อนเริ่ม',
    additionalContent: Column(
      children: [
        HeightInputCard(
          controller: _heightController,
          errorText: _heightError,
          onChanged: (_) {
            if (_heightError != null) setState(() => _heightError = null);
          },
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.straighten_outlined,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'ระยะเป้าหมาย',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _protocolVariant == FullertonProtocolVariant.oneFoot,
                  title: const Text('ใช้ระยะ 1 ฟุตตามที่กำหนด'),
                  subtitle: Text(
                    _protocolVariant == FullertonProtocolVariant.oneFoot
                        ? '30.48 ซม. — แบบทดลอง ไม่ใช่ระยะมาตรฐาน FAB'
                        : '25.4 ซม. — ระยะมาตรฐาน FAB 10 นิ้ว',
                  ),
                  onChanged: (enabled) => setState(
                    () => _protocolVariant = enabled
                        ? FullertonProtocolVariant.oneFoot
                        : FullertonProtocolVariant.standardTenInches,
                  ),
                ),
                if (_protocolVariant == FullertonProtocolVariant.oneFoot)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warningContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'คู่มือ FAB ใช้ไม้บรรทัด 12 นิ้วเป็นอุปกรณ์ แต่ระยะดินสอจริงคือ 10 นิ้ว การเปิด 1 ฟุตจึงเป็น Modified FAB',
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
    illustration: const SideReachIllustration(),
    instructions: const <String>[
      'ตั้งมือถือด้านข้างให้กล้องหน้าเห็นทั้งตัว ปลายนิ้ว และเท้าทั้งสองข้าง',
      'ยืนในฐานเท้าปกติ ระบบจะจำตำแหน่งเท้าเอง ไม่ต้องวางตามวงตายตัว',
      'ยกแขนข้างเดียวที่หันเข้ากล้องให้ตั้งฉากกับลำตัว เหยียดข้อศอกและนิ้ว',
      'ระบบจะตรึงเป้าหมายเสมือนไว้ด้านหน้าปลายนิ้ว แล้วนับถอยหลังเริ่มเอง',
    ],
    notice:
        'ควรมีผู้ดูแลยืนด้านข้างเพื่อป้องกันการล้ม เป้าหมายบนจอเป็นการประมาณจากกล้องหน้าและส่วนสูง ไม่ใช่ AR ระยะโลกหรือเครื่องมือแพทย์ที่ผ่านการรับรอง',
    buttonLabel: 'จัดตำแหน่งและคาลิเบรต',
    onContinue: _continue,
  );
}
