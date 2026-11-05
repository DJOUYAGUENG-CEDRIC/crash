import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/wallet.dart';
import '../models/wallet_transaction.dart';
import 'auth_providers.dart';
import 'service_providers.dart';

/// Realtime balance — updates automatically after every bet/cashout/
/// admin adjustment, no manual refresh needed.
final walletProvider = StreamProvider<Wallet?>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(null);
  return ref.watch(walletServiceProvider).watchWallet(userId);
});

final recentTransactionsProvider = FutureProvider<List<WalletTransaction>>((
  ref,
) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];
  return ref.watch(walletServiceProvider).fetchRecentTransactions(userId);
});
