import 'package:supabase_flutter/supabase_flutter.dart';

/// Shared game clock. Every device animates the multiplier from the
/// server's running_started_at, so each one must measure elapsed time on
/// the server's clock rather than its own (phone clocks drift by seconds).
/// [sync] measures the offset through the server_now() RPC
/// (0020_centralized_shared_rounds.sql); until then the offset is zero.
class ServerClock {
  ServerClock._();

  static Duration _offset = Duration.zero;

  static Duration get offset => _offset;

  static DateTime now() => DateTime.now().add(_offset);

  static Future<void> sync(SupabaseClient client) async {
    try {
      final sentAt = DateTime.now();
      final response = await client.rpc('server_now');
      final receivedAt = DateTime.now();
      final serverTime = DateTime.parse(response as String);
      final roundTrip = receivedAt.difference(sentAt);
      final localMidpoint = sentAt.add(roundTrip ~/ 2);
      _offset = serverTime.difference(localMidpoint);
    } catch (_) {
      // Keep the previous offset: animation only, the server settles bets.
    }
  }

  /// Test hook.
  static void setOffsetForTesting(Duration offset) => _offset = offset;
}
