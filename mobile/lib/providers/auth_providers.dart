import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';
import 'service_providers.dart';

final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

/// Null when signed out. Recomputes on every auth state change (sign
/// in, sign out, token refresh).
final currentUserIdProvider = Provider<String?>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  return authState.value?.session?.user.id ?? ref.watch(authServiceProvider).currentSession?.user.id;
});

final isSignedInProvider = Provider<bool>((ref) => ref.watch(currentUserIdProvider) != null);

final profileProvider = FutureProvider<Profile>((ref) async {
  // Re-fetches whenever the signed-in user changes.
  ref.watch(currentUserIdProvider);
  return ref.watch(authServiceProvider).fetchProfile();
});
