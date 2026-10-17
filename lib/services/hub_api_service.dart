import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/hub_api_config.dart';

/// Handles outbound requests from the game client to the SunShade Hub
/// backend (Next.js on Vercel). Failures are logged and swallowed —
/// a Hub sync issue must never crash or block gameplay.
class HubApiService {
  static const String _matchIngestPath = 'matches/ingest';
  static const String _gameName = 'War: Second Wind';

  /// Reports a completed match's outcome to the Hub so it can be reflected
  /// in cross-game stats, the leaderboard, and the ecosystem activity log.
  static Future<void> submitMatchResult({
    required String opponentName,
    required String result,
    required String matchType,
    required int moves,
  }) async {
    final session = Supabase.instance.client.auth.currentSession;
    final token = session?.accessToken;

    if (token == null) {
      debugPrint(
        '[HubApiService] No active Supabase session — skipping match '
        'result submission.',
      );
      return;
    }

    final uri = Uri.parse('${HubApiConfig.baseUrl}$_matchIngestPath');
    final payload = <String, dynamic>{
      'game_name': _gameName,
      'opponent_name': opponentName,
      'result': result,
      'match_type': matchType,
      'moves': moves,
    };

    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          '[HubApiService] submitMatchResult failed: '
          '${response.statusCode} ${response.body}',
        );
      }
    } on SocketException catch (e) {
      debugPrint('[HubApiService] Network unavailable, skipping sync: $e');
    } on HttpException catch (e) {
      debugPrint('[HubApiService] HTTP error while syncing match result: $e');
    } on FormatException catch (e) {
      debugPrint('[HubApiService] Malformed response from Hub: $e');
    } catch (e) {
      debugPrint('[HubApiService] Unexpected error submitting match result: $e');
    }
  }
}
