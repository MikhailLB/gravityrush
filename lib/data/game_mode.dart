import 'dart:math';

import 'package:flutter/material.dart';

import '../core/elements.dart';
import '../core/palette.dart';
import 'session_config.dart';

/// A purchasable, replayable game mode. Each mode procedurally builds a
/// [SessionConfig] every time it is played — no two runs are identical.
class GameMode {
  final String id;
  final String name;
  final String tagline;
  final IconData icon;
  final Color color;
  final int price;
  final SessionConfig Function() build;

  const GameMode({
    required this.id,
    required this.name,
    required this.tagline,
    required this.icon,
    required this.color,
    required this.price,
    required this.build,
  });

  static const List<Essence> _all = Essence.values;

  static List<Point<int>> _scatterCorruption(int n, int rows, int cols) {
    final rng = Random();
    final out = <Point<int>>{};
    var guard = 0;
    while (out.length < n && guard < n * 20 + 30) {
      guard++;
      out.add(Point(rng.nextInt(rows), rng.nextInt(cols)));
    }
    return out.toList();
  }

  static final List<GameMode> all = [
    GameMode(
      id: 'endless',
      name: 'Endless Sandbox',
      tagline: 'Every cleared line buys you time. Survive forever.',
      icon: Icons.all_inclusive_rounded,
      color: Palette.success,
      price: 400,
      build: () => const SessionConfig(
        title: 'Endless Sandbox',
        rows: 8,
        cols: 8,
        palette: _all,
        timeSeconds: 30,
        timeBonusPerLine: 1.6,
        volatileChance: 0.05,
        endless: true,
      ),
    ),
    GameMode(
      id: 'blitz',
      name: 'Blitz',
      tagline: 'Fifteen moves. One explosive high score.',
      icon: Icons.bolt_rounded,
      color: Palette.accentBright,
      price: 250,
      build: () => const SessionConfig(
        title: 'Blitz',
        rows: 8,
        cols: 8,
        palette: _all,
        moves: 15,
        volatileChance: 0.06,
        endless: true,
      ),
    ),
    GameMode(
      id: 'time_attack',
      name: 'Time Attack',
      tagline: 'Seventy-five seconds. No mercy.',
      icon: Icons.timer_rounded,
      color: Palette.gold,
      price: 700,
      build: () => const SessionConfig(
        title: 'Time Attack',
        rows: 8,
        cols: 8,
        palette: _all,
        timeSeconds: 75,
        volatileChance: 0.04,
        endless: true,
      ),
    ),
    GameMode(
      id: 'inferno',
      name: 'Inferno Rush',
      tagline: 'Volatile chaos and creeping corruption. Hold the line.',
      icon: Icons.local_fire_department_rounded,
      color: Palette.danger,
      price: 1200,
      build: () => SessionConfig(
        title: 'Inferno Rush',
        rows: 8,
        cols: 8,
        palette: _all,
        timeSeconds: 60,
        timeBonusPerLine: 0.9,
        volatileSeed: 6,
        volatileChance: 0.14,
        corruption: _scatterCorruption(4, 8, 8),
        endless: true,
      ),
    ),
  ];
}
