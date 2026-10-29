import 'package:flutter/material.dart';

/// Drop-in replacement for [GestureDetector] that adds a pointer cursor and a
/// subtle lift on hover (web / desktop). Behaviour of the taps is unchanged.
class HoverTap extends StatefulWidget {
  const HoverTap({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.onDoubleTap,
    this.behavior,
    this.lift = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDoubleTap;
  final HitTestBehavior? behavior;

  /// Set to false for large full-width images where only the cursor is wanted.
  final bool lift;

  @override
  State<HoverTap> createState() => _HoverTapState();
}

class _HoverTapState extends State<HoverTap> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final clickable = widget.onTap != null ||
        widget.onLongPress != null ||
        widget.onDoubleTap != null;
    final raised = _hovered && widget.lift;

    return MouseRegion(
      cursor: clickable ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onDoubleTap: widget.onDoubleTap,
        behavior: widget.behavior,
        child: AnimatedScale(
          scale: raised ? 1.03 : 1.0,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: AnimatedSlide(
            offset: raised ? const Offset(0, -0.015) : Offset.zero,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Drop-in replacement for [Card] that rises slightly (shadow + lift) when the
/// mouse is over it. Looks and behaves exactly like [Card] otherwise.
class HoverCard extends StatefulWidget {
  const HoverCard({
    super.key,
    this.color,
    this.shadowColor,
    this.elevation,
    this.shape,
    this.margin,
    this.clipBehavior,
    this.child,
  });

  final Color? color;
  final Color? shadowColor;
  final double? elevation;
  final ShapeBorder? shape;
  final EdgeInsetsGeometry? margin;
  final Clip? clipBehavior;
  final Widget? child;

  @override
  State<HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<HoverCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final base = widget.elevation ?? CardTheme.of(context).elevation ?? 1.0;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedSlide(
        offset: _hovered ? const Offset(0, -0.01) : Offset.zero,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: Card(
          color: widget.color,
          shadowColor: widget.shadowColor,
          elevation: _hovered ? base + 6 : base,
          shape: widget.shape,
          margin: widget.margin,
          clipBehavior: widget.clipBehavior,
          child: widget.child,
        ),
      ),
    );
  }
}
