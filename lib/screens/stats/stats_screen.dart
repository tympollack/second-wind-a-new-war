import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/metal_panel.dart';

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final userId = ref.read(authProvider).user?.id;
    if (userId == null) return;

    final data = await SupabaseService.getUser(userId);
    if (mounted) {
      setState(() {
        _userData = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: AppTheme.darkSurface,
        title: const Text(
          'STRATEGY',
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
              child: Column(
                children: [
                  MetalPanel(
                    title: 'COMBAT RECORD',
                    child: Column(
                      children: [
                        _buildStatRow('VICTORIES',
                            '${_userData?['wins'] ?? 0}', AppTheme.winGreen),
                        const SizedBox(height: 8),
                        _buildStatRow('DEFEATS',
                            '${_userData?['losses'] ?? 0}', AppTheme.warRed),
                        const SizedBox(height: 8),
                        _buildStatRow(
                            'BATTLES',
                            '${_userData?['games_played'] ?? 0}',
                            AppTheme.primaryCyan),
                        const SizedBox(height: 8),
                        _buildStatRow(
                            'WARS TRIGGERED',
                            '${_userData?['wars_triggered'] ?? 0}',
                            AppTheme.goldTrump),
                        const SizedBox(height: 8),
                        _buildStatRow(
                            'SECOND WINDS',
                            '${_userData?['second_winds_used'] ?? 0}',
                            AppTheme.primaryCyan),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  MetalPanel(
                    title: 'WIN RATE',
                    child: _buildWinRate(),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'RobotoCondensed',
            fontSize: 13,
            color: AppTheme.metalGray,
            letterSpacing: 1,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'RobotoCondensed',
            fontWeight: FontWeight.w900,
            fontSize: 20,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildWinRate() {
    final wins = _userData?['wins'] as int? ?? 0;
    final losses = _userData?['losses'] as int? ?? 0;
    final total = wins + losses;
    final rate = total > 0 ? (wins / total * 100).toStringAsFixed(1) : '0.0';

    return Column(
      children: [
        Text(
          '$rate%',
          style: const TextStyle(
            fontFamily: 'RobotoCondensed',
            fontWeight: FontWeight.w900,
            fontSize: 48,
            color: AppTheme.primaryCyan,
          ),
        ),
        const SizedBox(height: 8),
        if (total > 0)
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: wins / total,
              backgroundColor: AppTheme.warRed.withValues(alpha: 0.3),
              valueColor:
                  const AlwaysStoppedAnimation(AppTheme.winGreen),
              minHeight: 8,
            ),
          ),
      ],
    );
  }
}
