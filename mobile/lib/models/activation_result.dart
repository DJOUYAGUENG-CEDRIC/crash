/// Mirrors the `activation_result` composite type returned by
/// check_activation() (supabase/migrations/0005_admin_functions.sql).
class ActivationResult {
  final bool allowed;
  final String reason;
  final String? currentVersion;
  final String? minimumSupportedVersion;
  final String? downloadUrl;

  const ActivationResult({
    required this.allowed,
    required this.reason,
    required this.currentVersion,
    required this.minimumSupportedVersion,
    required this.downloadUrl,
  });

  factory ActivationResult.fromJson(Map<String, dynamic> json) => ActivationResult(
    allowed: json['allowed'] as bool,
    reason: json['reason'] as String,
    currentVersion: json['current_version'] as String?,
    minimumSupportedVersion: json['minimum_supported_version'] as String?,
    downloadUrl: json['download_url'] as String?,
  );
}
