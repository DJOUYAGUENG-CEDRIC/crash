import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/activation_result.dart';
import 'supabase_service.dart';

/// Enforces spec §30/§48: an installed APK is never itself an
/// authorization. Every launch/resume calls check_activation(), which
/// re-verifies account status, app version, and device authorization
/// server-side — the client never assumes the previous local state is
/// still valid after being backgrounded or reconnecting.
class ActivationService {
  static const _deviceIdKey = 'crashx_device_identifier';

  SupabaseClient get _client => SupabaseService.client;

  /// A locally-generated, persisted UUID — not a hardware identifier.
  /// Modern Android does not expose a stable, permission-free hardware
  /// ID, so this is the standard, privacy-respecting alternative: it
  /// survives app restarts but resets on uninstall/data clear, which is
  /// the correct behavior anyway (a fresh install should re-activate).
  Future<String> _getOrCreateDeviceIdentifier() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null) return existing;

    final generated = const Uuid().v4();
    await prefs.setString(_deviceIdKey, generated);
    return generated;
  }

  Future<String> _getDeviceName() async {
    final deviceInfo = DeviceInfoPlugin();
    try {
      final info = await deviceInfo.androidInfo;
      return '${info.manufacturer} ${info.model}'.trim();
    } catch (_) {
      return 'Appareil Android';
    }
  }

  Future<ActivationResult> checkActivation() async {
    final deviceIdentifier = await _getOrCreateDeviceIdentifier();
    final deviceName = await _getDeviceName();
    final packageInfo = await PackageInfo.fromPlatform();

    final row = await _client.rpc(
      'check_activation',
      params: {
        'p_device_identifier': deviceIdentifier,
        'p_device_name': deviceName,
        'p_platform': 'android',
        'p_app_version': packageInfo.version,
      },
    );

    return ActivationResult.fromJson(row as Map<String, dynamic>);
  }
}
