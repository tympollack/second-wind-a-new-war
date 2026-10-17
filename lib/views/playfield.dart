import 'package:flutter/material.dart';
import '../models/playing_card.dart';
import '../theme/app_theme.dart';
import '../widgets/card_widget.dart';
import '../widgets/card_clash_particle_emitter.dart';

/// Custom Painter for Tabletop Green/Navy Felt Surface with Wood Beveled Border
class TabletopFeltPainter extends CustomPainter {
  final Color feltColor;

  const TabletopFeltPainter({
    this.feltColor = const Color(0xFF14532D), // Deep green felt
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Wood border frame
    final woodPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF3F2E18), Color(0xFF281E10), Color(0xFF1A130A)],
      ).createShader(rect);
    canvas.drawRect(rect, woodPaint);

    // Inner Felt Playfield
    const borderThickness = 12.0;
    final feltRect = Rect.fromLTWH(
      borderThickness,
      borderThickness,
      size.width - borderThickness * 2,
      size.height - borderThickness * 2,
    );
    final feltRRect = RRect.fromRectAndRadius(feltRect, const Radius.circular(16));

    final feltGradient = RadialGradient(
      center: Alignment.center,
      radius: 0.85,
      colors: [
        feltColor.withValues(alpha: 0.95),
        const Color(0xFF062814),
        const Color(0xFF02140A),
      ],
    );
    final feltPaint = Paint()..shader = feltGradient.createShader(feltRect);
    canvas.drawRRect(feltRRect, feltPaint);

    // Subtle table felt stitching line
    final stitchPaint = Paint()
      ..color = const Color(0xFFD4AF37).withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final stitchRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        borderThickness + 6,
        borderThickness + 6,
        size.width - (borderThickness + 6) * 2,
        size.height - (borderThickness + 6) * 2,
      ),
      const Radius.circular(12),
    );
    canvas.drawRRect(stitchRRect, stitchPaint);
  }

  @override
  bool shouldRepaint(covariant TabletopFeltPainter oldDelegate) =>
      oldDelegate.feltColor != feltColor;
}

/// Tabletop Playfield View with dealing hand animations, felt surface, and status badges
class TabletopPlayfieldView extends StatefulWidget {
  final PlayingCard? playerCard;
  final PlayingCard? opponentCard;
  final bool isPlayerCardFaceUp;
  final bool isOpponentCardFaceUp;
  final CardStatus playerCardStatus;
  final CardStatus opponentCardStatus;
  final CardBackTheme cardBackTheme;
  final bool isWar;
  final bool isSecondWindActive;
  final VoidCallback? onDealTap;

  const TabletopPlayfieldView({
    super.key,
    this.playerCard,
    this.opponentCard,
    this.isPlayerCardFaceUp = true,
    this.isOpponentCardFaceUp = true,
    this.playerCardStatus = CardStatus.normal,
    this.opponentCardStatus = CardStatus.normal,
    this.cardBackTheme = CardBackTheme.canyonCyan,
    this.isWar = false,
    this.isSecondWindActive = false,
    this.onDealTap,
  });

  @override
  State<TabletopPlayfieldView> createState() => _TabletopPlayfieldViewState();
}

class _TabletopPlayfieldViewState extends State<TabletopPlayfieldView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _handAnimController;

  @override
  void initState() {
    super.initState();
    _handAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..forward();
  }

  @override
  void didUpdateWidget(covariant TabletopPlayfieldView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playerCard != oldWidget.playerCard ||
        widget.opponentCard != oldWidget.opponentCard ||
        widget.isWar != oldWidget.isWar) {
      _handAnimController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _handAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final cardW = (screenSize.width * 0.22).clamp(70.0, 110.0);
    final cardH = cardW * 1.45;

    return CustomPaint(
      painter: const TabletopFeltPainter(),
      child: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Opponent Area & Dealing Hand
                  SizedBox(
                    height: cardH + 20,
                    child: DealingHandWidget(
                      slideAnimation: _handAnimController,
                      isOpponent: true,
                      cardWidth: cardW,
                      cardHeight: cardH,
                      child: widget.opponentCard != null
                          ? FlippableCardWidget(
                              isFaceUp: widget.isOpponentCardFaceUp,
                              card: widget.opponentCard!,
                              status: widget.opponentCardStatus,
                              cardBackTheme: widget.cardBackTheme,
                              width: cardW,
                              height: cardH,
                            )
                          : CardBackWidget(
                              theme: widget.cardBackTheme,
                              width: cardW,
                              height: cardH,
                            ),
                    ),
                  ),

                  // Center Battle Arena & Status Badges
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Active Badges Row
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            alignment: WrapAlignment.center,
                            children: [
                              if (widget.playerCardStatus == CardStatus.trump ||
                                  widget.opponentCardStatus == CardStatus.trump)
                                const StatusBadgeWidget(
                                  type: StatusBadgeType.trump,
                                  customLabel: 'TRUMP CARD',
                                ),
                              if (widget.playerCardStatus == CardStatus.musketeer ||
                                  widget.opponentCardStatus == CardStatus.musketeer)
                                const StatusBadgeWidget(
                                  type: StatusBadgeType.musketeer,
                                  customLabel: 'MUSKETEER DOMINATES',
                                ),
                              if (widget.isSecondWindActive)
                                const StatusBadgeWidget(
                                  type: StatusBadgeType.secondWind,
                                  customLabel: 'SECOND WIND ACTIVE',
                                ),
                              if (widget.isWar)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade900,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.amberAccent, width: 2),
                                  ),
                                  child: const Text(
                                    '⚔ WAR SEQUENCE ⚔',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (widget.onDealTap != null)
                            ElevatedButton.icon(
                              onPressed: widget.onDealTap,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.winGreen,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(Icons.touch_app),
                              label: const Text(
                                'DRAW / FLIP',
                                style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.8),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Player Area & Dealing Hand
                  SizedBox(
                    height: cardH + 20,
                    child: DealingHandWidget(
                      slideAnimation: _handAnimController,
                      isOpponent: false,
                      cardWidth: cardW,
                      cardHeight: cardH,
                      child: widget.playerCard != null
                          ? FlippableCardWidget(
                              isFaceUp: widget.isPlayerCardFaceUp,
                              card: widget.playerCard!,
                              status: widget.playerCardStatus,
                              cardBackTheme: widget.cardBackTheme,
                              width: cardW,
                              height: cardH,
                            )
                          : CardBackWidget(
                              theme: widget.cardBackTheme,
                              width: cardW,
                              height: cardH,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Kenney card clash spark emitter active on War event
          Positioned.fill(
            child: CardClashParticleEmitter(
              isWar: widget.isWar,
            ),
          ),
        ],
      ),
    );
  }
}
