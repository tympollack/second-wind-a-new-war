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

  bool _isCollecting = false;
  int? _lastP1Cards;
  int? _lastP2Cards;
  RoundResult? _lastWinner;

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

    final userId = ref.read(authProvider).user?.id;
    if (userId != null) {
      ref.read(gameProvider.notifier).loadGame(widget.matchId, userId);
    }
  }

  @override
  void dispose() {
    _warAnimController.dispose();
    _collectAnimController.dispose();
    super.dispose();
  }

  void _startCollectAndPlay() {
    final gs = ref.read(gameProvider).gameState;
    if (gs == null) return;
    setState(() {
      _isCollecting = true;
      _lastWinner = gs.lastResult;
      _lastP1Cards = gs.p1Deck.length;
      _lastP2Cards = gs.p2Deck.length;
    });
    _collectAnimController.reset();
    _collectAnimController.forward();
  }

  void _finishCollectAndPlay() {
    final userId = ref.read(authProvider).user?.id;
    if (userId == null) return;
    ref.read(gameProvider.notifier).collectAndPlay(userId).then((_) {
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

    if (gs == null || gameNotifier.isLoading) {
      return _buildLoadingScreen();
    }

    final playerNum = gameNotifier.playerNum;
    final isGameOver = gs.phase == GamePhase.gameOver;
    final isWar =
        gs.phase == GamePhase.warPending || gs.phase == GamePhase.warResult;

    // P1 is always left, P2 is always right
    final p1DeckCount = gs.p1Deck.length;
    final p2DeckCount = gs.p2Deck.length;
    final p1Card = gs.p1BattleCard;
    final p2Card = gs.p2BattleCard;
    final p1FaceDown = gs.p1FaceDownCount;
    final p2FaceDown = gs.p2FaceDownCount;
    final showCards = p1Card != null && p2Card != null;

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
                p1Cards: p1DeckCount + (isP1Win && showCards ? potCards : 0),
                p2Cards: p2DeckCount + (isP2Win && showCards ? potCards : 0),
                removedCards: removedCards,
                lastP1Cards: _lastP1Cards,
                lastP2Cards: _lastP2Cards,
              ),
            ),
            // Main battle area — horizontal: P1 deck | cards | P2 deck
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // P1 deck area (left)
                    _buildPlayerDeck(
                      label: playerNum == 1 ? 'YOU' : 'OPP',
                      count: p1DeckCount,
                      color: AppTheme.player1Color,
                      secondWind: !gs.secondWindUsed &&
                          gs.secondWindDeck.isNotEmpty &&
                          gs.secondWindRecipient == null,
                      secondWindCount: gs.secondWindDeck.length,
                    ),
                    // Center battle area
                    Expanded(
                      child: _buildBattleArea(
                        gs: gs,
                        p1Card: p1Card,
                        p2Card: p2Card,
                        showCards: showCards,
                        isP1Win: isP1Win,
                        isP2Win: isP2Win,
                        isWar: isWar,
                        p1FaceDown: p1FaceDown,
                        p2FaceDown: p2FaceDown,
                      ),
                    ),
                    // P2 deck area (right)
                    _buildPlayerDeck(
                      label: playerNum == 2 ? 'YOU' : 'OPP',
                      count: p2DeckCount,
                      color: AppTheme.player2Color,
                      secondWind: false,
                      secondWindCount: 0,
                    ),
                  ],
                ),
              ),
            ),
            // Status banner
            if (gs.statusBanner != null && !_isCollecting)
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
          Image.asset(
            'assets/images/backgrounds/light_loading.jpg',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                Container(color: AppTheme.darkBg),
          ),
          Container(color: Colors.black.withValues(alpha: 0.4)),
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 200,
                  child: LinearProgressIndicator(
                    color: AppTheme.primaryCyan,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface.withValues(alpha: 0.9),
        border: Border(
          bottom: BorderSide(
            color: AppTheme.metalGray.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
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
                  'RETREAT',
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
          const Spacer(),
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
                    color: AppTheme.warRed,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ],
          const Spacer(),
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
    );
  }

  Widget _buildGameInfo(GameState gs) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (gs.trumpSuit != null) ...[
            _buildInfoChip(
              icon: '\u2726',
              value: gs.trumpSuit!.name.toUpperCase(),
              color: AppTheme.goldTrump,
            ),
            const SizedBox(width: 24),
          ],
          if (gs.muskRank != null) ...[
            _buildInfoChip(
              icon: '\u2694',
              value: _rankLabel(gs.muskRank!),
              color: AppTheme.purpleMusketeer,
            ),
            const SizedBox(width: 24),
          ],
          if (gs.pot.isNotEmpty)
            _buildInfoChip(
              icon: '\u2660',
              value: '${gs.pot.length} in pot',
              color: Colors.orange,
            ),
          if (gs.secondWindUsed) ...[
            if (gs.trumpSuit != null || gs.muskRank != null || gs.pot.isNotEmpty)
              const SizedBox(width: 24),
            _buildInfoChip(
              icon: '\u2600',
              value: '2ND WIND USED',
              color: AppTheme.primaryCyan,
            ),
          ],
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
    required bool secondWind,
    required int secondWindCount,
  }) {
    return SizedBox(
      width: 90,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Deck visual (stack of cards)
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
          if (secondWind) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.primaryCyan.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: AppTheme.primaryCyan.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                '2W: $secondWindCount',
                style: const TextStyle(
                  fontFamily: 'RobotoCondensed',
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                  color: AppTheme.primaryCyan,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBattleArea({
    required GameState gs,
    required PlayingCard? p1Card,
    required PlayingCard? p2Card,
    required bool showCards,
    required bool isP1Win,
    required bool isP2Win,
    required bool isWar,
    required int p1FaceDown,
    required int p2FaceDown,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Round reason text above cards
        if (gs.roundReason != null && !_isCollecting)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
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
        // Cards row: P1 card — VS/War indicator — P2 card
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // P1 face-down cards (war)
            if (isWar && p1FaceDown > 0)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FaceDownCardWidget(count: p1FaceDown, width: 50, height: 75),
              ),
            // P1 battle card
            AnimatedSlide(
              offset: _isCollecting && _lastWinner == RoundResult.p1Wins
                  ? Offset(-_collectAnimation.value * 1.5, 0)
                  : _isCollecting && _lastWinner == RoundResult.p2Wins
                      ? Offset(_collectAnimation.value * 1.5, 0)
                      : Offset.zero,
              duration: const Duration(milliseconds: 50),
              child: AnimatedOpacity(
                opacity: _isCollecting ? 1.0 - _collectAnimation.value : 1.0,
                duration: const Duration(milliseconds: 50),
                child: showCards && p1Card != null
                    ? PlayingCardWidget(
                        card: p1Card,
                        gameState: gs,
                        isWinner: isP1Win,
                        width: 80,
                        height: 120,
                      )
                    : _buildEmptySlot(),
              ),
            ),
            // VS / War indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildBattleIndicator(isWar),
            ),
            // P2 battle card
            AnimatedSlide(
              offset: _isCollecting && _lastWinner == RoundResult.p2Wins
                  ? Offset(_collectAnimation.value * 1.5, 0)
                  : _isCollecting && _lastWinner == RoundResult.p1Wins
                      ? Offset(-_collectAnimation.value * 1.5, 0)
                      : Offset.zero,
              duration: const Duration(milliseconds: 50),
              child: AnimatedOpacity(
                opacity: _isCollecting ? 1.0 - _collectAnimation.value : 1.0,
                duration: const Duration(milliseconds: 50),
                child: showCards && p2Card != null
                    ? PlayingCardWidget(
                        card: p2Card,
                        gameState: gs,
                        isWinner: isP2Win,
                        width: 80,
                        height: 120,
                      )
                    : _buildEmptySlot(),
              ),
            ),
            // P2 face-down cards (war)
            if (isWar && p2FaceDown > 0)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: FaceDownCardWidget(count: p2FaceDown, width: 50, height: 75),
              ),
          ],
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
            style: TextStyle(fontSize: 36, color: AppTheme.warRed),
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
            AppTheme.primaryCyan.withValues(alpha: 0.15),
            AppTheme.primaryCyan.withValues(alpha: 0.05),
          ],
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'RobotoCondensed',
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: AppTheme.primaryCyan,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildActionArea(
      GameState gs, bool isGameOver, String? userId, int playerNum) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          : _buildPlayArea(gs, userId),
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
            color: didWin ? AppTheme.winGreen : AppTheme.warRed,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            MilitaryButton(
              label: 'REDEPLOY',
              color: AppTheme.primaryCyan,
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

  Widget _buildPlayArea(GameState gs, String? userId) {
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
      buttonLabel = 'PLAY CARD';
      onPressed = null; // disabled during animation
    } else if (gs.phase == GamePhase.idle) {
      buttonLabel = 'PLAY CARD';
      onPressed = userId != null
          ? () => ref.read(gameProvider.notifier).advance(userId)
          : null;
    } else if (isResultNonTie) {
      // Cards are showing — next tap collects + plays new round
      buttonLabel = 'PLAY CARD';
      onPressed = userId != null ? () => _startCollectAndPlay() : null;
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

    Color buttonColor = isResultTie ? AppTheme.warRed : AppTheme.primaryRed;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MilitaryButton(
          label: buttonLabel,
          color: buttonColor,
          onPressed: onPressed,
          width: 220,
        ),
        const SizedBox(height: 4),
        if (gs.phase == GamePhase.idle)
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
