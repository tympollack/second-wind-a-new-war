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
  late Animation<double> _collectAnimation;
  late AnimationController _pulseAnimController;
  late Animation<double> _pulseAnimation;
  late AnimationController _fireAnimController;
  late Animation<double> _fireAnimation;

  bool _isCollecting = false;
  int? _lastP1Cards;
  int? _lastP2Cards;
  RoundResult? _lastWinner;
  
  bool _isAutoPlay = false;
  bool _isWarDelaying = false;

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
    _collectAnimation = CurvedAnimation(
      parent: _collectAnimController,
      curve: Curves.easeIn,
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
      _lastP1Cards = gs.p1Deck.length;
      _lastP2Cards = gs.p2Deck.length;
    });
    _collectAnimController.reset();
    _collectAnimController.forward();
  }

  void _triggerAutoPlay(GameState gs, String? userId) {
    if (userId == null || gs.phase == GamePhase.gameOver || _isWarDelaying || _isCollecting) return;
    
    final playerNum = ref.read(gameProvider).playerNum;
    final isReady = (playerNum == 1 && gs.p1Ready) || (playerNum == 2 && gs.p2Ready);
    
    if (isReady) return;

    final isResultNonTie = (gs.phase == GamePhase.result || gs.phase == GamePhase.warResult) && gs.lastResult != RoundResult.tie;
    
    if (isResultNonTie) {
      final didWin = (gs.lastResult == RoundResult.p1Wins && playerNum == 1) || 
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
            _lastP1Cards = gs.p1Deck.length;
            _lastP2Cards = gs.p2Deck.length;
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

    ref.listen<GameState?>(
      gameProvider.select((state) => state.gameState),
      (previous, current) {
        if (current == null) return;
        // Check for warResult transition
        if (previous?.phase != GamePhase.warResult && current.phase == GamePhase.warResult) {
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
      },
    );

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
              )
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
    final isReady = (playerNum == 1 && gs.p1Ready) || (playerNum == 2 && gs.p2Ready);
    final hasCollected = (gs.phase == GamePhase.result || gs.phase == GamePhase.warResult) && isReady;
    final showCards = p1Card != null && p2Card != null && !hasCollected;

    final isP1Win = gs.lastResult == RoundResult.p1Wins;
    final isP2Win = gs.lastResult == RoundResult.p2Wins;

    final removedCards = gs.removedCardIds.length;
    final potCards = gs.pot.length +
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
            // Game info (Trump, Musketeer, etc.) — larger, closer to play area
            _buildGameInfo(gs),
            // Progress bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
              child: GameProgressBar(
                p1Cards: p1DeckCount,
                p2Cards: p2DeckCount,
                p1Discard: gs.p1Discard.length + (isP1Win && showCards ? potCards : 0),
                p2Discard: gs.p2Discard.length + (isP2Win && showCards ? potCards : 0),
                removedCards: removedCards,
                lastP1Cards: _lastP1Cards,
                lastP2Cards: _lastP2Cards,
              ),
            ),
            // Main battle area with Stack and AnimatedAlign
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildMainGameArea(gs, playerNum, showCards, isP1Win, isP2Win, isWar, p1DeckCount, p2DeckCount, p1FaceDown, p2FaceDown),
              ),
            ),
            // Status banner
            if (gs.statusBanner != null && !hasCollected)
              _buildStatusBanner(gs.statusBanner!),
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
        final fireAlpha = anyOnFire ? (0.15 + _fireAnimation.value * 0.12) : 0.0;
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
            color: anyOnFire ? null : AppTheme.darkSurface.withValues(alpha: 0.9),
            border: Border(
              bottom: BorderSide(
                color: anyOnFire
                    ? const Color(0xFFCC5500).withValues(alpha: 0.3 + _fireAnimation.value * 0.2)
                    : AppTheme.metalGray.withValues(alpha: 0.2),
              ),
            ),
          ),
          child: child,
        );
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () {
                  ref.read(gameProvider.notifier).leaveGame();
                  Navigator.of(context).pop();
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back, size: 16, color: AppTheme.metalGray),
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
                    Icon(Icons.smart_toy, size: 16, color: _isAutoPlay ? Theme.of(context).colorScheme.primary : AppTheme.metalGray),
                    const SizedBox(width: 4),
                    Text(
                      'AUTO',
                      style: TextStyle(
                        fontFamily: 'RobotoCondensed',
                        fontSize: 12,
                        color: _isAutoPlay ? Theme.of(context).colorScheme.primary : AppTheme.metalGray,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (gs.p1WinStreak >= 3)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(
                        '🔥×${gs.p1WinStreak}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  if (gs.p2WinStreak >= 3)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(
                        '🔥×${gs.p2WinStreak}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  GestureDetector(
                    onTap: () {
                      final matchId = ref.read(gameProvider).matchId;
                      if (matchId != null) {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => MatchStatsScreen(matchId: matchId),
                        ));
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bar_chart, size: 14,
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7)),
                        const SizedBox(width: 3),
                        Text(
                          'STATS',
                          style: TextStyle(
                            fontFamily: 'RobotoCondensed',
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
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
            ],
          ),
          Row(
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

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 16,
        runSpacing: 8,
        children: [
          if (gs.trumpSuit != null)
            _buildInfoChip(
              icon: '\u2726',
              value: gs.trumpSuit!.name.toUpperCase(),
              color: AppTheme.goldTrump,
            ),
          if (gs.muskRank != null)
            _buildInfoChip(
              icon: '\u2694',
              value: musketeersDead ? '💀' : 'MUSK: ${_rankLabel(gs.muskRank!)}',
              color: AppTheme.purpleMusketeer,
            ),
          if (gs.pot.isNotEmpty)
            _buildInfoChip(
              icon: '\u2660',
              value: '${gs.pot.length} in pot',
              color: Colors.orange,
            ),
          if (gs.removedCardIds.isNotEmpty)
            _buildInfoChip(
              icon: '\u2620',
              value: '${gs.removedCardIds.length} BURNED',
              color: AppTheme.metalGray,
            ),
          // Second Wind in the status bar
          if (!gs.secondWindUsed && gs.secondWindDeck.isNotEmpty)
            _buildInfoChip(
              icon: '💨',
              value: '2W: ${gs.secondWindDeck.length}',
              color: AppTheme.winGreen,
            ),
          if (gs.secondWindUsed)
            _buildInfoChip(
              icon: '☀',
              value: '2W SPENT',
              color: AppTheme.metalGray,
            ),
        ],
      ),
    );
  }

  String _rankLabel(int rank) {
    switch (rank) {
      case 11: return 'J';
      case 12: return 'Q';
      case 13: return 'K';
      case 14: return 'A';
      default: return rank.toString();
    }
  }

  Widget _buildInfoChip({
    required String icon,
    required String value,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          icon,
          style: TextStyle(fontSize: 18, color: color),
        ),
        const SizedBox(width: 6),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'RobotoCondensed',
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: color,
            letterSpacing: 0.5,
          ),
        ),
      ],
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
          opacity = (0.85 + brightBoost + _pulseAnimation.value * 0.15).clamp(0.0, 1.0);
        }
        return Opacity(
          opacity: opacity,
          child: child,
        );
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
                colors: [
                  color.withValues(alpha: 0.15),
                  AppTheme.darkCard,
                ],
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
      width: 60 + (lastTrick.length > 1 ? (lastTrick.length - 1) * 15.0 : 0.0),
      height: 84,
      child: lastTrick.isNotEmpty
          ? Stack(
              children: List.generate(lastTrick.length, (index) {
                return Positioned(
                  left: index * 15.0,
                  child: PlayingCardWidget(
                    card: lastTrick[index],
                    gameState: gs,
                    isWinner: false,
                    isBurning: false,
                    width: 60,
                    height: 84,
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
          ? [
              discardWidget,
              const SizedBox(width: 8),
              deckWidget,
            ]
          : [
              deckWidget,
              const SizedBox(width: 8),
              discardWidget,
            ],
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

  Widget _buildFaceDownCardsStack(List<PlayingCard> cards, GameState gs, bool isP1) {
    return Stack(
      alignment: isP1 ? Alignment.centerRight : Alignment.centerLeft,
      children: List.generate(cards.length, (index) {
        return Padding(
          padding: EdgeInsets.only(
            left: isP1 ? 0 : index * 20.0,
            right: isP1 ? index * 20.0 : 0,
          ),
          child: PlayingCardWidget(
            card: cards[index],
            gameState: gs,
            isWinner: false,
            isBurning: false,
            width: 60,
            height: 90,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMainGameArea(
      GameState gs, int playerNum, bool showCards, bool isP1Win, bool isP2Win, 
      bool isWar, int p1DeckCount, int p2DeckCount, int p1FaceDown, int p2FaceDown) {

    // Calculate alignments
    final p1Ready = gs.p1Ready || showCards;
    final p2Ready = gs.p2Ready || showCards;
    
    // P1 Battle Card Alignment
    Alignment p1Align = Alignment.centerLeft;
    if (p1Ready) {
      if (_isCollecting) {
        p1Align = _lastWinner == RoundResult.p1Wins ? Alignment.centerLeft : Alignment.centerRight;
      } else {
        p1Align = const Alignment(-0.08, 0); // Fanned slightly left
      }
    }

    // P2 Battle Card Alignment
    Alignment p2Align = Alignment.centerRight;
    if (p2Ready) {
      if (_isCollecting) {
        p2Align = _lastWinner == RoundResult.p1Wins ? Alignment.centerLeft : Alignment.centerRight;
      } else {
        p2Align = const Alignment(0.08, 0); // Fanned slightly right
      }
    }

    // P1 War Face Down Alignment
    Alignment p1WarAlign = Alignment.centerLeft;
    if (isWar && p1FaceDown > 0) {
      if (_isCollecting) {
        p1WarAlign = _lastWinner == RoundResult.p1Wins ? Alignment.centerLeft : Alignment.centerRight;
      } else {
        p1WarAlign = const Alignment(-0.25, 0);
      }
    }

    // P2 War Face Down Alignment
    Alignment p2WarAlign = Alignment.centerRight;
    if (isWar && p2FaceDown > 0) {
      if (_isCollecting) {
        p2WarAlign = _lastWinner == RoundResult.p1Wins ? Alignment.centerLeft : Alignment.centerRight;
      } else {
        p2WarAlign = const Alignment(0.25, 0);
      }
    }

    final p1Card = gs.p1BattleCard;
    final p2Card = gs.p2BattleCard;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Center text (VS, Round reason)
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (gs.roundReason != null && !_isCollecting)
              Padding(
                padding: const EdgeInsets.only(bottom: 120),
                child: Text(
                  gs.roundReason!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'RobotoCondensed',
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppTheme.metalLight,
                  ),
                ),
              ),
            _buildBattleIndicator(isWar),
          ],
        ),

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
                  ? _buildFaceDownCardsStack(_getP1FaceDownCards(gs), gs, true)
                  : FaceDownCardWidget(count: p1FaceDown, width: 60, height: 90, spread: 20.0),
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
                  ? _buildFaceDownCardsStack(_getP2FaceDownCards(gs), gs, false)
                  : FaceDownCardWidget(count: p2FaceDown, width: 60, height: 90, spread: 20.0),
            ),
          ),

        // P1 Battle Card
        if (p1Ready)
          AnimatedAlign(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutQuart,
            alignment: p1Align,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: _isCollecting ? 0.0 : 1.0,
              child: showCards && p1Card != null
                  ? Transform.rotate(
                      angle: -0.05,
                      child: PlayingCardWidget(
                        card: p1Card,
                        gameState: gs,
                        isWinner: isP1Win,
                        isBurning: gs.p1WinStreak >= 3,
                        width: 80,
                        height: 120,
                      ),
                    )
                  : const FaceDownCardWidget(count: 1, width: 80, height: 120),
            ),
          ),

        // P2 Battle Card
        if (p2Ready)
          AnimatedAlign(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutQuart,
            alignment: p2Align,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: _isCollecting ? 0.0 : 1.0,
              child: showCards && p2Card != null
                  ? Transform.rotate(
                      angle: 0.05,
                      child: PlayingCardWidget(
                        card: p2Card,
                        gameState: gs,
                        isWinner: isP2Win,
                        isBurning: gs.p2WinStreak >= 3,
                        width: 80,
                        height: 120,
                      ),
                    )
                  : const FaceDownCardWidget(count: 1, width: 80, height: 120),
            ),
          ),

        // Left Deck
        Align(
          alignment: Alignment.centerLeft,
          child: _buildPlayerDeck(
            label: playerNum == 1 ? 'YOU' : 'OPP',
            count: p1DeckCount,
            color: AppTheme.player1Color,
            gs: gs,
            isLeft: true,
          ),
        ),

        // Right Deck
        Align(
          alignment: Alignment.centerRight,
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

  Widget _buildEmptySlot() {
    return Container(
      width: 80,
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.metalGray.withValues(alpha: 0.2),
          width: 2,
        ),
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
      GameState gs, bool isGameOver, String? userId, int playerNum) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface.withValues(alpha: 0.9),
        border: Border(
          top: BorderSide(
            color: AppTheme.metalGray.withValues(alpha: 0.2),
          ),
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

  Widget _buildPlayArea(GameState gs, String? userId, int playerNum) {
    // Determine button label and action
    String buttonLabel;
    VoidCallback? onPressed;

    final isResultNonTie = (gs.phase == GamePhase.result ||
            gs.phase == GamePhase.warResult) &&
        gs.lastResult != RoundResult.tie;
    final isResultTie = (gs.phase == GamePhase.result ||
            gs.phase == GamePhase.warResult) &&
        gs.lastResult == RoundResult.tie;

    if (_isCollecting) {
      buttonLabel = 'WAITING...';
      onPressed = null; // disabled during animation
    } else if (_isWarDelaying) {
      buttonLabel = 'OBSERVING WAR...';
      onPressed = null;
    } else {
      final isReady = (playerNum == 1 && gs.p1Ready) || (playerNum == 2 && gs.p2Ready);
      
      if (isReady) {
        buttonLabel = 'WAITING FOR OPPONENT...';
        onPressed = null;
      } else if (gs.phase == GamePhase.idle) {
        buttonLabel = 'PLAY CARD';
        onPressed = userId != null
            ? () => ref.read(gameProvider.notifier).advance(userId)
            : null;
      } else if (isResultNonTie) {
        final didWin = (gs.lastResult == RoundResult.p1Wins && playerNum == 1) || 
                       (gs.lastResult == RoundResult.p2Wins && playerNum == 2);
        buttonLabel = didWin ? 'COLLECT CARDS' : 'WAITING FOR WINNER TO COLLECT...';
        onPressed = userId != null ? (didWin ? () => _startCollectAndPlay() : null) : null;
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
        MilitaryButton(
          label: buttonLabel,
          onPressed: onPressed,
          width: double.infinity,
        ),
        const SizedBox(height: 4),
        if (gs.phase == GamePhase.idle && gs.round == 0)
          const Text(
            'Tap to flip the next card',
            style: TextStyle(
              fontFamily: 'RobotoCondensed',
              fontSize: 10,
              color: AppTheme.metalGray,
            ),
          ),
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
