import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/wallet.dart';
import '../models/wallet_transaction.dart';
import 'supabase_service.dart';

class WalletService {
  SupabaseClient get _client => SupabaseService.client;

  Future<Wallet> fetchWallet(String userId) async {
    final row = await _client
        .from('wallets')
        .select()
        .eq('user_id', userId)
        .single();
    return Wallet.fromJson(row);
  }

  /// Realtime balance updates — reflects every place_bet/cashout_bet/
  /// admin_adjust_balance the server applies, without a manual refetch.
  Stream<Wallet> watchWallet(String userId) {
    return _client
        .from('wallets')
        .stream(primaryKey: ['user_id'])
        .eq('user_id', userId)
        .map((rows) => Wallet.fromJson(rows.first));
  }

  Future<List<WalletTransaction>> fetchRecentTransactions(
    String userId, {
    int limit = 50,
  }) async {
    final rows = await _client
        .from('transactions')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((r) => WalletTransaction.fromJson(r as Map<String, dynamic>))
        .toList();
  }
}
