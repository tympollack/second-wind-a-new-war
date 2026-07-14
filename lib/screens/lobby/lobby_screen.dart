import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../providers/game_provider.dart';
import '../../services/supabase_service.dart';
import '../../services/bot_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/military_button.dart';
import '../../widgets/metal_panel.dart';
import '../game/game_screen.dart';
import '../stats/match_stats_screen.dart';
import '../stats/stats_screen.dart';
import '../settings/settings_screen.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../achievements/achievements_screen.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  const LobbyScreen({super.key});

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  final _joinCodeController = TextEditingController();
  String? _error;
  bool _isLoading = false;
  Map<String, dynamic>? _waitingMatch;
  RealtimeChannel? _matchChannel;
  int _waitSeconds = 0;
  Timer? _countdownTimer;
  List<Map<String, dynamic>> _onlineUsers = [];
  List<Map<String, dynamic>> _userMatches = [];

  RealtimeChannel? _presenceChannel;

  @override
  void initState() {
    super.initState();
    _initPresence();
    _loadActiveMatches();
  }

  Future<void> _loadActiveMatches() async {
    final userId = ref.read(authProvider).user?.id;
    if (userId == null) return;
    try {
      final matches = await SupabaseService.getUserMatches(userId);
      if (mounted) setState(() => _userMatches = matches);
    } catch (_) {}
  }

  @override
  void dispose() {
    _joinCodeController.dispose();
    _matchChannel?.unsubscribe();
    _presenceChannel?.unsubscribe();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _initPresence() {
    final userId = ref.read(authProvider).user?.id;
    final displayName = ref.read(authProvider).displayName ?? 'Commander';
    if (userId == null) return;

    _presenceChannel = SupabaseService.client.channel('wsw-lobby');

    _presenceChannel!.onPresenceSync((_) {
      final state = _presenceChannel!.presenceState();
      final List<Map<String, dynamic>> online = [];

      for (final presenceInfo in state) {
        for (final presence in presenceInfo.presences) {
          online.add({
            'id': presence.payload['id'],
            'display_name': presence.payload['display_name'],
          });
        }
      }

      // Deduplicate by ID
      final uniqueOnline = {for (var user in online) user['id']: user}.values.toList();

      if (mounted) {
        setState(() {
          _onlineUsers = uniqueOnline;
        });
      }
    }).subscribe((status, [error]) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        await _presenceChannel!.track({
          'id': userId,
          'display_name': displayName,
        });
      }
    });
  }

  Future<void> _createGame() async {
    final userId = ref.read(authProvider).user?.id;
    if (userId == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final match = await SupabaseService.createMatch(userId);
      setState(() {
        _waitingMatch = match;
        _isLoading = false;
      });

      _matchChannel = SupabaseService.subscribeToMatch(
        match['id'] as String,
        (updated) {
          if (updated['status'] == 'in_progress' &&
              updated['player2_id'] != null) {
            _countdownTimer?.cancel();
            _navigateToGame(updated['id'] as String);
          }
        },
      );

      _startCountup(match['id'] as String);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to create game: $e';
      });
    }
  }

  Future<void> _joinGame() async {
    final code = _joinCodeController.text.trim();
    if (code.isEmpty) return;
    final userId = ref.read(authProvider).user?.id;
    if (userId == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final matchId = await SupabaseService.joinMatchByCode(code, userId);
      _navigateToGame(matchId);
    } catch (e) {
      String errorMessage = 'Failed to join game';
      if (e is Exception) {
        errorMessage = e.toString().replaceAll('Exception: ', '');
      }
      setState(() {
        _isLoading = false;
        _error = errorMessage;
      });
    }
  }

  void _startCountup(String matchId) {
    _waitSeconds = 0;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _waitSeconds++);

      // Polling fallback: Check if opponent joined every 2 seconds
      if (_waitSeconds % 2 == 0) {
        try {
          final match = await SupabaseService.getMatch(matchId);
          if (match != null && match['player2_id'] != null) {
            _countdownTimer?.cancel();
            _navigateToGame(matchId);
          }
        } catch (_) {}
      }
    });
  }

  Future<void> _startBotGame(String matchId, String userId) async {
    _countdownTimer?.cancel();
    _matchChannel?.unsubscribe();

    final botName = BotService.generateBotName();
    try {
      await SupabaseService.startBotMatch(matchId);
      _navigateToBotGame(matchId, botName);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to start bot match: $e';
          _waitingMatch = null;
        });
      }
    }
  }

  Future<void> _navigateToBotGame(String matchId, String botName) async {
    _matchChannel?.unsubscribe();
    final userId = ref.read(authProvider).user?.id;
    if (userId == null) return;

    ref.read(gameProvider.notifier).loadBotGame(matchId, userId, botName);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(matchId: matchId),
      ),
    );
    if (mounted) {
      _loadActiveMatches();
      setState(() {
        _waitingMatch = null;
        _isLoading = false;
      });
    }
  }

  String _formatElapsed(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m > 0) return '${m}m ${s.toString().padLeft(2, '0')}s';
    return '${s}s';
  }

  Future<void> _instantBotGame() async {
    final userId = ref.read(authProvider).user?.id;
    if (userId == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final match = await SupabaseService.createMatch(userId);
      await _startBotGame(match['id'] as String, userId);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to start bot game: $e';
      });
    }
  }

  Future<void> _cancelWaiting() async {
    if (_waitingMatch == null) return;
    _matchChannel?.unsubscribe();
    _countdownTimer?.cancel();
    await SupabaseService.deleteMatch(_waitingMatch!['id'] as String);
    setState(() {
      _waitingMatch = null;
      _waitSeconds = 0;
    });
  }

  Future<void> _navigateToGame(String matchId) async {
    _matchChannel?.unsubscribe();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(matchId: matchId),
      ),
    );
    if (mounted) {
      _loadActiveMatches();
      setState(() {
        _waitingMatch = null;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (previous, next) {
      if (previous?.displayName != next.displayName && next.displayName != null) {
        final userId = next.user?.id;
        if (userId != null && _presenceChannel != null) {
          _presenceChannel!.track({
            'id': userId,
            'display_name': next.displayName,
          });
        }
      }
    });

    final authState = ref.watch(authProvider);
    final displayName = authState.displayName ?? 'Commander';

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background
          Container(color: AppTheme.darkBg),
          // Content
          SafeArea(
            child: Row(
              children: [
                // Left sidebar
                _buildSidebar(context),
                // Main content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Matchmaking panel
                        Expanded(
                          flex: 3,
                          child: _buildMatchmakingPanel(),
                        ),
                        const SizedBox(width: 16),
                        // Commanders panel
                        Expanded(
                          flex: 2,
                          child: _buildCommandersPanel(displayName),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Title
          Positioned(
            top: 8,
            left: 8,
            child: SafeArea(
              child: Row(
                children: [
                  Text(
                    'WAR: ',
                    style: TextStyle(
                      fontFamily: 'RobotoCondensed',
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      color: AppTheme.metalLight,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'SECOND WIND',
                    style: TextStyle(
                      fontFamily: 'RobotoCondensed',
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                      color: AppTheme.metalGray,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 10,
                        ),
                      ],
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

  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(left: 8, top: 40, bottom: 8),
      child: Column(
        children: [
          _buildSidebarButton(
            icon: Icons.analytics_outlined,
            label: 'STRATEGY',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StatsScreen()),
            ),
          ),
          const SizedBox(height: 8),
          _buildSidebarButton(
            icon: Icons.military_tech_outlined,
            label: 'ARSENAL',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          const SizedBox(height: 8),
          _buildSidebarButton(
            icon: Icons.handshake_outlined,
            label: 'DIPLOMACY',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
            ),
          ),
          const SizedBox(height: 8),
          _buildSidebarButton(
            icon: Icons.emoji_events_outlined,
            label: 'MEDALS',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AchievementsScreen()),
            ),
          ),
          const Spacer(),
          _buildSidebarButton(
            icon: Icons.logout,
            label: 'LOGOUT',
            onTap: () => ref.read(authProvider.notifier).signOut(),
            color: AppTheme.warRed,
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(
            color: AppTheme.darkSurface.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: (color ?? AppTheme.metalGray).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color ?? AppTheme.metalLight),
              const SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'RobotoCondensed',
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      letterSpacing: 1,
                      color: color ?? AppTheme.metalLight,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMatchmakingPanel() {
    if (_waitingMatch != null) {
      return MetalPanel(
        title: 'WAITING FOR OPPONENT',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const Text(
              'Share this code:',
              style: TextStyle(color: AppTheme.metalGray),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: AppTheme.darkBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).colorScheme.primary),
              ),
              child: Text(
                _waitingMatch!['join_code'] as String? ?? '------',
                style: TextStyle(
                  fontFamily: 'RobotoCondensed',
                  fontWeight: FontWeight.w900,
                  fontSize: 36,
                  color: Theme.of(context).colorScheme.primary,
                  letterSpacing: 8,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Searching for opponent... ${_formatElapsed(_waitSeconds)}',
                  style: const TextStyle(color: AppTheme.metalGray, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: MilitaryButton(
                    label: 'PLAY VS BOT',
                    color: AppTheme.metalGray,
                    onPressed: () {
                      final userId = ref.read(authProvider).user?.id;
                      if (userId != null) _startBotGame(_waitingMatch!['id'] as String, userId);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MilitaryButton(
                    label: 'CANCEL',
                    color: AppTheme.warRed,
                    onPressed: _cancelWaiting,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return MetalPanel(
      title: 'MATCHMAKING',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          MilitaryButton(
            label: 'CREATE GAME',
            isLoading: _isLoading,
            onPressed: _createGame,
            width: double.infinity,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                  child: Divider(
                      color: AppTheme.metalGray.withValues(alpha: 0.3))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'OR JOIN',
                  style: TextStyle(
                    fontFamily: 'RobotoCondensed',
                    fontSize: 11,
                    color: AppTheme.metalGray.withValues(alpha: 0.5),
                    letterSpacing: 1,
                  ),
                ),
              ),
              Expanded(
                  child: Divider(
                      color: AppTheme.metalGray.withValues(alpha: 0.3))),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _joinCodeController,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 6,
                  style: const TextStyle(
                    fontFamily: 'RobotoCondensed',
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: AppTheme.metalLight,
                    letterSpacing: 4,
                  ),
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    hintText: 'CODE',
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              MilitaryButton(
                label: 'JOIN',
                isLoading: _isLoading,
                color: Theme.of(context).colorScheme.primary,
                onPressed: _joinGame,
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: AppTheme.warRed, fontSize: 12),
            ),
          ],
          const SizedBox(height: 24),
          MilitaryButton(
            label: 'PLAY VS BOT',
            isLoading: _isLoading,
            onPressed: _instantBotGame,
            width: double.infinity,
          ),

          // ── Match History ───────────────────────────────────────
          Builder(builder: (context) {
            final activeMatches = _userMatches.where((m) => m['status'] == 'in_progress').toList();
            final finishedMatches = _userMatches.where((m) => m['status'] == 'completed').toList();

            if (_userMatches.isEmpty) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (activeMatches.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildSectionDivider(context, 'ACTIVE MATCHES'),
                  const SizedBox(height: 8),
                  ...activeMatches.map((m) => _buildMatchCard(context, m, isFinished: false)),
                ],
                if (finishedMatches.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildSectionDivider(context, 'HISTORY'),
                  const SizedBox(height: 8),
                  ...finishedMatches.map((m) => _buildMatchCard(context, m, isFinished: true)),
                ],
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCommandersPanel(String displayName) {
    return MetalPanel(
      title: 'COMMANDERS',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ONLINE (${_onlineUsers.length})',
            style: const TextStyle(
              fontFamily: 'RobotoCondensed',
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 1,
              color: AppTheme.metalGray,
            ),
          ),
          const SizedBox(height: 8),
          // Current user
          _buildCommanderRow(displayName, isCurrentUser: true),
          const SizedBox(height: 4),
          // Other online users
          ..._onlineUsers
              .where((u) =>
                  u['id'] != ref.read(authProvider).user?.id)
              .take(8)
              .map((u) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _buildCommanderRow(
                        u['display_name'] as String? ?? 'Unknown'),
                  )),
        ],
      ),
    );
  }

  Widget _buildCommanderRow(String name, {bool isCurrentUser = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        border: isCurrentUser
            ? Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3))
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name.toUpperCase(),
              style: TextStyle(
                fontFamily: 'RobotoCondensed',
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: isCurrentUser ? Theme.of(context).colorScheme.primary : AppTheme.metalLight,
                letterSpacing: 0.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCurrentUser ? Theme.of(context).colorScheme.primary : AppTheme.primaryRed,
              boxShadow: [
                BoxShadow(
                  color: (isCurrentUser ? Theme.of(context).colorScheme.primary : AppTheme.primaryRed)
                      .withValues(alpha: 0.5),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionDivider(BuildContext context, String label) {
    return Row(
      children: [
        Expanded(child: Divider(color: AppTheme.metalGray.withValues(alpha: 0.3))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'RobotoCondensed',
              fontSize: 10,
              color: AppTheme.metalGray.withValues(alpha: 0.5),
              letterSpacing: 1.5,
            ),
          ),
        ),
        Expanded(child: Divider(color: AppTheme.metalGray.withValues(alpha: 0.3))),
      ],
    );
  }

  Widget _buildMatchCard(
    BuildContext context,
    Map<String, dynamic> match, {
    required bool isFinished,
  }) {
    final matchId = match['id'] as String;
    final p1Name = match['p1_name'] as String? ?? 'Player 1';
    final p2Name = match['p2_name'] as String? ?? 'Player 2';
    final round = match['round'] as int? ?? 0;
    final gameWinner = match['game_winner'] as String?;
    final primary = Theme.of(context).colorScheme.primary;

    final dimColor = AppTheme.metalGray.withValues(alpha: 0.4);
    final borderColor = isFinished
        ? AppTheme.metalGray.withValues(alpha: 0.2)
        : primary.withValues(alpha: 0.3);
    final bgColor = isFinished
        ? AppTheme.darkSurface.withValues(alpha: 0.3)
        : AppTheme.darkSurface.withValues(alpha: 0.6);

    String? winnerLabel;
    if (isFinished && gameWinner != null) {
      winnerLabel = gameWinner == 'Player 1' ? p1Name : p2Name;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Player row + round
            Row(
              children: [
                Expanded(
                  child: Text(
                    p1Name.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'RobotoCondensed',
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: AppTheme.player1Color.withValues(alpha: isFinished ? 0.5 : 1.0),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  round > 0 ? 'RD $round' : '—',
                  style: TextStyle(
                    fontFamily: 'RobotoCondensed',
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: isFinished ? dimColor : AppTheme.metalLight,
                  ),
                ),
                Expanded(
                  child: Text(
                    p2Name.toUpperCase(),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: 'RobotoCondensed',
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: AppTheme.player2Color.withValues(alpha: isFinished ? 0.5 : 1.0),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            // Winner line (finished only)
            if (winnerLabel != null) ...[
              const SizedBox(height: 4),
              Text(
                '🏆 $winnerLabel wins',
                style: TextStyle(
                  fontFamily: 'RobotoCondensed',
                  fontSize: 11,
                  color: AppTheme.metalGray,
                ),
              ),
            ],

            const SizedBox(height: 8),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // View Stats always visible
                GestureDetector(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => MatchStatsScreen(matchId: matchId),
                  )),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.darkBg,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: AppTheme.metalGray.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      'VIEW STATS',
                      style: TextStyle(
                        fontFamily: 'RobotoCondensed',
                        fontSize: 11,
                        color: AppTheme.metalGray,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
                // Resume only for active matches
                if (!isFinished) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _navigateToGame(matchId),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: primary.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        'RESUME',
                        style: TextStyle(
                          fontFamily: 'RobotoCondensed',
                          fontSize: 11,
                          color: primary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
