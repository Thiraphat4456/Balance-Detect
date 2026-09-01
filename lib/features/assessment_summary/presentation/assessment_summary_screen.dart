import 'package:balance_detect/core/constants/assessment_config.dart';
import 'package:balance_detect/core/domain/assessment_enums.dart';
import 'package:balance_detect/core/providers/app_providers.dart';
import 'package:balance_detect/core/widgets/app_scaffold_body.dart';
import 'package:balance_detect/core/widgets/loading_view.dart';
import 'package:balance_detect/core/widgets/status_banner.dart';
import 'package:balance_detect/features/assessment/domain/assessment_session.dart';
import 'package:balance_detect/features/fullerton/domain/fullerton_reach_calibration_service.dart';
import 'package:balance_detect/features/fullerton/domain/fullerton_result.dart';
import 'package:balance_detect/features/functional_reach/domain/functional_reach_result.dart';
import 'package:balance_detect/features/tug/domain/sensor_models.dart';
import 'package:balance_detect/features/tug/domain/tug_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AssessmentSummaryScreen extends ConsumerWidget {
  const AssessmentSummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('สรุปผลการประเมิน')),
    body: FutureBuilder<List<AssessmentSession>>(
      future: ref.read(assessmentRepositoryProvider).getSessions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingView(label: 'กำลังรวบรวมผลล่าสุด');
        }
        if (snapshot.hasError) {
          return const Center(child: Text('ไม่สามารถโหลดสรุปผลได้'));
        }
        final sessions = snapshot.data ?? const <AssessmentSession>[];
        FunctionalReachResult? reach;
        FullertonResult? fullerton;
        TugResult? tug;
        for (final session in sessions) {
          reach ??= session.functionalReach?.valid == true
              ? session.functionalReach
              : null;
          fullerton ??= session.fullerton?.valid == true
              ? session.fullerton
              : null;
          tug ??= session.tug?.valid == true ? session.tug : null;
        }
        final hasResults = reach != null || fullerton != null || tug != null;
        final risk = tug?.riskStatus == AssessmentStatus.risk;
        final warning =
            reach?.status == AssessmentStatus.warning ||
            tug?.measurementMode == TugMeasurementMode.accelerometerOnly ||
            (fullerton != null &&
                (!fullerton.protocolVariant.isStandard ||
                    fullerton.score <= 2));
        final experimentalOnlyWarning =
            !risk &&
            reach?.status != AssessmentStatus.warning &&
            fullerton != null &&
            !fullerton.protocolVariant.isStandard;
        final accelerometerOnlyTugWarning =
            !risk &&
            reach?.status != AssessmentStatus.warning &&
            tug?.measurementMode == TugMeasurementMode.accelerometerOnly &&
            (fullerton == null || fullerton.protocolVariant.isStandard);
        final overallStatus = !hasResults
            ? AssessmentStatus.invalid
            : risk
            ? AssessmentStatus.risk
            : warning
            ? AssessmentStatus.warning
            : AssessmentStatus.normal;
        return AppScaffoldBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ผลล่าสุดของแต่ละแบบทดสอบ',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 18),
              _SummaryCard(
                title: 'Functional Reach',
                value: reach == null
                    ? 'ยังไม่มีผล'
                    : '${reach.distanceInch.toStringAsFixed(1)} นิ้ว',
                detail: reach == null
                    ? 'ทำแบบทดสอบเพื่อเพิ่มข้อมูล'
                    : reach.distanceInch <
                          AssessmentConfig.functionalReachThresholdInches
                    ? 'ต่ำกว่า ${AssessmentConfig.functionalReachThresholdInches.toStringAsFixed(0)} นิ้ว'
                    : 'ไม่น้อยกว่า ${AssessmentConfig.functionalReachThresholdInches.toStringAsFixed(0)} นิ้ว',
              ),
              const SizedBox(height: 14),
              _SummaryCard(
                title: fullerton == null || fullerton.protocolVariant.isStandard
                    ? 'Fullerton'
                    : fullerton.protocolVariant.isExperimental
                    ? 'Modified Fullerton — ทดลอง'
                    : 'Fullerton — โปรโตคอลเดิม',
                value: fullerton == null
                    ? 'ยังไม่มีผล'
                    : '${fullerton.score} / 4 คะแนน',
                detail: fullerton == null
                    ? 'ทำแบบทดสอบเพื่อเพิ่มข้อมูล'
                    : 'ตรวจพบ ${fullerton.stepCount} ก้าว'
                          '${fullerton.targetDistanceCm == null ? '' : ' · เป้าหมาย ${fullerton.targetDistanceCm!.toStringAsFixed(1)} ซม.'}'
                          '${fullerton.protocolVariant.isStandard ? '' : ' · ไม่เทียบเกณฑ์มาตรฐาน'}',
              ),
              const SizedBox(height: 14),
              _SummaryCard(
                title:
                    tug?.measurementMode == TugMeasurementMode.accelerometerOnly
                    ? 'TUG — Accelerometer-only'
                    : 'Timed Up and Go (TUG)',
                value: tug == null
                    ? 'ยังไม่มีผล'
                    : '${tug.totalSeconds.toStringAsFixed(1)} วินาที',
                detail: tug == null
                    ? 'ทำแบบทดสอบเพื่อเพิ่มข้อมูล'
                    : '${tug.totalSeconds > AssessmentConfig.tugRiskThresholdSeconds ? 'มากกว่า' : 'ไม่เกิน'} '
                          '${AssessmentConfig.tugRiskThresholdSeconds.toStringAsFixed(1)} วินาที'
                          '${tug.measurementMode == TugMeasurementMode.accelerometerOnly ? ' · ไม่ยืนยันช่วงหมุน' : ''}',
              ),
              const SizedBox(height: 24),
              StatusBanner(
                status: overallStatus,
                label: !hasResults
                    ? 'ข้อมูลยังไม่เพียงพอ'
                    : accelerometerOnlyTugWarning
                    ? 'มีผล TUG จากโหมดพื้นฐาน'
                    : experimentalOnlyWarning
                    ? 'มีผล Fullerton แบบทดลอง'
                    : overallStatus == AssessmentStatus.normal
                    ? 'ผลล่าสุดอยู่ในเกณฑ์เบื้องต้น'
                    : 'พบสัญญาณความเสี่ยงด้านการทรงตัว',
                detail: !hasResults
                    ? 'ยังไม่มีผลที่ใช้ได้สำหรับสรุป'
                    : accelerometerOnlyTugWarning
                    ? 'ผล Accelerometer-only ไม่ได้ยืนยันช่วงหมุนและควรเทียบกับผู้จับเวลาจริง'
                    : experimentalOnlyWarning
                    ? 'ผล Modified FAB ถูกแยกจากการตีความตามเกณฑ์มาตรฐาน'
                    : overallStatus == AssessmentStatus.normal
                    ? 'ผลจากแอปเป็นการคัดกรอง ไม่ใช่การวินิจฉัย'
                    : 'ควรได้รับการประเมินเพิ่มเติมจากผู้เชี่ยวชาญ',
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
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
          const SizedBox(height: 8),
          Text(value, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(detail),
        ],
      ),
    ),
  );
}
