import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/playing_card.dart';
import '../theme/app_theme.dart';

enum CardBackTheme {
  canyonCyan,
  subterraneanCrimson,
}

enum StatusBadgeType {
  trump,
  musketeer,
  secondWind,
}

/// Vector Painter for Standard 52-Card Suit Glyphs
class SuitVectorPainter extends CustomPainter {
  final Suit suit;
  final Color color;

  const SuitVectorPainter({required this.suit, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final w = size.width;
    final h = size.height;

    switch (suit) {
      case Suit.hearts:
        final path = Path()
          ..moveTo(w * 0.5, h * 0.82)
          ..cubicTo(w * 0.1, h * 0.55, 0, h * 0.3, w * 0.25, h * 0.1)
          ..cubicTo(w * 0.42, 0, w * 0.5, h * 0.22, w * 0.5, h * 0.22)
          ..cubicTo(w * 0.5, h * 0.22, w * 0.58, 0, w * 0.75, h * 0.1)
          ..cubicTo(w, h * 0.3, w * 0.9, h * 0.55, w * 0.5, h * 0.82)
          ..close();
        canvas.drawPath(path, paint);
        break;

      case Suit.diamonds:
        final path = Path()
          ..moveTo(w * 0.5, h * 0.05)
          ..lineTo(w * 0.92, h * 0.5)
          ..lineTo(w * 0.5, h * 0.95)
          ..lineTo(w * 0.08, h * 0.5)
          ..close();
        canvas.drawPath(path, paint);
        break;

      case Suit.spades:
        final path = Path()
          ..moveTo(w * 0.5, h * 0.08)
          ..cubicTo(w * 0.7, h * 0.32, w * 0.95, h * 0.52, w * 0.8, h * 0.72)
          ..cubicTo(w * 0.65, h * 0.86, w * 0.54, h * 0.68, w * 0.5, h * 0.62)
          ..cubicTo(w * 0.46, h * 0.68, w * 0.35, h * 0.86, w * 0.2, h * 0.72)
          ..cubicTo(w * 0.05, h * 0.52, w * 0.3, h * 0.32, w * 0.5, h * 0.08)
          ..close();
        // Spade Stem
        final stem = Path()
          ..moveTo(w * 0.45, h * 0.62)
          ..lineTo(w * 0.35, h * 0.92)
          ..lineTo(w * 0.65, h * 0.92)
          ..lineTo(w * 0.55, h * 0.62)
          ..close();
        canvas.drawPath(path, paint);
        canvas.drawPath(stem, paint);
        break;

      case Suit.clubs:
        final r = w * 0.22;
        // Top circle
        canvas.drawCircle(Offset(w * 0.5, h * 0.32), r, paint);
        // Left circle
        canvas.drawCircle(Offset(w * 0.32, h * 0.56), r, paint);
        // Right circle
        canvas.drawCircle(Offset(w * 0.68, h * 0.56), r, paint);
        // Center fill
        canvas.drawCircle(Offset(w * 0.5, h * 0.52), r * 0.8, paint);
        // Club stem
        final stem = Path()
          ..moveTo(w * 0.46, h * 0.55)
          ..lineTo(w * 0.36, h * 0.92)
          ..lineTo(w * 0.64, h * 0.92)
          ..lineTo(w * 0.54, h * 0.55)
          ..close();
        canvas.drawPath(stem, paint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant SuitVectorPainter oldDelegate) =>
      oldDelegate.suit != suit || oldDelegate.color != color;
}

/// Custom Card Back Painter for Canyon Cyan and Subterranean Crimson
class CardBackPainter extends CustomPainter {
  final CardBackTheme theme;

  const CardBackPainter({required this.theme});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(10));

    // Outer border & background gradient
    final gradient = theme == CardBackTheme.canyonCyan
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0891B2), Color(0xFF0E7490), Color(0xFF155E75), Color(0xFF083344)],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFDC2626), Color(0xFFB91C1C), Color(0xFF7F1D1D), Color(0xFF450A0A)],
          );

    final bgPaint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRRect(rrect, bgPaint);

    // Inner bevel border
    final borderCol = theme == CardBackTheme.canyonCyan
        ? const Color(0xFF67E8F9)
        : const Color(0xFFFCA5A5);

    final innerBorderPaint = Paint()
      ..color = borderCol.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final innerRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(4, 4, size.width - 8, size.height - 8),
      const Radius.circular(7),
    );
    canvas.drawRRect(innerRRect, innerBorderPaint);

    // Geometric pattern grid / lattice (Kenney Boardgame style)
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final step = 14.0;
    for (double i = -size.height; i < size.width + size.height; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i + size.height, size.height), gridPaint);
      canvas.drawLine(Offset(i, size.height), Offset(i + size.height, 0), gridPaint);
    }

    // Central Emblem
    final center = Offset(size.width / 2, size.height / 2);
    final emblemRadius = math.min(size.width, size.height) * 0.22;

    final emblemBgPaint = Paint()
      ..color = (theme == CardBackTheme.canyonCyan
              ? const Color(0xFF083344)
              : const Color(0xFF450A0A))
          .withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, emblemRadius, emblemBgPaint);

    final emblemStrokePaint = Paint()
      ..color = borderCol
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, emblemRadius, emblemStrokePaint);

    // Central decorative diamond crest
    final crestPath = Path()
      ..moveTo(center.dx, center.dy - emblemRadius * 0.7)
      ..lineTo(center.dx + emblemRadius * 0.7, center.dy)
      ..lineTo(center.dx, center.dy + emblemRadius * 0.7)
      ..lineTo(center.dx - emblemRadius * 0.7, center.dy)
      ..close();

    final crestPaint = Paint()
      ..color = borderCol.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;
    canvas.drawPath(crestPath, crestPaint);
  }

  @override
  bool shouldRepaint(covariant CardBackPainter oldDelegate) => oldDelegate.theme != theme;
}

/// Themed Card Back Widget (Canyon Cyan & Subterranean Crimson)
class CardBackWidget extends StatelessWidget {
  final CardBackTheme theme;
  final double width;
  final double height;

  const CardBackWidget({
    super.key,
    this.theme = CardBackTheme.canyonCyan,
    this.width = 80,
    this.height = 120,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CustomPaint(
          size: Size(width, height),
          painter: CardBackPainter(theme: theme),
        ),
      ),
    );
  }
}

/// Full 52-Card Face Vector Widget with High-Resolution Scaling
class CardFaceWidget extends StatelessWidget {
  final PlayingCard card;
  final CardStatus status;
  final bool isWinner;
  final bool isBurning;
  final double width;
  final double height;

  const CardFaceWidget({
    super.key,
    required this.card,
    this.status = CardStatus.normal,
    this.isWinner = false,
    this.isBurning = false,
    this.width = 80,
    this.height = 120,
  });

  @override
  Widget build(BuildContext context) {
    final isRed = card.isRed;
    Color primaryColor;
    Color borderColor;

    switch (status) {
      case CardStatus.trump:
        primaryColor = AppTheme.goldTrump;
        borderColor = AppTheme.goldTrump;
        break;
      case CardStatus.musketeer:
        primaryColor = AppTheme.purpleMusketeer;
        borderColor = AppTheme.purpleMusketeer;
        break;
      case CardStatus.joker:
        primaryColor = AppTheme.cyanJoker;
        borderColor = AppTheme.cyanJoker;
        break;
      case CardStatus.normal:
        primaryColor = isRed ? const Color(0xFFDC2626) : const Color(0xFF1E293B);
        borderColor = isWinner ? AppTheme.winGreen : const Color(0xFF94A3B8);
        break;
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC), // ivory / crisp white card face
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: isWinner ? 3.0 : 1.8),
        boxShadow: [
          if (isWinner)
            BoxShadow(
              color: AppTheme.winGreen.withValues(alpha: 0.6),
              blurRadius: 16,
              spreadRadius: 3,
            ),
          if (status == CardStatus.trump)
            BoxShadow(
              color: AppTheme.goldTrump.withValues(alpha: 0.4),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Top-Left Corner Index
          Positioned(
            top: 4,
            left: 5,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  card.rankLabel,
                  style: TextStyle(
                    fontFamily: 'RobotoCondensed',
                    fontWeight: FontWeight.w900,
                    fontSize: width * 0.2,
                    color: primaryColor,
                    height: 1.0,
                  ),
                ),
                if (card.suit != null)
                  SizedBox(
                    width: width * 0.14,
                    height: width * 0.14,
                    child: CustomPaint(
                      painter: SuitVectorPainter(suit: card.suit!, color: primaryColor),
                    ),
                  ),
              ],
            ),
          ),

          // Bottom-Right Corner Index (Inverted)
          Positioned(
            bottom: 4,
            right: 5,
            child: Transform.rotate(
              angle: math.pi,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    card.rankLabel,
                    style: TextStyle(
                      fontFamily: 'RobotoCondensed',
                      fontWeight: FontWeight.w900,
                      fontSize: width * 0.2,
                      color: primaryColor,
                      height: 1.0,
                    ),
                  ),
                  if (card.suit != null)
                    SizedBox(
                      width: width * 0.14,
                      height: width * 0.14,
                      child: CustomPaint(
                        painter: SuitVectorPainter(suit: card.suit!, color: primaryColor),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Center Card Art / Pips Layout
          Center(
            child: _buildCenterArt(card, primaryColor, width, height),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterArt(PlayingCard card, Color color, double w, double h) {
    if (card.isJoker) {
      return Icon(Icons.star_rounded, size: w * 0.55, color: color);
    }

    if (card.suit == null) {
      return const SizedBox.shrink();
    }

    // Court cards (Jack, Queen, King)
    if (card.rank >= 11 && card.rank <= 13) {
      return Container(
        width: w * 0.52,
        height: h * 0.58,
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
          borderRadius: BorderRadius.circular(6),
          color: color.withValues(alpha: 0.05),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              card.rankLabel,
              style: TextStyle(
                fontFamily: 'RobotoCondensed',
                fontWeight: FontWeight.w900,
                fontSize: w * 0.28,
                color: color,
              ),
            ),
            SizedBox(
              width: w * 0.22,
              height: w * 0.22,
              child: CustomPaint(
                painter: SuitVectorPainter(suit: card.suit!, color: color),
              ),
            ),
          ],
        ),
      );
    }

    // Ace - oversized center suit
    if (card.rank == 14) {
      return SizedBox(
        width: w * 0.44,
        height: h * 0.44,
        child: CustomPaint(
          painter: SuitVectorPainter(suit: card.suit!, color: color),
        ),
      );
    }

    // Pip cards 2 through 10
    final pipSize = (w * 0.16).clamp(10.0, 20.0);
    Widget suitPip() => SizedBox(
          width: pipSize,
          height: pipSize,
          child: CustomPaint(
            painter: SuitVectorPainter(suit: card.suit!, color: color),
          ),
        );

    switch (card.rank) {
      case 2:
        return SizedBox(
          height: h * 0.5,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [suitPip(), suitPip()],
          ),
        );
      case 3:
        return SizedBox(
          height: h * 0.55,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [suitPip(), suitPip(), suitPip()],
          ),
        );
      case 4:
        return SizedBox(
          width: w * 0.44,
          height: h * 0.5,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [suitPip(), suitPip()]),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [suitPip(), suitPip()]),
            ],
          ),
        );
      case 5:
        return SizedBox(
          width: w * 0.44,
          height: h * 0.52,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [suitPip(), suitPip()]),
              suitPip(),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [suitPip(), suitPip()]),
            ],
          ),
        );
      case 6:
      case 7:
      case 8:
        return SizedBox(
          width: w * 0.44,
          height: h * 0.55,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [suitPip(), suitPip()]),
              if (card.rank >= 7) suitPip(),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [suitPip(), suitPip()]),
              if (card.rank == 8) suitPip(),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [suitPip(), suitPip()]),
            ],
          ),
        );
      case 9:
      case 10:
      default:
        return SizedBox(
          width: w * 0.48,
          height: h * 0.58,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [suitPip(), suitPip()]),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [suitPip(), if (card.rank == 10) suitPip()]),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [suitPip(), suitPip()]),
            ],
          ),
        );
    }
  }
}

/// Status Badges for Trump, Musketeer, and Second Wind
class StatusBadgeWidget extends StatelessWidget {
  final StatusBadgeType type;
  final String? customLabel;

  const StatusBadgeWidget({
    super.key,
    required this.type,
    this.customLabel,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color border;
    IconData icon;
    String label;

    switch (type) {
      case StatusBadgeType.trump:
        bg = const Color(0xFFF59E0B);
        border = const Color(0xFFFDE68A);
        icon = Icons.workspace_premium;
        label = customLabel ?? 'TRUMP';
        break;
      case StatusBadgeType.musketeer:
        bg = const Color(0xFF8B5CF6);
        border = const Color(0xFFDDD6FE);
        icon = Icons.shield_outlined;
        label = customLabel ?? 'MUSKETEER';
        break;
      case StatusBadgeType.secondWind:
        bg = const Color(0xFFEF4444);
        border = const Color(0xFFFECACA);
        icon = Icons.air_rounded;
        label = customLabel ?? 'SECOND WIND';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.9),
        border: Border.all(color: border, width: 1.5),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: bg.withValues(alpha: 0.5),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 13),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 10,
              letterSpacing: 0.6,
              fontFamily: 'RobotoCondensed',
            ),
          ),
        ],
      ),
    );
  }
}

/// Cartoon Hand Grip Painter (gripping the card edge from the front)
class HandGripPainter extends CustomPainter {
  final bool isOpponent;
  final Color skinColor;

  const HandGripPainter({
    this.isOpponent = false,
    this.skinColor = const Color(0xFFFFDBAC),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final skinPaint = Paint()
      ..color = skinColor
      ..style = PaintingStyle.fill;

    final outlinePaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // 4 Cartoon rounded fingers grasping the edge
    final fingerWidth = w / 4.8;
    final fingerHeight = h * 0.75;

    for (int i = 0; i < 4; i++) {
      final x = i * (fingerWidth * 1.1) + fingerWidth * 0.2;
      final y = isOpponent ? 0.0 : h - fingerHeight;
      final fingerRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, fingerWidth, fingerHeight),
        Radius.circular(fingerWidth * 0.45),
      );
      canvas.drawRRect(fingerRect, skinPaint);
      canvas.drawRRect(fingerRect, outlinePaint);
    }
  }

  @override
  bool shouldRepaint(covariant HandGripPainter oldDelegate) =>
      oldDelegate.isOpponent != isOpponent || oldDelegate.skinColor != skinColor;
}

/// Cartoon Arm Sleeve Painter (reaching behind card towards screen edge)
class ArmSleevePainter extends CustomPainter {
  final bool isOpponent;
  final Color sleeveColor;

  const ArmSleevePainter({
    this.isOpponent = false,
    this.sleeveColor = const Color(0xFF2563EB),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final sleevePaint = Paint()
      ..color = sleeveColor
      ..style = PaintingStyle.fill;

    final outlinePaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Sleeve Arm
    final sleeveRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.2, 0, w * 0.6, h),
      const Radius.circular(8),
    );
    canvas.drawRRect(sleeveRect, sleevePaint);
    canvas.drawRRect(sleeveRect, outlinePaint);

    // Cuff highlight band
    final cuffPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    final cuffRect = Rect.fromLTWH(w * 0.2, isOpponent ? h - 10 : 0, w * 0.6, 10);
    canvas.drawRect(cuffRect, cuffPaint);
  }

  @override
  bool shouldRepaint(covariant ArmSleevePainter oldDelegate) =>
      oldDelegate.isOpponent != isOpponent || oldDelegate.sleeveColor != sleeveColor;
}

/// Kenney Modular Character Dealing Hand Rig
class DealingHandPainter extends CustomPainter {
  final bool isOpponent;
  final Color sleeveColor;
  final Color skinColor;

  const DealingHandPainter({
    this.isOpponent = false,
    this.sleeveColor = const Color(0xFF2563EB),
    this.skinColor = const Color(0xFFFFDBAC),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final sleevePaint = Paint()
      ..color = sleeveColor
      ..style = PaintingStyle.fill;

    final skinPaint = Paint()
      ..color = skinColor
      ..style = PaintingStyle.fill;

    final outlinePaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Sleeve Arm
    final sleeveRect = isOpponent
        ? RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.25, 0, w * 0.5, h * 0.5), const Radius.circular(8))
        : RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.25, h * 0.5, w * 0.5, h * 0.5), const Radius.circular(8));

    canvas.drawRRect(sleeveRect, sleevePaint);
    canvas.drawRRect(sleeveRect, outlinePaint);

    // Rounded cartoon hand / glove (Kenney style)
    final handCenter = isOpponent ? Offset(w * 0.5, h * 0.65) : Offset(w * 0.5, h * 0.35);
    canvas.drawCircle(handCenter, w * 0.28, skinPaint);
    canvas.drawCircle(handCenter, w * 0.28, outlinePaint);

    // Thumb / grip detail
    final thumbOffset = isOpponent ? Offset(w * 0.32, h * 0.78) : Offset(w * 0.32, h * 0.22);
    canvas.drawCircle(thumbOffset, w * 0.13, skinPaint);
    canvas.drawCircle(thumbOffset, w * 0.13, outlinePaint);
  }

  @override
  bool shouldRepaint(covariant DealingHandPainter oldDelegate) =>
      oldDelegate.isOpponent != isOpponent ||
      oldDelegate.sleeveColor != sleeveColor ||
      oldDelegate.skinColor != skinColor;
}

/// Animated Dealing Hand Widget sliding onto the table during draw/war
class DealingHandWidget extends StatelessWidget {
  final Animation<double> slideAnimation;
  final bool isOpponent;
  final double cardWidth;
  final double cardHeight;
  final Widget? child;

  const DealingHandWidget({
    super.key,
    required this.slideAnimation,
    this.isOpponent = false,
    this.cardWidth = 80,
    this.cardHeight = 120,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final offsetTween = isOpponent
        ? Tween<Offset>(begin: const Offset(0, -1.3), end: const Offset(0, 0.0))
        : Tween<Offset>(begin: const Offset(0, 1.3), end: const Offset(0, 0.0));

    final sleeveColor = isOpponent ? const Color(0xFFEF4444) : const Color(0xFF3B82F6);

    return SlideTransition(
      position: offsetTween.animate(
        CurvedAnimation(parent: slideAnimation, curve: Curves.easeOutCubic),
      ),
      child: child != null
          ? Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // 1. Arm sleeve extending outward toward screen edge
                Positioned(
                  top: isOpponent ? -cardHeight * 0.45 : null,
                  bottom: !isOpponent ? -cardHeight * 0.45 : null,
                  child: CustomPaint(
                    size: Size(cardWidth * 0.65, cardHeight * 0.5),
                    painter: ArmSleevePainter(
                      isOpponent: isOpponent,
                      sleeveColor: sleeveColor,
                    ),
                  ),
                ),
                // 2. The Card being dealt
                child!,
                // 3. Gripping Cartoon Hand Fingers on TOP of the card edge
                Positioned(
                  top: isOpponent ? -8 : null,
                  bottom: !isOpponent ? -8 : null,
                  child: CustomPaint(
                    size: Size(cardWidth * 0.7, 28),
                    painter: HandGripPainter(
                      isOpponent: isOpponent,
                    ),
                  ),
                ),
              ],
            )
          : CustomPaint(
              size: Size(cardWidth * 1.1, cardHeight),
              painter: DealingHandPainter(
                isOpponent: isOpponent,
                sleeveColor: sleeveColor,
              ),
            ),
    );
  }
}

/// 3D Flippable Card with 60 FPS Smooth Rotation (never mirrored)
class FlippableCardWidget extends StatelessWidget {
  final bool isFaceUp;
  final PlayingCard card;
  final CardStatus status;
  final CardBackTheme cardBackTheme;
  final double width;
  final double height;
  final bool isWinner;

  const FlippableCardWidget({
    super.key,
    required this.isFaceUp,
    required this.card,
    this.status = CardStatus.normal,
    this.cardBackTheme = CardBackTheme.canyonCyan,
    this.width = 80,
    this.height = 120,
    this.isWinner = false,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
      tween: Tween<double>(begin: isFaceUp ? 1.0 : 0.0, end: isFaceUp ? 1.0 : 0.0),
      builder: (context, value, _) {
        final isFront = value >= 0.5;
        final rotationY = value * math.pi;

        return Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001) // 3D Perspective
            ..rotateY(isFront ? rotationY - math.pi : rotationY),
          alignment: Alignment.center,
          child: isFront
              ? CardFaceWidget(
                  card: card,
                  status: status,
                  isWinner: isWinner,
                  width: width,
                  height: height,
                )
              : CardBackWidget(
                  theme: cardBackTheme,
                  width: width,
                  height: height,
                ),
        );
      },
    );
  }
}
