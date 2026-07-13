/// Environment configuration resolved at build time via `--dart-define`.
///
/// Examples:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
///   flutter build appbundle --dart-define=API_BASE_URL=https://api.berdikari.id/api/v1
abstract final class Env {
  /// Base URL of the Berdikari API (berdikari-api, Laravel).
  ///
  /// Defaults to the local Docker Compose API as reachable from the iOS
  /// simulator. Android emulators must override with `10.0.2.2`.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000/api/v1',
  );
}
