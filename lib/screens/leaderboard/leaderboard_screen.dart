import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/metal_panel.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<Map<String, dynamic>> _leaders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    try {
      final data = await SupabaseService.getLeaderboard();
      if (mounted) {
        setState(() {
          _leaders = data;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: AppTheme.darkSurface,
        title: const Text(
          'DIPLOMACY',
          style: TextStyle(
            fontFamily: 'RobotoCondensed',
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color: AppTheme.metalLight,
          ),
        ),
        iconTheme: const IconThemeData(color: AppTheme.metalGray),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryCyan))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: MetalPanel(
                title: 'LEADERBOARD',
                child: _leaders.isEmpty
                    ? const Center(
                        child: Text(
                          'No commanders ranked yet',
                          style: TextStyle(color: AppTheme.metalGray),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _leaders.length,
                        separatorBuilder: (context, index) => Divider(
                          color: AppTheme.metalGray.withValues(alpha: 0.2),
                          height: 1,
                        ),
                        itemBuilder: (context, index) {
                          final leader = _leaders[index];
                          final rank = index + 1;
                          Color rankColor;
                          if (rank == 1) {
                            rankColor = AppTheme.goldTrump;
                          } else if (rank == 2) {
                            rankColor = AppTheme.metalLight;
                          } else if (rank == 3) {
                            rankColor = Colors.brown.shade300;
                          } else {
                            rankColor = AppTheme.metalGray;
                          }

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 30,
                                  child: Text(
                                    '#$rank',
                                    style: TextStyle(
                                      fontFamily: 'RobotoCondensed',
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                      color: rankColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    (leader['display_name'] as String? ??
                                            'Unknown')
                                        .toUpperCase(),
                                    style: const TextStyle(
                                      fontFamily: 'RobotoCondensed',
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: AppTheme.metalLight,
                                      letterSpacing: 0.5,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '${leader['wins'] ?? 0}W',
                                  style: const TextStyle(
                                    fontFamily: 'RobotoCondensed',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: AppTheme.winGreen,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${leader['losses'] ?? 0}L',
                                  style: const TextStyle(
                                    fontFamily: 'RobotoCondensed',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: AppTheme.warRed,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),
    );
  }
}
