import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/palette.dart';
import '../../engine/tile.dart';
import '../../game/session_controller.dart';
import 'orb_widget.dart';

/// Renders the live board and translates gestures (tap-to-swap and swipe) into
/// [SessionController.trySwap] calls. All motion is implicit: the widget simply
/// draws the board's current state and lets [AnimatedPositioned]/[AnimatedScale]
/// interpolate between frames.
class BoardView extends StatefulWidget {
  final SessionController controller;
  final Set<Point<int>> hintCells;

  const BoardView({
    super.key,
    required this.controller,
    this.hintCells = const {},
  });

  @override
  State<BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends State<BoardView> {
  Point<int>? _selected;
  Point<int>? _dragStart;
  bool _dragHandled = false;

  SessionController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    c.addListener(_onChange);
  }

  @override
  void didUpdateWidget(covariant BoardView old) {
    super.didUpdateWidget(old);
    if (old.controller != c) {
      old.controller.removeListener(_onChange);
      c.addListener(_onChange);
    }
  }

  @override
  void dispose() {
    c.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  bool get _locked => c.status != SessionStatus.ready;

  Point<int>? _cellAt(Offset local, double cell) {
    final col = (local.dx / cell).floor();
    final row = (local.dy / cell).floor();
    if (row < 0 || row >= c.board.rows || col < 0 || col >= c.board.cols) {
      return null;
    }
    return Point(row, col);
  }

  void _handleTap(Point<int> cell) {
    if (_locked) return;
    final tile = c.board.grid[cell.x][cell.y];
    if (tile == null || !tile.movable) {
      setState(() => _selected = null);
      return;
    }
    final sel = _selected;
    if (sel == null) {
      setState(() => _selected = cell);
    } else if (sel == cell) {
      setState(() => _selected = null);
    } else if (c.board.areAdjacent(sel, cell)) {
      _selected = null;
      c.trySwap(sel, cell);
    } else {
      setState(() => _selected = cell);
    }
  }

  void _handleSwipe(Point<int> from, Offset delta) {
    if (_locked || _dragHandled) return;
    final adx = delta.dx.abs();
    final ady = delta.dy.abs();
    Point<int> to;
    if (adx > ady) {
      to = Point(from.x, from.y + (delta.dx > 0 ? 1 : -1));
    } else {
      to = Point(from.x + (delta.dy > 0 ? 1 : -1), from.y);
    }
    if (!c.board.inBounds(to.x, to.y)) return;
    _dragHandled = true;
    _selected = null;
    c.trySwap(from, to);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = c.board.cols;
        final rows = c.board.rows;
        final cell = min(
          constraints.maxWidth / cols,
          constraints.maxHeight / rows,
        );
        final boardW = cell * cols;
        final boardH = cell * rows;

        return Center(
          child: Container(
            width: boardW,
            height: boardH,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.black.withValues(alpha: 0.28),
              border: Border.all(color: Palette.panelBorder, width: 1.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(19),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) {
                  final p = _cellAt(d.localPosition, cell);
                  if (p != null) _handleTap(p);
                },
                onPanStart: (d) {
                  _dragHandled = false;
                  _dragStart = _cellAt(d.localPosition, cell);
                },
                onPanUpdate: (d) {
                  final start = _dragStart;
                  if (start != null && d.delta.distance > 0) {
                    final total = d.localPosition -
                        Offset(
                          (start.y + 0.5) * cell,
                          (start.x + 0.5) * cell,
                        );
                    if (total.distance > cell * 0.45) {
                      _handleSwipe(start, total);
                    }
                  }
                },
                onPanEnd: (_) => _dragStart = null,
                child: Stack(
                  children: _buildTiles(cell),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildTiles(double cell) {
    final widgets = <Widget>[];
    for (var r = 0; r < c.board.rows; r++) {
      for (var col = 0; col < c.board.cols; col++) {
        final tile = c.board.grid[r][col];
        if (tile == null) continue;
        final p = Point(r, col);
        widgets.add(
          AnimatedPositioned(
            key: ValueKey(tile.id),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            left: col * cell,
            top: r * cell,
            width: cell,
            height: cell,
            child: _OrbCell(
              tile: tile,
              size: cell,
              clearing: c.clearing.contains(tile.id),
              selected: _selected == p,
              hint: widget.hintCells.contains(p),
            ),
          ),
        );
      }
    }
    return widgets;
  }
}

/// One animated cell: scales in on spawn and scales out while clearing.
class _OrbCell extends StatefulWidget {
  final Tile tile;
  final double size;
  final bool clearing;
  final bool selected;
  final bool hint;

  const _OrbCell({
    required this.tile,
    required this.size,
    required this.clearing,
    required this.selected,
    required this.hint,
  });

  @override
  State<_OrbCell> createState() => _OrbCellState();
}

class _OrbCellState extends State<_OrbCell> with SingleTickerProviderStateMixin {
  late final AnimationController _in;

  @override
  void initState() {
    super.initState();
    _in = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      value: widget.tile.isCorruption ? 1.0 : 0.0,
    )..forward();
  }

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget content = OrbWidget(tile: widget.tile, size: widget.size);

    if (widget.selected || widget.hint) {
      content = Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: widget.selected ? Palette.accentBright : Palette.gold,
            width: 2.2,
          ),
          boxShadow: Palette.glow(
            widget.selected ? Palette.accentBright : Palette.gold,
            blur: 14,
          ),
        ),
        child: content,
      );
    }

    return AnimatedScale(
      scale: widget.clearing ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInBack,
      child: AnimatedOpacity(
        opacity: widget.clearing ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: ScaleTransition(
          scale: CurvedAnimation(parent: _in, curve: Curves.easeOutBack),
          child: content,
        ),
      ),
    );
  }
}
