import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/activation_result.dart';
import 'auth_providers.dart';
import 'service_providers.dart';

/// Re-evaluated on sign-in and whenever the app resumes from background
/// (see main.dart's lifecycle observer, which calls
/// `ref.invalidate(activationProvider)`). Never trust the previous
/// result after a reconnect — spec §48.
final activationProvider = FutureProvider<ActivationResult>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) {
    return const ActivationResult(
      allowed: false,
      reason: 'NOT_AUTHENTICATED',
      currentVersion: null,
      minimumSupportedVersion: null,
      downloadUrl: null,
    );
  }
  return ref.watch(activationServiceProvider).checkActivation();
});
