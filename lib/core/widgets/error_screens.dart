import 'package:balance_detect/core/widgets/app_scaffold_body.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionErrorScreen extends StatelessWidget {
  const PermissionErrorScreen({
    required this.message,
    required this.onRetry,
    super.key,
    this.canOpenSettings = false,
  });

  final String message;
  final VoidCallback onRetry;
  final bool canOpenSettings;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('ไม่สามารถดำเนินการได้')),
    body: AppScaffoldBody(
      child: Column(
        children: [
          const SizedBox(height: 48),
          Icon(
            Icons.no_photography_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 20),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 28),
          FilledButton(onPressed: onRetry, child: const Text('ลองอีกครั้ง')),
          if (canOpenSettings) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: openAppSettings,
              child: const Text('เปิดการตั้งค่าอุปกรณ์'),
            ),
          ],
        ],
      ),
    ),
  );
}

class InvalidTestScreen extends StatelessWidget {
  const InvalidTestScreen({
    required this.reason,
    required this.onRetry,
    super.key,
  });

  final String reason;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('การทดสอบไม่สมบูรณ์')),
    body: AppScaffoldBody(
      child: Column(
        children: [
          const SizedBox(height: 40),
          Icon(
            Icons.replay_circle_filled_outlined,
            size: 88,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 20),
          Text(
            'ยังไม่บันทึกเป็นผลประเมิน',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text(
            reason,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 28),
          FilledButton(onPressed: onRetry, child: const Text('ทดสอบอีกครั้ง')),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('กลับ'),
          ),
        ],
      ),
    ),
  );
}
