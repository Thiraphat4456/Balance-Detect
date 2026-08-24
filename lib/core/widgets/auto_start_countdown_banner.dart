import 'package:flutter/material.dart';

/// Makes the hands-free transition explicit while the camera prepares itself.
class AutoStartCountdownBanner extends StatelessWidget {
  const AutoStartCountdownBanner({
    required this.seconds,
    required this.readyMessage,
    this.countdownMessage = 'ระบบจะเริ่มเองเมื่อครบเวลา',
    super.key,
  });

  final int? seconds;
  final String readyMessage;
  final String countdownMessage;

  @override
  Widget build(BuildContext context) {
    final isCountingDown = seconds != null;
    return Semantics(
      liveRegion: true,
      label: isCountingDown ? 'เริ่มอัตโนมัติใน $seconds วินาที' : readyMessage,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              isCountingDown ? Icons.timer_outlined : Icons.volume_up_outlined,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isCountingDown ? 'เริ่มใน $seconds วินาที' : readyMessage,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isCountingDown ? 'เตรียมตัวให้อยู่นิ่ง' : countdownMessage,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
