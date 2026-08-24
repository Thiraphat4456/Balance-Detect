import 'package:balance_detect/core/domain/assessment_enums.dart';
import 'package:balance_detect/core/providers/app_providers.dart';
import 'package:balance_detect/core/theme/app_theme.dart';
import 'package:balance_detect/core/utils/date_time_format.dart';
import 'package:balance_detect/core/widgets/app_scaffold_body.dart';
import 'package:balance_detect/core/widgets/loading_view.dart';
import 'package:balance_detect/features/assessment/domain/assessment_session.dart';
import 'package:balance_detect/features/assessment/domain/session_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  late Future<List<AssessmentSession>> _sessions;
  int _loadedRevision = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _sessions = ref.read(assessmentRepositoryProvider).getSessions();
  }

  Future<void> _refresh() async {
    setState(_load);
    await _sessions;
  }

  @override
  Widget build(BuildContext context) {
    final revision = ref.watch(historyRevisionProvider);
    if (revision != _loadedRevision) {
      _loadedRevision = revision;
      _load();
    }
    return Scaffold(
      appBar: AppBar(title: const Text('ประวัติ')),
      body: FutureBuilder<List<AssessmentSession>>(
        future: _sessions,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LoadingView(label: 'กำลังโหลดประวัติ');
          }
          if (snapshot.hasError) {
            return _HistoryError(onRetry: _refresh);
          }
          final sessions = snapshot.data ?? const <AssessmentSession>[];
          if (sessions.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 90),
                  Icon(
                    Icons.history_rounded,
                    size: 82,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'ยังไม่มีผลการประเมิน',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'ผลที่บันทึกแล้วจะแสดงที่นี่',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
              itemCount: sessions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, index) => _HistoryCard(
                session: sessions[index],
                onTap: () async {
                  await context.push('/history/${sessions[index].id}');
                  if (mounted) await _refresh();
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.session, required this.onTap});

  final AssessmentSession session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = SessionSummary.status(session);
    final statusColor = switch (status) {
      AssessmentStatus.normal => AppColors.normal,
      AssessmentStatus.warning => AppColors.warning,
      AssessmentStatus.risk || AssessmentStatus.invalid => AppColors.risk,
    };
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      DateTimeFormat.thaiShort(session.timestamp),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 12),
              if (session.functionalReach != null)
                _ValueRow(
                  label: 'Functional Reach',
                  value:
                      '${session.functionalReach!.distanceInch.toStringAsFixed(1)} นิ้ว',
                ),
              if (session.fullerton != null)
                _ValueRow(
                  label: 'Fullerton',
                  value: '${session.fullerton!.score} / 4',
                ),
              if (session.tug != null)
                _ValueRow(
                  label: 'TUG',
                  value:
                      '${session.tug!.totalSeconds.toStringAsFixed(1)} วินาที',
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.circle, size: 12, color: statusColor),
                  const SizedBox(width: 8),
                  Text(
                    SessionSummary.label(session),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

class _HistoryError extends StatelessWidget {
  const _HistoryError({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => AppScaffoldBody(
    child: Column(
      children: [
        const SizedBox(height: 60),
        const Icon(Icons.error_outline, size: 72, color: AppColors.risk),
        const SizedBox(height: 16),
        const Text('ไม่สามารถโหลดประวัติได้'),
        const SizedBox(height: 20),
        FilledButton(onPressed: onRetry, child: const Text('ลองอีกครั้ง')),
      ],
    ),
  );
}
