import 'package:flutter/material.dart';
import '../models/playing_card.dart';
import '../models/game_state.dart';
import '../engine/game_engine.dart';
import '../theme/app_theme.dart';

class PlayingCardWidget extends StatelessWidget {
  final PlayingCard card;
  final GameState gameState;
  final bool isWinner;
  final double width;
  final double height;

  const PlayingCardWidget({
    super.key,
    required this.card,
    required this.gameState,
    this.isWinner = false,
    this.width = 80,
    this.height = 120,
  });

  @override
  Widget build(BuildContext context) {
    final status = getCardStatus(card, gameState);

    Color borderColor;
    Color bgStart;
    Color bgEnd;
    String? statusLabel;
    Color? statusBgColor;
    Color? statusTextColor;
    Color textColor;

    switch (status) {
      case CardStatus.joker:
        borderColor = AppTheme.cyanJoker;
        bgStart = AppTheme.cyanJoker.withValues(alpha: 0.2);
        bgEnd = AppTheme.darkCard;
        statusLabel = 'JOKER';
        statusBgColor = AppTheme.cyanJoker;
        statusTextColor = Colors.black;
        textColor = AppTheme.cyanJoker;
      case CardStatus.musketeer:
        borderColor = AppTheme.purpleMusketeer;
        bgStart = AppTheme.purpleMusketeer.withValues(alpha: 0.2);
        bgEnd = AppTheme.darkCard;
        statusLabel = 'MUSK';
        statusBgColor = AppTheme.purpleMusketeer;
        statusTextColor = Colors.white;
        textColor = AppTheme.purpleMusketeer;
      case CardStatus.trump:
        borderColor = AppTheme.goldTrump;
        bgStart = AppTheme.goldTrump.withValues(alpha: 0.15);
        bgEnd = AppTheme.darkCard;
        statusLabel = 'TRUMP';
        statusBgColor = AppTheme.goldTrump;
        statusTextColor = Colors.black;
        textColor = AppTheme.goldTrump;
      case CardStatus.normal:
        borderColor = AppTheme.metalGray;
        bgStart = AppTheme.darkCard;
        bgEnd = AppTheme.darkCard;
        statusLabel = null;
        textColor = card.isRed ? Colors.red.shade400 : Colors.white;
    }

    // Trump cards override suit symbol
    String displaySuit = card.suitSymbol;
    if (status == CardStatus.trump) {
      displaySuit = '\u2726'; // diamond star for trump
    } else if (status == CardStatus.musketeer) {
      displaySuit = '\u2694'; // crossed swords for musketeer
    }

    return AnimatedScale(
      scale: isWinner ? 1.15 : 1.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [bgStart, bgEnd],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 2),
          boxShadow: [
            if (isWinner)
              BoxShadow(
                color: AppTheme.winGreen.withValues(alpha: 0.4),
                blurRadius: 16,
                spreadRadius: 4,
              ),
            if (status == CardStatus.joker)
              BoxShadow(
                color: AppTheme.cyanJoker.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Joker electricity effect
            if (status == CardStatus.joker)
              Positioned.fill(
                child: CustomPaint(
                  painter: _ElectricityPainter(borderColor),
                ),
              ),
            // Card content
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    card.rankLabel,
                    style: TextStyle(
                      fontFamily: 'RobotoCondensed',
                      fontWeight: FontWeight.w900,
                      fontSize: width * 0.35,
                      color: textColor,
                      height: 1,
                    ),
                  ),
                  Text(
                    displaySuit,
                    style: TextStyle(
                      fontSize: width * 0.25,
                      color: textColor,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            // Status badge
            if (statusLabel != null)
              Positioned(
                top: -1,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusBgColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontFamily: 'RobotoCondensed',
                        fontWeight: FontWeight.w900,
                        fontSize: 8,
                        letterSpacing: 1,
                        color: statusTextColor,
                      ),
                    ),
                  ),
                ),
              ),
            // Winner badge
            if (isWinner)
              Positioned(
                bottom: 2,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.winGreen,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'WIN',
                      style: TextStyle(
                        fontFamily: 'RobotoCondensed',
                        fontWeight: FontWeight.w900,
                        fontSize: 8,
                        color: Colors.black,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ),
            // Top-left rank
            Positioned(
              top: 4,
              left: 6,
              child: Text(
                card.rankLabel,
                style: TextStyle(
                  fontFamily: 'RobotoCondensed',
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  color: textColor.withValues(alpha: 0.7),
                ),
              ),
            ),
            // Bottom-right rank (inverted)
            Positioned(
              bottom: 4,
              right: 6,
              child: Transform.rotate(
                angle: 3.14159,
                child: Text(
                  card.rankLabel,
                  style: TextStyle(
                    fontFamily: 'RobotoCondensed',
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    color: textColor.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FaceDownCardWidget extends StatelessWidget {
  final int count;
  final double width;
  final double height;

  const FaceDownCardWidget({
    super.key,
    required this.count,
    this.width = 60,
    this.height = 90,
  });

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    final displayCount = count.clamp(1, 3);
    return SizedBox(
      width: width + (displayCount - 1) * 8,
      height: height,
      child: Stack(
        children: List.generate(displayCount, (i) {
          return Positioned(
            left: i * 8.0,
            child: Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1A2744),
                    Color(0xFF0E1829),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.metalGray.withValues(alpha: 0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(2, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '?',
                  style: TextStyle(
                    fontSize: width * 0.4,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primaryCyan.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _ElectricityPainter extends CustomPainter {
  final Color color;

  _ElectricityPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Simple lightning bolt lines
    final path = Path()
      ..moveTo(size.width * 0.3, 0)
      ..lineTo(size.width * 0.5, size.height * 0.3)
      ..lineTo(size.width * 0.35, size.height * 0.3)
      ..lineTo(size.width * 0.6, size.height * 0.6)
      ..lineTo(size.width * 0.45, size.height * 0.6)
      ..lineTo(size.width * 0.7, size.height);

    canvas.drawPath(path, paint);

    final path2 = Path()
      ..moveTo(size.width * 0.7, 0)
      ..lineTo(size.width * 0.5, size.height * 0.4)
      ..lineTo(size.width * 0.65, size.height * 0.4)
      ..lineTo(size.width * 0.3, size.height);

    canvas.drawPath(path2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
