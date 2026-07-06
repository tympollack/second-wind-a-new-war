import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war_second_wind/engine/game_engine.dart';
import 'package:war_second_wind/widgets/progress_bar_widget.dart';
import 'package:war_second_wind/widgets/playing_card_widget.dart';

void main() {
  testWidgets('GameProgressBar renders with initial state', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GameProgressBar(
            p1Cards: 18,
            p2Cards: 18,
            p1Discard: 0,
            p2Discard: 0,
            removedCards: 0,
          ),
        ),
      ),
    );

    expect(find.byType(GameProgressBar), findsOneWidget);
  });

  testWidgets('GameProgressBar renders with discarded cards', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GameProgressBar(
            p1Cards: 10,
            p2Cards: 12,
            p1Discard: 5,
            p2Discard: 3,
            removedCards: 6,
          ),
        ),
      ),
    );

    expect(find.byType(GameProgressBar), findsOneWidget);
  });
  
  testWidgets('PlayingCardWidget renders a card', (WidgetTester tester) async {
    final state = createInitialGameState();
    
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayingCardWidget(
            card: state.p1Deck.first,
            gameState: state,
            isWinner: false,
            isBurning: false,
          ),
        ),
      ),
    );

    expect(find.byType(PlayingCardWidget), findsOneWidget);
  });
  
  testWidgets('FaceDownCardWidget renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FaceDownCardWidget(count: 3),
        ),
      ),
    );

    expect(find.byType(FaceDownCardWidget), findsOneWidget);
  });
}
