import 'package:supabase_flutter/supabase_flutter.dart';

/// Maps the known server error codes (see game_service.dart / auth_service.dart
/// doc comments) to short, friendly French sentences. Unknown codes fall back
/// to a generic message rather than leaking a raw backend string to a player.
String friendlyBetErrorMessage(Object error) {
  final code = error is PostgrestException ? error.message : error.toString();
  switch (code) {
    case 'ROUND_NOT_OPEN':
      return 'Les mises sont fermées pour ce tour.';
    case 'INVALID_AMOUNT':
      return 'Montant de mise invalide.';
    case 'INVALID_AUTO_CASHOUT':
      return "Multiplicateur d'encaissement automatique invalide.";
    case 'INSUFFICIENT_FUNDS':
      return 'Solde insuffisant.';
    case 'ACCESS DENIED':
      return 'Accès refusé.';
    case 'BET_NOT_ACTIVE':
      return "Cette mise n'est plus active.";
    case 'ROUND_NOT_RUNNING':
      return "Le tour n'est pas en cours.";
    case 'ROUND_CRASHED':
      return 'Le tour a déjà crashé.';
    default:
      return 'Une erreur est survenue.';
  }
}

/// Friendly copy for sign-in failures — Supabase returns fairly generic
/// AuthExceptions for bad credentials, so we keep this deliberately short.
String friendlyLoginErrorMessage(Object error) {
  if (error is AuthException) {
    return 'Identifiant ou mot de passe incorrect.';
  }
  return 'Connexion impossible. Vérifiez votre connexion internet.';
}
