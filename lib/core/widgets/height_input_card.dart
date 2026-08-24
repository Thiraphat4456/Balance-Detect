import 'package:balance_detect/core/constants/assessment_config.dart';
import 'package:balance_detect/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class HeightInputCard extends StatelessWidget {
  const HeightInputCard({
    required this.controller,
    required this.onChanged,
    super.key,
    this.errorText,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.primaryContainer.withValues(alpha: .45),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.primary.withValues(alpha: .25)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.height_outlined, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'กรอกส่วนสูงก่อนเริ่ม',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'ระบบจะใช้ส่วนสูงช่วยคำนวณสเกลจากท่าทางของคุณ ไม่ต้องใช้วัตถุอ้างอิงในขั้นแรก',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: 'ส่วนสูงผู้ทดสอบ',
            hintText: 'เช่น 165',
            suffixText: 'ซม.',
            prefixIcon: const Icon(Icons.person_outline),
            errorText: errorText,
            helperText:
                '${AssessmentConfig.anthropometricMinHeightCm.toStringAsFixed(0)}–${AssessmentConfig.anthropometricMaxHeightCm.toStringAsFixed(0)} ซม.',
          ),
        ),
      ],
    ),
  );
}
