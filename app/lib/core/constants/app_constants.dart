import 'dart:io' show Platform;

class AppConstants {
  AppConstants._();

  static const String appName = 'Household';

  // Production domain (tunnel to local server)
  static const String _prodHost = 'house.epy.digital';

  // Override via --dart-define=API_HOST=your-host:port
  static const String _apiHost = String.fromEnvironment(
    'API_HOST',
    defaultValue: '',
  );

  // Set to 'local' to force local dev mode: --dart-define=ENV=local
  static const String _env = String.fromEnvironment('ENV', defaultValue: '');

  static String get _resolvedHost {
    if (_apiHost.isNotEmpty) return _apiHost;
    if (_env == 'local') {
      return Platform.isAndroid ? '10.0.2.2:8888' : 'localhost:8888';
    }
    return _prodHost;
  }

  static bool get _isLocal => _env == 'local';

  static String get apiBaseUrl =>
      '${_isLocal ? 'http' : 'https'}://$_resolvedHost/api/v1';
  static String get wsBaseUrl =>
      '${_isLocal ? 'ws' : 'wss'}://$_resolvedHost/ws';

  // Storage keys
  static const String keyAccessToken = 'access_token';
  static const String keyRefreshToken = 'refresh_token';
  static const String keySelectedLocale = 'selected_locale';
  static const String keyActiveHouseholdId = 'active_household_id';
}
