import 'package:flutter_test/flutter_test.dart';
import 'package:war_second_wind/engine/game_engine.dart';
import 'package:war_second_wind/models/game_state.dart';

void main() {
  test('createInitialGameState deals correct card counts', () {
    final state = createInitialGameState();
    expect(state.p1Deck.length, 18);
    expect(state.p2Deck.length, 18);
    expect(state.secondWindDeck.length, 18);
    expect(state.phase, GamePhase.idle);
    expect(state.round, 0);
  });

  test('advanceGame plays a round', () {
    final state = createInitialGameState();
    final next = advanceGame(state, 'Player 1');
    expect(next.round, 1);
    expect(next.p1BattleCard, isNotNull);
    expect(next.p2BattleCard, isNotNull);
    expect(next.phase, GamePhase.result);
  });

  test('same rank triggers war (tie)', () {
    final state = createInitialGameState();
    final next = advanceGame(state, 'Player 1');
    if (next.lastResult == RoundResult.tie) {
      expect(next.roundReason, contains('WAR'));
    }
  });

  test('canAdvance returns correct values', () {
    final state = createInitialGameState();
    expect(canAdvance(state), true);
    state.phase = GamePhase.gameOver;
    expect(canAdvance(state), false);
  });
}
