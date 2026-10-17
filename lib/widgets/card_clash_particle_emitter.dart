import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CardClashParticleEmitter
//
// High-performance pooled particle system for War: Second Wind.
// Emits Kenney-styled card clash sparks when equal cards trigger a War event.
//
// Invariants:
//   • Fixed pre-allocated particle pool — zero memory allocations during gameplay
//   • Particles automatically dispose upon completion
// ─────────────────────────────────────────────────────────────────────────────

class ClashSparkParticle {
  Offset position = Offset.zero;
  Offset velocity = Offset.zero;
  double life = 0.0;
  double maxLife = 0.45;
  double startSize = 3.0;
  double endSize = 0.5;
  Color startColor = Colors.white;
  Color endColor = Colors.transparent;
  bool active = false;

  void reset() {
    active = false;
    life = 0.0;
    position = Offset.zero;
    velocity = Offset.zero;
  }
}

class CardClashParticleEmitter extends StatefulWidget {
  final int capacity;
  final bool autoTriggerOnWar;
  final bool isWar;

  const CardClashParticleEmitter({
    super.key,
    this.capacity = 80,
    this.autoTriggerOnWar = true,
    this.isWar = false,
  });

  @override
  State<CardClashParticleEmitter> createState() => CardClashParticleEmitterState();
}

class CardClashParticleEmitterState extends State<CardClashParticleEmitter>
    with SingleTickerProviderStateMixin {
  late final List<ClashSparkParticle> _pool;
  late final Ticker _ticker;
  final math.Random _random = math.Random();
  Duration? _lastElapsed;

  int get activeCount => _pool.where((p) => p.active).length;
  int get poolSize => _pool.length;

  @override
  void initState() {
    super.initState();
    _pool = List<ClashSparkParticle>.generate(
      widget.capacity,
      (_) => ClashSparkParticle(),
    );
    _ticker = createTicker(_onTick);

    if (widget.isWar && widget.autoTriggerOnWar) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) emitClashSparks(null);
      });
    }
  }

  @override
  void didUpdateWidget(covariant CardClashParticleEmitter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isWar && !oldWidget.isWar && widget.autoTriggerOnWar) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) emitClashSparks(null);
      });
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  ClashSparkParticle? _acquire() {
    for (var i = 0; i < widget.capacity; i++) {
      if (!_pool[i].active) return _pool[i];
    }
    // Recycle oldest if pool saturated
    ClashSparkParticle? oldest;
    double maxRatio = -1;
    for (var i = 0; i < widget.capacity; i++) {
      final ratio = _pool[i].life / _pool[i].maxLife;
      if (ratio > maxRatio) {
        maxRatio = ratio;
        oldest = _pool[i];
      }
    }
    oldest?.reset();
    return oldest;
  }

  Offset _resolveCenter(Offset? center) {
    if (center != null) return center;
    try {
      final renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox != null && renderBox.hasSize) {
        return renderBox.size.center(Offset.zero);
      }
    } catch (_) {}
    return const Offset(150, 200);
  }

  void emitClashSparks(Offset? center, {int count = 24}) {
    final effectiveCenter = _resolveCenter(center);

    const sparkColors = [
      Color(0xFFFFFFFF), // Brilliant white
      Color(0xFFFFD700), // Pure gold
      Color(0xFFFF9800), // Amber spark
      Color(0xFFFF3D00), // Flame orange
      Color(0xFF00E5FF), // Cyan arc flare
    ];

    for (var i = 0; i < count; i++) {
      final p = _acquire();
      if (p == null) break;

      p.position = effectiveCenter;

      // Omnidirectional starburst clash with explosive speeds
      final angle = (i / count) * 2 * math.pi + (_random.nextDouble() - 0.5) * 0.5;
      final speed = 140.0 + _random.nextDouble() * 260.0;
      p.velocity = Offset(math.cos(angle) * speed, math.sin(angle) * speed);

      p.life = 0.0;
      p.maxLife = 0.35 + _random.nextDouble() * 0.20;
      p.startSize = 3.5 + _random.nextDouble() * 3.5;
      p.endSize = 0.5;

      final col = sparkColors[_random.nextInt(sparkColors.length)];
      p.startColor = col;
      p.endColor = col.withValues(alpha: 0.0);
      p.active = true;
    }

    if (!_ticker.isTicking) {
      _lastElapsed = null;
      _ticker.start();
    }

    if (mounted) setState(() {});
  }

  void clear() {
    for (final p in _pool) {
      p.reset();
    }
    if (_ticker.isTicking) {
      _ticker.stop();
    }
    _lastElapsed = null;
    if (mounted) setState(() {});
  }

  void _onTick(Duration elapsed) {
    if (_lastElapsed == null) {
      _lastElapsed = elapsed;
      return;
    }

    final rawDt = (elapsed - _lastElapsed!).inMicroseconds / 1e6;
    _lastElapsed = elapsed;
    if (rawDt <= 0) return;
    final dt = rawDt.clamp(0.0, 1.0);

    bool hasActive = false;
    for (var i = 0; i < widget.capacity; i++) {
      final p = _pool[i];
      if (!p.active) continue;

      p.life += dt;
      if (p.life >= p.maxLife) {
        // Automatic disposal upon completion
        p.active = false;
        continue;
      }

      hasActive = true;
      p.position += p.velocity * dt;
      p.velocity = p.velocity * 0.91; // Air friction deceleration
    }

    if (!hasActive) {
      _ticker.stop();
      _lastElapsed = null;
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _ClashSparkPainter(particles: _pool),
      ),
    );
  }
}

class _ClashSparkPainter extends CustomPainter {
  final List<ClashSparkParticle> particles;
  final Paint _sparkPaint = Paint()..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
  final Paint _corePaint = Paint()..style = PaintingStyle.fill;

  _ClashSparkPainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      if (!p.active) continue;

      final progress = (p.life / p.maxLife).clamp(0.0, 1.0);
      final color = Color.lerp(p.startColor, p.endColor, progress) ?? p.startColor;
      final currentSize = (p.startSize + (p.endSize - p.startSize) * progress).clamp(0.5, 8.0);

      _sparkPaint
        ..color = color
        ..strokeWidth = currentSize;

      // Draw spark streak pointing back against velocity vector
      final tail = p.position - (p.velocity * 0.025);
      canvas.drawLine(p.position, tail, _sparkPaint);

      _corePaint.color = color;
      canvas.drawCircle(p.position, currentSize * 0.6, _corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ClashSparkPainter oldDelegate) => true;
}
