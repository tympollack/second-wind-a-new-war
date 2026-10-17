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

class _AchievementsScreenState extends ConsumerState<AchievementsScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  Set<String> _unlockedIds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _loadAchievements();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
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
                style: TextStyle(
                  fontFamily: 'RobotoCondensed',
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))
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
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final glowOpacity = isUnlocked ? _pulseAnimation.value : 0.0;
        
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              if (isUnlocked)
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: glowOpacity * 0.4),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
            ],
          ),
          child: MetalPanel(
            padding: const EdgeInsets.all(2), // Reduced padding so gradient fills
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    isUnlocked ? const Color(0xFF1E1B4B).withValues(alpha: 0.8) : Colors.transparent, // indigo-900 equivalent
                    isUnlocked ? const Color(0xFF0F172A).withValues(alpha: 0.6) : Colors.transparent, // slate-900
                  ],
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Opacity(
                opacity: isUnlocked ? 1.0 : 0.4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              if (isUnlocked)
                                BoxShadow(
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                ),
                            ],
                          ),
                          child: Text(
                            achievement.icon,
                            style: const TextStyle(fontSize: 24),
                          ),
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
                                  ? Theme.of(context).colorScheme.primary
                                  : AppTheme.metalGray,
                              letterSpacing: 0.5,
                              shadows: [
                                if (isUnlocked)
                                  Shadow(
                                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                                    blurRadius: 4,
                                  ),
                              ],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isUnlocked)
                          Icon(
                            Icons.check_circle,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Flexible(
                      child: Text(
                        achievement.description,
                        style: TextStyle(
                          fontFamily: 'RobotoCondensed',
                          fontSize: 11,
                          color: isUnlocked ? Colors.white70 : AppTheme.metalGray,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
