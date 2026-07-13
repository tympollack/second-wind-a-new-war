import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GameProgressBar extends StatefulWidget {
  final int p1Cards;
  final int p2Cards;
  final int p1Discard;
  final int p2Discard;
  final int removedCards;
  final int? lastP1Cards;
  final int? lastP2Cards;
  final int? lastP1Total;
  final int? lastP2Total;

  const GameProgressBar({
    super.key,
    required this.p1Cards,
    required this.p2Cards,
    required this.p1Discard,
    required this.p2Discard,
    required this.removedCards,
    this.lastP1Cards,
    this.lastP2Cards,
    this.lastP1Total,
    this.lastP2Total,
  });

  @override
  State<GameProgressBar> createState() => _GameProgressBarState();
}

class _GameProgressBarState extends State<GameProgressBar>
    with TickerProviderStateMixin {
  late AnimationController _flashController;
  late Animation<double> _flashAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _flashAnimation = CurvedAnimation(
      parent: _flashController,
      curve: Curves.easeInOut,
    );
    _flashController.forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );
    _pulseController.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(GameProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldP1Total = oldWidget.p1Cards + oldWidget.p1Discard;
    final newP1Total = widget.p1Cards + widget.p1Discard;
    final oldP2Total = oldWidget.p2Cards + oldWidget.p2Discard;
    final newP2Total = widget.p2Cards + widget.p2Discard;
    if (oldP1Total != newP1Total || oldP2Total != newP2Total) {
      _flashController.reset();
      _flashController.forward();
    }
  }

  @override
  void dispose() {
    _flashController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const totalSegments = 54;
    final p1Total = widget.p1Cards + widget.p1Discard;
    final p2Total = widget.p2Cards + widget.p2Discard;

    // Total-card deltas give the actual number of segments won/lost.
    final p1GainedAmount = widget.lastP1Total != null
        ? (p1Total - widget.lastP1Total!).clamp(0, totalSegments)
        : 0;
    final p2GainedAmount = widget.lastP2Total != null
        ? (p2Total - widget.lastP2Total!).clamp(0, totalSegments)
        : 0;

    // Fallback to the old deck-only logic when totals are not supplied.
    final p1Gained =
        widget.lastP1Cards != null && widget.p1Cards > widget.lastP1Cards!;
    final p1Lost =
        widget.lastP1Cards != null && widget.p1Cards < widget.lastP1Cards!;

    return AnimatedBuilder(
      animation: Listenable.merge([_flashAnimation, _pulseAnimation]),
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
                p1Discard: widget.p1Discard,
                p2Discard: widget.p2Discard,
                removedCards: widget.removedCards,
                totalSegments: totalSegments,
                flashValue: _flashAnimation.value,
                pulseValue: _pulseAnimation.value,
                p1GainedAmount: p1GainedAmount,
                p2GainedAmount: p2GainedAmount,
                p1Gained: p1Gained,
                p1Lost: p1Lost,
                p1LowCards: p1Total < 5,
                p2LowCards: p2Total < 5,
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
  final int p1Discard;
  final int p2Discard;
  final int removedCards;
  final int totalSegments;
  final double flashValue;
  final double pulseValue;
  final int p1GainedAmount;
  final int p2GainedAmount;
  final bool p1Gained;
  final bool p1Lost;
  final bool p1LowCards;
  final bool p2LowCards;

  _ProgressBarPainter({
    required this.p1Cards,
    required this.p2Cards,
    required this.p1Discard,
    required this.p2Discard,
    required this.removedCards,
    required this.totalSegments,
    required this.flashValue,
    required this.pulseValue,
    required this.p1GainedAmount,
    required this.p2GainedAmount,
    required this.p1Gained,
    required this.p1Lost,
    required this.p1LowCards,
    required this.p2LowCards,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final segWidth = size.width / totalSegments;
    final segHeight = size.height;
    const gap = 1.0;

    final leftBurned = (removedCards / 2).ceil();
    final rightBurned = removedCards - leftBurned;

    for (int i = 0; i < totalSegments; i++) {
      final rect = Rect.fromLTWH(
        i * segWidth + gap / 2,
        0,
        segWidth - gap,
        segHeight,
      );

      Color color;

      if (i < leftBurned) {
        // Left burned segments
        color = AppTheme.metalGray.withValues(alpha: 0.25);
      } else if (i < leftBurned + p1Cards) {
        // P1 active deck
        final p1Index = i - leftBurned;
        final isLow = p1LowCards;

        color = AppTheme.player1Color.withValues(alpha: 0.8);

        if (isLow) {
          final pulseAlpha = 0.5 + pulseValue * 0.3;
          color = color.withValues(alpha: pulseAlpha);
        }
        if (p1Lost && p1Index >= p1Cards - 1) {
          color = Color.lerp(AppTheme.warRed, color, flashValue) ?? color;
        }
      } else if (i < leftBurned + p1Cards + p1Discard) {
        // P1 discard pile (darker shade)
        final discardIndex = i - (leftBurned + p1Cards);
        final gainedFromPot =
            p1GainedAmount > 0 && discardIndex >= p1Discard - p1GainedAmount;
        color = AppTheme.player1Color.withValues(alpha: 0.3);
        if (gainedFromPot) {
          final flash = (1.0 - flashValue).clamp(0.0, 1.0);
          color = Color.lerp(AppTheme.winGreen, color, flashValue) ?? color;
          if (flash > 0) {
            color = color.withValues(alpha: 0.3 + flash * 0.5);
          }
        }
      } else if (i < totalSegments - rightBurned - p2Cards - p2Discard) {
        // Empty/pot area in the middle
        color = AppTheme.darkCard.withValues(alpha: 0.5);
      } else if (i < totalSegments - rightBurned - p2Cards) {
        // P2 discard pile (darker shade)
        final discardIndex =
            i - (totalSegments - rightBurned - p2Cards - p2Discard);
        final gainedFromPot =
            p2GainedAmount > 0 && discardIndex < p2GainedAmount;
        color = AppTheme.player2Color.withValues(alpha: 0.3);
        if (gainedFromPot) {
          final flash = (1.0 - flashValue).clamp(0.0, 1.0);
          color = Color.lerp(AppTheme.winGreen, color, flashValue) ?? color;
          if (flash > 0) {
            color = color.withValues(alpha: 0.3 + flash * 0.5);
          }
        }
      } else if (i < totalSegments - rightBurned) {
        // P2 active deck
        final isLow = p2LowCards;

        color = AppTheme.player2Color.withValues(alpha: 0.8);

        if (isLow) {
          final pulseAlpha = 0.5 + pulseValue * 0.3;
          color = color.withValues(alpha: pulseAlpha);
        }
      } else {
        // Right burned segments
        color = AppTheme.metalGray.withValues(alpha: 0.25);
      }

      canvas.drawRect(rect, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressBarPainter oldDelegate) {
    return oldDelegate.p1Cards != p1Cards ||
        oldDelegate.p2Cards != p2Cards ||
        oldDelegate.p1Discard != p1Discard ||
        oldDelegate.p2Discard != p2Discard ||
        oldDelegate.removedCards != removedCards ||
        oldDelegate.flashValue != flashValue ||
        oldDelegate.pulseValue != pulseValue;
  }
}
