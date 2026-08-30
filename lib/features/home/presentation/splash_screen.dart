import 'dart:async';

import 'package:balance_detect/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) context.go('/home');
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.primary,
    body: SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.monitor_heart_outlined,
                size: 54,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Balance Detect',
              style: Theme.of(
                context,
              ).textTheme.headlineLarge?.copyWith(color: AppColors.surface),
            ),
            const SizedBox(height: 10),
            const Text(
              'ประเมินการทรงตัวอย่างเป็นขั้นตอน',
              style: TextStyle(color: AppColors.surface, fontSize: 18),
            ),
          ],
        ),
      ),
    ),
  );
}
