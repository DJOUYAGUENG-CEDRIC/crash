import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/activation_providers.dart';
import '../../providers/auth_providers.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_header.dart';

/// Hosts the persistent bottom navigation (spec §14 — "le menu doit
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

  static const _menuItems = [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'Accueil',
    ),
    NavigationDestination(
      icon: Icon(Icons.sports_esports_outlined),
      selectedIcon: Icon(Icons.sports_esports),
      label: 'Crash',
    ),
    NavigationDestination(
      icon: Icon(Icons.bar_chart_outlined),
      selectedIcon: Icon(Icons.bar_chart),
      label: 'Historique',
    ),
    NavigationDestination(
      icon: Icon(Icons.card_giftcard_outlined),
      selectedIcon: Icon(Icons.card_giftcard),
      label: 'Bonus',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person),
      label: 'Profil',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCrashPage = navigationShell.currentIndex == 1;
    ref.listen(isSignedInProvider, (previous, isSignedIn) {
      if (isSignedIn == false) context.go('/login');
    });
    ref.listen(activationProvider, (previous, next) {
      final result = next.value;
      if (result != null && !result.allowed) context.go('/');
    });

    return Scaffold(
      appBar: AppHeader(
        showBackButton: isCrashPage,
        onBack: isCrashPage
            ? () {
                navigationShell.goBranch(0);
              }
            : null,
      ),
      drawer: const AppDrawer(),
      body: navigationShell,
      floatingActionButton: navigationShell.currentIndex != 1
          ? FloatingActionButton(
              tooltip: 'Ouvrir le menu',
              onPressed: () => _openMenu(context, navigationShell),
              child: const Icon(Icons.add_rounded, size: 30),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  static Future<void> _openMenu(
    BuildContext context,
    StatefulNavigationShell navigationShell,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Menu',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _menuItems.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.15,
                ),
                itemBuilder: (itemContext, index) {
                  final item = _menuItems[index];
                  final selected = index == navigationShell.currentIndex;
                  return Material(
                    color: selected
                        ? Theme.of(itemContext).colorScheme.primaryContainer
                        : Theme.of(itemContext)
                              .colorScheme
                              .surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        navigationShell.goBranch(
                          index,
                          initialLocation:
                              index == navigationShell.currentIndex,
                        );
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          item.icon,
                          const SizedBox(height: 8),
                          Text(item.label),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
