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
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.height_outlined,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ส่วนสูงผู้ทดสอบ',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    'ใช้ช่วยคำนวณระยะจากภาพ',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                'จำเป็น',
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: AppColors.primaryDark),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: 'กรอกส่วนสูง',
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
