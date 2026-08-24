import 'package:balance_detect/core/constants/assessment_config.dart';
import 'package:balance_detect/core/domain/assessment_enums.dart';
import 'package:balance_detect/core/providers/app_providers.dart';
import 'package:balance_detect/core/utils/date_time_format.dart';
import 'package:balance_detect/core/widgets/app_scaffold_body.dart';
import 'package:balance_detect/core/widgets/loading_view.dart';
import 'package:balance_detect/core/widgets/status_banner.dart';
import 'package:balance_detect/features/assessment/domain/assessment_session.dart';
import 'package:balance_detect/features/assessment/domain/session_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HistoryDetailScreen extends ConsumerWidget {
  const HistoryDetailScreen({required this.sessionId, super.key});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('รายละเอียดผล')),
    body: FutureBuilder<AssessmentSession?>(
      future: ref.read(assessmentRepositoryProvider).getSession(sessionId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingView(label: 'กำลังโหลดรายละเอียด');
        }
        final session = snapshot.data;
        if (snapshot.hasError || session == null) {
          return const Center(child: Text('ไม่พบผลการประเมินนี้'));
        }
        return AppScaffoldBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'สรุปผลการประเมิน',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(DateTimeFormat.thaiShort(session.timestamp)),
              const SizedBox(height: 22),
              if (session.functionalReach != null) ...[
                _ResultCard(
                  title: 'Functional Reach Test',
                  value:
                      '${session.functionalReach!.distanceInch.toStringAsFixed(1)} นิ้ว',
                  detail: session.functionalReach!.valid
                      ? session.functionalReach!.distanceInch <
                                AssessmentConfig.functionalReachThresholdInches
                            ? 'ต่ำกว่าเกณฑ์ ${AssessmentConfig.functionalReachThresholdInches.toStringAsFixed(0)} นิ้ว'
                            : 'ถึงเกณฑ์ ${AssessmentConfig.functionalReachThresholdInches.toStringAsFixed(0)} นิ้ว'
                      : 'พบการขยับเท้า — ผลไม่สมบูรณ์',
                ),
                const SizedBox(height: 14),
              ],
              if (session.fullerton != null) ...[
                _ResultCard(
                  title: 'Fullerton Advanced Balance Scale',
                  value: '${session.fullerton!.score} / 4 คะแนน',
                  detail:
                      'ตรวจพบ ${session.fullerton!.stepCount} ก้าว'
                      '${session.fullerton!.supervisionRequired == true ? ' และต้องมีผู้ดูแล' : ''}',
                ),
                const SizedBox(height: 14),
              ],
              if (session.tug != null) ...[
                _ResultCard(
                  title: 'Timed Up and Go (TUG)',
                  value:
                      '${session.tug!.totalSeconds.toStringAsFixed(1)} วินาที',
                  detail: session.tug!.riskStatus == AssessmentStatus.risk
                      ? 'มากกว่าเกณฑ์ ${AssessmentConfig.tugRiskThresholdSeconds.toStringAsFixed(1)} วินาที'
                      : 'ไม่เกินเกณฑ์ ${AssessmentConfig.tugRiskThresholdSeconds.toStringAsFixed(1)} วินาที',
                ),
                const SizedBox(height: 14),
                if (session.tug!.standDuration != null)
                  _PhaseBreakdown(session: session),
              ],
              const SizedBox(height: 20),
              StatusBanner(
                status: SessionSummary.status(session),
                label: SessionSummary.label(session),
                detail:
                    SessionSummary.status(session) == AssessmentStatus.normal
                    ? 'ผลนี้เป็นการคัดกรองเบื้องต้น'
                    : 'ควรได้รับการประเมินเพิ่มเติมจากผู้เชี่ยวชาญ',
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.title,
    required this.value,
    required this.detail,
  });

  final String title;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Text(value, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 5),
          Text(detail),
        ],
      ),
    ),
  );
}

class _PhaseBreakdown extends StatelessWidget {
  const _PhaseBreakdown({required this.session});

  final AssessmentSession session;

  @override
  Widget build(BuildContext context) {
    final tug = session.tug!;
    final phases = <(String, double?)>[
      ('ลุกขึ้น', tug.standDuration),
      ('เดินไป', tug.outboundWalkDuration),
      ('หมุนตัว', tug.turnDuration),
      ('เดินกลับ', tug.returnWalkDuration),
      ('นั่งลง', tug.sitDuration),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ช่วงการเคลื่อนไหว',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final phase in phases)
              if (phase.$2 != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(phase.$1)),
                      Text('${phase.$2!.toStringAsFixed(1)} วินาที'),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
