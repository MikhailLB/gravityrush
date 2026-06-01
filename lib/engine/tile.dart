import '../core/elements.dart';

/// The kinds of objects that can occupy a board cell.
enum TileKind {
  /// A plain elemental orb.
  orb,

  /// Forged from a line of four. When triggered, detonates its whole row
  /// and column (a "Nova Cross").
  cross,

  /// Forged from an L / T shape. When triggered, detonates a 3x3 bloom.
  bloom,

  /// Forged from a line of five. A wild "Prism" — swap it with any orb to
  /// vaporise every orb of that essence.
  prism,

  /// A hazard tile (the skull). It cannot be moved or matched directly and
  /// must be cleansed by triggering a reaction next to it.
  corruption,

  /// An unstable orb. It matches by essence like a normal orb, but whenever it
  /// is cleared it detonates a 3x3 bloom — driving chain explosions. Levels seed
  /// more of these as the campaign progresses.
  volatileOrb,
}

/// A single logical tile on the board.
///
/// Every tile carries a stable [id] so the view layer can animate it as a
/// persistent object as it slides, clears and respawns.
class Tile {
  final int id;
  TileKind kind;

  /// `null` for [TileKind.prism] and [TileKind.corruption].
  Essence? essence;

  Tile({required this.id, required this.kind, this.essence});

  bool get isOrb => kind == TileKind.orb;
  bool get isCorruption => kind == TileKind.corruption;
  bool get isPrism => kind == TileKind.prism;
  bool get isVolatile => kind == TileKind.volatileOrb;
  bool get isSpecial =>
      kind == TileKind.cross || kind == TileKind.bloom || kind == TileKind.prism;

  /// Whether the player is allowed to drag/swap this tile.
  bool get movable => kind != TileKind.corruption;

  /// Whether this tile participates in line-matching by essence.
  bool get matchable =>
      kind == TileKind.orb ||
      kind == TileKind.cross ||
      kind == TileKind.bloom ||
      kind == TileKind.volatileOrb;

  Tile copy() => Tile(id: id, kind: kind, essence: essence);
}
