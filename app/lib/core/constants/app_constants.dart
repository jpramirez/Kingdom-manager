class AppConstants {
  AppConstants._();

  static const String appName = 'Household';
  static const String apiBaseUrl = 'http://10.0.2.2:8082/api/v1'; // Android emulator → host
  static const String wsBaseUrl = 'ws://10.0.2.2:8082/ws';

  // Storage keys
  static const String keyAccessToken = 'access_token';
  static const String keyRefreshToken = 'refresh_token';
  static const String keySelectedLocale = 'selected_locale';
  static const String keyActiveHouseholdId = 'active_household_id';
}
