import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;

/// Where the Spring Boot API is. Set it at build time with `--dart-define=API_BASE_URL=...`:
///
/// * Flutter web, development: nothing needed — `http://localhost:8083`.
/// * Android emulator, development: nothing needed — `http://10.0.2.2:8083` (the host machine).
/// * Physical phone, development: the computer's LAN address, e.g.
///   `flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8083`
///   (same Wi-Fi network; allow port 8083 through the computer's firewall).
/// * Release builds: always pass the production HTTPS address, e.g.
///   `flutter build apk --dart-define=API_BASE_URL=https://api.example.lk`.
///   A release build without it has no development fallback and says so when it cannot connect.
class AppConfig {
  AppConfig._();

  static const String _override = String.fromEnvironment('API_BASE_URL');

  /// True when this build was given an API address, or is a development build that has a default.
  static bool get isConfigured => _override.isNotEmpty || !kReleaseMode;

  static String get apiBaseUrl =>
      (_override.isNotEmpty
              ? _override
              : kReleaseMode
              // Never guess in a release build: the development hosts below only exist on a dev machine.
              ? ''
              : kIsWeb
              ? 'http://localhost:8083'
              : 'http://10.0.2.2:8083')
          .replaceAll(RegExp(r'/+$'), '');

  /// Uploaded files are served by the API under /api/...; make them absolute.
  static String? mediaUrl(String? url) =>
      url != null && url.startsWith('/api/') ? '$apiBaseUrl$url' : url;
}
