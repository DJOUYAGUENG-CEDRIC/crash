import 'package:crashx/models/bet.dart';
import 'package:crashx/models/enums.dart';
import 'package:crashx/models/game_round.dart';
import 'package:crashx/models/profile.dart';
import 'package:crashx/models/wallet.dart';
import 'package:crashx/services/auth_service.dart';
import 'package:crashx/services/game_service.dart';

/// Test doubles for the app's services (spec §52: widget tests must run
/// fully offline — no test ever touches a real Supabase project). Each
/// fake extends the real service and overrides every public member, so
/// the inherited private `_client` getter (which would hit
/// `Supabase.instance` and throw if Supabase was never initialized) is
/// never reached.
class FakeAuthService extends AuthService {
  FakeAuthService({this.signInError, Profile? profile})
    : _profile = profile ?? sampleProfile();

  final Profile _profile;
  Object? signInError;

  bool signInCalled = false;
  bool signOutCalled = false;
  String? lastSignInEmail;
  String? updatedDisplayName;

  @override
  Future<void> signIn({required String email, required String password}) async {
    signInCalled = true;
    lastSignInEmail = email;
    if (signInError != null) throw signInError!;
  }

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }

  @override
  Future<Profile> fetchProfile() async => _profile;

  @override
  Future<void> updateDisplayName(String displayName) async {
    updatedDisplayName = displayName;
  }
}

class FakeGameService extends GameService {
  FakeGameService({
    this.placeBetError,
    this.cashoutError,
    this._placeBetResult,
    this._cashoutResult,
  });

  final Bet? _placeBetResult;
  final Bet? _cashoutResult;
  Object? placeBetError;
  Object? cashoutError;

  bool placeBetCalled = false;
  bool cashoutCalled = false;
  String? lastCashoutBetId;
  int? lastBetSlot;
  double? lastBetAmount;
  double? lastAutoCashout;

  @override
  Future<Bet> placeBet({
    required String roundId,
    required int slot,
    required double amount,
    double? autoCashoutMultiplier,
  }) async {
    placeBetCalled = true;
    lastBetSlot = slot;
    lastBetAmount = amount;
    lastAutoCashout = autoCashoutMultiplier;
    if (placeBetError != null) throw placeBetError!;
    return _placeBetResult ??
        sampleBet(slot: slot, amount: amount, status: BetStatus.pending);
  }

  @override
  Future<Bet> cashout(String betId) async {
    cashoutCalled = true;
    lastCashoutBetId = betId;
    if (cashoutError != null) throw cashoutError!;
    return _cashoutResult ?? sampleBet(status: BetStatus.cashedOut);
  }
}

Profile sampleProfile({
  String id = 'user-1',
  String email = 'joueur@example.com',
  String displayName = 'Joueur Test',
}) {
  return Profile(
    id: id,
    email: email,
    displayName: displayName,
    status: AccountStatus.active,
    invitationId: null,
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

Wallet sampleWallet({double balance = 10000}) {
  return Wallet(userId: 'user-1', balance: balance, currency: 'FCFA');
}

GameRound sampleRound({
  String id = 'round-1',
  int roundNumber = 1,
  RoundStatus status = RoundStatus.betting,
  double? crashMultiplier,
  int? countdown,
  DateTime? bettingStartedAt,
  DateTime? runningStartedAt,
}) {
  return GameRound(
    id: id,
    roundNumber: roundNumber,
    status: status,
    crashMultiplier: crashMultiplier,
    countdown: countdown,
    bettingStartedAt: bettingStartedAt,
    runningStartedAt: runningStartedAt,
    crashedAt: null,
    totalBetsAmount: 0,
    totalPlayers: 0,
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

Bet sampleBet({
  String id = 'bet-1',
  String roundId = 'round-1',
  int slot = 1,
  double amount = 100,
  BetStatus status = BetStatus.active,
  double? cashoutMultiplier,
  double? payout,
  DateTime? flightStartedAt,
  DateTime? cashedOutAt,
}) {
  return Bet(
    id: id,
    roundId: roundId,
    userId: 'user-1',
    slot: slot,
    amount: amount,
    status: status,
    autoCashoutMultiplier: null,
    cashoutMultiplier: cashoutMultiplier,
    payout: payout,
    placedAt: DateTime.utc(2026, 1, 1),
    flightStartedAt:
        flightStartedAt ??
        (status == BetStatus.active || status == BetStatus.cashedOut
            ? (cashedOutAt ?? DateTime.now()).subtract(
                const Duration(seconds: 10),
              )
            : null),
    cashedOutAt: cashedOutAt,
  );
}
