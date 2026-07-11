import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/game_state.dart';
import '../engine/game_engine.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  // Auth
  static User? get currentUser => client.auth.currentUser;
  static String? get userId => currentUser?.id;

  static Future<AuthResponse> signInAnonymously() async {
    return client.auth.signInAnonymously();
  }



  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  // User profile
  static Future<void> upsertUser(String id, String displayName,
      {String? deviceId}) async {
    final data = <String, dynamic>{
      'id': id,
      'display_name': displayName,
    };
    if (deviceId != null) {
      data['device_id'] = deviceId;
    }
    await client.schema('wsw').from('users').upsert(data);
  }

  static Future<Map<String, dynamic>?> getUser(String id) async {
    final response =
        await client.schema('wsw').from('users').select().eq('id', id).maybeSingle();
    return response;
  }

  static Future<void> updateDisplayName(String id, String name) async {
    await client.schema('wsw').from('users').update({'display_name': name}).eq('id', id);
  }

  static Future<void> updateCardBack(String id, String cardBack) async {
    await client
        .schema('wsw')
        .from('users')
        .update({'selected_card_back': cardBack}).eq('id', id);
  }

  static Future<void> updateFcmToken(String id, String token) async {
    await client
        .schema('wsw')
        .from('users')
        .update({'fcm_token': token}).eq('id', id);
  }

  // Matches
  static String _generateJoinCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  static Future<Map<String, dynamic>> createMatch(String playerId) async {
    final response = await client
        .schema('wsw')
        .from('matches')
        .insert({'player1_id': playerId, 'status': 'waiting', 'join_code': _generateJoinCode()})
        .select()
        .single();

    final initialState = createInitialGameState();
    await client.schema('wsw').from('game_states').insert({
      'match_id': response['id'],
      'state': initialState.toJson(),
      'version': 0,
    });

    return response;
  }

  static Future<void> startBotMatch(String matchId) async {
    await client.schema('wsw').from('matches').update({
      'status': 'in_progress',
    }).eq('id', matchId);
  }

  static Future<Map<String, dynamic>?> findMatch(String joinCode) async {
    return client
        .schema('wsw')
        .from('matches')
        .select()
        .eq('join_code', joinCode.toUpperCase().trim())
        .eq('status', 'waiting')
        .maybeSingle();
  }

  static Future<void> joinMatch(String matchId, String playerId) async {
    await client.schema('wsw').from('matches').update({
      'player2_id': playerId,
      'status': 'in_progress',
    }).eq('id', matchId);
  }

  static Future<Map<String, dynamic>?> getMatch(String matchId) async {
    return client.schema('wsw').from('matches').select().eq('id', matchId).maybeSingle();
  }

  static Future<void> deleteMatch(String matchId) async {
    await client.schema('wsw').from('game_states').delete().eq('match_id', matchId);
    await client.schema('wsw').from('matches').delete().eq('id', matchId);
  }

  /// Returns all matches (active + completed) for a user, with player names
  /// and game state (for round count and winner) joined.
  static Future<List<Map<String, dynamic>>> getUserMatches(String userId) async {
    try {
      // Fetch matches with player display names via join
      final rows = await client
          .schema('wsw')
          .from('matches')
          .select(
            'id, status, join_code, created_at, finished_at, winner_id, '
            'player1_id, player2_id'
          )
          .or('player1_id.eq.$userId,player2_id.eq.$userId')
          .order('created_at', ascending: false)
          .limit(20);

      // Enrich each match with display names and game state
      final enriched = <Map<String, dynamic>>[];
      for (final row in rows) {
        final map = Map<String, dynamic>.from(row);

        // Fetch player names
        final p1Id = row['player1_id'] as String?;
        final p2Id = row['player2_id'] as String?;
        if (p1Id != null) {
          final p1 = await client.schema('wsw').from('users')
              .select('display_name').eq('id', p1Id).maybeSingle();
          map['p1_name'] = p1?['display_name'] as String? ?? 'Player 1';
        }
        if (p2Id != null) {
          final p2 = await client.schema('wsw').from('users')
              .select('display_name').eq('id', p2Id).maybeSingle();
          map['p2_name'] = p2?['display_name'] as String? ?? 'Player 2';
        }

        // Fetch game state for round number
        final gs = await client.schema('wsw').from('game_states')
            .select('state').eq('match_id', row['id'] as String).maybeSingle();
        if (gs != null) {
          final stateJson = gs['state'] as Map<String, dynamic>? ?? {};
          map['round'] = stateJson['round'] as int? ?? 0;
          map['game_winner'] = stateJson['gameWinner'] as String?;
        }

        enriched.add(map);
      }
      return enriched;
    } catch (_) {
      return [];
    }
  }

  /// Marks a match as completed and records the winner + finish timestamp.
  /// Call this AFTER recording any achievements but BEFORE final UI navigation.
  static Future<void> finishMatch(String matchId, String winnerId) async {
    await client.schema('wsw').from('matches').update({
      'status': 'completed',
      'winner_id': winnerId,
      'finished_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', matchId);
  }

  // Game State
  static Future<Map<String, dynamic>?> getGameState(String matchId) async {
    return client
        .schema('wsw')
        .from('game_states')
        .select()
        .eq('match_id', matchId)
        .maybeSingle();
  }

  static Future<bool> updateGameState(
      String gameStateId, GameState state, int currentVersion) async {
    try {
      final response = await client.schema('wsw').from('game_states').update({
        'state': state.toJson(),
        'version': currentVersion + 1,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', gameStateId).eq('version', currentVersion).select();

      if (response.isEmpty) {
        debugPrint('Concurrency conflict: State was modified by opponent.');
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('Error updating game state: $e');
      return false;
    }
  }

  static Future<void> resetGameState(
      String gameStateId, String matchId) async {
    final freshState = createInitialGameState();
    await client.schema('wsw').from('game_states').update({
      'state': freshState.toJson(),
      'version': 0,
    }).eq('id', gameStateId);

    await client.schema('wsw').from('matches').update({
      'status': 'in_progress',
      'winner_id': null,
    }).eq('id', matchId);
  }

  // Stats
  static Future<void> recordWin(String userId) async {
    await client.schema('wsw').rpc('increment_wins', params: {'user_id_param': userId});
  }

  static Future<void> recordLoss(String userId) async {
    await client.schema('wsw').rpc('increment_losses', params: {'user_id_param': userId});
  }

  static Future<List<Map<String, dynamic>>> getLeaderboard() async {
    return client
        .schema('wsw')
        .from('users')
        .select()
        .order('wins', ascending: false)
        .limit(50);
  }

  // Achievements
  static Future<List<Map<String, dynamic>>> getUserAchievements(
      String userId) async {
    return client
        .schema('wsw')
        .from('user_achievements')
        .select()
        .eq('user_id', userId);
  }

  static Future<void> unlockAchievement(
      String userId, String achievementId) async {
    await client.schema('wsw').from('user_achievements').upsert({
      'user_id': userId,
      'achievement_id': achievementId,
    });
  }

  // Online users
  static Future<List<Map<String, dynamic>>> getOnlineUsers() async {
    return client
        .schema('wsw')
        .from('users')
        .select('id, display_name')
        .limit(20);
  }

  // Realtime subscriptions
  static RealtimeChannel subscribeToMatch(
    String matchId,
    void Function(Map<String, dynamic>) onUpdate,
  ) {
    return client
        .channel('match-$matchId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'wsw',
          table: 'matches',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: matchId,
          ),
          callback: (payload) {
            onUpdate(payload.newRecord);
          },
        )
        .subscribe();
  }

  static RealtimeChannel subscribeToGameState(
    String matchId,
    void Function(Map<String, dynamic>) onUpdate,
  ) {
    return client
        .channel('game-$matchId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'wsw',
          table: 'game_states',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'match_id',
            value: matchId,
          ),
          callback: (payload) {
            onUpdate(payload.newRecord);
          },
        )
        .subscribe();
  }

  static void removeChannel(RealtimeChannel channel) {
    client.removeChannel(channel);
  }
}
