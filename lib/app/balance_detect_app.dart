import 'package:balance_detect/core/routing/app_router.dart';
import 'package:balance_detect/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class BalanceDetectApp extends StatelessWidget {
  const BalanceDetectApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'Balance Detect',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    routerConfig: appRouter,
  );
}
