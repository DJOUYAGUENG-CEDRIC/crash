import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';
import 'supabase_service.dart';

/// Account creation ONLY ever happens through activate-invitation
/// (public Supabase signup is disabled server-side — see README §2).
/// This service never calls supabase.auth.signUp().
class AuthService {
  SupabaseClient get _client => SupabaseService.client;

  Session? get currentSession => _client.auth.currentSession;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Consumes an invitation token and creates the player's login, via
  /// the activate-invitation Edge Function (uses the service role
  /// server-side — this app never has that key). Signs the new account
  /// in immediately afterward.
  Future<void> activateInvitation({
    required String token,
    required String email,
    required String password,
    required String displayName,
  }) async {
    final response = await _client.functions.invoke(
      'activate-invitation',
      body: {'token': token, 'email': email, 'password': password, 'display_name': displayName},
    );

    if (response.status != 200) {
      final error = (response.data is Map) ? response.data['error'] as String? : null;
      throw AuthException(error ?? 'ACTIVATION_FAILED');
    }

    await signIn(email: email, password: password);
  }

  Future<Profile> fetchProfile() async {
    final uid = currentSession?.user.id;
    if (uid == null) throw StateError('Not authenticated');
    final row = await _client.from('profiles').select().eq('id', uid).single();
    return Profile.fromJson(row);
  }

  Future<void> updateDisplayName(String displayName) async {
    await _client.rpc('update_display_name', params: {'p_display_name': displayName});
  }
}
