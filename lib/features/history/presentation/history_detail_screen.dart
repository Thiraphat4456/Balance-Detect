import 'package:balance_detect/core/constants/assessment_config.dart';
import 'package:balance_detect/core/domain/assessment_enums.dart';
import 'package:balance_detect/core/providers/app_providers.dart';
import 'package:balance_detect/core/utils/date_time_format.dart';
import 'package:balance_detect/core/widgets/app_scaffold_body.dart';
import 'package:balance_detect/core/widgets/loading_view.dart';
import 'package:balance_detect/core/widgets/status_banner.dart';
import 'package:balance_detect/features/assessment/domain/assessment_session.dart';
import 'package:balance_detect/features/assessment/domain/session_summary.dart';
import 'package:balance_detect/features/fullerton/domain/fullerton_reach_calibration_service.dart';
import 'package:balance_detect/features/tug/domain/sensor_models.dart';
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
        final fullerton = session.fullerton;
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
              if (fullerton != null) ...[
                _ResultCard(
                  title: fullerton.protocolVariant.isStandard
                      ? 'Fullerton Advanced Balance Scale — Item 2'
                      : fullerton.protocolVariant.isExperimental
                      ? 'Modified Fullerton — แบบทดลอง 1 ฟุต'
                      : 'Fullerton — ผลเดิมไม่ระบุโปรโตคอล',
                  value: '${fullerton.score} / 4 คะแนน',
                  detail:
                      'ตรวจพบ ${fullerton.stepCount} ก้าว'
                      '${fullerton.supervisionRequired == true ? ' และต้องมีผู้ควบคุมใกล้ชิด' : ''}'
                      '${fullerton.targetDistanceCm == null ? '' : ' · เป้าหมาย ${fullerton.targetDistanceCm!.toStringAsFixed(1)} ซม.'}'
                      '${fullerton.heightCm == null ? '' : ' · ส่วนสูง ${fullerton.heightCm!.toStringAsFixed(0)} ซม.'}'
                      '${fullerton.protocolVariant.isStandard ? '' : ' · ไม่ใช้เทียบเกณฑ์ FAB มาตรฐานโดยตรง'}',
                ),
                const SizedBox(height: 14),
              ],
              if (session.tug != null) ...[
                _ResultCard(
                  title:
                      session.tug!.measurementMode ==
                          TugMeasurementMode.accelerometerOnly
                      ? 'Timed Up and Go — Accelerometer-only'
                      : 'Timed Up and Go (TUG)',
                  value:
                      '${session.tug!.totalSeconds.toStringAsFixed(1)} วินาที',
                  detail:
                      '${session.tug!.riskStatus == AssessmentStatus.risk ? 'มากกว่า' : 'ไม่เกิน'}เกณฑ์ '
                      '${AssessmentConfig.tugRiskThresholdSeconds.toStringAsFixed(1)} วินาที'
                      '${session.tug!.measurementMode == TugMeasurementMode.accelerometerOnly ? ' · ไม่ได้ยืนยันช่วงหมุนด้วย Gyroscope' : ''}'
                      '${session.tug!.measurementMode == TugMeasurementMode.legacyUnspecified ? ' · ผลเดิมไม่ระบุชนิดเซนเซอร์' : ''}',
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
                    : session.tug?.measurementMode ==
                              TugMeasurementMode.accelerometerOnly &&
                          session.tug?.riskStatus != AssessmentStatus.risk &&
                          session.functionalReach?.status !=
                              AssessmentStatus.warning &&
                          (fullerton == null ||
                              fullerton.protocolVariant.isStandard)
                    ? 'ผล TUG นี้วัดด้วย Accelerometer-only และไม่ยืนยันช่วงหมุน จึงควรเทียบกับผู้จับเวลาจริง'
                    : fullerton != null &&
                          !fullerton.protocolVariant.isStandard &&
                          session.functionalReach?.status !=
                              AssessmentStatus.warning &&
                          session.tug?.riskStatus != AssessmentStatus.risk
                    ? 'ผล Fullerton นี้เป็นแบบทดลองหรือไม่ระบุโปรโตคอล จึงไม่ใช้เทียบเกณฑ์มาตรฐาน'
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
