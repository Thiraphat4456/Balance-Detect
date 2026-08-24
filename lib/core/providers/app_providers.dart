import 'package:balance_detect/core/database/app_database.dart';
import 'package:balance_detect/features/assessment/data/local_assessment_repository.dart';
import 'package:balance_detect/features/assessment/domain/assessment_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final assessmentRepositoryProvider = Provider<AssessmentRepository>((ref) {
  return LocalAssessmentRepository(ref.watch(appDatabaseProvider));
});

class DebugOverlayController extends Notifier<bool> {
  @override
  bool build() => false;

  void setEnabled(bool enabled) => state = enabled;
}

final debugOverlayProvider = NotifierProvider<DebugOverlayController, bool>(
  DebugOverlayController.new,
);

class HistoryRevisionController extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state += 1;
}

final historyRevisionProvider =
    NotifierProvider<HistoryRevisionController, int>(
      HistoryRevisionController.new,
    );
