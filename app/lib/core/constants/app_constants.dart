import 'dart:io' show Platform;

class AppConstants {
  AppConstants._();

  static const String appName = 'Household';

  // Override via --dart-define=API_HOST=your-host:port
  static const String _apiHost = String.fromEnvironment(
    'API_HOST',
    defaultValue: '',
  );

  static String get _resolvedHost {
    if (_apiHost.isNotEmpty) return _apiHost;
    // Auto-detect: Android emulator uses 10.0.2.2, others use localhost
    return Platform.isAndroid ? '10.0.2.2:8888' : 'localhost:8888';
  }

  static String get apiBaseUrl => 'http://$_resolvedHost/api/v1';
  static String get wsBaseUrl => 'ws://$_resolvedHost/ws';

  // Storage keys
  static const String keyAccessToken = 'access_token';
  static const String keyRefreshToken = 'refresh_token';
  static const String keySelectedLocale = 'selected_locale';
  static const String keyActiveHouseholdId = 'active_household_id';
}
