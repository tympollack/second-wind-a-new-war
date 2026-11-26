import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/playing_card.dart';
import '../widgets/card_widget.dart';

/// Canonical `@digitalcanopy/assets` R2 CDN, 52-card atlas manifest, and
/// hot-swapping registry adapter for War: Second Wind (`app_scope: 'wsw'`).
class WswSpriteBounds {
  final double x;
  final double y;
  final double w;
  final double h;

  const WswSpriteBounds({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });
}

class WswAnchorPoint {
  final double ax;
  final double ay;

  const WswAnchorPoint({required this.ax, required this.ay});
}

class WswFlameSpriteData {
  final List<double> srcPosition;
  final List<double> srcSize;
  final List<double> anchor;

  const WswFlameSpriteData({
    required this.srcPosition,
    required this.srcSize,
    required this.anchor,
  });
}

class WswCatalogAsset {
  final String appScope;
  final String category;
  final String assetKey;
  final String cdnUrl;
  final Map<String, dynamic> metadata;

  const WswCatalogAsset({
    required this.appScope,
    required this.category,
    required this.assetKey,
    required this.cdnUrl,
    this.metadata = const {},
  });

  factory WswCatalogAsset.fromMap(Map<String, dynamic> map) {
    final rawMeta = map['metadata'];
    final Map<String, dynamic> parsedMeta;
    if (rawMeta is Map<String, dynamic>) {
      parsedMeta = rawMeta;
    } else if (rawMeta is String && rawMeta.isNotEmpty) {
      parsedMeta = Map<String, dynamic>.from(jsonDecode(rawMeta) as Map);
    } else {
      parsedMeta = const {};
    }

    return WswCatalogAsset(
      appScope: (map['app_scope'] ?? '').toString(),
      category: (map['category'] ?? '').toString(),
      assetKey: (map['asset_key'] ?? '').toString(),
      cdnUrl: (map['cdn_url'] ?? '').toString(),
      metadata: parsedMeta,
    );
  }
}

class WswAssetOverride {
  final String url;
  final WswSpriteBounds? frame;
  final WswAnchorPoint? anchor;
  final Map<String, dynamic> metadata;

  const WswAssetOverride({
    required this.url,
    this.frame,
    this.anchor,
    this.metadata = const {},
  });
}

class AssetRegistryService {
  AssetRegistryService._internal();

  static final AssetRegistryService instance = AssetRegistryService._internal();

  factory AssetRegistryService.create() => AssetRegistryService._internal();

  static const String cdnBaseUrl = 'https://cdn.sunshade.icu/assets/kenney';
  static const String appScope = 'wsw';

  static const List<String> atlasSuits = ['spades', 'hearts', 'clubs', 'diamonds'];
  static const List<String> atlasValues = [
    'a', '02', '03', '04', '05', '06', '07', '08', '09', '10', 'j', 'q', 'k',
  ];
  static const List<String> atlasCardBacks = [
    'blue', 'red', 'green', 'yellow', 'cyan', 'default',
  ];

  static const double cardFrameWidth = 140;
  static const double cardFrameHeight = 190;
  static const double atlasMaxWidth = 2048;

  /// Generates the full 58-frame `playingCardsAtlas` coordinates (52 faces + 6 backs)
  /// matching `@digitalcanopy/assets` `playing-cards.atlas.json`.
  static Map<String, WswSpriteBounds> buildPlayingCardsAtlasFrames() {
    final frames = <String, WswSpriteBounds>{};
    double x = 0;
    double y = 0;

    void addFrame(String key) {
      frames[key] = WswSpriteBounds(
        x: x,
        y: y,
        w: cardFrameWidth,
        h: cardFrameHeight,
      );
      x += cardFrameWidth;
      if (x + cardFrameWidth > atlasMaxWidth) {
        x = 0;
        y += cardFrameHeight;
      }
    }

    for (final suit in atlasSuits) {
      for (final val in atlasValues) {
        addFrame('card-$suit-$val');
      }
    }
    for (final back in atlasCardBacks) {
      addFrame('cardback-$back');
    }
    return frames;
  }

  static final Map<String, WswSpriteBounds> playingCardAtlasFrames =
      buildPlayingCardsAtlasFrames();

  static const Map<String, WswSpriteBounds> uiAtlasFrames = {
    'button-default': WswSpriteBounds(x: 0, y: 0, w: 128, h: 128),
    'panel-metal': WswSpriteBounds(x: 1152, y: 0, w: 128, h: 128),
    'bar-progress-bg': WswSpriteBounds(x: 768, y: 128, w: 128, h: 128),
    'bar-progress-fill': WswSpriteBounds(x: 896, y: 128, w: 128, h: 128),
  };

  /// Seed dataset matching `@digitalcanopy/assets` `SEED_CATALOG_ASSETS` (`wsw` + `all`).
  static const List<WswCatalogAsset> seedCatalog = [
    WswCatalogAsset(
      appScope: 'wsw',
      category: 'card_back',
      assetKey: 'card-back-cyan',
      cdnUrl: '$cdnBaseUrl/cards/backs/card_back_cyan.png',
      metadata: {'format': 'png', 'width': 140, 'height': 190, 'license': 'CC0-Kenney'},
    ),
    WswCatalogAsset(
      appScope: 'wsw',
      category: 'card_back',
      assetKey: 'card-back-crimson',
      cdnUrl: '$cdnBaseUrl/cards/backs/card_back_crimson.png',
      metadata: {'format': 'png', 'width': 140, 'height': 190, 'license': 'CC0-Kenney'},
    ),
    WswCatalogAsset(
      appScope: 'wsw',
      category: 'card_face',
      assetKey: 'card-face-spades-ace',
      cdnUrl: '$cdnBaseUrl/cards/faces/card_spades_A.png',
      metadata: {'format': 'png', 'width': 140, 'height': 190, 'license': 'CC0-Kenney'},
    ),
    WswCatalogAsset(
      appScope: 'wsw',
      category: 'card_face',
      assetKey: 'card-face-hearts-king',
      cdnUrl: '$cdnBaseUrl/cards/faces/card_hearts_K.png',
      metadata: {'format': 'png', 'width': 140, 'height': 190, 'license': 'CC0-Kenney'},
    ),
    WswCatalogAsset(
      appScope: 'all',
      category: 'particle_fx',
      assetKey: 'fx-particle-starburst',
      cdnUrl: '$cdnBaseUrl/particles/starburst.png',
      metadata: {'format': 'png', 'width': 64, 'height': 64, 'license': 'CC0-Kenney'},
    ),
    WswCatalogAsset(
      appScope: 'all',
      category: 'ui_audio',
      assetKey: 'audio-ui-tap',
      cdnUrl: '$cdnBaseUrl/audio/ui/tap_clean.ogg',
      metadata: {'format': 'ogg', 'duration_ms': 85, 'license': 'CC0-Kenney'},
    ),
    WswCatalogAsset(
      appScope: 'all',
      category: 'impact_audio',
      assetKey: 'audio-impact-wood-thud',
      cdnUrl: '$cdnBaseUrl/audio/impacts/wood_thud.ogg',
      metadata: {'format': 'ogg', 'duration_ms': 140, 'license': 'CC0-Kenney'},
    ),
  ];

  final Map<String, WswAssetOverride> _overrides = {};
  final Map<String, WswAssetOverride> _catalogEntries = {};
  final Map<String, String> _packOverrides = {};
  final ValueNotifier<int> swapRevision = ValueNotifier<int>(0);
  bool _hydrated = false;
  bool _hydratedFromRemote = false;
  List<WswCatalogAsset> _cachedCatalog = seedCatalog;

  bool get isHydrated => _hydrated;

  void reset() {
    _overrides.clear();
    _catalogEntries.clear();
    _packOverrides.clear();
    _hydrated = false;
    _hydratedFromRemote = false;
    _cachedCatalog = seedCatalog;
    swapRevision.value++;
  }

  void registerOverride(String key, WswAssetOverride override) {
    _overrides[key.trim()] = override;
    swapRevision.value++;
  }

  void registerPackOverride(String pack, String cdnBase) {
    final cleanPack = pack.replaceAll(RegExp(r'^/+|/+$'), '').toLowerCase();
    _packOverrides[cleanPack] = cdnBase.replaceAll(RegExp(r'/+$'), '');
    swapRevision.value++;
  }

  bool hasOverride(String key) {
    final cleanKey = key.trim();
    return _overrides.containsKey(cleanKey) || _catalogEntries.containsKey(cleanKey);
  }

  void loadCatalog(List<WswCatalogAsset> assets, {String? scope}) {
    final filtered = (scope == null
            ? assets
            : assets.where((a) => a.appScope == scope || a.appScope == 'all'))
        .toList();
    _catalogEntries.clear();
    for (final asset in filtered) {
      final cleanKey = asset.assetKey.trim();
      if (cleanKey.isEmpty) continue;
      _catalogEntries[cleanKey] = WswAssetOverride(
        url: asset.cdnUrl,
        metadata: asset.metadata,
      );
    }
    _cachedCatalog = filtered;
    _hydrated = true;
    swapRevision.value++;
  }

  Future<List<WswCatalogAsset>> hydrateCatalog({
    SupabaseClient? supabaseClient,
    bool force = false,
  }) async {
    if (_hydrated && !force && (supabaseClient == null || _hydratedFromRemote)) {
      return _cachedCatalog;
    }

    if (supabaseClient != null) {
      try {
        final rows = await supabaseClient
            .schema('catalog')
            .from('assets')
            .select('app_scope, category, asset_key, cdn_url, metadata')
            .inFilter('app_scope', [appScope, 'all']);

        if (rows.isNotEmpty) {
          final parsed = rows
              .map(WswCatalogAsset.fromMap)
              .where((a) => a.assetKey.isNotEmpty && a.cdnUrl.isNotEmpty)
              .toList();
          if (parsed.isNotEmpty) {
            _hydratedFromRemote = true;
            loadCatalog(parsed, scope: appScope);
            return parsed;
          }
        }
      } catch (err) {
        debugPrint('[AssetRegistryService] Remote catalog unavailable, using seed: $err');
      }
    }

    _hydratedFromRemote = false;
    loadCatalog(seedCatalog, scope: appScope);
    return seedCatalog;
  }

  static String cardKeyFor(PlayingCard card) {
    if (card.isJoker || card.suit == null) {
      return 'card-joker';
    }
    final suitName = card.suit!.name;
    final String valueKey;
    switch (card.rank) {
      case 14:
        valueKey = 'a';
      case 13:
        valueKey = 'k';
      case 12:
        valueKey = 'q';
      case 11:
        valueKey = 'j';
      default:
        valueKey = card.rank.toString().padLeft(2, '0');
    }
    return 'card-$suitName-$valueKey';
  }

  static String cardBackKeyFor(CardBackTheme theme) {
    return theme == CardBackTheme.canyonCyan ? 'cardback-cyan' : 'cardback-red';
  }

  String resolveAssetUrl(String pack, String assetPath, {String ext = 'png'}) {
    final cleanPack = pack.replaceAll(RegExp(r'^/+|/+$'), '').toLowerCase();
    final cleanPath = assetPath.replaceAll(RegExp(r'^/+|/+$'), '');
    final bareKey = cleanPath.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');

    if (_overrides.containsKey(bareKey)) {
      return _overrides[bareKey]!.url;
    }
    if (_overrides.containsKey(cleanPath)) {
      return _overrides[cleanPath]!.url;
    }

    final cleanExt = ext.startsWith('.') ? ext.substring(1) : ext;
    final hasExt = RegExp(r'\.[a-zA-Z0-9]+$').hasMatch(cleanPath);
    final finalPath = hasExt ? cleanPath : '$cleanPath.$cleanExt';

    final packBase = _packOverrides[cleanPack];
    if (packBase != null) {
      return '$packBase/$finalPath';
    }
    if (_catalogEntries.containsKey(bareKey)) {
      return _catalogEntries[bareKey]!.url;
    }
    if (_catalogEntries.containsKey(cleanPath)) {
      return _catalogEntries[cleanPath]!.url;
    }
    return '$cdnBaseUrl/$cleanPack/$finalPath';
  }

  static String? _seedAliasForCardKey(String key) {
    if (key == 'card-spades-a') return 'card-face-spades-ace';
    if (key == 'card-hearts-k') return 'card-face-hearts-king';
    return null;
  }

  String resolveCardUrl(PlayingCard card) {
    final key = cardKeyFor(card);
    if (_overrides.containsKey(key)) {
      return _overrides[key]!.url;
    }
    final aliasKey = _seedAliasForCardKey(key);
    if (aliasKey != null && _overrides.containsKey(aliasKey)) {
      return _overrides[aliasKey]!.url;
    }
    if (_packOverrides.containsKey('cards')) {
      return resolveAssetUrl('cards', key);
    }
    if (_catalogEntries.containsKey(key)) {
      return _catalogEntries[key]!.url;
    }
    if (aliasKey != null && _hydratedFromRemote && _catalogEntries.containsKey(aliasKey)) {
      return _catalogEntries[aliasKey]!.url;
    }
    return resolveAssetUrl('cards', key);
  }

  String resolveCardBackUrl(CardBackTheme theme) {
    final catalogKey = theme == CardBackTheme.canyonCyan
        ? 'card-back-cyan'
        : 'card-back-crimson';
    if (_overrides.containsKey(catalogKey)) {
      return _overrides[catalogKey]!.url;
    }
    final backKey = cardBackKeyFor(theme);
    if (_overrides.containsKey(backKey)) {
      return _overrides[backKey]!.url;
    }
    if (_packOverrides.containsKey('cards')) {
      return resolveAssetUrl('cards', backKey);
    }
    if (_catalogEntries.containsKey(catalogKey)) {
      return _catalogEntries[catalogKey]!.url;
    }
    return resolveAssetUrl('cards', backKey);
  }

  String resolveHandRigUrl({required bool isOpponent}) {
    final charKey = isOpponent ? 'char-shirts-shirt-red-0' : 'char-shirts-shirt-blue-0';
    const category = 'shirts';
    final itemKey = isOpponent ? 'shirt-red-0' : 'shirt-blue-0';
    if (_overrides.containsKey(charKey)) {
      return _overrides[charKey]!.url;
    }
    if (_packOverrides.containsKey('modular-characters')) {
      return resolveAssetUrl('modular-characters', '$category/$itemKey');
    }
    if (_catalogEntries.containsKey(charKey)) {
      return _catalogEntries[charKey]!.url;
    }
    return resolveAssetUrl('modular-characters', '$category/$itemKey');
  }

  String resolveUiSpriteUrl(String spriteKey) {
    return resolveAssetUrl('ui-pack', spriteKey);
  }

  WswFlameSpriteData? resolveCardFlameSpriteData(String cardKey) {
    final cleanKey = cardKey.trim();
    final override = _overrides[cleanKey] ?? _catalogEntries[cleanKey];
    final frame = override?.frame ?? playingCardAtlasFrames[cleanKey];
    if (frame == null) return null;

    final anchor = override?.anchor ?? const WswAnchorPoint(ax: 0.5, ay: 0.5);
    return WswFlameSpriteData(
      srcPosition: [frame.x, frame.y],
      srcSize: [frame.w, frame.h],
      anchor: [anchor.ax, anchor.ay],
    );
  }
}
