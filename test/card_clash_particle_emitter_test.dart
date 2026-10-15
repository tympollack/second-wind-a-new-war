import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war_second_wind/widgets/card_clash_particle_emitter.dart';

void main() {
  group('CardClashParticleEmitter Tests', () {
    testWidgets('initializes with pre-allocated pool and zero active particles',
        (tester) async {
      final key = GlobalKey<CardClashParticleEmitterState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CardClashParticleEmitter(
              key: key,
              capacity: 40,
              isWar: false,
            ),
          ),
        ),
      );

      final state = key.currentState!;
      expect(state.poolSize, equals(40));
      expect(state.activeCount, equals(0));
    });

    testWidgets('emitClashSparks activates pooled spark particles and auto-disposes',
        (tester) async {
      final key = GlobalKey<CardClashParticleEmitterState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CardClashParticleEmitter(
              key: key,
              capacity: 40,
              isWar: false,
            ),
          ),
        ),
      );

      final state = key.currentState!;
      state.emitClashSparks(const Offset(100, 100), count: 20);
      expect(state.activeCount, equals(20));

      // Pump frames to advance animation past expiration (0.55s)
      await tester.pump(const Duration(milliseconds: 100));
      expect(state.activeCount, equals(20));

      await tester.pump(const Duration(milliseconds: 600));
      // Particles must be disposed back into pool
      expect(state.activeCount, equals(0));
    });

    testWidgets('auto-triggers sparks when isWar becomes true',
        (tester) async {
      final key = GlobalKey<CardClashParticleEmitterState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CardClashParticleEmitter(
              key: key,
              capacity: 40,
              isWar: false,
            ),
          ),
        ),
      );

      final state = key.currentState!;
      expect(state.activeCount, equals(0));

      // Re-pump with isWar: true
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CardClashParticleEmitter(
              key: key,
              capacity: 40,
              isWar: true,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(state.activeCount, greaterThan(0));
    });

    testWidgets('recycles oldest particles when pool capacity is exceeded to prevent memory leaks',
        (tester) async {
      final key = GlobalKey<CardClashParticleEmitterState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CardClashParticleEmitter(
              key: key,
              capacity: 15,
              isWar: false,
            ),
          ),
        ),
      );

      final state = key.currentState!;
      state.emitClashSparks(const Offset(50, 50), count: 15);
      expect(state.activeCount, equals(15));
      expect(state.poolSize, equals(15));

      // Emit more particles than pool capacity
      state.emitClashSparks(const Offset(50, 50), count: 10);
      expect(state.poolSize, equals(15));
      expect(state.activeCount, equals(15));
    });

    testWidgets('clear resets all active particles back into pool',
        (tester) async {
      final key = GlobalKey<CardClashParticleEmitterState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CardClashParticleEmitter(
              key: key,
              capacity: 30,
              isWar: false,
            ),
          ),
        ),
      );

      final state = key.currentState!;
      state.emitClashSparks(const Offset(100, 100), count: 12);
      expect(state.activeCount, equals(12));

      state.clear();
      expect(state.activeCount, equals(0));
    });
  });
}
