import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/activation_service.dart';
import '../services/auth_service.dart';
import '../services/game_service.dart';
import '../services/wallet_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final walletServiceProvider = Provider<WalletService>((ref) => WalletService());
final gameServiceProvider = Provider<GameService>((ref) => GameService());
final activationServiceProvider = Provider<ActivationService>(
  (ref) => ActivationService(),
);
