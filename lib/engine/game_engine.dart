import '../models/playing_card.dart';
import '../models/game_state.dart';
import 'deck.dart';

GameState createInitialGameState() {
  final allCards = buildFullDeck();
  return GameState(
    p1Deck: allCards.sublist(0, 18),
    p2Deck: allCards.sublist(18, 36),
    secondWindDeck: allCards.sublist(36, 54),
    p1MaxCardsHeld: 18,
    p2MaxCardsHeld: 18,
  );
}

// Card Status Helpers

bool _isMuskCard(
    PlayingCard card, int? muskRank, Map<int, int> removedByRank) {
  if (muskRank == null || card.isJoker) return false;
  if ((removedByRank[muskRank] ?? 0) >= 4) return false;
  return card.rank == muskRank;
}

bool _isTrumpCard(PlayingCard card, Suit? trumpSuit) {
  if (trumpSuit == null || card.isJoker) return false;
  return card.suit == trumpSuit;
}

int _categoryOf(
    PlayingCard card, Suit? trumpSuit, int? muskRank, Map<int, int> removedByRank) {
  if (card.isJoker) return 3;
  if (_isMuskCard(card, muskRank, removedByRank)) return 2;
  if (_isTrumpCard(card, trumpSuit)) return 1;
  return 0;
}

CardStatus getCardStatus(PlayingCard card, GameState state) {
  if (card.isJoker) return CardStatus.joker;
  if (_isMuskCard(card, state.muskRank, state.removedByRank)) {
    return CardStatus.musketeer;
  }
  if (_isTrumpCard(card, state.trumpSuit)) return CardStatus.trump;
  return CardStatus.normal;
}

// "Always War" Rule: same numeric value = ALWAYS tie (War)
RoundResult _compareCards(PlayingCard a, PlayingCard b, Suit? trumpSuit,
    int? muskRank, Map<int, int> removedByRank) {
  if (a.rank == b.rank) return RoundResult.tie;

  final aLvl = _categoryOf(a, trumpSuit, muskRank, removedByRank);
  final bLvl = _categoryOf(b, trumpSuit, muskRank, removedByRank);

  if (aLvl != bLvl) {
    return aLvl > bLvl ? RoundResult.p1Wins : RoundResult.p2Wins;
  }

  return a.rank > b.rank ? RoundResult.p1Wins : RoundResult.p2Wins;
}

// Returns a neutral reason string with no player/perspective framing.
// For a tie this is the full display text (symmetric for both players).
// Otherwise this is just an optional special-condition suffix (e.g. "Joker
// beats all!"); the perspective-based sentence ("K beats 3" / "3 loses to K")
// is built client-side per viewer in the UI.
String _buildReason(PlayingCard p1, PlayingCard p2, RoundResult result,
    Suit? trumpSuit, int? muskRank, Map<int, int> removedByRank) {
  if (result == RoundResult.tie) return 'Equal rank \u2014 WAR!';
  final winner = result == RoundResult.p1Wins ? p1 : p2;
  final loser = result == RoundResult.p1Wins ? p2 : p1;
  if (winner.isJoker) return 'Joker beats all!';
  if (_isMuskCard(winner, muskRank, removedByRank)) {
    return 'Musketeer card dominates!';
  }
  if (_isTrumpCard(winner, trumpSuit) &&
      !_isTrumpCard(loser, trumpSuit) &&
      !winner.isJoker) {
    return 'Trump suit wins!';
  }
  return '';
}

void _maybeSetTrump(GameState state) {
  if (state.trumpSuit != null) return;
  final p1 = state.p1BattleCard;
  final p2 = state.p2BattleCard;
  if (p1 == null || p2 == null || p1.isJoker || p2.isJoker) return;
  if (p1.suit == p2.suit) {
    state.trumpSuit = p1.suit;
    state.statusBanner = 'Trump suit declared: ${p1.suitSymbol} ${p1.suit!.name.toUpperCase()}!';
  }
}

void _removeCardFromGame(GameState state, PlayingCard card) {
  state.removedCardIds.add(card.id);
  if (!card.isJoker) {
    final prev = state.removedByRank[card.rank] ?? 0;
    state.removedByRank[card.rank] = prev + 1;
  }
}

void _giveSecondWind(GameState state, int playerNum) {
  final deck = playerNum == 1 ? state.p1Deck : state.p2Deck;
  for (final c in state.secondWindDeck) {
    deck.add(c);
  }
  state.secondWindDeck = [];
  state.secondWindUsed = true;
  state.secondWindRecipient = 'Player $playerNum';
  state.statusBanner = 'Player $playerNum received the Second Wind!';
}

void _endGame(GameState state, String winner) {
  state.gameWinner = winner;
  state.phase = GamePhase.gameOver;
}

void _refillIfEmpty(GameState state, int playerNum) {
  final deck = playerNum == 1 ? state.p1Deck : state.p2Deck;
  final discard = playerNum == 1 ? state.p1Discard : state.p2Discard;
  if (deck.isEmpty && discard.isNotEmpty) {
    deck.addAll(shuffleList(discard));
    discard.clear();
    state.statusBanner = 'Player $playerNum shuffled their discard pile into their deck!';
  }
}

GameState _playRound(GameState state) {
  _refillIfEmpty(state, 1);
  _refillIfEmpty(state, 2);

  if (state.p1Deck.isEmpty || state.p2Deck.isEmpty) {
    final winner = state.p2Deck.isEmpty ? 'Player 1' : 'Player 2';
    _endGame(state, winner);
    return state;
  }

  state.p1Ready = false;
  state.p2Ready = false;

  state.p1BattleCard = state.p1Deck.removeAt(0);
  state.p2BattleCard = state.p2Deck.removeAt(0);
  state.round++;
  state.roundReason = null;
  state.warDepth = 0;

  _maybeSetTrump(state);
  state.lastResult = _compareCards(state.p1BattleCard!, state.p2BattleCard!,
      state.trumpSuit, state.muskRank, state.removedByRank);
  state.roundReason = _buildReason(state.p1BattleCard!, state.p2BattleCard!,
      state.lastResult!, state.trumpSuit, state.muskRank, state.removedByRank);

  if (state.lastResult != RoundResult.tie) {
    state.pot.addAll([state.p1BattleCard!, state.p2BattleCard!]);
  }

  state.phase = GamePhase.result;
  return state;
}

GameState _startWar(GameState state) {
  state.warDepth++;
  state.warsTriggered++;
  if (state.warDepth > state.maxWarChainDepth) {
    state.maxWarChainDepth = state.warDepth;
  }

  if (state.p1BattleCard != null) {
    _removeCardFromGame(state, state.p1BattleCard!);
  }
  if (state.p2BattleCard != null) {
    _removeCardFromGame(state, state.p2BattleCard!);
  }

  if (state.muskRank == null &&
      state.p1BattleCard != null &&
      !state.p1BattleCard!.isJoker) {
    state.muskRank = state.p1BattleCard!.rank;
    state.statusBanner =
        '${state.p1BattleCard!.rankName}s are now Musketeers!';
  }

  final p1Total = state.p1Deck.length + state.p1Discard.length;
  final p2Total = state.p2Deck.length + state.p2Discard.length;
  final p1Take = (p1Total - 1).clamp(0, 3);
  final p2Take = (p2Total - 1).clamp(0, 3);
  state.p1FaceDownCount = p1Take;
  state.p2FaceDownCount = p2Take;

  for (var i = 0; i < p1Take; i++) {
    _refillIfEmpty(state, 1);
    if (state.p1Deck.isNotEmpty) state.pot.add(state.p1Deck.removeAt(0));
  }
  for (var i = 0; i < p2Take; i++) {
    _refillIfEmpty(state, 2);
    if (state.p2Deck.isNotEmpty) state.pot.add(state.p2Deck.removeAt(0));
  }

  // The tied cards that triggered the war have been burned; clear them so
  // the UI shows a fresh face-down placeholder instead of the old cards
  // while players wait to flip their war cards.
  state.p1BattleCard = null;
  state.p2BattleCard = null;

  state.phase = GamePhase.warPending;
  return state;
}

GameState _flipWarCard(GameState state) {
  _refillIfEmpty(state, 1);
  if (state.p1Deck.isEmpty) {
    if (!state.secondWindUsed) {
      _giveSecondWind(state, 1);
      if (state.p1Deck.isEmpty) {
        _endGame(state, 'Player 2');
        return state;
      }
    } else {
      _endGame(state, 'Player 2');
      return state;
    }
  }

  _refillIfEmpty(state, 2);
  if (state.p2Deck.isEmpty) {
    if (!state.secondWindUsed) {
      _giveSecondWind(state, 2);
      if (state.p2Deck.isEmpty) {
        _endGame(state, 'Player 1');
        return state;
      }
    } else {
      _endGame(state, 'Player 1');
      return state;
    }
  }

  state.p1Ready = false;
  state.p2Ready = false;

  state.p1BattleCard = state.p1Deck.removeAt(0);
  state.p2BattleCard = state.p2Deck.removeAt(0);
  state.roundReason = null;

  _maybeSetTrump(state);
  state.lastResult = _compareCards(state.p1BattleCard!, state.p2BattleCard!,
      state.trumpSuit, state.muskRank, state.removedByRank);
  state.roundReason = _buildReason(state.p1BattleCard!, state.p2BattleCard!,
      state.lastResult!, state.trumpSuit, state.muskRank, state.removedByRank);

  if (state.lastResult != RoundResult.tie) {
    state.pot.addAll([state.p1BattleCard!, state.p2BattleCard!]);
  }

  state.phase = GamePhase.warResult;
  return state;
}

GameState _awardPot(GameState state) {
  final isP1Win = state.lastResult == RoundResult.p1Wins;
  final winnerDiscard = isP1Win ? state.p1Discard : state.p2Discard;
  final loserNum = isP1Win ? 2 : 1;
  final wasWar = state.warDepth > 0;

  // Track win streaks and round wins
  if (isP1Win) {
    state.p1WinStreak++;
    state.p2WinStreak = 0;
    state.p1RoundsWon++;
  } else {
    state.p2WinStreak++;
    state.p1WinStreak = 0;
    state.p2RoundsWon++;
  }

  // Track wars won
  if (wasWar) {
    if (isP1Win) {
      state.p1WarsWon++;
    } else {
      state.p2WarsWon++;
    }
  }

  // Track trump-win streaks (consecutive round wins by trump-card advantage)
  final winnerCard = isP1Win ? state.p1BattleCard : state.p2BattleCard;
  final wonByTrump =
      winnerCard != null && getCardStatus(winnerCard, state) == CardStatus.trump;
  if (isP1Win) {
    state.p1TrumpStreak = wonByTrump ? state.p1TrumpStreak + 1 : 0;
    state.p2TrumpStreak = 0;
    if (state.p1TrumpStreak > state.p1MaxTrumpStreak) {
      state.p1MaxTrumpStreak = state.p1TrumpStreak;
    }
  } else {
    state.p2TrumpStreak = wonByTrump ? state.p2TrumpStreak + 1 : 0;
    state.p1TrumpStreak = 0;
    if (state.p2TrumpStreak > state.p2MaxTrumpStreak) {
      state.p2MaxTrumpStreak = state.p2TrumpStreak;
    }
  }

  // Ensure the won card (loser's card) is on top of the discard pile
  if (state.p1BattleCard != null && state.p2BattleCard != null) {
    final loserCard = isP1Win ? state.p2BattleCard! : state.p1BattleCard!;
    if (state.pot.contains(loserCard)) {
      state.pot.remove(loserCard);
      state.pot.add(loserCard);
    }
  }

  if (isP1Win) {
    state.p1LastTrick = List.from(state.pot);
  } else {
    state.p2LastTrick = List.from(state.pot);
  }
  winnerDiscard.addAll(state.pot);
  state.pot = [];

  // Clear round description when cards are collected
  state.roundReason = null;

  state.warDepth = 0;
  state.p1BattleCard = null;
  state.p2BattleCard = null;
  state.lastResult = null;
  state.p1FaceDownCount = 0;
  state.p2FaceDownCount = 0;

  // Track peak card counts and low-card thresholds for both players
  final p1Total = state.p1Deck.length + state.p1Discard.length;
  final p2Total = state.p2Deck.length + state.p2Discard.length;
  if (p1Total > state.p1MaxCardsHeld) state.p1MaxCardsHeld = p1Total;
  if (p2Total > state.p2MaxCardsHeld) state.p2MaxCardsHeld = p2Total;
  if (p1Total <= 5) state.p1WasLowCards = true;
  if (p2Total <= 5) state.p2WasLowCards = true;
  if (p1Total <= 1) state.p1WasOneCard = true;
  if (p2Total <= 1) state.p2WasOneCard = true;

  final loserDeck = isP1Win ? state.p2Deck : state.p1Deck;
  final loserDiscard = isP1Win ? state.p2Discard : state.p1Discard;

  if (loserDeck.isEmpty && loserDiscard.isEmpty) {
    if (!state.secondWindUsed) {
      _giveSecondWind(state, loserNum);
      state.phase = GamePhase.idle;
      return state;
    } else {
      _endGame(state, isP1Win ? 'Player 1' : 'Player 2');
      return state;
    }
  }

  state.phase = GamePhase.idle;
  return state;
}

GameState advanceGame(GameState currentState, String actionBy) {
  final state = currentState.copyWith();
  state.statusBanner = null;
  state.lastActionBy = actionBy;
  state.lastActionTimestamp = DateTime.now().millisecondsSinceEpoch;

  switch (state.phase) {
    case GamePhase.idle:
      if (actionBy == 'Player 1') {
        state.p1Ready = true;
      } else if (actionBy == 'Player 2') {
        state.p2Ready = true;
      }
      if (state.p1Ready && state.p2Ready) {
        return _playRound(state);
      }
      return state;
    case GamePhase.result:
      if (state.lastResult != RoundResult.tie) {
        final winnerLabel = state.lastResult == RoundResult.p1Wins ? 'Player 1' : 'Player 2';
        if (actionBy == winnerLabel) {
          return _awardPot(state);
        }
        return state;
      } else {
        if (actionBy == 'Player 1') {
          state.p1Ready = true;
        } else if (actionBy == 'Player 2') {
          state.p2Ready = true;
        }
        if (state.p1Ready && state.p2Ready) {
          state.p1Ready = false;
          state.p2Ready = false;
          return _startWar(state);
        }
        return state;
      }
    case GamePhase.warPending:
      if (actionBy == 'Player 1') {
        state.p1Ready = true;
      } else if (actionBy == 'Player 2') {
        state.p2Ready = true;
      }
      if (state.p1Ready && state.p2Ready) {
        return _flipWarCard(state);
      }
      return state;
    case GamePhase.warResult:
      if (state.lastResult != RoundResult.tie) {
        final winnerLabel = state.lastResult == RoundResult.p1Wins ? 'Player 1' : 'Player 2';
        if (actionBy == winnerLabel) {
          return _awardPot(state);
        }
        return state;
      } else {
        if (actionBy == 'Player 1') {
          state.p1Ready = true;
        } else if (actionBy == 'Player 2') {
          state.p2Ready = true;
        }
        if (state.p1Ready && state.p2Ready) {
          state.p1Ready = false;
          state.p2Ready = false;
          return _startWar(state);
        }
        return state;
      }
    default:
      return state;
  }
}

bool canAdvance(GameState state) {
  return state.phase == GamePhase.idle ||
      state.phase == GamePhase.result ||
      state.phase == GamePhase.warPending ||
      state.phase == GamePhase.warResult;
}
