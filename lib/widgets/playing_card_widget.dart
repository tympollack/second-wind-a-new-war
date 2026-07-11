import 'package:flutter/material.dart';
import '../models/playing_card.dart';
import '../models/game_state.dart';
import '../engine/game_engine.dart';
import '../theme/app_theme.dart';

class PlayingCardWidget extends StatelessWidget {
  final PlayingCard card;
  final GameState gameState;
  final bool isWinner;
  final bool isBurning;
  final double width;
  final double height;
  final bool showBadge;

  const PlayingCardWidget({
    super.key,
    required this.card,
    required this.gameState,
    this.isWinner = false,
    this.isBurning = false,
    this.width = 80,
    this.height = 120,
    this.showBadge = true,
  });

  @override
  Widget build(BuildContext context) {
    final status = getCardStatus(card, gameState);

    Color borderColor;
    Color bgStart;
    Color bgEnd;
    Color textColor;

    switch (status) {
      case CardStatus.joker:
        borderColor = AppTheme.cyanJoker;
        bgStart = Color.alphaBlend(AppTheme.cyanJoker.withValues(alpha: 0.3), AppTheme.darkCard);
        bgEnd = AppTheme.darkCard;
        textColor = AppTheme.cyanJoker;
      case CardStatus.musketeer:
        borderColor = AppTheme.purpleMusketeer;
        bgStart = Color.alphaBlend(AppTheme.purpleMusketeer.withValues(alpha: 0.4), AppTheme.darkCard);
        bgEnd = AppTheme.darkCard;
        textColor = Colors.white;
      case CardStatus.trump:
        borderColor = AppTheme.goldTrump;
        bgStart = Color.alphaBlend(AppTheme.goldTrump.withValues(alpha: 0.4), AppTheme.darkCard);
        bgEnd = AppTheme.darkCard;
        textColor = AppTheme.goldTrump;
      case CardStatus.normal:
        borderColor = AppTheme.metalGray;
        bgStart = AppTheme.darkCard;
        bgEnd = AppTheme.darkBg;
        textColor = card.isRed ? Colors.red.shade400 : AppTheme.gunmetalGray;
    }

    // Musketeer cards override suit symbol; trump cards keep their real suit (shown in gold via textColor)
    String displaySuit = card.suitSymbol;
    if (status == CardStatus.musketeer) {
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
            if (isBurning)
              BoxShadow(
                color: const Color(0xFFCC5500).withValues(alpha: 0.7),
                blurRadius: 24,
                spreadRadius: 6,
              ),
            if (isBurning)
              BoxShadow(
                color: const Color(0xFFFF8C00).withValues(alpha: 0.4),
                blurRadius: 8,
                spreadRadius: 2,
              ),
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
          clipBehavior: Clip.none,
          children: [
            // Fire overlay when burning
            if (isBurning)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CustomPaint(
                    painter: _FireOverlayPainter(),
                  ),
                ),
              ),
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
                      fontSize: width * (card.rankLabel.length > 1 ? 0.28 : 0.35),
                      color: textColor,
                      height: 1,
                    ),
                  ),
                  SizedBox(height: height * 0.08),
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

            // Top-left rank
            Positioned(
              top: 4,
              left: 6,
              child: SizedBox(
                width: 18,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    card.rankLabel,
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      fontFamily: 'RobotoCondensed',
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                      color: textColor.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),
            ),
            // Bottom-right rank (inverted)
            Positioned(
              bottom: 4,
              right: 6,
              child: Transform.rotate(
                angle: 3.14159,
                child: SizedBox(
                  width: 18,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      card.rankLabel,
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        fontFamily: 'RobotoCondensed',
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                        color: textColor.withValues(alpha: 0.7),
                      ),
                    ),
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
  final double spread;

  const FaceDownCardWidget({
    super.key,
    required this.count,
    this.width = 60,
    this.height = 90,
    this.spread = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    final displayCount = count.clamp(1, 3);
    return SizedBox(
      width: width + (displayCount - 1) * spread,
      height: height,
      child: Stack(
        children: List.generate(displayCount, (i) {
          return Positioned(
            left: i * spread,
            child: Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF312E81), // indigo-900 equivalent
                    Color(0xFF111827), // gray-900 equivalent
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.metalGray.withValues(alpha: 0.6),
                  width: 2,
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
                    color: Colors.indigo.shade300,
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

class _FireOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Fiery gradient from bottom - warm orange/red flames rising
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final gradient = LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [
        const Color(0xFFCC5500).withValues(alpha: 0.45),
        const Color(0xFFFF8C00).withValues(alpha: 0.25),
        const Color(0xFFFFD700).withValues(alpha: 0.10),
        Colors.transparent,
      ],
      stops: const [0.0, 0.35, 0.65, 1.0],
    );
    final paint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRect(rect, paint);

    // Flame tongue paths on top edge
    final flamePaint = Paint()
      ..color = const Color(0xFFFF8C00).withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    final flame1 = Path()
      ..moveTo(size.width * 0.1, size.height * 0.15)
      ..quadraticBezierTo(size.width * 0.2, 0, size.width * 0.3, size.height * 0.12)
      ..quadraticBezierTo(size.width * 0.25, size.height * 0.22, size.width * 0.1, size.height * 0.15);
    canvas.drawPath(flame1, flamePaint);

    final flame2 = Path()
      ..moveTo(size.width * 0.55, size.height * 0.1)
      ..quadraticBezierTo(size.width * 0.7, 0, size.width * 0.82, size.height * 0.14)
      ..quadraticBezierTo(size.width * 0.72, size.height * 0.25, size.width * 0.55, size.height * 0.1);
    canvas.drawPath(flame2, flamePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
