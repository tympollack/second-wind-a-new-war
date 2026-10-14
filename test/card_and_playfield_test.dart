import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war_second_wind/models/playing_card.dart';
import 'package:war_second_wind/widgets/card_widget.dart';
import 'package:war_second_wind/views/playfield.dart';

void main() {
  group('CardWidget & Kenney Vector Assets Tests', () {
    testWidgets('Renders all four vector suit glyphs cleanly', (tester) async {
      for (final suit in Suit.values) {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(
              width: 50,
              height: 50,
              child: CustomPaint(
                painter: SuitVectorPainter(
                  suit: suit,
                  color: Colors.red,
                ),
              ),
            ),
          ),
        );
        expect(
          find.byWidgetPredicate((w) => w is CustomPaint && w.painter is SuitVectorPainter),
          findsOneWidget,
        );
      }
    });

    testWidgets('Renders Canyon Cyan and Subterranean Crimson card backs', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                CardBackWidget(theme: CardBackTheme.canyonCyan),
                CardBackWidget(theme: CardBackTheme.subterraneanCrimson),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(CardBackWidget), findsNWidgets(2));
    });

    testWidgets('Renders standard 52-card face vector layout and royal court cards', (tester) async {
      const aceSpades = PlayingCard(id: 1, suit: Suit.spades, rank: 14, isJoker: false);
      const kingHearts = PlayingCard(id: 2, suit: Suit.hearts, rank: 13, isJoker: false);
      const tenDiamonds = PlayingCard(id: 3, suit: Suit.diamonds, rank: 10, isJoker: false);
      const joker = PlayingCard(id: 4, suit: null, rank: 15, isJoker: true);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                CardFaceWidget(card: aceSpades),
                CardFaceWidget(card: kingHearts),
                CardFaceWidget(card: tenDiamonds),
                CardFaceWidget(card: joker),
              ],
            ),
          ),
        ),
      );

      expect(find.text('A'), findsWidgets);
      expect(find.text('K'), findsWidgets);
      expect(find.text('10'), findsWidgets);
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    });

    testWidgets('Renders status badges for Trump, Musketeer, and Second Wind', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                StatusBadgeWidget(type: StatusBadgeType.trump, customLabel: 'TRUMP 2X'),
                StatusBadgeWidget(type: StatusBadgeType.musketeer, customLabel: 'MUSKETEER 3X'),
                StatusBadgeWidget(type: StatusBadgeType.secondWind, customLabel: 'SECOND WIND ACTIVE'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('TRUMP 2X'), findsOneWidget);
      expect(find.text('MUSKETEER 3X'), findsOneWidget);
      expect(find.text('SECOND WIND ACTIVE'), findsOneWidget);
      expect(find.byIcon(Icons.workspace_premium), findsOneWidget);
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
      expect(find.byIcon(Icons.air_rounded), findsOneWidget);
    });

    testWidgets('Renders Dealing Hand rigs for player and opponent', (tester) async {
      final controller = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(milliseconds: 300),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                DealingHandWidget(slideAnimation: controller, isOpponent: false),
                DealingHandWidget(slideAnimation: controller, isOpponent: true),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(DealingHandWidget), findsNWidgets(2));
      controller.dispose();
    });

    testWidgets('FlippableCardWidget flips smoothly between face-up and card back', (tester) async {
      const card = PlayingCard(id: 10, suit: Suit.clubs, rank: 7, isJoker: false);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FlippableCardWidget(
              isFaceUp: false,
              card: card,
              cardBackTheme: CardBackTheme.canyonCyan,
            ),
          ),
        ),
      );

      expect(find.byType(CardBackWidget), findsOneWidget);
      expect(find.byType(CardFaceWidget), findsNothing);

      // Re-pump with isFaceUp: true
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FlippableCardWidget(
              isFaceUp: true,
              card: card,
              cardBackTheme: CardBackTheme.canyonCyan,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(CardFaceWidget), findsOneWidget);
    });

    testWidgets('TabletopPlayfieldView renders felt table, dealing hands, and interactive battle area', (tester) async {
      const p1Card = PlayingCard(id: 11, suit: Suit.hearts, rank: 14, isJoker: false);
      const p2Card = PlayingCard(id: 12, suit: Suit.spades, rank: 13, isJoker: false);
      bool dealTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TabletopPlayfieldView(
              playerCard: p1Card,
              opponentCard: p2Card,
              playerCardStatus: CardStatus.trump,
              isWar: true,
              isSecondWindActive: true,
              onDealTap: () => dealTapped = true,
            ),
          ),
        ),
      );

      expect(find.byType(TabletopPlayfieldView), findsOneWidget);
      expect(find.text('⚔ WAR SEQUENCE ⚔'), findsOneWidget);
      expect(find.text('TRUMP CARD'), findsOneWidget);
      expect(find.text('SECOND WIND ACTIVE'), findsOneWidget);

      await tester.tap(find.text('DRAW / FLIP'));
      expect(dealTapped, isTrue);
    });
  });
}
