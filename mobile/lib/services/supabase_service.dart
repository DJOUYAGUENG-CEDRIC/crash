import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/env/env.dart';

/// Thin wrapper around the Supabase singleton. Initialized once in
/// main.dart before runApp(). Only ever uses the public anon key —
/// see core/env/env.dart and README §5/§46.
class SupabaseService {
  SupabaseService._();

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseAnonKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
