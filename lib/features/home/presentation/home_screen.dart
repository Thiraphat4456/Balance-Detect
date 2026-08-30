import 'package:balance_detect/core/theme/app_theme.dart';
import 'package:balance_detect/core/widgets/app_scaffold_body.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: AppScaffoldBody(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _BrandHeader(),
          const SizedBox(height: 28),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  'เลือกแบบประเมิน',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceStrong,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '3 รายการ',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'เลือกหนึ่งรายการ ระบบจะแนะนำการเตรียมตัวและตรวจความพร้อมให้ทีละขั้น',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.outline),
          ),
          const SizedBox(height: 20),
          _AssessmentCard(
            title: 'วัดระยะเอื้อม',
            standardName: 'Functional Reach Test',
            description: 'วัดระยะเอื้อมไปข้างหน้าโดยไม่ขยับเท้า',
            typeLabel: 'ใช้กล้อง',
            setupItems: const <_SetupItem>[
              _SetupItem(Icons.camera_front_outlined, 'กล้องหน้า'),
              _SetupItem(Icons.accessibility_new_rounded, 'เห็นเต็มตัว'),
            ],
            icon: Icons.accessibility_new_rounded,
            onTap: () => context.push('/functional-reach'),
          ),
          const SizedBox(height: 12),
          _AssessmentCard(
            title: 'ทดสอบเอื้อมหยิบ',
            standardName: 'Fullerton Advanced Balance',
            description: 'ประเมินการเอื้อมหยิบและตรวจการก้าวเท้า',
            typeLabel: 'ใช้กล้อง',
            setupItems: const <_SetupItem>[
              _SetupItem(Icons.camera_front_outlined, 'กล้องหน้า'),
              _SetupItem(Icons.inventory_2_outlined, 'เตรียมของหยิบ'),
            ],
            icon: Icons.directions_walk_rounded,
            onTap: () => context.push('/fullerton'),
          ),
          const SizedBox(height: 12),
          _AssessmentCard(
            title: 'ทดสอบลุก–เดิน–นั่ง',
            standardName: 'Timed Up and Go (TUG)',
            description: 'จับเวลาลุก เดิน 3 เมตร หมุนตัว และกลับมานั่ง',
            typeLabel: 'ใช้เซนเซอร์',
            setupItems: const <_SetupItem>[
              _SetupItem(Icons.phone_android_rounded, 'คาดมือถือที่เอว'),
              _SetupItem(Icons.chair_outlined, 'เตรียมเก้าอี้'),
            ],
            icon: Icons.sensors_rounded,
            onTap: () => context.push('/tug'),
          ),
          const SizedBox(height: 28),
          Text('ผลการประเมิน', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _SummaryCard(onTap: () => context.push('/summary')),
          const SizedBox(height: 16),
          const _ClinicalNotice(),
        ],
      ),
    ),
  );
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(
          Icons.monitor_heart_outlined,
          color: AppColors.surface,
          semanticLabel: 'Balance Detect',
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Balance Detect',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              'คัดกรองการทรงตัวเบื้องต้น',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.outline),
            ),
          ],
        ),
      ),
      const SizedBox(width: 12),
      const Icon(
        Icons.verified_user_outlined,
        color: AppColors.primary,
        semanticLabel: 'เครื่องมือคัดกรองสุขภาพ',
      ),
    ],
  );
}

class _AssessmentCard extends StatelessWidget {
  const _AssessmentCard({
    required this.title,
    required this.standardName,
    required this.description,
    required this.typeLabel,
    required this.setupItems,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String standardName;
  final String description;
  final String typeLabel;
  final List<_SetupItem> setupItems;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label:
        '$title $standardName $description $typeLabel '
        '${setupItems.map((item) => item.label).join(' ')}',
    child: Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: AppColors.primaryDark, size: 27),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          standardName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 19,
                    color: AppColors.outline,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(description, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoTag(
                    icon: Icons.medical_information_outlined,
                    label: typeLabel,
                    emphasized: true,
                  ),
                  ...setupItems.map(
                    (item) => _InfoTag(icon: item.icon, label: item.label),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _SetupItem {
  const _SetupItem(this.icon, this.label);

  final IconData icon;
  final String label;
}

class _InfoTag extends StatelessWidget {
  const _InfoTag({
    required this.icon,
    required this.label,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: emphasized ? AppColors.primaryContainer : AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: emphasized ? AppColors.primaryDark : AppColors.outline,
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: emphasized ? AppColors.primaryDark : AppColors.outline,
          ),
        ),
      ],
    ),
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.insert_chart_outlined_rounded,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'สรุปผลล่าสุด',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    'ดูผลและสถานะจากทุกแบบประเมิน',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 19,
              color: AppColors.outline,
            ),
          ],
        ),
      ),
    ),
  );
}

class _ClinicalNotice extends StatelessWidget {
  const _ClinicalNotice();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, color: AppColors.primary, size: 21),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'ใช้สำหรับคัดกรองเบื้องต้น ไม่ทดแทนการวินิจฉัยโดยบุคลากรทางการแพทย์',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    ),
  );
}
