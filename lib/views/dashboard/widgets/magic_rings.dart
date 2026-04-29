import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/pages/home.dart' show connectButtonCenter;
import 'package:dropweb/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Local 60fps ripple/glow rings anchored around the connect button.
///
/// Reads [connectButtonCenter] (set by _ConnectCircle via GlobalKey).
/// 2 rings, 14s cycle, painted into a small box centered on the button —
/// not the fullscreen overlay anymore.
///
/// Performance notes (round 6 — local box, smooth vsync):
/// - The overlay watches `runTimeProvider` via a boolean `.select`, so the
///   per-second runtime ticks don't rebuild this subtree — only
///   connected/disconnected transitions do.
/// - The local center of the connect button is cached in [_RingsAnimator] and
///   only recomputed when the global position changes, instead of resolving
///   `globalToLocal` every animation tick.
/// - The painter is driven directly by the [AnimationController] at vsync
///   through [AnimatedBuilder] — no throttling, no progress downsampling.
///   A previous 12fps throttling experiment looked like lag and was reverted.
/// - Spatial optimization: painter is bounded to a fixed-size local box
///   ([_ringBoxSize]) positioned around the button center. The dirty rect on
///   each repaint shrinks from the full screen down to a small square, which
///   is what actually cost frames on Pixel 10 while VPN was active. 60fps
///   smoothness is preserved; rasterizer load drops because the area being
///   re-rasterized each vsync is a fraction of the screen.
class MagicRingsOverlay extends ConsumerStatefulWidget {
  const MagicRingsOverlay({super.key});

  @override
  ConsumerState<MagicRingsOverlay> createState() => _MagicRingsOverlayState();
}

class _MagicRingsOverlayState extends ConsumerState<MagicRingsOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 14000),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Narrow the watch to a primitive bool so per-second runtime ticks don't
    // rebuild this overlay. Only connected/disconnected transitions matter.
    final isConnected =
        ref.watch(runTimeProvider.select((state) => state != null));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Only show on dashboard — rings must not leak into Settings/other pages.
    final isOnDashboard = ref.watch(isCurrentPageProvider(PageLabel.dashboard));
    final visible = isConnected && isDark && isOnDashboard;

    if (visible && !_controller.isAnimating) _controller.repeat();

    final color = Theme.of(context).colorScheme.primary;

    return AnimatedOpacity(
      opacity: visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
      onEnd: () {
        if (!visible && _controller.isAnimating) {
          _controller.stop();
          _controller.reset();
        }
      },
      child: IgnorePointer(
        child: ValueListenableBuilder<Offset?>(
          valueListenable: connectButtonCenter,
          builder: (_, btnCenter, __) {
            if (btnCenter == null) return const SizedBox.shrink();
            return _RingsAnimator(
              btnCenter: btnCenter,
              controller: _controller,
              color: color,
            );
          },
        ),
      ),
    );
  }
}

/// Local box size (px) around the connect button used for the rings paint.
///
/// 360.0 reads as a generous halo around the connect circle without leaking
/// across the rest of the dashboard. The `maxRadius` of the painter is then
/// `size.shortestSide / 2 = 180`, so the outermost ring fits inside the box
/// and the rasterizer never has to repaint outside this square.
const double _ringBoxSize = 360.0;

/// Wraps the per-frame [AnimatedBuilder] but resolves the local overlay
/// coordinate of the connect button only when [btnCenter] changes (or after
/// the first layout pass), instead of every animation tick.
///
/// Why: the parent widget tree never moves between frames of the 14s cycle,
/// so `globalToLocal` always returns the same value. Calling it on every
/// frame inside the [AnimatedBuilder] forced a fullscreen `findRenderObject`
/// + matrix conversion 60 times per second for no benefit.
class _RingsAnimator extends StatefulWidget {
  const _RingsAnimator({
    required this.btnCenter,
    required this.controller,
    required this.color,
  });

  final Offset btnCenter;
  final AnimationController controller;
  final Color color;

  @override
  State<_RingsAnimator> createState() => _RingsAnimatorState();
}

class _RingsAnimatorState extends State<_RingsAnimator> {
  Offset? _localCenter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(_recomputeLocalCenter);
  }

  @override
  void didUpdateWidget(covariant _RingsAnimator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.btnCenter != widget.btnCenter) {
      WidgetsBinding.instance.addPostFrameCallback(_recomputeLocalCenter);
    }
  }

  void _recomputeLocalCenter(Duration _) {
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    // Guard against detached/no-size RenderBox; a later layout pass will
    // schedule another frame and we'll catch it via didUpdateWidget or the
    // initial post-frame callback retry path.
    if (box == null || !box.hasSize || !box.attached) {
      // Try again next frame — the overlay is still laying out.
      WidgetsBinding.instance.addPostFrameCallback(_recomputeLocalCenter);
      return;
    }
    final next = box.globalToLocal(widget.btnCenter);
    if (next != _localCenter) {
      setState(() => _localCenter = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localCenter = _localCenter;
    if (localCenter == null) return const SizedBox.shrink();
    final color = widget.color;
    // Position a fixed-size box around the button center so the painter's
    // dirty rect is local, not fullscreen. The Stack lets the box float over
    // the dashboard without affecting layout (parent is IgnorePointer).
    return Stack(
      children: [
        Positioned(
          left: localCenter.dx - _ringBoxSize / 2,
          top: localCenter.dy - _ringBoxSize / 2,
          width: _ringBoxSize,
          height: _ringBoxSize,
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: widget.controller,
              builder: (_, __) {
                return CustomPaint(
                  size: const Size(_ringBoxSize, _ringBoxSize),
                  painter: _LocalRingsPainter(
                    progress: widget.controller.value,
                    color: color,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Paints the expanding rings inside a local box.
///
/// Center is `size.center(Offset.zero)`; max radius is `size.shortestSide / 2`
/// so the largest ring fits exactly inside the box. The painter mutates a
/// single reusable [Paint] across rings instead of allocating one per ring.
class _LocalRingsPainter extends CustomPainter {
  _LocalRingsPainter({
    required this.progress,
    required this.color,
  });

  final double progress;
  final Color color;

  static const _ringCount = 2;
  // Slightly higher base alpha than the old fullscreen painter — rings are
  // smaller now, so they need a bit more presence to read as an active-VPN
  // cue without being loud.
  static const _baseAlpha = 0.22;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = size.shortestSide / 2;
    // Single Paint instance, mutated per ring. Cheaper than allocating a
    // fresh Paint object inside the loop on every vsync repaint.
    final paint = Paint()..style = PaintingStyle.stroke;

    for (int i = 0; i < _ringCount; i++) {
      final phase = (progress + i / _ringCount) % 1.0;
      final radius = phase * maxRadius;
      final fade = 1.0 - phase;
      final alpha = fade * fade * _baseAlpha;
      if (alpha < 0.003) continue;
      final strokeWidth = 1.2 * (1.0 - phase * 0.5);
      if (strokeWidth < 0.1) continue;

      paint
        ..strokeWidth = strokeWidth
        ..color = color.withValues(alpha: alpha);

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_LocalRingsPainter old) =>
      old.progress != progress || old.color != color;
}
