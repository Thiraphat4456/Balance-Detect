import 'package:balance_detect/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class ChecklistTile extends StatelessWidget {
  const ChecklistTile({
    required this.label,
    required this.passed,
    super.key,
    this.pending = false,
  });

  final String label;
  final bool passed;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final icon = pending
        ? Icons.hourglass_top_rounded
        : passed
        ? Icons.check_circle
        : Icons.radio_button_unchecked_rounded;
    final color = pending
        ? AppColors.outline
        : passed
        ? AppColors.normal
        : AppColors.warning;
    final stateLabel = pending
        ? 'กำลังตรวจ'
        : passed
        ? 'พร้อม'
        : 'ยังไม่พร้อม';
    return Semantics(
      label: '$label $stateLabel',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Icon(icon, color: color, size: 25),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
            ),
            const SizedBox(width: 8),
            Text(
              stateLabel,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PreparationItem extends StatelessWidget {
  const PreparationItem({required this.label, required this.icon, super.key});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: 25),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
        ),
        const SizedBox(width: 8),
        Text(
          'ตรวจด้วยตนเอง',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.outline,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
