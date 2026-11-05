import 'package:crashx/providers/service_providers.dart';
import 'package:crashx/screens/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/fakes.dart';

/// Minimal router just for this test: LoginScreen plus dummy
/// destination for the place it navigates to, so context.go has somewhere real to land — no real Supabase project
/// involved anywhere (spec §52).
GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: Text('HOME_STUB')),
      ),
    ],
  );
}

Widget _wrap(FakeAuthService fakeAuth) {
  return ProviderScope(
    overrides: [authServiceProvider.overrideWithValue(fakeAuth)],
    child: MaterialApp.router(routerConfig: _buildRouter()),
  );
}

void main() {
  testWidgets(
    'shows a validation error and never calls the service for an invalid login',
    (tester) async {
      final fakeAuth = FakeAuthService();
      await tester.pumpWidget(_wrap(fakeAuth));

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Identifiant'),
        'a b',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mot de passe'),
        'password123',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'SE CONNECTER'));
      await tester.pump();

      expect(find.text('Identifiant invalide.'), findsOneWidget);
      expect(fakeAuth.signInCalled, isFalse);
    },
  );

  testWidgets('valid credentials call signIn and navigate away on success', (
    tester,
  ) async {
    final fakeAuth = FakeAuthService();
    await tester.pumpWidget(_wrap(fakeAuth));

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Identifiant'),
      'joueur@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mot de passe'),
      'password123',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'SE CONNECTER'));
    await tester.pumpAndSettle();

    expect(fakeAuth.signInCalled, isTrue);
    expect(fakeAuth.lastSignInEmail, 'joueur@example.com');
    expect(find.text('HOME_STUB'), findsOneWidget);
  });

  testWidgets('a thrown AuthException surfaces a friendly French error', (
    tester,
  ) async {
    final fakeAuth = FakeAuthService(
      signInError: const AuthException('Invalid login credentials'),
    );
    await tester.pumpWidget(_wrap(fakeAuth));

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Identifiant'),
      'joueur@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mot de passe'),
      'wrongpassword',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'SE CONNECTER'));
    await tester.pumpAndSettle();

    expect(find.text('Identifiant ou mot de passe incorrect.'), findsOneWidget);
  });

  testWidgets('a simple identifier signs in with the internal address', (
    tester,
  ) async {
    final fakeAuth = FakeAuthService();
    await tester.pumpWidget(_wrap(fakeAuth));

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Identifiant'),
      'Moussa.K',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mot de passe'),
      'password123',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'SE CONNECTER'));
    await tester.pumpAndSettle();

    expect(fakeAuth.lastSignInEmail, 'moussa.k@joueurs.crashx.app');
  });
}
