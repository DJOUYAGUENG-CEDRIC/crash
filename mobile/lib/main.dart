import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/env/env.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'providers/activation_providers.dart';
import 'services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!Env.isConfigured) {
    runApp(const _MissingConfigApp());
    return;
  }

  await SupabaseService.initialize();
  runApp(const ProviderScope(child: CrashXApp()));
}

class CrashXApp extends ConsumerStatefulWidget {
  const CrashXApp({super.key});

  @override
  ConsumerState<CrashXApp> createState() => _CrashXAppState();
}

class _CrashXAppState extends ConsumerState<CrashXApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Spec §48: never trust the previous local state after the app was
    // backgrounded — re-verify account/device/version with the server
    // as soon as it comes back to the foreground.
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(activationProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'CRASHX',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: AppRouter.router,
    );
  }
}

/// Fails loudly and obviously if someone runs the app without passing
/// --dart-define SUPABASE_URL / SUPABASE_ANON_KEY (see README §5),
/// instead of silently hitting an empty Supabase URL at runtime.
class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Color(0xFF0B0D14),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Configuration manquante.\n\n'
              'Lancez avec :\n'
              '--dart-define=SUPABASE_URL=...\n'
              '--dart-define=SUPABASE_ANON_KEY=...',
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
