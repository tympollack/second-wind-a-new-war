import 'playing_card.dart';

enum GamePhase {
  idle,
  flipping,
  result,
  warPending,
  warFlipping,
  warResult,
  gameOver,
}

enum RoundResult { p1Wins, p2Wins, tie }

class GameState {
  List<PlayingCard> p1Deck;
  List<PlayingCard> p2Deck;
  List<PlayingCard> p1Discard;
  List<PlayingCard> p2Discard;
  List<PlayingCard> p1LastTrick;
  List<PlayingCard> p2LastTrick;
  List<PlayingCard> secondWindDeck;
  bool secondWindUsed;
  String? secondWindRecipient;
  Suit? trumpSuit;
  int? muskRank;
  Map<int, int> removedByRank;
  List<int> removedCardIds;
  PlayingCard? p1BattleCard;
  PlayingCard? p2BattleCard;
  List<PlayingCard> pot;
  int p1FaceDownCount;
  int p2FaceDownCount;
  bool p1Ready;
  bool p2Ready;
  GamePhase phase;
  RoundResult? lastResult;
  String? gameWinner;
  int round;
  int warDepth;
  String? roundReason;
  String? statusBanner;
  String? lastActionBy;
  int lastActionTimestamp;
  int p1WinStreak;
  int p2WinStreak;
  int p1RoundsWon;
  int p2RoundsWon;

  // ── Achievement / stat tracking (persisted for the lifetime of a match) ──
  int warsTriggered;
  int p1WarsWon;
  int p2WarsWon;
  int maxWarChainDepth;
  int p1MaxCardsHeld;
  int p2MaxCardsHeld;
  bool p1WasLowCards;
  bool p2WasLowCards;
  bool p1WasOneCard;
  bool p2WasOneCard;
  int p1TrumpStreak;
  int p2TrumpStreak;
  int p1MaxTrumpStreak;
  int p2MaxTrumpStreak;

  GameState({
    required this.p1Deck,
    required this.p2Deck,
    List<PlayingCard>? p1Discard,
    List<PlayingCard>? p2Discard,
    List<PlayingCard>? p1LastTrick,
    List<PlayingCard>? p2LastTrick,
    required this.secondWindDeck,
    this.secondWindUsed = false,
    this.secondWindRecipient,
    this.trumpSuit,
    this.muskRank,
    Map<int, int>? removedByRank,
    List<int>? removedCardIds,
    this.p1BattleCard,
    this.p2BattleCard,
    List<PlayingCard>? pot,
    this.p1FaceDownCount = 0,
    this.p2FaceDownCount = 0,
    this.p1Ready = false,
    this.p2Ready = false,
    this.phase = GamePhase.idle,
    this.lastResult,
    this.gameWinner,
    this.round = 0,
    this.warDepth = 0,
    this.roundReason,
    this.statusBanner,
    this.lastActionBy,
    int? lastActionTimestamp,
    this.p1WinStreak = 0,
    this.p2WinStreak = 0,
    this.p1RoundsWon = 0,
    this.p2RoundsWon = 0,
    this.warsTriggered = 0,
    this.p1WarsWon = 0,
    this.p2WarsWon = 0,
    this.maxWarChainDepth = 0,
    this.p1MaxCardsHeld = 0,
    this.p2MaxCardsHeld = 0,
    this.p1WasLowCards = false,
    this.p2WasLowCards = false,
    this.p1WasOneCard = false,
    this.p2WasOneCard = false,
    this.p1TrumpStreak = 0,
    this.p2TrumpStreak = 0,
    this.p1MaxTrumpStreak = 0,
    this.p2MaxTrumpStreak = 0,
  })  : p1Discard = p1Discard ?? [],
        p2Discard = p2Discard ?? [],
        p1LastTrick = p1LastTrick ?? [],
        p2LastTrick = p2LastTrick ?? [],
        removedByRank = removedByRank ?? {},
        removedCardIds = removedCardIds ?? [],
        pot = pot ?? [],
        lastActionTimestamp =
            lastActionTimestamp ?? DateTime.now().millisecondsSinceEpoch;

  factory GameState.fromJson(Map<String, dynamic> json) {
    return GameState(
      p1Deck: (json['p1Deck'] as List)
          .map((c) => PlayingCard.fromJson(c as Map<String, dynamic>))
          .toList(),
      p2Deck: (json['p2Deck'] as List)
          .map((c) => PlayingCard.fromJson(c as Map<String, dynamic>))
          .toList(),
      p1Discard: (json['p1Discard'] as List?)
              ?.map((c) => PlayingCard.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      p2Discard: (json['p2Discard'] as List?)
              ?.map((c) => PlayingCard.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      p1LastTrick: (json['p1LastTrick'] as List?)
              ?.map((c) => PlayingCard.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      p2LastTrick: (json['p2LastTrick'] as List?)
              ?.map((c) => PlayingCard.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      secondWindDeck: (json['secondWindDeck'] as List)
          .map((c) => PlayingCard.fromJson(c as Map<String, dynamic>))
          .toList(),
      secondWindUsed: json['secondWindUsed'] as bool? ?? false,
      secondWindRecipient: json['secondWindRecipient'] as String?,
      trumpSuit: json['trumpSuit'] != null
          ? Suit.values.firstWhere((s) => s.name == json['trumpSuit'])
          : null,
      muskRank: json['muskRank'] as int?,
      removedByRank: (json['removedByRank'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(int.parse(k), v as int)) ??
          {},
      removedCardIds: (json['removedCardIds'] as List?)
              ?.map((e) => e as int)
              .toList() ??
          [],
      p1BattleCard: json['p1BattleCard'] != null
          ? PlayingCard.fromJson(json['p1BattleCard'] as Map<String, dynamic>)
          : null,
      p2BattleCard: json['p2BattleCard'] != null
          ? PlayingCard.fromJson(json['p2BattleCard'] as Map<String, dynamic>)
          : null,
      pot: (json['pot'] as List?)
              ?.map((c) => PlayingCard.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      p1FaceDownCount: json['p1FaceDownCount'] as int? ?? 0,
      p2FaceDownCount: json['p2FaceDownCount'] as int? ?? 0,
      p1Ready: json['p1Ready'] as bool? ?? false,
      p2Ready: json['p2Ready'] as bool? ?? false,
      phase: GamePhase.values.firstWhere(
        (p) => p.name == json['phase'],
        orElse: () => GamePhase.idle,
      ),
      lastResult: json['lastResult'] != null
          ? RoundResult.values.firstWhere(
              (r) => r.name == json['lastResult'],
              orElse: () => RoundResult.tie,
            )
          : null,
      gameWinner: json['gameWinner'] as String?,
      round: json['round'] as int? ?? 0,
      warDepth: json['warDepth'] as int? ?? 0,
      roundReason: json['roundReason'] as String?,
      statusBanner: json['statusBanner'] as String?,
      lastActionBy: json['lastActionBy'] as String?,
      lastActionTimestamp: json['lastActionTimestamp'] as int? ??
          DateTime.now().millisecondsSinceEpoch,
      p1WinStreak: json['p1WinStreak'] as int? ?? 0,
      p2WinStreak: json['p2WinStreak'] as int? ?? 0,
      p1RoundsWon: json['p1RoundsWon'] as int? ?? 0,
      p2RoundsWon: json['p2RoundsWon'] as int? ?? 0,
      warsTriggered: json['warsTriggered'] as int? ?? 0,
      p1WarsWon: json['p1WarsWon'] as int? ?? 0,
      p2WarsWon: json['p2WarsWon'] as int? ?? 0,
      maxWarChainDepth: json['maxWarChainDepth'] as int? ?? 0,
      p1MaxCardsHeld: json['p1MaxCardsHeld'] as int? ?? 0,
      p2MaxCardsHeld: json['p2MaxCardsHeld'] as int? ?? 0,
      p1WasLowCards: json['p1WasLowCards'] as bool? ?? false,
      p2WasLowCards: json['p2WasLowCards'] as bool? ?? false,
      p1WasOneCard: json['p1WasOneCard'] as bool? ?? false,
      p2WasOneCard: json['p2WasOneCard'] as bool? ?? false,
      p1TrumpStreak: json['p1TrumpStreak'] as int? ?? 0,
      p2TrumpStreak: json['p2TrumpStreak'] as int? ?? 0,
      p1MaxTrumpStreak: json['p1MaxTrumpStreak'] as int? ?? 0,
      p2MaxTrumpStreak: json['p2MaxTrumpStreak'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'p1Deck': p1Deck.map((c) => c.toJson()).toList(),
        'p2Deck': p2Deck.map((c) => c.toJson()).toList(),
        'p1Discard': p1Discard.map((c) => c.toJson()).toList(),
        'p2Discard': p2Discard.map((c) => c.toJson()).toList(),
        'p1LastTrick': p1LastTrick.map((c) => c.toJson()).toList(),
        'p2LastTrick': p2LastTrick.map((c) => c.toJson()).toList(),
        'secondWindDeck': secondWindDeck.map((c) => c.toJson()).toList(),
        'secondWindUsed': secondWindUsed,
        'secondWindRecipient': secondWindRecipient,
        'trumpSuit': trumpSuit?.name,
        'muskRank': muskRank,
        'removedByRank':
            removedByRank.map((k, v) => MapEntry(k.toString(), v)),
        'removedCardIds': removedCardIds,
        'p1BattleCard': p1BattleCard?.toJson(),
        'p2BattleCard': p2BattleCard?.toJson(),
        'pot': pot.map((c) => c.toJson()).toList(),
        'p1FaceDownCount': p1FaceDownCount,
        'p2FaceDownCount': p2FaceDownCount,
        'p1Ready': p1Ready,
        'p2Ready': p2Ready,
        'phase': phase.name,
        'lastResult': lastResult?.name,
        'gameWinner': gameWinner,
        'round': round,
        'warDepth': warDepth,
        'roundReason': roundReason,
        'statusBanner': statusBanner,
        'lastActionBy': lastActionBy,
        'lastActionTimestamp': lastActionTimestamp,
        'p1WinStreak': p1WinStreak,
        'p2WinStreak': p2WinStreak,
        'p1RoundsWon': p1RoundsWon,
        'p2RoundsWon': p2RoundsWon,
        'warsTriggered': warsTriggered,
        'p1WarsWon': p1WarsWon,
        'p2WarsWon': p2WarsWon,
        'maxWarChainDepth': maxWarChainDepth,
        'p1MaxCardsHeld': p1MaxCardsHeld,
        'p2MaxCardsHeld': p2MaxCardsHeld,
        'p1WasLowCards': p1WasLowCards,
        'p2WasLowCards': p2WasLowCards,
        'p1WasOneCard': p1WasOneCard,
        'p2WasOneCard': p2WasOneCard,
        'p1TrumpStreak': p1TrumpStreak,
        'p2TrumpStreak': p2TrumpStreak,
        'p1MaxTrumpStreak': p1MaxTrumpStreak,
        'p2MaxTrumpStreak': p2MaxTrumpStreak,
      };

  GameState copyWith() {
    return GameState.fromJson(toJson());
  }
}
