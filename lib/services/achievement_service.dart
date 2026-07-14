import '../engine/game_engine.dart';
import '../models/game_state.dart';
import '../models/playing_card.dart';
import 'supabase_service.dart';

/// Centralized achievement-unlock logic.
///
/// [checkMatchAchievements] is called after every in-game state transition
/// (both by the acting client and by clients that merely observe the
/// transition via realtime sync) and unlocks any MATCH-scope achievement
/// whose condition became true going from [before] to [after].
///
/// [checkGameAndPlayerAchievements] is called once when a match finishes and
/// evaluates the cumulative GAME-scope and PLAYER-scope achievements using
/// data queried from Supabase.
class AchievementService {
  /// [p1UserId]/[p2UserId] are the real user ids seated as Player 1/Player 2
  /// for this match (null for a bot seat — bots never unlock achievements).
  static void checkMatchAchievements(
    GameState before,
    GameState after, {
    String? p1UserId,
    String? p2UserId,
  }) {
    void unlock(String? userId, String achievementId) {
      if (userId == null) return;
      SupabaseService.unlockAchievement(userId, achievementId);
    }

    final wasWar = before.warDepth > 0;

    // ── Round dealt (idle → result, or warPending → warResult) ──────────
    final roundJustDealt =
        (before.phase == GamePhase.idle && after.phase == GamePhase.result) ||
            (before.phase == GamePhase.warPending &&
                after.phase == GamePhase.warResult);
    if (roundJustDealt &&
        after.p1BattleCard != null &&
        after.p2BattleCard != null) {
      final p1Card = after.p1BattleCard!;
      final p2Card = after.p2BattleCard!;

      if (p1Card.isJoker && p2Card.isJoker) {
        unlock(p1UserId, 'joker_clash');
        unlock(p2UserId, 'joker_clash');
      }
      if (getCardStatus(p1Card, after) == CardStatus.musketeer &&
          getCardStatus(p2Card, after) == CardStatus.musketeer) {
        unlock(p1UserId, 'musk_vs_musk');
        unlock(p2UserId, 'musk_vs_musk');
      }
    }

    // ── Trump suit just got set ──────────────────────────────────────────
    if (before.trumpSuit == null && after.trumpSuit != null) {
      unlock(p1UserId, 'trump_setter');
      unlock(p2UserId, 'trump_setter');
    }

    // ── War just started (idle result/warResult tie → warPending) ───────
    final warJustStarted = before.phase != GamePhase.warPending &&
        after.phase == GamePhase.warPending;
    if (warJustStarted) {
      if (before.muskRank == null && after.muskRank != null) {
        unlock(p1UserId, 'musk_creator');
        unlock(p2UserId, 'musk_creator');
      }
      if (after.maxWarChainDepth >= 2) {
        unlock(p1UserId, 'double_war');
        unlock(p2UserId, 'double_war');
      }
      if (after.maxWarChainDepth >= 3) {
        unlock(p1UserId, 'triple_war');
        unlock(p2UserId, 'triple_war');
      }
    }

    // ── First War fully resolved (warPending → warResult, first ever) ───
    final warJustResolved = before.phase == GamePhase.warPending &&
        after.phase == GamePhase.warResult;
    if (warJustResolved && after.warsTriggered == 1) {
      unlock(p1UserId, 'first_war');
      unlock(p2UserId, 'first_war');
    }

    // ── Musk-rank fully destroyed ─────────────────────────────────────
    if (after.muskRank != null &&
        (after.removedByRank[after.muskRank] ?? 0) >= 4) {
      unlock(p1UserId, 'musk_destroyer');
      unlock(p2UserId, 'musk_destroyer');
    }

    // ── War of attrition (4+ cards burned via war) ───────────────────
    if (after.removedCardIds.length >= 4) {
      unlock(p1UserId, 'war_of_attrition');
      unlock(p2UserId, 'war_of_attrition');
    }

    // ── War monger (10+ wars triggered in one game) ──────────────────
    if (after.warsTriggered >= 10) {
      unlock(p1UserId, 'war_monger');
      unlock(p2UserId, 'war_monger');
    }

    // ── Second Wind received ─────────────────────────────────────────
    if (!before.secondWindUsed && after.secondWindUsed) {
      final recipientIsP1 = after.secondWindRecipient == 'Player 1';
      unlock(recipientIsP1 ? p1UserId : p2UserId, 'second_wind_receiver');
    }

    // ── Round/War just collected (result/warResult → idle) ──────────────
    final roundJustCollected =
        (before.phase == GamePhase.result || before.phase == GamePhase.warResult) &&
            before.lastResult != null &&
            before.lastResult != RoundResult.tie &&
            after.phase == GamePhase.idle;
    if (roundJustCollected) {
      final isP1Win = before.lastResult == RoundResult.p1Wins;
      final winnerUserId = isP1Win ? p1UserId : p2UserId;
      final winnerCard = isP1Win ? before.p1BattleCard : before.p2BattleCard;
      final loserFaceDown =
          isP1Win ? before.p2FaceDownCount : before.p1FaceDownCount;

      if (before.round == 1) unlock(winnerUserId, 'first_blood');

      if (winnerCard != null) {
        final status = getCardStatus(winnerCard, before);
        if (status == CardStatus.trump) unlock(winnerUserId, 'trump_win');
        if (status == CardStatus.musketeer) unlock(winnerUserId, 'musk_win');
        if (winnerCard.isJoker) unlock(winnerUserId, 'joker_wild');
      }

      if (isP1Win) {
        if (after.p1MaxTrumpStreak >= 5) unlock(p1UserId, 'trump_domination');
        if (after.p1WinStreak >= 10) unlock(p1UserId, 'lucky_streak');
        if (before.p1WasLowCards) unlock(p1UserId, 'comeback_kid');
        if (before.p1WasOneCard) unlock(p1UserId, 'cliffhanger');
        if (after.p1MaxCardsHeld >= 30) unlock(p1UserId, 'domination');
        if (after.p1MaxCardsHeld >= 40) unlock(p1UserId, 'supremacy');
        if (after.p1MaxCardsHeld >= 50) unlock(p1UserId, 'totality');
        if (wasWar && after.p1WarsWon == 1) unlock(p1UserId, 'war_winner');
        if (after.p1WarsWon >= 5) unlock(p1UserId, 'war_machine');
        if (wasWar && loserFaceDown == 0) unlock(p1UserId, 'ruthless');
      } else {
        if (after.p2MaxTrumpStreak >= 5) unlock(p2UserId, 'trump_domination');
        if (after.p2WinStreak >= 10) unlock(p2UserId, 'lucky_streak');
        if (before.p2WasLowCards) unlock(p2UserId, 'comeback_kid');
        if (before.p2WasOneCard) unlock(p2UserId, 'cliffhanger');
        if (after.p2MaxCardsHeld >= 30) unlock(p2UserId, 'domination');
        if (after.p2MaxCardsHeld >= 40) unlock(p2UserId, 'supremacy');
        if (after.p2MaxCardsHeld >= 50) unlock(p2UserId, 'totality');
        if (wasWar && after.p2WarsWon == 1) unlock(p2UserId, 'war_winner');
        if (after.p2WarsWon >= 5) unlock(p2UserId, 'war_machine');
        if (wasWar && loserFaceDown == 0) unlock(p2UserId, 'ruthless');
      }
    }

    // ── Game just ended ───────────────────────────────────────────────
    final gameJustEnded =
        before.phase != GamePhase.gameOver && after.phase == GamePhase.gameOver;
    if (gameJustEnded && after.gameWinner != null) {
      final winnerIsP1 = after.gameWinner == 'Player 1';
      final winnerUserId = winnerIsP1 ? p1UserId : p2UserId;

      if (after.warsTriggered == 0) unlock(winnerUserId, 'perfect_game');
      if (after.round < 20) unlock(winnerUserId, 'speed_demon');
      if (after.round >= 100) {
        unlock(p1UserId, 'marathon');
        unlock(p2UserId, 'marathon');
      }
      if (!after.secondWindUsed) unlock(winnerUserId, 'clean_sweep');

      if (after.secondWindUsed) {
        final recipientIsWinner =
            after.secondWindRecipient == after.gameWinner;
        if (recipientIsWinner) {
          unlock(winnerUserId, 'second_wind_survivor');
        } else {
          unlock(winnerUserId, 'underdog');
        }
      }

      // Musketeer Master: the round that just ended the game (via
      // `_awardPot`) still has its battle cards on `before` since they are
      // cleared inside that same transition.
      final winnerFinalCard =
          winnerIsP1 ? before.p1BattleCard : before.p2BattleCard;
      if (winnerFinalCard != null &&
          getCardStatus(winnerFinalCard, before) == CardStatus.musketeer) {
        unlock(winnerUserId, 'musketeer_master');
      }

      final winnerTotal = winnerIsP1
          ? after.p1Deck.length + after.p1Discard.length
          : after.p2Deck.length + after.p2Discard.length;
      if (winnerTotal >= 54) unlock(winnerUserId, 'flawless_victory');
    }
  }

  /// Evaluates GAME-scope (cumulative wins) and PLAYER-scope (bounty)
  /// achievements. Call once per match completion, after stats have been
  /// recorded (wins/losses/games_played).
  static Future<void> checkGameAndPlayerAchievements(
    String userId, {
    List<Map<String, dynamic>>? summaries,
  }) async {
    final matchSummaries =
        summaries ?? await SupabaseService.getUserMatchSummaries(userId);

    final wins = matchSummaries
        .where((s) =>
            s['status'] == 'completed' && s['winner_id'] == userId)
        .length;
    final gamesPlayed =
        matchSummaries.where((s) => s['status'] == 'completed').length;

    if (wins >= 10) SupabaseService.unlockAchievement(userId, 'war_veteran');
    if (wins >= 50) SupabaseService.unlockAchievement(userId, 'war_hero');
    if (gamesPlayed >= 250) {
      SupabaseService.unlockAchievement(userId, 'veteran_player');
    }

    // Daily Orders: played at least one game today.
    final now = DateTime.now();
    final playedToday = matchSummaries.any((m) {
      final createdAt = m['created_at'] as String?;
      if (createdAt == null) return false;
      final d = DateTime.parse(createdAt).toLocal();
      return d.year == now.year && d.month == now.month && d.day == now.day;
    });
    if (playedToday) {
      SupabaseService.unlockAchievement(userId, 'daily_mission');
    }

    // Social Butterfly: 5+ distinct opponents (bots/null excluded).
    final distinctOpponents = matchSummaries
        .map((m) => m['opponent_id'] as String?)
        .where((id) => id != null)
        .toSet();
    if (distinctOpponents.length >= 5) {
      SupabaseService.unlockAchievement(userId, 'social_butterfly');
    }

    // Card Collector: held 40+ cards at once in 5+ different games.
    final gamesWith40Plus = matchSummaries
        .where((m) => (m['max_cards_held'] as int? ?? 0) >= 40)
        .length;
    if (gamesWith40Plus >= 5) {
      SupabaseService.unlockAchievement(userId, 'card_collector');
    }

    // Dedicated Soldier: played on 7 consecutive calendar days (incl. today).
    final playDates = matchSummaries
        .map((m) {
          final createdAt = m['created_at'] as String?;
          if (createdAt == null) return null;
          final d = DateTime.parse(createdAt).toLocal();
          return DateTime(d.year, d.month, d.day);
        })
        .whereType<DateTime>()
        .toSet();
    var streak = 0;
    var cursor = DateTime(now.year, now.month, now.day);
    while (playDates.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    if (streak >= 7) {
      SupabaseService.unlockAchievement(userId, 'dedicated_player');
    }
  }
}
