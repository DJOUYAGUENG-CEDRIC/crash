import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/activation_providers.dart';
import '../../providers/auth_providers.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_header.dart';

/// Hosts the 5-tab persistent bottom navigation (spec §14 — "le menu doit
/// être persistant") around a [StatefulShellRoute.indexedStack] branch.
///
/// Also acts as a live guard for any player already inside the app: if
/// they sign out (elsewhere) or the periodic activation re-check (see
/// main.dart's resume listener) comes back disallowed while they're on
/// any of the 5 tabs, this bounces them back out to the splash gate
/// instead of leaving them stranded on a tab with a now-invalid session.
class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Accueil'),
    NavigationDestination(
      icon: Icon(Icons.sports_esports_outlined),
      selectedIcon: Icon(Icons.sports_esports),
      label: 'Crash',
    ),
    NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Historique'),
    NavigationDestination(icon: Icon(Icons.card_giftcard_outlined), selectedIcon: Icon(Icons.card_giftcard), label: 'Bonus'),
    NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profil'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(isSignedInProvider, (previous, isSignedIn) {
      if (isSignedIn == false) context.go('/login');
    });
    ref.listen(activationProvider, (previous, next) {
      final result = next.value;
      if (result != null && !result.allowed) context.go('/');
    });

    return Scaffold(
      appBar: const AppHeader(),
      drawer: const AppDrawer(),
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: _destinations,
      ),
    );
  }
}
