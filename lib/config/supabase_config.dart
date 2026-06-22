class SupabaseConfig {
  static const _envUrl = String.fromEnvironment('SUPABASE_URL');
  static const _envKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static const _fallbackUrl = 'https://rsrocfnczlzswlbenaqt.supabase.co';
  static const _fallbackKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
      'eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJzcm9jZm5jemx6c3dsYmVuYXF0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE5OTExMzksImV4cCI6MjA5NzU2NzEzOX0.'
      'oUOlId8jRT9ExlhLy7NHuKpKzNw6--H2TaD6ogElP1Y';

  static String get url => _envUrl.isNotEmpty ? _envUrl : _fallbackUrl;
  static String get anonKey => _envKey.isNotEmpty ? _envKey : _fallbackKey;
}
