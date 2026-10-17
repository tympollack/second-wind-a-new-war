class SupabaseConfig {
  static const _envUrl = String.fromEnvironment('SUPABASE_URL');
  static const _envKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static String get url {
    if (_envUrl.isEmpty) {
      throw Exception('SUPABASE_URL is not defined. Use --dart-define=SUPABASE_URL=...');
    }
    return _envUrl;
  }

  static String get anonKey {
    if (_envKey.isEmpty) {
      throw Exception('SUPABASE_ANON_KEY is not defined. Use --dart-define=SUPABASE_ANON_KEY=...');
    }
    return _envKey;
  }
}
