import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war_second_wind/engine/game_engine.dart';
import 'package:war_second_wind/models/playing_card.dart';
import 'package:war_second_wind/services/asset_registry_service.dart';
import 'package:war_second_wind/widgets/playing_card_widget.dart';

void main() {
  group('TASK-PKG-APP-WSW: @digitalcanopy/assets 52-Card Deck & Hand Rig Adapter', () {
    test('generates all 58 playingCardsAtlas frames (52 faces + 6 backs)', () {
      expect(AssetRegistryService.playingCardAtlasFrames.length, equals(58));

      final registry = AssetRegistryService.create();
      final aceSpades = registry.resolveCardFlameSpriteData('card-spades-a');
      expect(aceSpades, isNotNull);
      expect(aceSpades!.srcPosition, [0.0, 0.0]);
      expect(aceSpades.srcSize, [140.0, 190.0]);
      expect(aceSpades.anchor, [0.5, 0.5]);

      final cardBackDefault = registry.resolveCardFlameSpriteData('cardback-default');
      expect(cardBackDefault, isNotNull);
      expect(cardBackDefault!.srcSize, [140.0, 190.0]);
    });

    test('hydrates wsw and shared catalog assets and resolves cards, backs, and hand rigs', () async {
      final registry = AssetRegistryService.create();
      final assets = await registry.hydrateCatalog();

      expect(assets.any((a) => a.assetKey == 'card-back-cyan'), isTrue);
      expect(assets.any((a) => a.assetKey == 'card-back-crimson'), isTrue);
      expect(assets.any((a) => a.assetKey == 'fx-particle-starburst'), isTrue);

      const ace = PlayingCard(id: 1, suit: Suit.spades, rank: 14, isJoker: false);
      const twoHearts = PlayingCard(id: 2, suit: Suit.hearts, rank: 2, isJoker: false);
      expect(
        registry.resolveCardUrl(ace),
        '${AssetRegistryService.cdnBaseUrl}/cards/card-spades-a.png',
      );
      expect(
        registry.resolveCardUrl(twoHearts),
        '${AssetRegistryService.cdnBaseUrl}/cards/card-hearts-02.png',
      );
      expect(
        registry.resolveCardBackUrl(CardBackTheme.canyonCyan),
        '${AssetRegistryService.cdnBaseUrl}/cards/backs/card_back_cyan.png',
      );
      expect(
        registry.resolveHandRigUrl(isOpponent: false),
        '${AssetRegistryService.cdnBaseUrl}/modular-characters/shirts/shirt-blue-0.png',
      );
      expect(
        registry.resolveHandRigUrl(isOpponent: true),
        '${AssetRegistryService.cdnBaseUrl}/modular-characters/shirts/shirt-red-0.png',
      );
    });

    test('supports custom IP pack and key hot-swapping for decks and hand rigs', () async {
      final registry = AssetRegistryService.create();
      await registry.hydrateCatalog();

      registry.registerPackOverride('cards', 'https://custom-ip.sunshade.icu/cyberpunk-cards');
      const kingClubs = PlayingCard(id: 13, suit: Suit.clubs, rank: 13, isJoker: false);
      expect(
        registry.resolveCardUrl(kingClubs),
        'https://custom-ip.sunshade.icu/cyberpunk-cards/card-clubs-k.png',
      );

      registry.registerOverride(
        'card-back-crimson',
        const WswAssetOverride(url: 'https://custom-ip.sunshade.icu/crimson-holo.png'),
      );
      expect(
        registry.resolveCardBackUrl(CardBackTheme.subterraneanCrimson),
        'https://custom-ip.sunshade.icu/crimson-holo.png',
      );
    });

    test('evicts removed catalog entries on forced refresh and respects pack swaps for backs', () async {
      final registry = AssetRegistryService.create();
      registry.loadCatalog([
        const WswCatalogAsset(
          appScope: 'wsw',
          category: 'card_face',
          assetKey: 'card-hearts-07',
          cdnUrl: 'https://custom.sunshade.icu/removed-7h.png',
        ),
      ], scope: 'wsw');
      expect(registry.hasOverride('card-hearts-07'), isTrue);

      await registry.hydrateCatalog(force: true);
      expect(registry.hasOverride('card-hearts-07'), isFalse);

      registry.registerPackOverride('cards', 'https://custom.sunshade.icu/custom-cards');
      expect(
        registry.resolveCardBackUrl(CardBackTheme.canyonCyan),
        'https://custom.sunshade.icu/custom-cards/cardback-cyan.png',
      );
    });

    testWidgets('PlayingCardWidget renders Image.network bound to CDN and updates on hot-swap', (tester) async {
      final registry = AssetRegistryService.instance;
      registry.reset();
      await registry.hydrateCatalog();

      const aceSpades = PlayingCard(id: 1, suit: Suit.spades, rank: 14, isJoker: false);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayingCardWidget(
              card: aceSpades,
              gameState: createInitialGameState(),
            ),
          ),
        ),
      );
      await tester.pump();

      final img = tester.widget<Image>(find.byType(Image).first);
      expect((img.image as NetworkImage).url, '${AssetRegistryService.cdnBaseUrl}/cards/card-spades-a.png');

      registry.registerPackOverride('cards', 'https://custom-ip.sunshade.icu/live-deck');
      await tester.pump();

      final swappedImg = tester.widget<Image>(find.byType(Image).first);
      expect((swappedImg.image as NetworkImage).url, 'https://custom-ip.sunshade.icu/live-deck/card-spades-a.png');
      registry.reset();
    });
  });
}
