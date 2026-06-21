import 'dart:math';
import '../models/playing_card.dart';

List<PlayingCard> buildFullDeck() {
  final deck = <PlayingCard>[];
  var id = 0;
  for (final suit in Suit.values) {
    for (var r = 2; r <= 14; r++) {
      deck.add(PlayingCard(id: id++, suit: suit, rank: r, isJoker: false));
    }
  }
  deck.add(PlayingCard(id: id++, suit: null, rank: 15, isJoker: true));
  deck.add(PlayingCard(id: id++, suit: null, rank: 15, isJoker: true));
  return shuffleList(deck);
}

List<T> shuffleList<T>(List<T> list) {
  final a = List<T>.from(list);
  final rng = Random();
  for (var i = a.length - 1; i > 0; i--) {
    final j = rng.nextInt(i + 1);
    final temp = a[i];
    a[i] = a[j];
    a[j] = temp;
  }
  return a;
}
