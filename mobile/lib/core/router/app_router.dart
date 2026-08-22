import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../screens/auth/activation_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/bonus/bonus_screen.dart';
import '../../screens/crash/crash_screen.dart';
import '../../screens/history/history_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/shell/main_shell.dart';
import '../../screens/splash/splash_screen.dart';

/// App-wide navigation graph. `/` (splash) is where auth + activation are
/// enforced (see SplashScreen's doc comment); everything under the
/// [StatefulShellRoute] shares the persistent 5-tab bottom nav (spec §14).
class AppRouter {
  AppRouter._();

  static final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

  static final GoRouter router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/activate', builder: (context, state) => const ActivationScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/home', builder: (context, state) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/crash', builder: (context, state) => const CrashScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/history', builder: (context, state) => const HistoryScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/bonus', builder: (context, state) => const BonusScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen())],
          ),
        ],
      ),
    ],
  );
}
