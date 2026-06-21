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
  Timer? _botTimer;
  int _waitSeconds = 0;
  Timer? _countdownTimer;
  List<Map<String, dynamic>> _onlineUsers = [];

  static const _botTimeoutSeconds = 15;

  @override
  void initState() {
    super.initState();
    _loadOnlineUsers();
  }

  @override
  void dispose() {
    _joinCodeController.dispose();
    _matchChannel?.unsubscribe();
    _botTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadOnlineUsers() async {
    try {
      final users = await SupabaseService.getOnlineUsers();
      if (mounted) setState(() => _onlineUsers = users);
    } catch (_) {}
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
          if (updated['status'] == 'in-progress' &&
              updated['player2_id'] != null) {
            _botTimer?.cancel();
            _countdownTimer?.cancel();
            _navigateToGame(updated['id'] as String);
          }
        },
      );

      _startBotCountdown(match['id'] as String, userId);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to create game';
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
      final match = await SupabaseService.findMatch(code);
      if (match == null) {
        setState(() {
          _isLoading = false;
          _error = 'Game not found or already started';
        });
        return;
      }

      if (match['player1_id'] == userId) {
        setState(() {
          _isLoading = false;
          _error = 'Cannot join your own game';
        });
        return;
      }

      await SupabaseService.joinMatch(match['id'] as String, userId);
      _navigateToGame(match['id'] as String);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to join game';
      });
    }
  }

  void _startBotCountdown(String matchId, String userId) {
    _waitSeconds = 0;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _waitSeconds++);
    });

    _botTimer?.cancel();
    _botTimer = Timer(const Duration(seconds: _botTimeoutSeconds), () {
      _startBotGame(matchId, userId);
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
        setState(() => _error = 'Failed to start bot match');
      }
    }
  }

  void _navigateToBotGame(String matchId, String botName) {
    _matchChannel?.unsubscribe();
    final userId = ref.read(authProvider).user?.id;
    if (userId == null) return;

    ref.read(gameProvider.notifier).loadBotGame(matchId, userId, botName);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(matchId: matchId),
      ),
    );
    setState(() {
      _waitingMatch = null;
      _isLoading = false;
    });
  }

  Future<void> _cancelWaiting() async {
    if (_waitingMatch == null) return;
    _matchChannel?.unsubscribe();
    _botTimer?.cancel();
    _countdownTimer?.cancel();
    await SupabaseService.deleteMatch(_waitingMatch!['id'] as String);
    setState(() {
      _waitingMatch = null;
      _waitSeconds = 0;
    });
  }

  void _navigateToGame(String matchId) {
    _matchChannel?.unsubscribe();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(matchId: matchId),
      ),
    );
    setState(() {
      _waitingMatch = null;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final displayName = authState.displayName ?? 'Commander';

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background
          Image.asset(
            'assets/images/backgrounds/dark_lobby.jpg',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(color: AppTheme.darkBg),
          ),
          Container(
            color: Colors.black.withValues(alpha: 0.5),
          ),
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
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'RobotoCondensed',
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: 1,
                  color: color ?? AppTheme.metalLight,
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
                border: Border.all(color: AppTheme.primaryCyan),
              ),
              child: Text(
                _waitingMatch!['join_code'] as String? ?? '------',
                style: const TextStyle(
                  fontFamily: 'RobotoCondensed',
                  fontWeight: FontWeight.w900,
                  fontSize: 36,
                  color: AppTheme.primaryCyan,
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
                    color: AppTheme.primaryCyan.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _waitSeconds < _botTimeoutSeconds
                      ? 'Searching for opponent... ${_botTimeoutSeconds - _waitSeconds}s'
                      : 'Matching with opponent...',
                  style: const TextStyle(color: AppTheme.metalGray, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 24),
            MilitaryButton(
              label: 'CANCEL',
              color: AppTheme.metalGray,
              onPressed: _cancelWaiting,
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
                color: AppTheme.primaryCyan,
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
          // Find Match button
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.primaryRed, width: 2),
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryRed.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: MilitaryButton(
              label: 'FIND MATCH',
              isLoading: _isLoading,
              onPressed: _createGame,
              width: double.infinity,
            ),
          ),
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
            ? AppTheme.primaryCyan.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        border: isCurrentUser
            ? Border.all(color: AppTheme.primaryCyan.withValues(alpha: 0.3))
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
                color: isCurrentUser ? AppTheme.primaryCyan : AppTheme.metalLight,
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
              color: isCurrentUser ? AppTheme.primaryCyan : AppTheme.primaryRed,
              boxShadow: [
                BoxShadow(
                  color: (isCurrentUser ? AppTheme.primaryCyan : AppTheme.primaryRed)
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
}
