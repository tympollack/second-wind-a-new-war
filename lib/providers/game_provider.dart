import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/game_state.dart';
import '../engine/game_engine.dart';
import '../services/supabase_service.dart';
import '../services/hub_api_service.dart';
import '../services/achievement_service.dart';
import 'settings_provider.dart';

class GameNotifierState {
  final GameState? gameState;
  final String? gameStateId;
  final String? matchId;
  final int version;
  final int playerNum;
  final String? error;
  final bool isLoading;
  final bool isBotMatch;
  final String? botName;
  final bool resultSubmitted;
  final String? player1Id;
  final String? player2Id;

  const GameNotifierState({
    this.gameState,
    this.gameStateId,
    this.matchId,
    this.version = 0,
    this.playerNum = 1,
    this.error,
    this.isLoading = false,
    this.isBotMatch = false,
    this.botName,
    this.resultSubmitted = false,
    this.player1Id,
    this.player2Id,
  });

  GameNotifierState copyWith({
    GameState? gameState,
    String? gameStateId,
    String? matchId,
    int? version,
    int? playerNum,
    String? error,
    bool? isLoading,
    bool? isBotMatch,
    String? botName,
    bool? resultSubmitted,
    String? player1Id,
    String? player2Id,
  }) {
    return GameNotifierState(
      gameState: gameState ?? this.gameState,
      gameStateId: gameStateId ?? this.gameStateId,
      matchId: matchId ?? this.matchId,
      version: version ?? this.version,
      playerNum: playerNum ?? this.playerNum,
      error: error,
      isLoading: isLoading ?? this.isLoading,
      isBotMatch: isBotMatch ?? this.isBotMatch,
      botName: botName ?? this.botName,
      resultSubmitted: resultSubmitted ?? this.resultSubmitted,
      player1Id: player1Id ?? this.player1Id,
      player2Id: player2Id ?? this.player2Id,
    );
  }
}

class GameNotifier extends StateNotifier<GameNotifierState> {
  final Ref ref;
  RealtimeChannel? _gameChannel;
  Timer? _botTimer;
  final _random = Random();

  GameNotifier(this.ref) : super(const GameNotifierState());

  Future<void> loadGame(String matchId, String userId) async {
    state = state.copyWith(isLoading: true, matchId: matchId);

    try {
      final match = await SupabaseService.getMatch(matchId);
      if (match != null) {
        final pNum = match['player1_id'] == userId ? 1 : 2;
        state = state.copyWith(
          playerNum: pNum,
          player1Id: match['player1_id'] as String?,
          player2Id: match['player2_id'] as String?,
        );
      }

      final gs = await SupabaseService.getGameState(matchId);
      if (gs == null) {
        state = state.copyWith(isLoading: false, error: 'Game state not found');
        return;
      }

      final gameState =
          GameState.fromJson(gs['state'] as Map<String, dynamic>);
      state = state.copyWith(
        gameState: gameState,
        gameStateId: gs['id'] as String,
        version: gs['version'] as int,
        isLoading: false,
      );

      if (!state.isBotMatch) {
        _subscribeToGameState(matchId);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadBotGame(String matchId, String userId,
      String botName) async {
    state = state.copyWith(
      isBotMatch: true,
      botName: botName,
    );
    await loadGame(matchId, userId);
  }

  void _subscribeToGameState(String matchId) {
    _gameChannel?.unsubscribe();
    _gameChannel = SupabaseService.subscribeToGameState(matchId, (payload) {
      final newState =
          GameState.fromJson(payload['state'] as Map<String, dynamic>);
      final oldState = state.gameState;
      if (oldState != null) {
        _handleHaptics(oldState, newState);
        _checkAchievements(oldState, newState);
      }
      state = state.copyWith(
        gameState: newState,
        version: payload['version'] as int,
      );
      // The passive client never calls advance()/collectAndPlay(), so game-
      // over detection (and the stats/achievement recording that depends on
      // it) must also happen here when the state syncs in via realtime.
      if (oldState != null &&
          oldState.phase != GamePhase.gameOver &&
          newState.phase == GamePhase.gameOver) {
        unawaited(_maybeReportMatchResult(newState));
      }
    });
  }

  void _checkAchievements(GameState before, GameState after) {
    AchievementService.checkMatchAchievements(
      before,
      after,
      p1UserId: state.player1Id,
      p2UserId: state.isBotMatch ? null : state.player2Id,
    );
  }

  Future<void> advance(String userId) async {
    final gs = state.gameState;
    if (gs == null || !canAdvance(gs) || state.gameStateId == null) return;

    final playerLabel = 'Player ${state.playerNum}';
    final nextState = advanceGame(gs, playerLabel);

    final currentVersion = state.version;

    _handleHaptics(gs, nextState);
    _checkAchievements(gs, nextState);

    state = state.copyWith(
      gameState: nextState,
      version: currentVersion + 1,
    );

    final success = await SupabaseService.updateGameState(
      state.gameStateId!,
      nextState,
      currentVersion,
    );

    if (!success) {
      state = state.copyWith(
        gameState: gs,
        version: currentVersion,
        error: 'Conflict: move rejected by server',
      );
      return;
    }

    if (nextState.phase == GamePhase.gameOver) {
      await _maybeReportMatchResult(nextState);
    } else {
      _checkBotTurn();
    }
  }

  Future<void> collectAndPlay(String userId) async {
    final gs = state.gameState;
    if (gs == null || state.gameStateId == null) return;

    // First advance: collect cards (result/warResult → idle)
    if (!canAdvance(gs)) return;
    final playerLabel = 'Player ${state.playerNum}';
    final currentVersion = state.version;
    final collected = advanceGame(gs, playerLabel);

    _handleHaptics(gs, collected);
    _checkAchievements(gs, collected);

    if (collected.phase == GamePhase.gameOver) {
      state = state.copyWith(
        gameState: collected,
        version: currentVersion + 1,
      );
      final success = await SupabaseService.updateGameState(state.gameStateId!, collected, currentVersion);
      if (!success) {
        state = state.copyWith(gameState: gs, version: currentVersion);
        return;
      }
      await _maybeReportMatchResult(collected);
      return;
    }

    // Second advance: play next round (idle → result)
    if (!canAdvance(collected)) {
      state = state.copyWith(
        gameState: collected,
        version: currentVersion + 1,
      );
      final success = await SupabaseService.updateGameState(state.gameStateId!, collected, currentVersion);
      if (!success) {
        state = state.copyWith(gameState: gs, version: currentVersion);
      }
      return;
    }
    
    final nextRound = advanceGame(collected, playerLabel);

    _handleHaptics(collected, nextRound);
    _checkAchievements(collected, nextRound);

    state = state.copyWith(
      gameState: nextRound,
      version: currentVersion + 1,
    );
    final success = await SupabaseService.updateGameState(state.gameStateId!, nextRound, currentVersion);
    if (!success) {
      state = state.copyWith(gameState: gs, version: currentVersion);
      return;
    }

    if (nextRound.phase == GamePhase.gameOver) {
      await _maybeReportMatchResult(nextRound);
    } else {
      _checkBotTurn();
    }
  }

  void _handleHaptics(GameState oldState, GameState newState) {
    if (!ref.read(settingsProvider).hapticsEnabled) return;

    if (oldState.phase != newState.phase) {
      if (newState.phase == GamePhase.warPending) {
        Future.delayed(const Duration(milliseconds: 400), () {
          HapticFeedback.heavyImpact();
          Future.delayed(const Duration(milliseconds: 150), () => HapticFeedback.lightImpact());
          Future.delayed(const Duration(milliseconds: 300), () => HapticFeedback.lightImpact());
          Future.delayed(const Duration(milliseconds: 450), () => HapticFeedback.lightImpact());
        });
      } else if (newState.phase == GamePhase.result || newState.phase == GamePhase.warResult) {
        if (newState.lastResult != RoundResult.tie) {
          final pNum = state.playerNum;
          final weWon = (newState.lastResult == RoundResult.p1Wins && pNum == 1) ||
                        (newState.lastResult == RoundResult.p2Wins && pNum == 2);
          if (weWon) {
            HapticFeedback.lightImpact();
          }
        }
      }
    }
  }

  void _checkBotTurn() {
    if (!state.isBotMatch) return;
    final gs = state.gameState;
    if (gs == null) return;
    final botNum = state.playerNum == 1 ? 2 : 1;
    final botReady = botNum == 1 ? gs.p1Ready : gs.p2Ready;

    bool shouldAct = false;
    if (gs.phase == GamePhase.idle || gs.phase == GamePhase.warPending) {
      if (!botReady) shouldAct = true;
    } else if (gs.phase == GamePhase.result || gs.phase == GamePhase.warResult) {
      if (gs.lastResult == RoundResult.tie) {
        if (!botReady) shouldAct = true;
      } else {
        final botWon = (gs.lastResult == RoundResult.p1Wins && botNum == 1) ||
            (gs.lastResult == RoundResult.p2Wins && botNum == 2);
        if (botWon) shouldAct = true;
      }
    }

    if (shouldAct) {
      _scheduleBotMove();
    }
  }

  void _scheduleBotMove() {
    _botTimer?.cancel();
    final delay = 800 + _random.nextInt(1200);
    _botTimer = Timer(Duration(milliseconds: delay), () {
      _executeBotMove();
    });
  }

  void _executeBotMove() {
    final gs = state.gameState;
    if (gs == null || state.gameStateId == null) return;
    if (gs.phase == GamePhase.gameOver) return;
    if (!canAdvance(gs)) return;

    final botPlayerLabel = state.playerNum == 1 ? 'Player 2' : 'Player 1';
    final currentVersion = state.version;
    final nextState = advanceGame(gs, botPlayerLabel);

    _handleHaptics(gs, nextState);
    _checkAchievements(gs, nextState);

    state = state.copyWith(
      gameState: nextState,
      version: currentVersion + 1,
    );

    SupabaseService.updateGameState(
      state.gameStateId!,
      nextState,
      currentVersion,
    ).then((success) async {
      if (!success) {
        state = state.copyWith(gameState: gs, version: currentVersion);
      } else if (nextState.phase == GamePhase.gameOver) {
        await _maybeReportMatchResult(nextState);
      } else {
        _checkBotTurn();
      }
    });
  }

  /// Reports the completed match to the SunShade Hub exactly once per match.
  /// Never throws — HubApiService already swallows and logs its own errors.
  Future<void> _maybeReportMatchResult(GameState gs) async {
    if (state.resultSubmitted) return;
    state = state.copyWith(resultSubmitted: true);

    final didWin = gs.gameWinner == 'Player ${state.playerNum}';
    final opponentName = state.isBotMatch
        ? (state.botName ?? 'Bot Opponent')
        : 'Player ${state.playerNum == 1 ? 2 : 1}';

    HubApiService.submitMatchResult(
      opponentName: opponentName,
      result: didWin ? 'Victory' : 'Defeat',
      matchType: state.isBotMatch ? 'Bot Match' : 'PvP',
      moves: gs.round,
    );

    // Resolve the actual winner by user id so the match row and stats are
    // accurate even when the local player is not the one who ended the game.
    final userId = SupabaseService.userId;
    final matchId = state.matchId;
    final winnerId = gs.gameWinner == 'Player 1'
        ? state.player1Id
        : state.player2Id;

    if (matchId != null) {
      await SupabaseService.completeMatch(matchId, winnerId);
    }

    if (userId != null) {
      final summaries = await SupabaseService.getUserMatchSummaries(userId);
      await SupabaseService.refreshUserStats(userId, summaries: summaries);
      // Game-scope (cumulative wins) and player-scope (bounty) achievements
      // depend on the refreshed stats, so run this last.
      await AchievementService.checkGameAndPlayerAchievements(
        userId,
        summaries: summaries,
      );
    }

    // Close the match time window after achievements are stamped.
    if (matchId != null) {
      await SupabaseService.finalizeMatch(matchId);
    }
  }

  Future<void> newGame() async {
    if (state.gameStateId == null || state.matchId == null) return;

    final freshState = createInitialGameState();
    state = state.copyWith(
      gameState: freshState,
      version: 0,
      resultSubmitted: false,
    );

    await SupabaseService.resetGameState(state.gameStateId!, state.matchId!);
  }

  void leaveGame() {
    _botTimer?.cancel();
    _gameChannel?.unsubscribe();
    _gameChannel = null;
    state = const GameNotifierState();
  }

  @override
  void dispose() {
    _botTimer?.cancel();
    _gameChannel?.unsubscribe();
    super.dispose();
  }
}

final gameProvider =
    StateNotifierProvider<GameNotifier, GameNotifierState>((ref) {
  return GameNotifier(ref);
});
