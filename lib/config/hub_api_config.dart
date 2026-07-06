class HubApiConfig {
  static const _envBaseUrl = String.fromEnvironment('HUB_API_BASE_URL');

  /// Development Hub environment. Override at build time with:
  /// flutter run --dart-define=HUB_API_BASE_URL=https://your-env/api/
  static const _fallbackDevUrl = 'https://hub-dev.madeintheshade.wtf/api/';

  static String get baseUrl => _envBaseUrl.isNotEmpty ? _envBaseUrl : _fallbackDevUrl;
}
