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

  const GameNotifierState({
    this.gameState,
    this.gameStateId,
    this.matchId,
    this.version = 0,
    this.playerNum = 1,
    this.error,
    this.isLoading = false,
  });

  GameNotifierState copyWith({
    GameState? gameState,
    String? gameStateId,
    String? matchId,
    int? version,
    int? playerNum,
    String? error,
    bool? isLoading,
  }) {
    return GameNotifierState(
      gameState: gameState ?? this.gameState,
      gameStateId: gameStateId ?? this.gameStateId,
      matchId: matchId ?? this.matchId,
      version: version ?? this.version,
      playerNum: playerNum ?? this.playerNum,
      error: error,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class GameNotifier extends StateNotifier<GameNotifierState> {
  RealtimeChannel? _gameChannel;

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

      _subscribeToGameState(matchId);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
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
  }

  Future<void> newGame() async {
    if (state.gameStateId == null || state.matchId == null) return;

    final freshState = createInitialGameState();
    state = state.copyWith(gameState: freshState, version: 0);

    await SupabaseService.resetGameState(state.gameStateId!, state.matchId!);
  }

  void leaveGame() {
    _gameChannel?.unsubscribe();
    _gameChannel = null;
    state = const GameNotifierState();
  }

  @override
  void dispose() {
    _gameChannel?.unsubscribe();
    super.dispose();
  }
}

final gameProvider =
    StateNotifierProvider<GameNotifier, GameNotifierState>((ref) {
  return GameNotifier();
});
