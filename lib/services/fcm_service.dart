import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'supabase_service.dart';

class FcmService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Initializes FCM permissions, token generation, and token refresh listeners.
  /// Should be called after the user is authenticated.
  static Future<void> initialize(String userId) async {
    // 1. Request permissions (especially required for iOS)
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized || 
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      
      // 2. Retrieve the initial token
      try {
        // For iOS, the APNs token must be available before we can get the FCM token
        if (Platform.isIOS) {
          await _messaging.getAPNSToken();
        }
        
        final String? token = await _messaging.getToken();
        if (token != null) {
          await SupabaseService.updateFcmToken(userId, token);
        }
      } catch (e) {
        // Token retrieval can fail in some emulator configurations or without APNs
      }

      // 3. Listen for token refreshes
      _messaging.onTokenRefresh.listen((newToken) {
        SupabaseService.updateFcmToken(userId, newToken);
      });

      // 4. (Optional) Listen to foreground messages if we want to show a custom snackbar
      // FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      //   print('Got a message whilst in the foreground!');
      //   print('Message data: ${message.data}');
      //   if (message.notification != null) {
      //     print('Message also contained a notification: ${message.notification}');
      //   }
      // });
    }
  }
}
