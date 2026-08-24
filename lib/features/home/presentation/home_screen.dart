import 'package:balance_detect/core/theme/app_theme.dart';
import 'package:balance_detect/core/widgets/app_scaffold_body.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: AppScaffoldBody(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.balance,
                  color: Colors.white,
                  semanticLabel: 'Balance Detect',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Balance Detect',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          Text(
            'เลือกแบบประเมิน',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'ระบบจะบอกวิธีเตรียมตัวและตรวจความพร้อมให้ทีละขั้น',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppColors.outline),
          ),
          const SizedBox(height: 24),
          _AssessmentCard(
            title: 'วัดระยะเอื้อม',
            standardName: 'Functional Reach',
            description: 'ยืนด้านข้าง แล้วยื่นแขนไปข้างหน้าให้ไกลที่สุด',
            setup: 'กล้องหน้า • เห็นร่างกายเต็มตัว',
            icon: Icons.accessibility_new_rounded,
            onTap: () => context.push('/functional-reach'),
          ),
          const SizedBox(height: 16),
          _AssessmentCard(
            title: 'ทดสอบเอื้อมหยิบ',
            standardName: 'Fullerton Balance',
            description: 'ประเมินการเอื้อมหยิบ พร้อมตรวจว่ามีการก้าวหรือไม่',
            setup: 'กล้องหน้า • เตรียมของที่จะหยิบ',
            icon: Icons.directions_walk_rounded,
            onTap: () => context.push('/fullerton'),
          ),
          const SizedBox(height: 16),
          _AssessmentCard(
            title: 'ทดสอบลุก–เดิน–นั่ง',
            standardName: 'Timed Up and Go (TUG)',
            description: 'จับเวลาลุก เดิน 3 เมตร หมุนตัว และกลับมานั่ง',
            setup: 'คาดมือถือที่เอว • เตรียมเก้าอี้',
            icon: Icons.sensors_rounded,
            onTap: () => context.push('/tug'),
          ),
          const SizedBox(height: 28),
          Text('ผลการประเมิน', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => context.push('/summary'),
            icon: const Icon(Icons.summarize_outlined),
            label: const Text('ดูสรุปผลล่าสุด'),
          ),
          const SizedBox(height: 16),
          Card(
            color: AppColors.surfaceMuted,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'แอปนี้เป็นเครื่องมือคัดกรองเบื้องต้น ไม่ใช่เครื่องมือวินิจฉัยโรค',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _AssessmentCard extends StatelessWidget {
  const _AssessmentCard({
    required this.title,
    required this.standardName,
    required this.description,
    required this.setup,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String standardName;
  final String description;
  final String setup;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$title $standardName $description $setup',
    child: Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: AppColors.primary, size: 30),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      standardName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.outline,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(description),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.checklist_rounded,
                          size: 20,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            setup,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Align(
                alignment: Alignment.center,
                child: Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
