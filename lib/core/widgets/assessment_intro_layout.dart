import 'package:balance_detect/core/theme/app_theme.dart';
import 'package:balance_detect/core/widgets/app_scaffold_body.dart';
import 'package:flutter/material.dart';

class AssessmentIntroLayout extends StatelessWidget {
  const AssessmentIntroLayout({
    required this.title,
    required this.standardName,
    required this.subtitle,
    required this.instructions,
    required this.illustration,
    required this.buttonLabel,
    required this.onContinue,
    super.key,
    this.notice,
    this.additionalContent,
  });

  final String title;
  final String standardName;
  final String subtitle;
  final List<String> instructions;
  final Widget illustration;
  final String buttonLabel;
  final VoidCallback onContinue;
  final String? notice;
  final Widget? additionalContent;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('วิธีเตรียมตัว')),
    body: AppScaffoldBody(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AssessmentHeading(
            title: title,
            standardName: standardName,
            subtitle: subtitle,
          ),
          if (additionalContent != null) ...[
            const SizedBox(height: 20),
            additionalContent!,
          ],
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Center(child: illustration),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  'ขั้นตอนเตรียมตัว',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${instructions.length} ขั้นตอน',
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: AppColors.outline),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InstructionList(instructions: instructions),
          if (notice != null) ...[
            const SizedBox(height: 16),
            _SafetyNotice(message: notice!),
          ],
        ],
      ),
    ),
    bottomNavigationBar: DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          12 + MediaQuery.paddingOf(context).bottom,
        ),
        child: FilledButton.icon(
          onPressed: onContinue,
          iconAlignment: IconAlignment.end,
          icon: const Icon(Icons.arrow_forward_rounded),
          label: Text(buttonLabel),
        ),
      ),
    ),
  );
}

class _AssessmentHeading extends StatelessWidget {
  const _AssessmentHeading({
    required this.title,
    required this.standardName,
    required this.subtitle,
  });

  final String title;
  final String standardName;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.assignment_outlined,
              size: 17,
              color: AppColors.primaryDark,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                standardName,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: AppColors.primaryDark),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Text(title, style: Theme.of(context).textTheme.headlineLarge),
      const SizedBox(height: 6),
      Text(
        subtitle,
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(color: AppColors.outline),
      ),
    ],
  );
}

class _InstructionList extends StatelessWidget {
  const _InstructionList({required this.instructions});

  final List<String> instructions;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      children: instructions.indexed
          .map((entry) {
            final isLast = entry.$1 == instructions.length - 1;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          '${entry.$1 + 1}',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: AppColors.primaryDark),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          entry.$2,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  const Padding(
                    padding: EdgeInsets.only(left: 58),
                    child: Divider(),
                  ),
              ],
            );
          })
          .toList(growable: false),
    ),
  );
}

class _SafetyNotice extends StatelessWidget {
  const _SafetyNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.warningContainer,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.warning.withValues(alpha: .28)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.health_and_safety_outlined, color: AppColors.warning),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ความปลอดภัย',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: AppColors.warning),
              ),
              const SizedBox(height: 4),
              Text(message),
            ],
          ),
        ),
      ],
    ),
  );
}
