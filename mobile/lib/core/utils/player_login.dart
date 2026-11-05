/// Players sign in with the login an admin created for them: either an
/// e-mail address or a simple identifier such as "moussa.k". Identifiers
/// are stored in Supabase Auth as an internal address. Must stay in sync
/// with supabase/functions/create-player/index.ts.
class PlayerLogin {
  PlayerLogin._();

  static const domain = 'joueurs.crashx.app';
  static final _identifier = RegExp(r'^[a-z0-9._-]{3,30}$');

  static bool isValid(String login) {
    final value = login.trim().toLowerCase();
    return value.contains('@') || _identifier.hasMatch(value);
  }

  static String toEmail(String login) {
    final value = login.trim().toLowerCase();
    return value.contains('@') ? value : '$value@$domain';
  }

  /// What to show an admin for an account: the identifier for internal
  /// addresses, the real e-mail otherwise.
  static String display(String email) =>
      email.endsWith('@$domain') ? email.split('@').first : email;
}
