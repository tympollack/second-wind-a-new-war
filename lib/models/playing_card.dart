enum Suit { spades, hearts, diamonds, clubs }

enum CardStatus { normal, trump, musketeer, joker }

class PlayingCard {
  final int id;
  final Suit? suit;
  final int rank; // 2-14 for regular, 15 for joker
  final bool isJoker;

  const PlayingCard({
    required this.id,
    required this.suit,
    required this.rank,
    required this.isJoker,
  });

  factory PlayingCard.fromJson(Map<String, dynamic> json) {
    return PlayingCard(
      id: json['id'] as int,
      suit: json['suit'] != null
          ? Suit.values.firstWhere((s) => s.name == json['suit'])
          : null,
      rank: json['rank'] as int,
      isJoker: json['isJoker'] as bool,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'suit': suit?.name,
        'rank': rank,
        'isJoker': isJoker,
      };

  String get rankLabel {
    if (isJoker) return '\u2605';
    switch (rank) {
      case 11:
        return 'J';
      case 12:
        return 'Q';
      case 13:
        return 'K';
      case 14:
        return 'A';
      default:
        return rank.toString();
    }
  }

  String get rankName {
    if (isJoker) return 'Joker';
    switch (rank) {
      case 11:
        return 'Jack';
      case 12:
        return 'Queen';
      case 13:
        return 'King';
      case 14:
        return 'Ace';
      default:
        return rank.toString();
    }
  }

  String get suitSymbol {
    if (isJoker || suit == null) return '\u2605';
    switch (suit!) {
      case Suit.spades:
        return '\u2660';
      case Suit.hearts:
        return '\u2665';
      case Suit.diamonds:
        return '\u2666';
      case Suit.clubs:
        return '\u2663';
    }
  }

  bool get isRed => suit == Suit.hearts || suit == Suit.diamonds;

  @override
  String toString() => isJoker ? 'Joker' : '$rankLabel$suitSymbol';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is PlayingCard && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
