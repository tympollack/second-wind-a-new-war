import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/game_state.dart';
import '../engine/game_engine.dart';
import '../services/supabase_service.dart';

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
    );
  }
}

class GameNotifier extends StateNotifier<GameNotifierState> {
  RealtimeChannel? _gameChannel;
  Timer? _botTimer;
  final _random = Random();

  GameNotifier() : super(const GameNotifierState());

  Future<void> loadGame(String matchId, String userId) async {
    state = state.copyWith(isLoading: true, matchId: matchId);

    try {
      final match = await SupabaseService.getMatch(matchId);
      if (match != null) {
        final pNum = match['player1_id'] == userId ? 1 : 2;
        state = state.copyWith(playerNum: pNum);
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
      state = state.copyWith(
        gameState: newState,
        version: payload['version'] as int,
      );
    });
  }

  Future<void> advance(String userId) async {
    final gs = state.gameState;
    if (gs == null || !canAdvance(gs) || state.gameStateId == null) return;

    final playerLabel = 'Player ${state.playerNum}';
    final nextState = advanceGame(gs, playerLabel);

    state = state.copyWith(
      gameState: nextState,
      version: state.version + 1,
    );

    try {
      await SupabaseService.updateGameState(
        state.gameStateId!,
        nextState,
        state.version,
      );
    } catch (e) {
      state = state.copyWith(error: 'Failed to sync game state');
    }

    if (state.isBotMatch && nextState.phase != GamePhase.gameOver) {
      _scheduleBotMove();
    }
  }

  /// Collect cards from the current result, then play the next round in one action.
  /// Used when the UI merges "collect" and "play next" into a single tap.
  Future<void> collectAndPlay(String userId) async {
    final gs = state.gameState;
    if (gs == null || state.gameStateId == null) return;

    // First advance: collect cards (result/warResult → idle)
    if (!canAdvance(gs)) return;
    final playerLabel = 'Player ${state.playerNum}';
    final collected = advanceGame(gs, playerLabel);

    if (collected.phase == GamePhase.gameOver) {
      state = state.copyWith(
        gameState: collected,
        version: state.version + 1,
      );
      _syncState(collected);
      return;
    }

    // Second advance: play next round (idle → result)
    if (!canAdvance(collected)) {
      state = state.copyWith(
        gameState: collected,
        version: state.version + 1,
      );
      _syncState(collected);
      return;
    }
    final nextRound = advanceGame(collected, playerLabel);

    state = state.copyWith(
      gameState: nextRound,
      version: state.version + 2,
    );
    _syncState(nextRound);

    if (state.isBotMatch && nextRound.phase != GamePhase.gameOver) {
      _scheduleBotMove();
    }
  }

  Future<void> _syncState(GameState gs) async {
    try {
      await SupabaseService.updateGameState(
        state.gameStateId!,
        gs,
        state.version,
      );
    } catch (e) {
      state = state.copyWith(error: 'Failed to sync game state');
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
    final nextState = advanceGame(gs, botPlayerLabel);

    state = state.copyWith(
      gameState: nextState,
      version: state.version + 1,
    );

    SupabaseService.updateGameState(
      state.gameStateId!,
      nextState,
      state.version,
    ).catchError((e) {
      state = state.copyWith(error: 'Failed to sync game state');
      return null;
    });
  }

  Future<void> newGame() async {
    if (state.gameStateId == null || state.matchId == null) return;

    final freshState = createInitialGameState();
    state = state.copyWith(gameState: freshState, version: 0);

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
  return GameNotifier();
});
