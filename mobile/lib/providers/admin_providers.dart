import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/admin_models.dart';
import '../services/admin_service.dart';
import 'auth_providers.dart';

final adminServiceProvider = Provider<AdminService>((ref) => AdminService());

/// The signed-in staff account, or null for a player. Re-fetched whenever
/// the signed-in user changes, and on every resume (main.dart).
final adminAccountProvider = FutureProvider<AdminAccount?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  return ref.watch(adminServiceProvider).fetchMyAdminAccount();
});
