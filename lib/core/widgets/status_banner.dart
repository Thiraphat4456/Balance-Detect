import 'package:balance_detect/core/domain/assessment_enums.dart';
import 'package:balance_detect/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class StatusBanner extends StatelessWidget {
  const StatusBanner({
    required this.status,
    required this.label,
    super.key,
    this.detail,
  });

  final AssessmentStatus status;
  final String label;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final (foreground, background, icon) = switch (status) {
      AssessmentStatus.normal => (
        AppColors.normal,
        AppColors.normalContainer,
        Icons.check_circle_outline,
      ),
      AssessmentStatus.warning => (
        AppColors.warning,
        AppColors.warningContainer,
        Icons.warning_amber_rounded,
      ),
      AssessmentStatus.risk || AssessmentStatus.invalid => (
        AppColors.risk,
        AppColors.riskContainer,
        Icons.error_outline,
      ),
    };
    return Semantics(
      liveRegion: true,
      label: '$label${detail == null ? '' : ' $detail'}',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: foreground, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (detail != null) ...[
                    const SizedBox(height: 3),
                    Text(detail!, style: TextStyle(color: foreground)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
