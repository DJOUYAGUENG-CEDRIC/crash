import 'package:crashx/providers/service_providers.dart';
import 'package:crashx/screens/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/fakes.dart';

/// Minimal router just for this test: LoginScreen plus dummy
/// destinations for the two places it can navigate to, so context.go /
/// context.push have somewhere real to land — no real Supabase project
/// involved anywhere (spec §52).
GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/', builder: (context, state) => const Scaffold(body: Text('HOME_STUB'))),
      GoRoute(path: '/activate', builder: (context, state) => const Scaffold(body: Text('ACTIVATE_STUB'))),
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
  testWidgets('shows a validation error and never calls the service for an invalid email', (tester) async {
    final fakeAuth = FakeAuthService();
    await tester.pumpWidget(_wrap(fakeAuth));

    await tester.enterText(find.widgetWithText(TextFormField, 'E-mail'), 'not-an-email');
    await tester.enterText(find.widgetWithText(TextFormField, 'Mot de passe'), 'password123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'SE CONNECTER'));
    await tester.pump();

    expect(find.text('Adresse e-mail invalide.'), findsOneWidget);
    expect(fakeAuth.signInCalled, isFalse);
  });

  testWidgets('valid credentials call signIn and navigate away on success', (tester) async {
    final fakeAuth = FakeAuthService();
    await tester.pumpWidget(_wrap(fakeAuth));

    await tester.enterText(find.widgetWithText(TextFormField, 'E-mail'), 'joueur@example.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Mot de passe'), 'password123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'SE CONNECTER'));
    await tester.pumpAndSettle();

    expect(fakeAuth.signInCalled, isTrue);
    expect(fakeAuth.lastSignInEmail, 'joueur@example.com');
    expect(find.text('HOME_STUB'), findsOneWidget);
  });

  testWidgets('a thrown AuthException surfaces a friendly French error', (tester) async {
    final fakeAuth = FakeAuthService(signInError: const AuthException('Invalid login credentials'));
    await tester.pumpWidget(_wrap(fakeAuth));

    await tester.enterText(find.widgetWithText(TextFormField, 'E-mail'), 'joueur@example.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Mot de passe'), 'wrongpassword');
    await tester.tap(find.widgetWithText(ElevatedButton, 'SE CONNECTER'));
    await tester.pumpAndSettle();

    expect(find.text('Adresse e-mail ou mot de passe incorrect.'), findsOneWidget);
  });

  testWidgets('the invitation link navigates to the activation screen', (tester) async {
    final fakeAuth = FakeAuthService();
    await tester.pumpWidget(_wrap(fakeAuth));

    await tester.tap(find.text("J'ai un code d'invitation"));
    await tester.pumpAndSettle();

    expect(find.text('ACTIVATE_STUB'), findsOneWidget);
  });
}
