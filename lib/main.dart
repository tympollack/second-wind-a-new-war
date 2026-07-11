import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/lobby/lobby_screen.dart';
import 'dart:convert';
import 'utils/sso/sso_cookie.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      // ignore: deprecated_member_use
      anonKey: SupabaseConfig.anonKey,
    );

    if (kIsWeb) {
      try {
        final uri = Uri.parse(SupabaseConfig.url);
        final projectRef = uri.host.split('.').first;
        final sessionJsonStr = await getSsoSessionJson(projectRef);
        
        if (sessionJsonStr != null) {
          String decoded = sessionJsonStr;
          if (!sessionJsonStr.startsWith('{') && !sessionJsonStr.startsWith('[')) {
            // Assume base64url encoded
            decoded = utf8.decode(base64Url.decode(base64Url.normalize(sessionJsonStr)));
          }
          final dynamic data = jsonDecode(decoded);
          String? refreshToken;
          if (data is List && data.length > 1) {
            refreshToken = data[1]?.toString();
          } else if (data is Map) {
            refreshToken = data['refresh_token']?.toString();
          }
          
          if (refreshToken != null) {
            final auth = Supabase.instance.client.auth;
            if (auth.currentSession == null) {
               await auth.setSession(refreshToken);
            }
          }
        }
      } catch (e) {
        debugPrint('SSO Cookie parsing error: $e');
      }
    }
  } catch (e) {
    debugPrint('Supabase init error: $e');
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }

  runApp(const ProviderScope(child: WarSecondWindApp()));
}

class WarSecondWindApp extends ConsumerWidget {
  const WarSecondWindApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return MaterialApp(
      title: 'War: Second Wind',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.getLightTheme(settings.primaryColorOverride),
      darkTheme: AppTheme.getDarkTheme(settings.primaryColorOverride),
      themeMode: settings.themeMode,
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    if (authState.user != null) {
      return const LobbyScreen();
    }

    return const AuthScreen();
  }
}
