import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../providers/game_provider.dart';
import '../../models/game_state.dart';
import '../../models/playing_card.dart';
import '../../services/device_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/playing_card_widget.dart';
import '../../widgets/military_button.dart';
import '../../widgets/progress_bar_widget.dart';
import '../../widgets/account_prompt_dialog.dart';
import '../stats/match_stats_screen.dart';

class GameScreen extends ConsumerStatefulWidget {
  final String matchId;
  const GameScreen({super.key, required this.matchId});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen>
    with TickerProviderStateMixin {
  late AnimationController _warAnimController;
  late Animation<double> _warPulse;
  late AnimationController _collectAnimController;
  late AnimationController _pulseAnimController;
  late Animation<double> _pulseAnimation;
  late AnimationController _fireAnimController;
  late Animation<double> _fireAnimation;

  bool _isCollecting = false;
  int? _lastP1Total;
  int? _lastP2Total;
  RoundResult? _lastWinner;

  bool _isAutoPlay = false;
  bool _isWarDelaying = false;
  String? _localStatusBanner;
  int _statusBannerToken = 0;

  @override
  void initState() {
    super.initState();
    _warAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _warPulse = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _warAnimController, curve: Curves.easeInOut),
    );

    _collectAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _collectAnimController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _finishCollectAndPlay();
      }
    });

    _pulseAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = CurvedAnimation(
      parent: _pulseAnimController,
      curve: Curves.easeInOut,
    );

    _fireAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _fireAnimation = CurvedAnimation(
      parent: _fireAnimController,
      curve: Curves.easeInOut,
    );

    final userId = ref.read(authProvider).user?.id;
    if (userId != null) {
      Future.microtask(
        () => ref.read(gameProvider.notifier).loadGame(widget.matchId, userId),
      );
    }
  }

  @override
  void dispose() {
    _warAnimController.dispose();
    _collectAnimController.dispose();
    _pulseAnimController.dispose();
    _fireAnimController.dispose();
    super.dispose();
  }

  void _startCollectAndPlay() {
    final gs = ref.read(gameProvider).gameState;
    if (gs == null) return;
    if (!mounted) return;
    setState(() {
      _isCollecting = true;
      _lastWinner = gs.lastResult;
      _lastP1Total = gs.p1Deck.length + gs.p1Discard.length;
      _lastP2Total = gs.p2Deck.length + gs.p2Discard.length;
    });
    _collectAnimController.reset();
    _collectAnimController.forward();
  }

  void _triggerAutoPlay(GameState gs, String? userId) {
    if (userId == null ||
        gs.phase == GamePhase.gameOver ||
        _isWarDelaying ||
        _isCollecting) {
      return;
    }

    final playerNum = ref.read(gameProvider).playerNum;
    final isReady =
        (playerNum == 1 && gs.p1Ready) || (playerNum == 2 && gs.p2Ready);

    if (isReady) return;

    final isResultNonTie =
        (gs.phase == GamePhase.result || gs.phase == GamePhase.warResult) &&
        gs.lastResult != RoundResult.tie;

    if (isResultNonTie) {
      final didWin =
          (gs.lastResult == RoundResult.p1Wins && playerNum == 1) ||
          (gs.lastResult == RoundResult.p2Wins && playerNum == 2);
      if (didWin) {
        _startCollectAndPlay();
      }
    } else {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _isAutoPlay) {
          ref.read(gameProvider.notifier).advance(userId);
        }
      });
    }
  }

  void _finishCollectAndPlay() {
    final userId = ref.read(authProvider).user?.id;
    if (userId == null) return;

    // Instead of auto-playing the next round, just collect.
    ref.read(gameProvider.notifier).advance(userId).then((_) {
      if (mounted) {
        final gs = ref.read(gameProvider).gameState;
        setState(() {
          _isCollecting = false;
          if (gs != null) {
            _lastP1Total = gs.p1Deck.length + gs.p1Discard.length;
            _lastP2Total = gs.p2Deck.length + gs.p2Discard.length;
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final gameNotifier = ref.watch(gameProvider);
    final gs = gameNotifier.gameState;
    final userId = ref.read(authProvider).user?.id;

    ref.listen<GameState?>(gameProvider.select((state) => state.gameState), (
      previous,
      current,
    ) {
      if (current == null) return;
      // Latch status banner messages (e.g. shuffle notices) locally so they
      // stay visible for a fixed duration instead of vanishing the instant
      // the synced state advances again (statusBanner is reset every turn).
      if (current.statusBanner != null &&
          current.statusBanner != previous?.statusBanner) {
        final token = ++_statusBannerToken;
        setState(() {
          _localStatusBanner = current.statusBanner;
        });
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && token == _statusBannerToken) {
            setState(() {
              _localStatusBanner = null;
            });
          }
        });
      }
      // Check for warResult transition
      if (previous?.phase != GamePhase.warResult &&
          current.phase == GamePhase.warResult) {
        setState(() {
          _isWarDelaying = true;
        });
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _isWarDelaying = false;
            });
            if (_isAutoPlay) _triggerAutoPlay(current, userId);
          }
        });
      } else {
        // If auto play is on, trigger next action
        if (_isAutoPlay && !_isWarDelaying) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _triggerAutoPlay(current, userId);
          });
        }
      }
    });

    if (gameNotifier.error != null) {
      return Scaffold(
        backgroundColor: AppTheme.darkBg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Error loading game: ${gameNotifier.error}',
                style: const TextStyle(color: AppTheme.warRed, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('GO BACK'),
              ),
            ],
          ),
        ),
      );
    }

    if (gs == null || gameNotifier.isLoading) {
      return _buildLoadingScreen();
    }

    final playerNum = gameNotifier.playerNum;
    final isGameOver = gs.phase == GamePhase.gameOver;
    final isWar =
        gs.phase == GamePhase.warPending || gs.phase == GamePhase.warResult;

    // P1 is always left, P2 is always right
    int p1DeckCount = gs.p1Deck.length;
    int p2DeckCount = gs.p2Deck.length;
    if (gs.phase == GamePhase.idle || gs.phase == GamePhase.warPending) {
      if (gs.p1Ready) p1DeckCount = (p1DeckCount - 1).clamp(0, 99);
      if (gs.p2Ready) p2DeckCount = (p2DeckCount - 1).clamp(0, 99);
    }
    final p1Card = gs.p1BattleCard;
    final p2Card = gs.p2BattleCard;
    final p1FaceDown = gs.p1FaceDownCount;
    final p2FaceDown = gs.p2FaceDownCount;
    final isReady =
        (playerNum == 1 && gs.p1Ready) || (playerNum == 2 && gs.p2Ready);
    final hasCollected =
        (gs.phase == GamePhase.result || gs.phase == GamePhase.warResult) &&
        isReady;
    final showCards = p1Card != null && p2Card != null && !hasCollected;

    final isP1Win = gs.lastResult == RoundResult.p1Wins;
    final isP2Win = gs.lastResult == RoundResult.p2Wins;

    final removedCards = gs.removedCardIds.length;
    final potCards =
        gs.pot.length +
        (showCards ? 2 : 0) +
        gs.p1FaceDownCount +
        gs.p2FaceDownCount;

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar with retreat + round info
            _buildTopBar(gs, playerNum),
            // Progress bar sits above the game-info chips (Trump, Musketeer,
            // etc.) row.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: GameProgressBar(
                p1Cards: p1DeckCount,
                p2Cards: p2DeckCount,
                p1Discard:
                    gs.p1Discard.length + (isP1Win && showCards ? potCards : 0),
                p2Discard:
                    gs.p2Discard.length + (isP2Win && showCards ? potCards : 0),
                removedCards: removedCards,
                lastP1Total: _lastP1Total,
                lastP2Total: _lastP2Total,
              ),
            ),
            // Main battle area with Stack and AnimatedAlign
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.darkSurface.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.metalGray.withValues(alpha: 0.12),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: _buildMainGameArea(
                    gs,
                    playerNum,
                    showCards,
                    isP1Win,
                    isP2Win,
                    isWar,
                    p1DeckCount,
                    p2DeckCount,
                    p1FaceDown,
                    p2FaceDown,
                    _getArenaTapAction(gs, userId, playerNum),
                  ),
                ),
              ),
            ),
            // Status banner
            if (_localStatusBanner != null && !hasCollected)
              _buildStatusBanner(_localStatusBanner!),
            // Action area
            _buildActionArea(gs, isGameOver, userId, playerNum),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: AppTheme.darkBg),
          Container(color: Colors.black.withValues(alpha: 0.4)),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 200,
                  child: LinearProgressIndicator(
                    color: Theme.of(context).colorScheme.primary,
                    backgroundColor: AppTheme.darkSurface,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Loading Tactical Matrix...',
                  style: TextStyle(
                    fontFamily: 'RobotoCondensed',
                    fontSize: 14,
                    color: AppTheme.metalGray,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(GameState gs, int playerNum) {
    final p1OnFire = gs.p1WinStreak >= 3;
    final p2OnFire = gs.p2WinStreak >= 3;
    final anyOnFire = p1OnFire || p2OnFire;

    return AnimatedBuilder(
      animation: _fireAnimation,
      builder: (context, child) {
        final fireAlpha = anyOnFire
            ? (0.15 + _fireAnimation.value * 0.12)
            : 0.0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: anyOnFire
                ? LinearGradient(
                    colors: [
                      p1OnFire
                          ? const Color(0xFFCC5500).withValues(alpha: fireAlpha)
                          : AppTheme.darkSurface.withValues(alpha: 0.9),
                      AppTheme.darkSurface.withValues(alpha: 0.9),
                      p2OnFire
                          ? const Color(0xFFCC5500).withValues(alpha: fireAlpha)
                          : AppTheme.darkSurface.withValues(alpha: 0.9),
                    ],
                  )
                : null,
            color: anyOnFire
                ? null
                : AppTheme.darkSurface.withValues(alpha: 0.9),
            border: Border(
              bottom: BorderSide(
                color: anyOnFire
                    ? const Color(
                        0xFFCC5500,
                      ).withValues(alpha: 0.3 + _fireAnimation.value * 0.2)
                    : AppTheme.metalGray.withValues(alpha: 0.2),
              ),
            ),
          ),
          child: child,
        );
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left cluster: navigation + auto-play toggle
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () {
                      ref.read(gameProvider.notifier).leaveGame();
                      Navigator.of(context).pop();
                    },
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.arrow_back,
                          size: 16,
                          color: AppTheme.metalGray,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'LOBBY',
                          style: TextStyle(
                            fontFamily: 'RobotoCondensed',
                            fontSize: 12,
                            color: AppTheme.metalGray,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isAutoPlay = !_isAutoPlay;
                        if (_isAutoPlay) {
                          final gs = ref.read(gameProvider).gameState;
                          final userId = ref.read(authProvider).user?.id;
                          if (gs != null) _triggerAutoPlay(gs, userId);
                        }
                      });
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.smart_toy,
                          size: 16,
                          color: _isAutoPlay
                              ? Theme.of(context).colorScheme.primary
                              : AppTheme.metalGray,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'AUTO',
                          style: TextStyle(
                            fontFamily: 'RobotoCondensed',
                            fontSize: 12,
                            color: _isAutoPlay
                                ? Theme.of(context).colorScheme.primary
                                : AppTheme.metalGray,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Center cluster: round + war status, given its own dedicated slot
          // so it can never be pushed into by the side clusters.
          Expanded(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'ROUND ${gs.round}',
                    style: const TextStyle(
                      fontFamily: 'RobotoCondensed',
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppTheme.metalLight,
                      letterSpacing: 1,
                    ),
                  ),
                  if (gs.warDepth > 0) ...[
                    const SizedBox(width: 16),
                    AnimatedBuilder(
                      animation: _warPulse,
                      builder: (context, child) => Transform.scale(
                        scale: _warPulse.value,
                        child: Text(
                          'WAR${gs.warDepth > 1 ? " x${gs.warDepth}" : ""}',
                          style: const TextStyle(
                            fontFamily: 'RobotoCondensed',
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: AppTheme.metalGray,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Right cluster: streaks + stats + player badge
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (gs.p1WinStreak >= 3)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.local_fire_department,
                            size: 14,
                            color: Color(0xFFFF8C00),
                          ),
                          Text(
                            '×${gs.p1WinStreak}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFFF8C00),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (gs.p2WinStreak >= 3)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.local_fire_department,
                            size: 14,
                            color: Color(0xFFFF8C00),
                          ),
                          Text(
                            '×${gs.p2WinStreak}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFFF8C00),
                            ),
                          ),
                        ],
                      ),
                    ),
                  GestureDetector(
                    onTap: () {
                      final matchId = ref.read(gameProvider).matchId;
                      if (matchId != null) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MatchStatsScreen(matchId: matchId),
                          ),
                        );
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.bar_chart,
                          size: 14,
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'STATS',
                          style: TextStyle(
                            fontFamily: 'RobotoCondensed',
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.7),
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'P$playerNum',
                    style: TextStyle(
                      fontFamily: 'RobotoCondensed',
                      fontSize: 12,
                      color: playerNum == 1
                          ? AppTheme.player1Color
                          : AppTheme.player2Color,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameInfo(GameState gs) {
    bool musketeersDead = false;
    if (gs.muskRank != null) {
      int removedMuskCount = gs.removedByRank[gs.muskRank!] ?? 0;
      musketeersDead = removedMuskCount >= 4;
    }

    final chips = <Widget>[
      if (gs.trumpSuit != null) _buildTrumpChip(gs.trumpSuit!),
      if (gs.muskRank != null)
        _buildInfoChip(
          iconData: musketeersDead ? Icons.dangerous : null,
          icon: musketeersDead ? null : '\u2694',
          value: musketeersDead ? 'DESTROYED' : _rankLabel(gs.muskRank!),
          color: AppTheme.purpleMusketeer,
        ),
      if (gs.pot.isNotEmpty)
        _buildInfoChip(
          iconData: Icons.style,
          value: '${gs.pot.length}',
          color: Colors.orange,
        ),
      if (gs.removedCardIds.isNotEmpty)
        _buildInfoChip(
          icon: '\u2620',
          value: '${gs.removedCardIds.length}',
          color: AppTheme.metalGray,
        ),
      if (!gs.secondWindUsed && gs.secondWindDeck.isNotEmpty)
        _buildInfoChip(
          iconData: Icons.air,
          value: '2W',
          color: AppTheme.winGreen,
        ),
      if (gs.secondWindUsed)
        _buildInfoChip(
          iconData: Icons.wb_sunny_outlined,
          value: '2W SPENT',
          color: AppTheme.metalGray,
        ),
    ];

    if (chips.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.metalGray.withValues(alpha: 0.15)),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 8,
        children: chips,
      ),
    );
  }

  String _rankLabel(int rank) {
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

  String _suitSymbol(Suit suit) {
    switch (suit) {
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

  Widget _buildTrumpChip(Suit suit) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      constraints: const BoxConstraints(minHeight: 32),
      decoration: BoxDecoration(
        color: AppTheme.goldTrump.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.goldTrump.withValues(alpha: 0.35)),
      ),
      // Constrain the suit symbol to the same 15x15 icon box used by the
      // other chips, so the trump chip never ends up taller than its neighbors.
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 15,
            height: 15,
            child: FittedBox(
              fit: BoxFit.contain,
              child: Text(
                _suitSymbol(suit),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.goldTrump,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    String? icon,
    IconData? iconData,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      constraints: const BoxConstraints(minHeight: 32),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (iconData != null)
            Icon(iconData, size: 15, color: color)
          else if (icon != null)
            Text(icon, style: TextStyle(fontSize: 15, color: color)),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'RobotoCondensed',
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerDeck({
    required String label,
    required int count,
    required Color color,
    required GameState gs,
    required bool isLeft,
  }) {
    final lastTrick = isLeft ? gs.p1LastTrick : gs.p2LastTrick;

    Widget deckWidget = AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        double opacity;
        if (count <= 3) {
          opacity = 0.25 + _pulseAnimation.value * 0.35;
        } else if (count <= 5) {
          opacity = 0.45 + _pulseAnimation.value * 0.30;
        } else {
          final brightBoost = count >= 20 ? 0.1 : 0.0;
          opacity = (0.85 + brightBoost + _pulseAnimation.value * 0.15).clamp(
            0.0,
            1.0,
          );
        }
        return Opacity(opacity: opacity, child: child);
      },
      child: Column(
        children: [
          Container(
            width: 60,
            height: 84,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color.withValues(alpha: 0.15), AppTheme.darkCard],
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: color.withValues(alpha: 0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(2, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontFamily: 'RobotoCondensed',
                  fontWeight: FontWeight.w900,
                  fontSize: 28,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'RobotoCondensed',
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: color,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );

    Widget discardWidget = SizedBox(
      width: 60 + (lastTrick.length > 1 ? (lastTrick.length - 1) * 32.0 : 0.0),
      height: 84,
      child: lastTrick.isNotEmpty
          ? Stack(
              children: List.generate(lastTrick.length, (index) {
                return Positioned(
                  left: index * 32.0,
                  child: PlayingCardWidget(
                    card: lastTrick[index],
                    gameState: gs,
                    isWinner: false,
                    isBurning: false,
                    width: 60,
                    height: 84,
                    showBadge: false,
                  ),
                );
              }),
            )
          : Container(
              width: 60,
              height: 84,
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppTheme.metalGray.withValues(alpha: 0.3),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  'TRICK',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.metalGray.withValues(alpha: 0.5),
                    fontFamily: 'RobotoCondensed',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: isLeft
          ? [deckWidget, const SizedBox(width: 8), discardWidget]
          : [discardWidget, const SizedBox(width: 8), deckWidget],
    );
  }

  // Helper methods to get face down cards from pot for war
  List<PlayingCard> _getP1FaceDownCards(GameState gs) {
    if (gs.p1FaceDownCount == 0) return [];
    int endIndex = gs.pot.length;
    if (gs.phase == GamePhase.warResult && gs.lastResult != RoundResult.tie) {
      endIndex -= 2;
    }
    final startIndex = endIndex - gs.p2FaceDownCount - gs.p1FaceDownCount;
    if (startIndex < 0 || endIndex > gs.pot.length) return [];
    return gs.pot.sublist(startIndex, startIndex + gs.p1FaceDownCount);
  }

  List<PlayingCard> _getP2FaceDownCards(GameState gs) {
    if (gs.p2FaceDownCount == 0) return [];
    int endIndex = gs.pot.length;
    if (gs.phase == GamePhase.warResult && gs.lastResult != RoundResult.tie) {
      endIndex -= 2;
    }
    final startIndex = endIndex - gs.p2FaceDownCount;
    if (startIndex < 0 || endIndex > gs.pot.length) return [];
    return gs.pot.sublist(startIndex, endIndex);
  }

  // maxWidth bounds the total footprint of the fanned pile so a long war
  // history (many cards) compresses instead of spilling past the arena
  // edge into the neighboring deck/trick column.
  Widget _buildFaceDownCardsStack(
    List<PlayingCard> cards,
    GameState gs,
    bool isP1, {
    double maxWidth = 140.0,
    double width = 60.0,
    double height = 90.0,
  }) {
    if (cards.isEmpty) return const SizedBox.shrink();
    final double availableSpread = (maxWidth - width).clamp(0.0, 80.0);
    final double spread = cards.length > 1
        ? (availableSpread / (cards.length - 1)).clamp(2.0, 20.0)
        : 0.0;

    return Stack(
      alignment: isP1 ? Alignment.centerRight : Alignment.centerLeft,
      children: List.generate(cards.length, (index) {
        return Padding(
          padding: EdgeInsets.only(
            left: isP1 ? 0 : index * spread,
            right: isP1 ? index * spread : 0,
          ),
          child: PlayingCardWidget(
            card: cards[index],
            gameState: gs,
            isWinner: false,
            isBurning: false,
            width: width,
            height: height,
            showBadge: false,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMainGameArea(
    GameState gs,
    int playerNum,
    bool showCards,
    bool isP1Win,
    bool isP2Win,
    bool isWar,
    int p1DeckCount,
    int p2DeckCount,
    int p1FaceDown,
    int p2FaceDown,
    VoidCallback? onArenaTap,
  ) {
    // Calculate alignments
    final p1Ready = gs.p1Ready || showCards || gs.phase == GamePhase.warPending;
    final p2Ready = gs.p2Ready || showCards || gs.phase == GamePhase.warPending;

    // P1 Battle Card Alignment
    Alignment p1Align = Alignment.centerLeft;
    if (p1Ready) {
      if (_isCollecting) {
        p1Align = _lastWinner == RoundResult.p1Wins
            ? Alignment.centerLeft
            : Alignment.centerRight;
      } else {
        p1Align = const Alignment(-0.35, 0); // Fanned slightly left
      }
    }

    // P2 Battle Card Alignment
    Alignment p2Align = Alignment.centerRight;
    if (p2Ready) {
      if (_isCollecting) {
        p2Align = _lastWinner == RoundResult.p1Wins
            ? Alignment.centerLeft
            : Alignment.centerRight;
      } else {
        p2Align = const Alignment(0.35, 0); // Fanned slightly right
      }
    }

    // P1 War Face Down Alignment
    Alignment p1WarAlign = Alignment.centerLeft;
    if (isWar && p1FaceDown > 0) {
      if (_isCollecting) {
        p1WarAlign = _lastWinner == RoundResult.p1Wins
            ? Alignment.centerLeft
            : Alignment.centerRight;
      } else {
        p1WarAlign = const Alignment(-0.6, 0);
      }
    }

    // P2 War Face Down Alignment
    Alignment p2WarAlign = Alignment.centerRight;
    if (isWar && p2FaceDown > 0) {
      if (_isCollecting) {
        p2WarAlign = _lastWinner == RoundResult.p1Wins
            ? Alignment.centerLeft
            : Alignment.centerRight;
      } else {
        p2WarAlign = const Alignment(0.6, 0);
      }
    }

    final p1Card = gs.p1BattleCard;
    final p2Card = gs.p2BattleCard;
    final perspectiveReason = _buildPerspectiveReason(gs, playerNum);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Minimum width for the center column so the chip status bar never
        // wraps vertically and pushes the card arena off-center. On very
        // narrow viewports the whole arena scrolls horizontally instead.
        final double minCenterWidth = (constraints.maxWidth * 0.55).clamp(
          260.0,
          360.0,
        );
        const double deckSlotMinWidth = 128.0;
        const double interSlotGap = 16.0;
        final double totalMinWidth =
            deckSlotMinWidth * 2 + interSlotGap + minCenterWidth;

        final Widget arena = Row(
          // Top-aligned so the player decks' top edge lines up with the top of
          // the status bar (chips), which now lives inside this battle area.
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left player deck + trick pile. Given its own fixed-width slot in
            // the Row so the battle cards in the center can never be overlapped
            // by it.
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildPlayerDeck(
                label: playerNum == 1 ? 'YOU' : 'OPP',
                count: p1DeckCount,
                color: AppTheme.player1Color,
                gs: gs,
                isLeft: true,
              ),
            ),

            // Center column: status bar sits at the very top (level with the
            // deck columns beside it), followed by the reason text strip and
            // the battle-card arena below. Constrained to a minimum width so
            // the chip bar never wraps vertically.
            Expanded(
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: minCenterWidth),
                child: Column(
                  children: [
                    _buildGameInfo(gs),
                    // Round-result reason text ("A beats K") lives in its own reserved
                    // strip above the battlefield, so it can never overlap the top edge
                    // of the battle cards regardless of screen size.
                    SizedBox(
                      height: 28,
                      child: (perspectiveReason != null && !_isCollecting)
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: Text(
                                  perspectiveReason,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'RobotoCondensed',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: AppTheme.metalLight,
                                  ),
                                ),
                              ),
                            )
                          : null,
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, arenaConstraints) {
                          // Each side's fanned war pile gets at most ~45% of the
                          // arena width, so a long war history compresses instead
                          // of spilling into the opponent's half or the deck
                          // columns outside this Expanded.
                          final double pileMaxWidth =
                              (arenaConstraints.maxWidth * 0.45).clamp(
                                60.0,
                                140.0,
                              );
                          // Scale the battle cards down if the arena is shorter
                          // than the ideal 230px (war card + battle card + VS).
                          const double idealArenaHeight = 230.0;
                          final double heightScale =
                              (arenaConstraints.maxHeight / idealArenaHeight)
                                  .clamp(0.65, 1.0);
                          final double battleCardWidth = 80 * heightScale;
                          final double battleCardHeight = 120 * heightScale;
                          final double warCardWidth = 60 * heightScale;
                          final double warCardHeight = 90 * heightScale;

                          Widget battleStack = Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [
                              // P1 War Face Down
                              if (isWar && p1FaceDown > 0)
                                AnimatedAlign(
                                  duration: const Duration(milliseconds: 400),
                                  curve: Curves.easeOutQuart,
                                  alignment: p1WarAlign,
                                  child: AnimatedOpacity(
                                    duration: const Duration(milliseconds: 300),
                                    opacity: _isCollecting ? 0.0 : 1.0,
                                    child: (gs.phase == GamePhase.warResult)
                                        ? _buildFaceDownCardsStack(
                                            _getP1FaceDownCards(gs),
                                            gs,
                                            true,
                                            maxWidth: pileMaxWidth,
                                            width: warCardWidth,
                                            height: warCardHeight,
                                          )
                                        : FaceDownCardWidget(
                                            count: p1FaceDown,
                                            width: warCardWidth,
                                            height: warCardHeight,
                                            spread: 20.0 * heightScale,
                                          ),
                                  ),
                                ),

                              // P2 War Face Down
                              if (isWar && p2FaceDown > 0)
                                AnimatedAlign(
                                  duration: const Duration(milliseconds: 400),
                                  curve: Curves.easeOutQuart,
                                  alignment: p2WarAlign,
                                  child: AnimatedOpacity(
                                    duration: const Duration(milliseconds: 300),
                                    opacity: _isCollecting ? 0.0 : 1.0,
                                    child: (gs.phase == GamePhase.warResult)
                                        ? _buildFaceDownCardsStack(
                                            _getP2FaceDownCards(gs),
                                            gs,
                                            false,
                                            maxWidth: pileMaxWidth,
                                            width: warCardWidth,
                                            height: warCardHeight,
                                          )
                                        : FaceDownCardWidget(
                                            count: p2FaceDown,
                                            width: warCardWidth,
                                            height: warCardHeight,
                                            spread: 20.0 * heightScale,
                                          ),
                                  ),
                                ),

                              // P1 Battle Card (always mounted so alignment animates deck -> battlefield)
                              AnimatedAlign(
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeOutQuart,
                                alignment: p1Align,
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 300),
                                  opacity: (p1Ready && !_isCollecting)
                                      ? 1.0
                                      : 0.0,
                                  child: showCards && p1Card != null
                                      ? PlayingCardWidget(
                                          card: p1Card,
                                          gameState: gs,
                                          isWinner: isP1Win,
                                          isBurning: gs.p1WinStreak >= 3,
                                          width: battleCardWidth,
                                          height: battleCardHeight,
                                        )
                                      : FaceDownCardWidget(
                                          count: 1,
                                          width: battleCardWidth,
                                          height: battleCardHeight,
                                        ),
                                ),
                              ),

                              // P2 Battle Card (always mounted so alignment animates deck -> battlefield)
                              AnimatedAlign(
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeOutQuart,
                                alignment: p2Align,
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 300),
                                  opacity: (p2Ready && !_isCollecting)
                                      ? 1.0
                                      : 0.0,
                                  child: showCards && p2Card != null
                                      ? PlayingCardWidget(
                                          card: p2Card,
                                          gameState: gs,
                                          isWinner: isP2Win,
                                          isBurning: gs.p2WinStreak >= 3,
                                          width: battleCardWidth,
                                          height: battleCardHeight,
                                        )
                                      : FaceDownCardWidget(
                                          count: 1,
                                          width: battleCardWidth,
                                          height: battleCardHeight,
                                        ),
                                ),
                              ),

                              // VS / war indicator — pinned to the bottom of the
                              // arena so it always sits below the cards instead of
                              // fighting them for the same centered space.
                              Positioned(
                                bottom: 0,
                                child: _buildBattleIndicator(isWar),
                              ),
                            ],
                          );

                          // Make the battle arena tappable when a player
                          // action is available (play, collect, war, flip).
                          if (onArenaTap != null) {
                            battleStack = GestureDetector(
                              onTap: onArenaTap,
                              behavior: HitTestBehavior.opaque,
                              child: battleStack,
                            );
                          }

                          return battleStack;
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Right player deck + trick pile.
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _buildPlayerDeck(
                label: playerNum == 2 ? 'YOU' : 'OPP',
                count: p2DeckCount,
                color: AppTheme.player2Color,
                gs: gs,
                isLeft: false,
              ),
            ),
          ],
        );

        if (constraints.maxWidth >= totalMinWidth) {
          return arena;
        }

        // The viewport is too narrow to fit the minimum arena width. Scroll
        // horizontally so the layout stays coherent and nothing is forced to
        // wrap or clip vertically.
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: totalMinWidth),
                child: arena,
              ),
            ),
          ),
        );
      },
    );
  }

  // Builds a per-viewer sentence: my card first, verb depends on whether
  // I won ("beats") or lost ("loses to"), followed by the opponent's card.
  String? _buildPerspectiveReason(GameState gs, int playerNum) {
    final result = gs.lastResult;
    if (result == null) return null;
    if (result == RoundResult.tie) {
      return (gs.roundReason != null && gs.roundReason!.isNotEmpty)
          ? gs.roundReason
          : 'Equal rank \u2014 WAR!';
    }
    final myCard = playerNum == 1 ? gs.p1BattleCard : gs.p2BattleCard;
    final oppCard = playerNum == 1 ? gs.p2BattleCard : gs.p1BattleCard;
    if (myCard == null || oppCard == null) return null;

    final iWon =
        (result == RoundResult.p1Wins && playerNum == 1) ||
        (result == RoundResult.p2Wins && playerNum == 2);
    final verb = iWon ? 'beats' : 'loses to';
    final base = '${myCard.rankLabel} $verb ${oppCard.rankLabel}';

    final suffix = gs.roundReason;
    if (suffix != null && suffix.isNotEmpty) {
      return '$base \u2014 $suffix';
    }
    return base;
  }

  Widget _buildBattleIndicator(bool isWar) {
    if (isWar) {
      return AnimatedBuilder(
        animation: _warPulse,
        builder: (context, child) => Transform.scale(
          scale: _warPulse.value,
          child: const Text(
            '\u2694',
            style: TextStyle(fontSize: 36, color: AppTheme.metalGray),
          ),
        ),
      );
    }
    return Text(
      'VS',
      style: TextStyle(
        fontFamily: 'RobotoCondensed',
        fontWeight: FontWeight.w900,
        fontSize: 18,
        color: AppTheme.metalGray.withValues(alpha: 0.5),
        letterSpacing: 2,
      ),
    );
  }

  Widget _buildStatusBanner(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
          ],
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'RobotoCondensed',
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildActionArea(
    GameState gs,
    bool isGameOver,
    String? userId,
    int playerNum,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface.withValues(alpha: 0.9),
        border: Border(
          top: BorderSide(color: AppTheme.metalGray.withValues(alpha: 0.2)),
        ),
      ),
      child: isGameOver
          ? _buildGameOverArea(gs, playerNum)
          : _buildPlayArea(gs, userId, playerNum),
    );
  }

  bool _promptShown = false;

  Future<void> _maybeShowAccountPrompt() async {
    if (_promptShown) return;
    final authState = ref.read(authProvider);
    if (!authState.isAnonymous) return;

    await DeviceService.incrementGamesPlayed();
    final shouldShow = await DeviceService.shouldShowAccountPrompt();
    if (!shouldShow || !mounted) return;

    _promptShown = true;
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AccountPromptDialog(),
    );
  }

  Widget _buildGameOverArea(GameState gs, int playerNum) {
    final didWin = gs.gameWinner == 'Player $playerNum';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowAccountPrompt();
    });

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          didWin ? 'VICTORY' : 'DEFEAT',
          style: TextStyle(
            fontFamily: 'RobotoCondensed',
            fontWeight: FontWeight.w900,
            fontSize: 28,
            color: didWin ? AppTheme.winGreen : AppTheme.metalGray,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            MilitaryButton(
              label: 'REDEPLOY',
              color: Theme.of(context).colorScheme.primary,
              onPressed: () {
                _promptShown = false;
                ref.read(gameProvider.notifier).newGame();
              },
            ),
            const SizedBox(width: 16),
            MilitaryButton(
              label: 'RETREAT',
              color: AppTheme.metalGray,
              onPressed: () {
                ref.read(gameProvider.notifier).leaveGame();
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ],
    );
  }

  // Returns the action the player can perform by tapping the battle arena
  // (play card, collect, go to war, flip war card). Returns null when no
  // player action is available so the arena is not tappable while waiting.
  VoidCallback? _getArenaTapAction(
    GameState gs,
    String? userId,
    int playerNum,
  ) {
    if (_isCollecting || _isWarDelaying || gs.phase == GamePhase.gameOver) {
      return null;
    }

    final isResultNonTie =
        (gs.phase == GamePhase.result || gs.phase == GamePhase.warResult) &&
        gs.lastResult != RoundResult.tie;
    final isResultTie =
        (gs.phase == GamePhase.result || gs.phase == GamePhase.warResult) &&
        gs.lastResult == RoundResult.tie;
    final isReady =
        (playerNum == 1 && gs.p1Ready) || (playerNum == 2 && gs.p2Ready);

    if (isReady) return null;

    if (gs.phase == GamePhase.idle) {
      return userId != null
          ? () => ref.read(gameProvider.notifier).advance(userId)
          : null;
    } else if (isResultNonTie) {
      final didWin =
          (gs.lastResult == RoundResult.p1Wins && playerNum == 1) ||
          (gs.lastResult == RoundResult.p2Wins && playerNum == 2);
      return (didWin && userId != null) ? () => _startCollectAndPlay() : null;
    } else if (isResultTie) {
      return userId != null
          ? () => ref.read(gameProvider.notifier).advance(userId)
          : null;
    } else if (gs.phase == GamePhase.warPending) {
      return userId != null
          ? () => ref.read(gameProvider.notifier).advance(userId)
          : null;
    }
    return null;
  }

  Widget _buildPlayArea(GameState gs, String? userId, int playerNum) {
    // Determine button label and action
    String buttonLabel;
    VoidCallback? onPressed;

    final isResultNonTie =
        (gs.phase == GamePhase.result || gs.phase == GamePhase.warResult) &&
        gs.lastResult != RoundResult.tie;
    final isResultTie =
        (gs.phase == GamePhase.result || gs.phase == GamePhase.warResult) &&
        gs.lastResult == RoundResult.tie;

    if (_isCollecting) {
      buttonLabel = 'WAITING...';
      onPressed = null; // disabled during animation
    } else if (_isWarDelaying) {
      buttonLabel = 'OBSERVING WAR...';
      onPressed = null;
    } else {
      final isReady =
          (playerNum == 1 && gs.p1Ready) || (playerNum == 2 && gs.p2Ready);

      if (isReady) {
        buttonLabel = 'WAITING FOR OPPONENT...';
        onPressed = null;
      } else if (gs.phase == GamePhase.idle) {
        buttonLabel = 'PLAY CARD';
        onPressed = userId != null
            ? () => ref.read(gameProvider.notifier).advance(userId)
            : null;
      } else if (isResultNonTie) {
        final didWin =
            (gs.lastResult == RoundResult.p1Wins && playerNum == 1) ||
            (gs.lastResult == RoundResult.p2Wins && playerNum == 2);
        buttonLabel = didWin
            ? 'COLLECT CARDS'
            : 'WAITING FOR WINNER TO COLLECT...';
        onPressed = userId != null
            ? (didWin ? () => _startCollectAndPlay() : null)
            : null;
      } else if (isResultTie) {
        buttonLabel = gs.phase == GamePhase.warResult
            ? 'DOUBLE WAR!'
            : 'GO TO WAR!';
        onPressed = userId != null
            ? () => ref.read(gameProvider.notifier).advance(userId)
            : null;
      } else if (gs.phase == GamePhase.warPending) {
        buttonLabel = 'FLIP WAR CARD';
        onPressed = userId != null
            ? () => ref.read(gameProvider.notifier).advance(userId)
            : null;
      } else {
        buttonLabel = 'WAIT';
        onPressed = null;
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: MilitaryButton(label: buttonLabel, onPressed: onPressed),
        ),
        const SizedBox(height: 4),
        if (gs.phase == GamePhase.warPending)
          const Text(
            '3 cards face down, 1 face up',
            style: TextStyle(
              fontFamily: 'RobotoCondensed',
              fontSize: 10,
              color: AppTheme.metalGray,
            ),
          ),
      ],
    );
  }
}
