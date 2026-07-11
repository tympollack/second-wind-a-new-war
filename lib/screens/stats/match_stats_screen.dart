import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/achievement.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/metal_panel.dart';

class MatchStatsScreen extends ConsumerStatefulWidget {
  final String matchId;

  const MatchStatsScreen({super.key, required this.matchId});

  @override
  ConsumerState<MatchStatsScreen> createState() => _MatchStatsScreenState();
}

class _MatchStatsScreenState extends ConsumerState<MatchStatsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isLoading = true;
  Map<String, dynamic>? _match;
  Map<String, dynamic>? _gameState;
  List<Map<String, dynamic>> _p1Achievements = [];
  List<Map<String, dynamic>> _p2Achievements = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    try {
      // Load match row
      final match = await SupabaseService.getMatch(widget.matchId);
      if (match == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Load game state
      final gs = await SupabaseService.getGameState(widget.matchId);
      final stateJson =
          (gs?['state'] as Map<String, dynamic>?) ?? {};

      // Determine match time window for achievement attribution
      final createdAt = match['created_at'] != null
          ? DateTime.parse(match['created_at'] as String)
          : null;
      final finishedAt = match['finished_at'] != null
          ? DateTime.parse(match['finished_at'] as String)
          : null;

      // Load achievements for both players within the match window
      final p1Id = match['player1_id'] as String?;
      final p2Id = match['player2_id'] as String?;

      List<Map<String, dynamic>> p1Ach = [];
      List<Map<String, dynamic>> p2Ach = [];

      if (p1Id != null) {
        final all = await SupabaseService.getUserAchievements(p1Id);
        p1Ach = all.where((a) {
          if (createdAt == null) return false;
          final unlocked = a['unlocked_at'] != null
              ? DateTime.parse(a['unlocked_at'] as String)
              : null;
          if (unlocked == null) return false;
          if (unlocked.isBefore(createdAt)) return false;
          if (finishedAt != null && unlocked.isAfter(finishedAt)) return false;
          return true;
        }).toList();
      }

      if (p2Id != null) {
        final all = await SupabaseService.getUserAchievements(p2Id);
        p2Ach = all.where((a) {
          if (createdAt == null) return false;
          final unlocked = a['unlocked_at'] != null
              ? DateTime.parse(a['unlocked_at'] as String)
              : null;
          if (unlocked == null) return false;
          if (unlocked.isBefore(createdAt)) return false;
          if (finishedAt != null && unlocked.isAfter(finishedAt)) return false;
          return true;
        }).toList();
      }

      // Enrich match with display names
      final enrichedMatch = Map<String, dynamic>.from(match);
      if (p1Id != null) {
        final p1 = await SupabaseService.getUser(p1Id);
        enrichedMatch['p1_name'] = p1?['display_name'] as String? ?? 'Player 1';
      }
      if (p2Id != null) {
        final p2 = await SupabaseService.getUser(p2Id);
        enrichedMatch['p2_name'] = p2?['display_name'] as String? ?? 'Player 2';
      }

      setState(() {
        _match = enrichedMatch;
        _gameState = stateJson;
        _p1Achievements = p1Ach;
        _p2Achievements = p2Ach;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isFinished = _match?['status'] == 'completed';
    final gameWinner = _gameState?['gameWinner'] as String?;
    final round = _gameState?['round'] as int? ?? 0;
    final p1Cards = (_gameState?['p1Deck'] as List?)?.length ?? 0;
    final p2Cards = (_gameState?['p2Deck'] as List?)?.length ?? 0;
    final p1Name = _match?['p1_name'] as String? ?? 'Player 1';
    final p2Name = _match?['p2_name'] as String? ?? 'Player 2';
    final userId = ref.read(authProvider).user?.id;
    final myPlayerNum = _match?['player1_id'] == userId ? 1 : 2;

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: AppTheme.darkSurface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.metalGray),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MATCH INTEL',
              style: const TextStyle(
                fontFamily: 'RobotoCondensed',
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: AppTheme.metalLight,
                letterSpacing: 2,
              ),
            ),
            Text(
              '$p1Name  vs  $p2Name',
              style: TextStyle(
                fontFamily: 'RobotoCondensed',
                fontSize: 11,
                color: AppTheme.metalGray,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: primary,
          unselectedLabelColor: AppTheme.metalGray,
          indicatorColor: primary,
          labelStyle: const TextStyle(
            fontFamily: 'RobotoCondensed',
            fontWeight: FontWeight.w700,
            fontSize: 12,
            letterSpacing: 1,
          ),
          tabs: const [
            Tab(text: 'OVERVIEW'),
            Tab(text: 'BATTLEFIELD'),
            Tab(text: 'MEDALS'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primary))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(
                  context, isFinished, gameWinner, round, p1Name, p2Name,
                  p1Cards, p2Cards, myPlayerNum, primary,
                ),
                _buildBattlefieldTab(context, p1Name, p2Name, primary),
                _buildMedalsTab(context, p1Name, p2Name, primary),
              ],
            ),
    );
  }

  Widget _buildOverviewTab(
    BuildContext context,
    bool isFinished,
    String? gameWinner,
    int round,
    String p1Name,
    String p2Name,
    int p1Cards,
    int p2Cards,
    int myPlayerNum,
    Color primary,
  ) {
    final p1Wins = _gameState?['p1Wins'] as int? ?? 0;
    final p2Wins = _gameState?['p2Wins'] as int? ?? 0;
    final burnedCount = (_gameState?['removedCardIds'] as List?)?.length ?? 0;
    final potCount = (_gameState?['pot'] as List?)?.length ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Winner banner (if finished)
          if (isFinished && gameWinner != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primary.withValues(alpha: 0.15),
                    primary.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primary.withValues(alpha: 0.4)),
              ),
              child: Column(
                children: [
                  const Text('🏆', style: TextStyle(fontSize: 36)),
                  const SizedBox(height: 8),
                  Text(
                    gameWinner == 'Player 1' ? p1Name : p2Name,
                    style: TextStyle(
                      fontFamily: 'RobotoCondensed',
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      color: primary,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    'VICTORIOUS',
                    style: TextStyle(
                      fontFamily: 'RobotoCondensed',
                      fontSize: 12,
                      color: primary.withValues(alpha: 0.6),
                      letterSpacing: 3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // In-progress badge
          if (!isFinished) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.winGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.winGreen.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.winGreen,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'MATCH IN PROGRESS',
                    style: TextStyle(
                      fontFamily: 'RobotoCondensed',
                      fontSize: 12,
                      color: AppTheme.winGreen,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Stats grid
          MetalPanel(
            title: 'MATCH SUMMARY',
            child: Column(
              children: [
                _buildStatRow('ROUND', '$round', primary),
                _buildStatRow('ROUNDS WON (P1)', '$p1Wins', AppTheme.player1Color),
                _buildStatRow('ROUNDS WON (P2)', '$p2Wins', AppTheme.player2Color),
                _buildStatRow('CARDS BURNED', '$burnedCount', AppTheme.metalGray),
                if (potCount > 0)
                  _buildStatRow('CARDS IN POT', '$potCount', Colors.orange),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Deck sizes
          MetalPanel(
            title: 'CURRENT CARD COUNTS',
            child: Column(
              children: [
                _buildStatRow(p1Name.toUpperCase(), '$p1Cards cards', AppTheme.player1Color),
                _buildStatRow(p2Name.toUpperCase(), '$p2Cards cards', AppTheme.player2Color),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBattlefieldTab(
      BuildContext context, String p1Name, String p2Name, Color primary) {
    final trumpSuit = _gameState?['trumpSuit'] as String?;
    final muskRank = _gameState?['muskRank'] as int?;
    final secondWindUsed = _gameState?['secondWindUsed'] as bool? ?? false;
    final removedByRank =
        (_gameState?['removedByRank'] as Map<String, dynamic>?)
            ?.map((k, v) => MapEntry(k, v as int)) ??
            {};
    final p1WinStreak = _gameState?['p1WinStreak'] as int? ?? 0;
    final p2WinStreak = _gameState?['p2WinStreak'] as int? ?? 0;

    String? muskLabel;
    if (muskRank != null) {
      const labels = {11: 'J', 12: 'Q', 13: 'K', 14: 'A'};
      final raw = labels[muskRank] ?? '$muskRank';
      final destroyed = (removedByRank[muskRank.toString()] ?? 0) >= 4;
      muskLabel = destroyed ? '$raw (💀 All Destroyed)' : raw;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: MetalPanel(
        title: 'BATTLEFIELD CONDITIONS',
        child: Column(
          children: [
            _buildStatRow('TRUMP SUIT', trumpSuit?.toUpperCase() ?? 'NONE', AppTheme.goldTrump),
            _buildStatRow('MUSK RANK', muskLabel ?? 'NONE', AppTheme.purpleMusketeer),
            _buildStatRow('2ND WIND', secondWindUsed ? 'SPENT' : 'AVAILABLE', secondWindUsed ? AppTheme.metalGray : AppTheme.winGreen),
            _buildStatRow('P1 WIN STREAK', '$p1WinStreak', AppTheme.player1Color),
            _buildStatRow('P2 WIN STREAK', '$p2WinStreak', AppTheme.player2Color),
            const Divider(color: AppTheme.metalGray, height: 24),
            _buildStatRow('BURNED BY RANK', '', AppTheme.metalGray),
            ...removedByRank.entries.where((e) => e.value > 0).map((e) {
              const labels = {'11': 'J', '12': 'Q', '13': 'K', '14': 'A'};
              final label = labels[e.key] ?? e.key;
              return _buildStatRow('  Rank $label', '${e.value}x', AppTheme.metalGray);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildMedalsTab(
      BuildContext context, String p1Name, String p2Name, Color primary) {
    final allDefs = AchievementDefinitions.all;

    Achievement? findDef(String id) {
      try {
        return allDefs.firstWhere((a) => a.id == id);
      } catch (_) {
        return null;
      }
    }

    Widget achList(List<Map<String, dynamic>> achs, String label, Color color) {
      if (achs.isEmpty) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: MetalPanel(
            title: label,
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'No medals earned this match',
                style: TextStyle(color: AppTheme.metalGray, fontSize: 13),
              ),
            ),
          ),
        );
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: MetalPanel(
          title: label,
          child: Column(
            children: achs.map((a) {
              final def = findDef(a['achievement_id'] as String);
              if (def == null) return const SizedBox.shrink();
              final scopeLabel = switch (def.scope) {
                AchievementScope.match => 'MATCH',
                AchievementScope.game => 'GAME',
                AchievementScope.player => 'BOUNTY',
              };
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Text(def.icon, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            def.name,
                            style: const TextStyle(
                              fontFamily: 'RobotoCondensed',
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppTheme.metalLight,
                            ),
                          ),
                          Text(
                            def.description,
                            style: const TextStyle(
                              fontFamily: 'RobotoCondensed',
                              fontSize: 11,
                              color: AppTheme.metalGray,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: color.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        scopeLabel,
                        style: TextStyle(
                          fontFamily: 'RobotoCondensed',
                          fontSize: 9,
                          color: color,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          achList(_p1Achievements, '${p1Name.toUpperCase()} MEDALS',
              AppTheme.player1Color),
          achList(_p2Achievements, '${p2Name.toUpperCase()} MEDALS',
              AppTheme.player2Color),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'RobotoCondensed',
              fontSize: 13,
              color: AppTheme.metalGray,
              letterSpacing: 0.5,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'RobotoCondensed',
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
