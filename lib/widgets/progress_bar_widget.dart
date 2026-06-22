import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GameProgressBar extends StatefulWidget {
  final int p1Cards;
  final int p2Cards;
  final int removedCards;
  final int? lastP1Cards;
  final int? lastP2Cards;

  const GameProgressBar({
    super.key,
    required this.p1Cards,
    required this.p2Cards,
    required this.removedCards,
    this.lastP1Cards,
    this.lastP2Cards,
  });

  @override
  State<GameProgressBar> createState() => _GameProgressBarState();
}

class _GameProgressBarState extends State<GameProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    _animController.forward();
  }

  @override
  void didUpdateWidget(GameProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.p1Cards != widget.p1Cards ||
        oldWidget.p2Cards != widget.p2Cards) {
      _animController.reset();
      _animController.forward();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const totalSegments = 54;
    final p1Gained = widget.lastP1Cards != null &&
        widget.p1Cards > widget.lastP1Cards!;
    final p1Lost = widget.lastP1Cards != null &&
        widget.p1Cards < widget.lastP1Cards!;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          height: 20,
          decoration: BoxDecoration(
            color: AppTheme.darkSurface,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: AppTheme.metalGray.withValues(alpha: 0.3),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: CustomPaint(
              size: const Size(double.infinity, 20),
              painter: _ProgressBarPainter(
                p1Cards: widget.p1Cards,
                p2Cards: widget.p2Cards,
                removedCards: widget.removedCards,
                totalSegments: totalSegments,
                animValue: _animation.value,
                p1Gained: p1Gained,
                p1Lost: p1Lost,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProgressBarPainter extends CustomPainter {
  final int p1Cards;
  final int p2Cards;
  final int removedCards;
  final int totalSegments;
  final double animValue;
  final bool p1Gained;
  final bool p1Lost;

  _ProgressBarPainter({
    required this.p1Cards,
    required this.p2Cards,
    required this.removedCards,
    required this.totalSegments,
    required this.animValue,
    required this.p1Gained,
    required this.p1Lost,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final segWidth = size.width / totalSegments;
    final segHeight = size.height;
    const gap = 1.0;

    for (int i = 0; i < totalSegments; i++) {
      final rect = Rect.fromLTWH(
        i * segWidth + gap / 2,
        0,
        segWidth - gap,
        segHeight,
      );

      Color color;
      if (i < p1Cards) {
        // P1 segment
        color = AppTheme.player1Color.withValues(alpha: 0.8);
        // Flash green on gain, red on loss
        if (p1Gained && i >= p1Cards - (p1Cards - (p1Cards - 1)).clamp(0, 5)) {
          final flash = (1.0 - animValue).clamp(0.0, 1.0);
          color = Color.lerp(AppTheme.winGreen, color, animValue) ?? color;
          if (flash > 0) {
            color = color.withValues(alpha: 0.8 + flash * 0.2);
          }
        }
        if (p1Lost && i >= p1Cards - 1) {
          color = Color.lerp(AppTheme.warRed, color, animValue) ?? color;
        }
      } else if (i < p1Cards + removedCards) {
        // Removed segment
        color = AppTheme.metalGray.withValues(alpha: 0.25);
      } else if (i < totalSegments - (totalSegments - p1Cards - removedCards - p2Cards)) {
        // Empty/second wind area
        color = AppTheme.darkCard.withValues(alpha: 0.5);
      } else {
        // P2 segment (from right)
        final p2Index = totalSegments - 1 - i;
        color = AppTheme.player2Color.withValues(alpha: 0.8);
        if (!p1Gained && !p1Lost) {
          // no flash
        } else if (!p1Gained && p1Lost && p2Index < 2) {
          color = Color.lerp(AppTheme.winGreen, color, animValue) ?? color;
        }
      }

      canvas.drawRect(rect, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressBarPainter oldDelegate) {
    return oldDelegate.p1Cards != p1Cards ||
        oldDelegate.p2Cards != p2Cards ||
        oldDelegate.removedCards != removedCards ||
        oldDelegate.animValue != animValue;
  }
}
