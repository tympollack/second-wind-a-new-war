import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../models/achievement.dart';
import '../../theme/app_theme.dart';
import '../../widgets/metal_panel.dart';

class AchievementsScreen extends ConsumerStatefulWidget {
  const AchievementsScreen({super.key});

  @override
  ConsumerState<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends ConsumerState<AchievementsScreen> {
  Set<String> _unlockedIds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAchievements();
  }

  Future<void> _loadAchievements() async {
    final userId = ref.read(authProvider).user?.id;
    if (userId == null) return;

    try {
      final data = await SupabaseService.getUserAchievements(userId);
      if (mounted) {
        setState(() {
          _unlockedIds = data
              .map((a) => a['achievement_id'] as String)
              .toSet();
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
          'MEDALS',
          style: TextStyle(
            fontFamily: 'RobotoCondensed',
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color: AppTheme.metalLight,
          ),
        ),
        iconTheme: const IconThemeData(color: AppTheme.metalGray),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${_unlockedIds.length}/${AchievementDefinitions.all.length}',
                style: const TextStyle(
                  fontFamily: 'RobotoCondensed',
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppTheme.primaryCyan,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryCyan))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.5,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: AchievementDefinitions.all.length,
                itemBuilder: (context, index) {
                  final achievement = AchievementDefinitions.all[index];
                  final isUnlocked = _unlockedIds.contains(achievement.id);
                  return _buildAchievementCard(achievement, isUnlocked);
                },
              ),
            ),
    );
  }

  Widget _buildAchievementCard(Achievement achievement, bool isUnlocked) {
    return MetalPanel(
      padding: const EdgeInsets.all(12),
      child: Opacity(
        opacity: isUnlocked ? 1.0 : 0.4,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  achievement.icon,
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    achievement.name.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'RobotoCondensed',
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: isUnlocked
                          ? AppTheme.goldTrump
                          : AppTheme.metalGray,
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isUnlocked)
                  const Icon(
                    Icons.check_circle,
                    size: 16,
                    color: AppTheme.winGreen,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Flexible(
              child: Text(
                achievement.description,
                style: const TextStyle(
                  fontFamily: 'RobotoCondensed',
                  fontSize: 11,
                  color: AppTheme.metalGray,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
