import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

/// Optional Firebase Remote Config layer on top of the compile-time
/// [Env.apiBaseUrl] default. Lets already-installed builds (demo/pilot APKs
/// in particular) be repointed at a different backend without a rebuild.
///
/// Fully optional by design: until `flutterfire configure` has been run for
/// this project (see README), Firebase isn't set up on the device/emulator
/// and every step here fails silently, leaving the compile-time default in
/// effect. Never let a Remote Config failure block app startup or login.
class RemoteConfigService {
  static const _apiBaseUrlKey = 'api_base_url';

  /// Fetches and activates Remote Config. Swallows all errors.
  ///
  /// Returns the resolved `api_base_url` override, or `null` if Remote
  /// Config is unavailable, unreachable, or the value is unset/empty.
  Future<String?> fetchApiBaseUrlOverride() async {
    try {
      await Firebase.initializeApp();
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval:
              kReleaseMode ? const Duration(hours: 1) : Duration.zero,
        ),
      );
      await remoteConfig.setDefaults(const {_apiBaseUrlKey: ''});
      await remoteConfig.fetchAndActivate();

      final override = remoteConfig.getString(_apiBaseUrlKey).trim();
      return override.isEmpty ? null : override;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('RemoteConfigService: unavailable ($error)');
      }
      return null;
    }
  }
}
