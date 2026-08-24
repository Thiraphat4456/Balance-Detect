import 'package:balance_detect/features/assessment_summary/presentation/assessment_summary_screen.dart';
import 'package:balance_detect/features/fullerton/presentation/fullerton_assessment_screen.dart';
import 'package:balance_detect/features/fullerton/presentation/fullerton_intro_screen.dart';
import 'package:balance_detect/features/functional_reach/presentation/functional_reach_assessment_screen.dart';
import 'package:balance_detect/features/functional_reach/presentation/functional_reach_intro_screen.dart';
import 'package:balance_detect/features/history/presentation/history_detail_screen.dart';
import 'package:balance_detect/features/history/presentation/history_screen.dart';
import 'package:balance_detect/features/home/presentation/home_screen.dart';
import 'package:balance_detect/features/home/presentation/splash_screen.dart';
import 'package:balance_detect/features/profile/presentation/profile_screen.dart';
import 'package:balance_detect/features/tug/presentation/tug_assessment_screen.dart';
import 'package:balance_detect/features/tug/presentation/tug_intro_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final appRouter = GoRouter(
  initialLocation: '/splash',
  routes: <RouteBase>[
    GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          _MainNavigationScaffold(navigationShell: navigationShell),
      branches: <StatefulShellBranch>[
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/history',
              builder: (context, state) => const HistoryScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/functional-reach',
      builder: (context, state) => const FunctionalReachIntroScreen(),
      routes: <RouteBase>[
        GoRoute(
          path: 'test',
          builder: (context, state) {
            final height = state.extra;
            if (height is! num) {
              return const _MissingHeightScreen();
            }
            return FunctionalReachAssessmentScreen(heightCm: height.toDouble());
          },
        ),
      ],
    ),
    GoRoute(
      path: '/fullerton',
      builder: (context, state) => const FullertonIntroScreen(),
      routes: <RouteBase>[
        GoRoute(
          path: 'test',
          builder: (context, state) => const FullertonAssessmentScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/tug',
      builder: (context, state) => const TugIntroScreen(),
      routes: <RouteBase>[
        GoRoute(
          path: 'test',
          builder: (context, state) => const TugAssessmentScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/summary',
      builder: (context, state) => const AssessmentSummaryScreen(),
    ),
    GoRoute(
      path: '/history/:sessionId',
      builder: (context, state) =>
          HistoryDetailScreen(sessionId: state.pathParameters['sessionId']!),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(title: const Text('ไม่พบหน้า')),
    body: Center(
      child: FilledButton(
        onPressed: () => context.go('/home'),
        child: const Text('กลับหน้าแรก'),
      ),
    ),
  ),
);

class _MainNavigationScaffold extends StatelessWidget {
  const _MainNavigationScaffold({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: navigationShell,
    bottomNavigationBar: NavigationBar(
      selectedIndex: navigationShell.currentIndex,
      onDestinationSelected: (index) => navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      ),
      destinations: const <NavigationDestination>[
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'หน้าแรก',
        ),
        NavigationDestination(
          icon: Icon(Icons.history_outlined),
          selectedIcon: Icon(Icons.history),
          label: 'ประวัติ',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'โปรไฟล์',
        ),
      ],
    ),
  );
}

class _MissingHeightScreen extends StatelessWidget {
  const _MissingHeightScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('ต้องกรอกส่วนสูงก่อน')),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.height_outlined, size: 64),
            const SizedBox(height: 16),
            const Text(
              'กรุณากลับไปหน้าวิธีเตรียมตัว แล้วกรอกส่วนสูงก่อนเริ่มการทดสอบ',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => context.go('/functional-reach'),
              child: const Text('กลับไปกรอกส่วนสูง'),
            ),
          ],
        ),
      ),
    ),
  );
}
