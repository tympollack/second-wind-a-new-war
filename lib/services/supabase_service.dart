import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/game_state.dart';
import '../engine/game_engine.dart';
import 'bot_service.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  // Auth
  static User? get currentUser => client.auth.currentUser;
  static String? get userId => currentUser?.id;

  static Future<AuthResponse> signInAnonymously() async {
    return client.auth.signInAnonymously();
  }

  static Future<AuthResponse> signInWithEmail(
      String email, String password) async {
    return client.auth.signInWithPassword(email: email, password: password);
  }

  static Future<AuthResponse> signUpWithEmail(
      String email, String password) async {
    return client.auth.signUp(email: email, password: password);
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
    await client.from('users').upsert(data);
  }

  static Future<Map<String, dynamic>?> getUser(String id) async {
    final response =
        await client.from('users').select().eq('id', id).maybeSingle();
    return response;
  }

  static Future<void> updateDisplayName(String id, String name) async {
    await client.from('users').update({'display_name': name}).eq('id', id);
  }

  static Future<void> updateCardBack(String id, String cardBack) async {
    await client
        .from('users')
        .update({'selected_card_back': cardBack}).eq('id', id);
  }

  // Matches
  static Future<Map<String, dynamic>> createMatch(String playerId) async {
    final response = await client
        .from('matches')
        .insert({'player1_id': playerId, 'status': 'waiting'})
        .select()
        .single();

    final initialState = createInitialGameState();
    await client.from('game_states').insert({
      'match_id': response['id'],
      'state': initialState.toJson(),
      'version': 0,
    });

    return response;
  }

  static Future<void> startBotMatch(String matchId, String botName) async {
    // Ensure bot user exists
    await client.from('users').upsert({
      'id': BotService.botUserId,
      'display_name': botName,
    });

    // Join the match as bot
    await client.from('matches').update({
      'player2_id': BotService.botUserId,
      'status': 'in-progress',
    }).eq('id', matchId);
  }

  static Future<Map<String, dynamic>?> findMatch(String joinCode) async {
    return client
        .from('matches')
        .select()
        .eq('join_code', joinCode.toUpperCase().trim())
        .eq('status', 'waiting')
        .maybeSingle();
  }

  static Future<void> joinMatch(String matchId, String playerId) async {
    await client.from('matches').update({
      'player2_id': playerId,
      'status': 'in-progress',
    }).eq('id', matchId);
  }

  static Future<Map<String, dynamic>?> getMatch(String matchId) async {
    return client.from('matches').select().eq('id', matchId).maybeSingle();
  }

  static Future<void> deleteMatch(String matchId) async {
    await client.from('game_states').delete().eq('match_id', matchId);
    await client.from('matches').delete().eq('id', matchId);
  }

  // Game State
  static Future<Map<String, dynamic>?> getGameState(String matchId) async {
    return client
        .from('game_states')
        .select()
        .eq('match_id', matchId)
        .maybeSingle();
  }

  static Future<void> updateGameState(
      String gameStateId, GameState state, int version) async {
    await client.from('game_states').update({
      'state': state.toJson(),
      'version': version,
    }).eq('id', gameStateId);
  }

  static Future<void> resetGameState(
      String gameStateId, String matchId) async {
    final freshState = createInitialGameState();
    await client.from('game_states').update({
      'state': freshState.toJson(),
      'version': 0,
    }).eq('id', gameStateId);

    await client.from('matches').update({
      'status': 'in-progress',
      'winner_id': null,
    }).eq('id', matchId);
  }

  // Stats
  static Future<void> recordWin(String userId) async {
    await client.rpc('increment_wins', params: {'user_id_param': userId});
  }

  static Future<void> recordLoss(String userId) async {
    await client.rpc('increment_losses', params: {'user_id_param': userId});
  }

  static Future<List<Map<String, dynamic>>> getLeaderboard() async {
    return client
        .from('users')
        .select()
        .order('wins', ascending: false)
        .limit(50);
  }

  // Achievements
  static Future<List<Map<String, dynamic>>> getUserAchievements(
      String userId) async {
    return client
        .from('user_achievements')
        .select()
        .eq('user_id', userId);
  }

  static Future<void> unlockAchievement(
      String userId, String achievementId) async {
    await client.from('user_achievements').upsert({
      'user_id': userId,
      'achievement_id': achievementId,
    });
  }

  // Online users
  static Future<List<Map<String, dynamic>>> getOnlineUsers() async {
    return client
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
          schema: 'public',
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
          schema: 'public',
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
