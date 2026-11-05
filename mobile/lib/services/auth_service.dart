import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';
import 'supabase_service.dart';

/// Player accounts are created by staff through the create-player Edge
/// Function (public Supabase signup is disabled server-side — see README
/// §2). This service never calls supabase.auth.signUp().
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

  Future<Profile> fetchProfile() async {
    final uid = currentSession?.user.id;
    if (uid == null) throw StateError('Not authenticated');
    final row = await _client.from('profiles').select().eq('id', uid).single();
    return Profile.fromJson(row);
  }

  Future<void> updateDisplayName(String displayName) async {
    await _client.rpc(
      'update_display_name',
      params: {'p_display_name': displayName},
    );
  }
}
