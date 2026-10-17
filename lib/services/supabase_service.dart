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
  static Future<void> upsertUser(String id, String displayName) async {
    final data = <String, dynamic>{
      'id': id,
      'display_name': displayName,
    };
    await client.schema('wsw').from('users').upsert(data);
  }

  static Future<Map<String, dynamic>?> getUser(String id) async {
    final response =
        await client.schema('wsw').from('users').select().eq('id', id).maybeSingle();
    return response;
  }

  /// Returns the user profile with fresh stats computed from match/game state
  /// history. If the `users` table is missing any stats columns, the computed
  /// values are still returned so the UI can display them.
  static Future<Map<String, dynamic>?> getUserStats(
    String id, {
    List<Map<String, dynamic>>? summaries,
    Map<String, dynamic>? user,
  }) async {
    final userData = user ?? await getUser(id);
    final matchSummaries = summaries ?? await getUserMatchSummaries(id);

    int wins = 0;
    int losses = 0;
    int gamesPlayed = 0;
    int warsTriggered = 0;
    int secondWindsUsed = 0;

    for (final s in matchSummaries) {
      if (s['status'] == 'completed') {
        gamesPlayed++;
        final winnerId = s['winner_id'] as String?;
        if (winnerId == id) {
          wins++;
        } else {
          losses++;
        }
      }
      warsTriggered += (s['wars_triggered'] as int? ?? 0);
      if (s['second_wind_used'] == true) secondWindsUsed++;
    }

    final stats = {
      'wins': wins,
      'losses': losses,
      'games_played': gamesPlayed,
      'wars_triggered': warsTriggered,
      'second_winds_used': secondWindsUsed,
    };

    if (userData == null) return stats;

    final merged = Map<String, dynamic>.from(userData);
    for (final entry in stats.entries) {
      final existing = merged[entry.key];
      if (existing == null || (existing is int && entry.value > existing)) {
        merged[entry.key] = entry.value;
      }
    }
    return merged;
  }

  /// Recomputes a user's stats from the database and writes them back to the
  /// `users` row. This keeps the strategy screen and leaderboard in sync
  /// without requiring dedicated RPC functions.
  static Future<void> refreshUserStats(
    String userId, {
    List<Map<String, dynamic>>? summaries,
    Map<String, dynamic>? user,
  }) async {
    final stats = await getUserStats(userId, summaries: summaries, user: user);
    if (stats == null) return;

    try {
      await client.schema('wsw').from('users').update({
        'wins': stats['wins'],
        'losses': stats['losses'],
      }).eq('id', userId);
    } catch (e) {
      debugPrint('refreshUserStats wins/losses update failed: $e');
    }

    try {
      await client.schema('wsw').from('users').update({
        'games_played': stats['games_played'],
        'wars_triggered': stats['wars_triggered'],
        'second_winds_used': stats['second_winds_used'],
      }).eq('id', userId);
    } catch (e) {
      debugPrint('refreshUserStats extra stats update failed: $e');
    }
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
    final stateResult = await client.schema('wsw').from('game_states').insert({
      'match_id': response['id'],
      'state': initialState.toJson(),
      'version': 0,
    }).select();

    if (stateResult.isEmpty) {
      throw Exception('Failed to create game state record');
    }

    return response;
  }

  static Future<void> startBotMatch(String matchId) async {
    await client.schema('wsw').from('matches').update({
      'status': 'in_progress',
    }).eq('id', matchId);
  }

  static Future<String> joinMatchByCode(String joinCode, String playerId) async {
    final response = await client.schema('wsw').rpc('join_match_by_code', params: {
      'join_code_param': joinCode,
      'player_id_param': playerId,
    });
    return response as String;
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

  /// Lightweight cross-match summary used for game/player-scope achievement
  /// checks (distinct opponents, daily/weekly play streaks, peak card counts)
  /// without the display-name enrichment `getUserMatches` performs.
  static Future<List<Map<String, dynamic>>> getUserMatchSummaries(
      String userId) async {
    try {
      final rows = await client
          .schema('wsw')
          .from('matches')
          .select('id, status, created_at, winner_id, player1_id, player2_id')
          .or('player1_id.eq.$userId,player2_id.eq.$userId');

      final matchIds = rows.map((r) => r['id'] as String).toList();
      final gameStateMap = <String, Map<String, dynamic>>{};
      if (matchIds.isNotEmpty) {
        final gsRows = await client
            .schema('wsw')
            .from('game_states')
            .select('match_id, state')
            .inFilter('match_id', matchIds);
        for (final row in gsRows) {
          final matchId = row['match_id'] as String?;
          if (matchId != null) {
            gameStateMap[matchId] = row['state'] as Map<String, dynamic>? ?? {};
          }
        }
      }

      final summaries = <Map<String, dynamic>>[];
      for (final row in rows) {
        final p1Id = row['player1_id'] as String?;
        final isP1 = p1Id == userId;
        final opponentId =
            isP1 ? row['player2_id'] as String? : row['player1_id'] as String?;

        final stateJson = gameStateMap[row['id'] as String] ?? {};
        final maxCardsHeld = isP1
            ? stateJson['p1MaxCardsHeld'] as int? ?? 0
            : stateJson['p2MaxCardsHeld'] as int? ?? 0;
        final warsTriggered = stateJson['warsTriggered'] as int? ?? 0;
        final secondWindUsed = stateJson['secondWindUsed'] as bool? ?? false;
        final secondWindRecipient = stateJson['secondWindRecipient'] as String?;
        final userGotSecondWind = secondWindUsed &&
            ((isP1 && secondWindRecipient == 'Player 1') ||
                (!isP1 && secondWindRecipient == 'Player 2'));

        summaries.add({
          'match_id': row['id'],
          'status': row['status'],
          'created_at': row['created_at'],
          'winner_id': row['winner_id'],
          'opponent_id': opponentId,
          'max_cards_held': maxCardsHeld,
          'wars_triggered': warsTriggered,
          'second_wind_used': userGotSecondWind,
        });
      }
      return summaries;
    } catch (e) {
      debugPrint('getUserMatchSummaries error: $e');
      return [];
    }
  }

  /// Marks a match as completed and records the winner. This makes the match
  /// visible to stat/achievement queries (which rely on `status` and
  /// `winner_id`) without yet closing the time window for medals.
  static Future<void> completeMatch(String matchId, String? winnerId) async {
    await client.schema('wsw').from('matches').update({
      'status': 'completed',
      'winner_id': winnerId,
    }).eq('id', matchId);
  }

  /// Closes the match by writing the finish timestamp. Call this AFTER all
  /// achievements have been unlocked so `finished_at` is later than every
  /// `unlocked_at` written during the match.
  static Future<void> finalizeMatch(String matchId) async {
    await client.schema('wsw').from('matches').update({
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

  /// Increments the user's completed-games counter. Requires an
  /// `increment_games_played(user_id_param uuid)` RPC function in the `wsw`
  /// schema (mirrors `increment_wins`/`increment_losses`).
  static Future<void> incrementGamesPlayed(String userId) async {
    try {
      await client
          .schema('wsw')
          .rpc('increment_games_played', params: {'user_id_param': userId});
    } catch (e) {
      debugPrint('increment_games_played RPC failed: $e');
    }
  }

  /// Increments the user's total wars-triggered counter by [count].
  /// Requires an `increment_wars_triggered(user_id_param uuid, amount_param
  /// int)` RPC function in the `wsw` schema.
  static Future<void> incrementWarsTriggered(String userId, int count) async {
    if (count <= 0) return;
    try {
      await client.schema('wsw').rpc('increment_wars_triggered', params: {
        'user_id_param': userId,
        'amount_param': count,
      });
    } catch (e) {
      debugPrint('increment_wars_triggered RPC failed: $e');
    }
  }

  /// Increments the user's second-winds-used counter. Requires an
  /// `increment_second_winds(user_id_param uuid)` RPC function in the `wsw`
  /// schema.
  static Future<void> incrementSecondWindsUsed(String userId) async {
    try {
      await client
          .schema('wsw')
          .rpc('increment_second_winds', params: {'user_id_param': userId});
    } catch (e) {
      debugPrint('increment_second_winds RPC failed: $e');
    }
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
    final rows = await client
        .schema('wsw')
        .from('user_achievements')
        .select()
        .eq('user_id', userId)
        .order('unlocked_at', ascending: true, nullsFirst: false);
    final seen = <String>{};
    final result = <Map<String, dynamic>>[];
    for (final row in rows) {
      final id = row['achievement_id'] as String?;
      if (id == null || seen.contains(id)) continue;
      seen.add(id);
      result.add(row);
    }
    return result;
  }

  static Future<void> unlockAchievement(
      String userId, String achievementId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    try {
      final existing = await client
          .schema('wsw')
          .from('user_achievements')
          .select('unlocked_at')
          .eq('user_id', userId)
          .eq('achievement_id', achievementId)
          .maybeSingle();

      if (existing == null) {
        await client.schema('wsw').from('user_achievements').upsert(
          {
            'user_id': userId,
            'achievement_id': achievementId,
            'unlocked_at': now,
          },
          ignoreDuplicates: true,
        );
      }

      // Stamp any rows (including duplicates from previous upserts) that are
      // missing the unlocked_at timestamp.
      await client
          .schema('wsw')
          .from('user_achievements')
          .update({'unlocked_at': now})
          .eq('user_id', userId)
          .eq('achievement_id', achievementId)
          .isFilter('unlocked_at', null);
    } catch (e) {
      debugPrint('unlockAchievement error: $e');
    }
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
