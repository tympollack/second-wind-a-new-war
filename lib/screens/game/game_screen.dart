import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../providers/game_provider.dart';
import '../../models/game_state.dart';
import '../../engine/game_engine.dart';
import '../../services/device_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/playing_card_widget.dart';
import '../../widgets/military_button.dart';
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
  late AnimationController _swordAnimController;
  late Animation<double> _swordRotation;

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

    _swordAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _swordRotation = Tween<double>(begin: -0.2, end: 0.2).animate(
      CurvedAnimation(parent: _swordAnimController, curve: Curves.elasticOut),
    );

    final userId = ref.read(authProvider).user?.id;
    if (userId != null) {
      ref.read(gameProvider.notifier).loadGame(widget.matchId, userId);
    }
  }

  @override
  void dispose() {
    _warAnimController.dispose();
    _swordAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameNotifier = ref.watch(gameProvider);
    final gs = gameNotifier.gameState;
    final userId = ref.read(authProvider).user?.id;

    if (gs == null || gameNotifier.isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.darkBg,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/backgrounds/light_loading.jpg',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(color: AppTheme.darkBg),
            ),
            Container(color: Colors.black.withValues(alpha: 0.4)),
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'WAR:',
                    style: TextStyle(
                      fontFamily: 'RobotoCondensed',
                      fontWeight: FontWeight.w900,
                      fontSize: 48,
                      color: AppTheme.metalLight,
                    ),
                  ),
                  Text(
                    'SECOND WIND',
                    style: TextStyle(
                      fontFamily: 'RobotoCondensed',
                      fontWeight: FontWeight.w700,
                      fontSize: 24,
                      color: AppTheme.metalLight,
                    ),
                  ),
                  SizedBox(height: 24),
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

    final playerNum = gameNotifier.playerNum;
    final isGameOver = gs.phase == GamePhase.gameOver;
    final isWar =
        gs.phase == GamePhase.warPending || gs.phase == GamePhase.warResult;
    final showCards = gs.p1BattleCard != null && gs.p2BattleCard != null;

    // Determine which cards are "mine" and "opponent's"
    final myDeckCount =
        playerNum == 1 ? gs.p1Deck.length : gs.p2Deck.length;
    final oppDeckCount =
        playerNum == 1 ? gs.p2Deck.length : gs.p1Deck.length;
    final myCard =
        playerNum == 1 ? gs.p1BattleCard : gs.p2BattleCard;
    final oppCard =
        playerNum == 1 ? gs.p2BattleCard : gs.p1BattleCard;
    final myFaceDown =
        playerNum == 1 ? gs.p1FaceDownCount : gs.p2FaceDownCount;
    final oppFaceDown =
        playerNum == 1 ? gs.p2FaceDownCount : gs.p1FaceDownCount;
    final isMyWin = (playerNum == 1 && gs.lastResult == RoundResult.p1Wins) ||
        (playerNum == 2 && gs.lastResult == RoundResult.p2Wins);
    final isOppWin = (playerNum == 1 && gs.lastResult == RoundResult.p2Wins) ||
        (playerNum == 2 && gs.lastResult == RoundResult.p1Wins);

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: Column(
        children: [
          // Top bar
          _buildTopBar(gs, playerNum),
          // Status banner
          if (gs.statusBanner != null) _buildStatusBanner(gs.statusBanner!),
          // Game info bar
          _buildInfoBar(gs),
          // Main battle area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // Opponent area
                  const SizedBox(height: 8),
                  _buildDeckCounter(
                    'OPPONENT',
                    oppDeckCount,
                    isOpponent: true,
                    playerColor: playerNum == 1
                        ? AppTheme.player2Color
                        : AppTheme.player1Color,
                  ),
                  const SizedBox(height: 16),
                  // Battle area
                  Expanded(
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Opponent face-down cards
                          if (isWar)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FaceDownCardWidget(count: oppFaceDown),
                            ),
                          // Opponent card
                          if (showCards && oppCard != null)
                            PlayingCardWidget(
                              card: oppCard,
                              gameState: gs,
                              isWinner: isOppWin,
                              width: 90,
                              height: 135,
                            )
                          else
                            _buildEmptySlot('OPP'),
                          const SizedBox(width: 16),
                          // VS / War indicator
                          _buildBattleIndicator(gs, isWar),
                          const SizedBox(width: 16),
                          // My card
                          if (showCards && myCard != null)
                            PlayingCardWidget(
                              card: myCard,
                              gameState: gs,
                              isWinner: isMyWin,
                              width: 90,
                              height: 135,
                            )
                          else
                            _buildEmptySlot('YOU'),
                          // My face-down cards
                          if (isWar)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: FaceDownCardWidget(count: myFaceDown),
                            ),
                        ],
                      ),
                    ),
                  ),
                  // My area
                  _buildDeckCounter(
                    'YOU (P$playerNum)',
                    myDeckCount,
                    playerColor: playerNum == 1
                        ? AppTheme.player1Color
                        : AppTheme.player2Color,
                  ),
                  // Second Wind indicator
                  if (!gs.secondWindUsed && gs.secondWindDeck.isNotEmpty)
                    _buildSecondWindIndicator(gs.secondWindDeck.length),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          // Action area
          _buildActionArea(gs, isGameOver, userId),
        ],
      ),
    );
  }

  Widget _buildTopBar(GameState gs, int playerNum) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 8,
      ),
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
            child: const Text(
              'RETREAT',
              style: TextStyle(
                fontFamily: 'RobotoCondensed',
                fontSize: 12,
                color: AppTheme.metalGray,
                letterSpacing: 1,
              ),
            ),
          ),
          const Spacer(),
          Text(
            'ROUND ${gs.round}',
            style: const TextStyle(
              fontFamily: 'RobotoCondensed',
              fontSize: 12,
              color: AppTheme.metalGray,
              letterSpacing: 1,
            ),
          ),
          Text(
            '  |  PLAYER $playerNum',
            style: const TextStyle(
              fontFamily: 'RobotoCondensed',
              fontSize: 12,
              color: AppTheme.metalGray,
              letterSpacing: 1,
            ),
          ),
          const Spacer(),
          if (gs.warDepth > 0)
            AnimatedBuilder(
              animation: _warPulse,
              builder: (context, child) => Transform.scale(
                scale: _warPulse.value,
                child: Text(
                  'WAR${gs.warDepth > 1 ? " x${gs.warDepth}" : ""}',
                  style: const TextStyle(
                    fontFamily: 'RobotoCondensed',
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: AppTheme.warRed,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryCyan.withValues(alpha: 0.2),
            AppTheme.primaryCyan.withValues(alpha: 0.05),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: AppTheme.primaryCyan.withValues(alpha: 0.3),
          ),
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

  Widget _buildInfoBar(GameState gs) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      color: AppTheme.darkSurface.withValues(alpha: 0.3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (gs.trumpSuit != null) ...[
            _buildInfoChip(
              'TRUMP',
              gs.trumpSuit!.name.toUpperCase(),
              AppTheme.goldTrump,
            ),
            const SizedBox(width: 16),
          ],
          if (gs.muskRank != null) ...[
            _buildInfoChip(
              'MUSKETEER',
              gs.muskRank.toString(),
              AppTheme.purpleMusketeer,
            ),
            const SizedBox(width: 16),
          ],
          if (gs.pot.isNotEmpty)
            _buildInfoChip(
              'POT',
              gs.pot.length.toString(),
              Colors.orange,
            ),
          if (gs.secondWindUsed) ...[
            const SizedBox(width: 16),
            const Text(
              '2ND WIND USED',
              style: TextStyle(
                fontFamily: 'RobotoCondensed',
                fontSize: 10,
                color: AppTheme.primaryCyan,
                letterSpacing: 1,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            fontFamily: 'RobotoCondensed',
            fontSize: 10,
            color: AppTheme.metalGray,
            letterSpacing: 1,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'RobotoCondensed',
            fontWeight: FontWeight.w900,
            fontSize: 12,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildDeckCounter(String label, int count,
      {bool isOpponent = false, Color? playerColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (playerColor ?? AppTheme.metalGray).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'RobotoCondensed',
              fontSize: 11,
              color: playerColor ?? AppTheme.metalGray,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            count.toString(),
            style: const TextStyle(
              fontFamily: 'RobotoCondensed',
              fontWeight: FontWeight.w900,
              fontSize: 28,
              color: AppTheme.metalLight,
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            'cards',
            style: TextStyle(
              fontFamily: 'RobotoCondensed',
              fontSize: 11,
              color: AppTheme.metalGray,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBattleIndicator(GameState gs, bool isWar) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (gs.roundReason != null)
          Container(
            constraints: const BoxConstraints(maxWidth: 140),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              gs.roundReason!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'RobotoCondensed',
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: AppTheme.metalLight,
              ),
            ),
          ),
        const SizedBox(height: 4),
        if (isWar)
          AnimatedBuilder(
            animation: _warPulse,
            builder: (context, child) => Transform.scale(
              scale: _warPulse.value,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Crossed swords
                  Transform.rotate(
                    angle: _swordRotation.value,
                    child: const Text(
                      '\u2694',
                      style: TextStyle(
                        fontSize: 40,
                        color: AppTheme.warRed,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Text(
            'VS',
            style: TextStyle(
              fontFamily: 'RobotoCondensed',
              fontWeight: FontWeight.w900,
              fontSize: 20,
              color: AppTheme.metalGray.withValues(alpha: 0.5),
              letterSpacing: 2,
            ),
          ),
      ],
    );
  }

  Widget _buildEmptySlot(String label) {
    return Container(
      width: 90,
      height: 135,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.metalGray.withValues(alpha: 0.2),
          width: 2,
          strokeAlign: BorderSide.strokeAlignInside,
        ),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'RobotoCondensed',
            fontSize: 12,
            color: AppTheme.metalGray.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }

  Widget _buildSecondWindIndicator(int count) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryCyan.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.primaryCyan.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.air, size: 16, color: AppTheme.primaryCyan),
          const SizedBox(width: 6),
          Text(
            'SECOND WIND READY ($count cards)',
            style: const TextStyle(
              fontFamily: 'RobotoCondensed',
              fontWeight: FontWeight.w600,
              fontSize: 11,
              color: AppTheme.primaryCyan,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionArea(GameState gs, bool isGameOver, String? userId) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface.withValues(alpha: 0.9),
        border: Border(
          top: BorderSide(
            color: AppTheme.metalGray.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: isGameOver
          ? _buildGameOverArea(gs)
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

  Widget _buildGameOverArea(GameState gs) {
    final playerNum = ref.read(gameProvider).playerNum;
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
        const SizedBox(height: 16),
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
    String buttonLabel;
    switch (gs.phase) {
      case GamePhase.idle:
        buttonLabel = 'PLAY CARD';
      case GamePhase.result:
        buttonLabel = gs.lastResult == RoundResult.tie
            ? 'GO TO WAR!'
            : 'COLLECT CARDS';
      case GamePhase.warPending:
        buttonLabel = 'FLIP WAR CARD';
      case GamePhase.warResult:
        buttonLabel = gs.lastResult == RoundResult.tie
            ? 'DOUBLE WAR!'
            : 'COLLECT ALL';
      default:
        buttonLabel = 'WAIT';
    }

    Color buttonColor = gs.lastResult == RoundResult.tie
        ? AppTheme.warRed
        : AppTheme.primaryRed;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MilitaryButton(
          label: buttonLabel,
          color: buttonColor,
          onPressed: canAdvance(gs) && userId != null
              ? () => ref.read(gameProvider.notifier).advance(userId)
              : null,
          width: 240,
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
