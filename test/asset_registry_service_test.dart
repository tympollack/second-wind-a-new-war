import 'package:flutter_test/flutter_test.dart';
import 'package:war_second_wind/models/playing_card.dart';
import 'package:war_second_wind/services/asset_registry_service.dart';
import 'package:war_second_wind/widgets/card_widget.dart';

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
  });
}
