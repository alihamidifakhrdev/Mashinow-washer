import 'dart:async' show Completer;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

/// انیمیشن تغییر تم — «افشای دایره‌ای» از محل سوییچ (سبک تلگرام):
///
///  ۱) لحظه‌ی تغییر، از نمای فعلی (تم قدیمی) عکس گرفته می‌شود
///  ۲) تم عوض می‌شود؛ در فریم بعد کل صفحه زیر عکس قدیمی پنهان است
///  ۳) یک دایره از مرکز سوییچ رشد می‌کند؛ داخل دایره تمِ جدید دیده
///     می‌شود و بیرون آن هنوز نمای قدیمی است — تا همه‌جا نو شود
///
/// اگر عکس‌برداری به هر دلیلی ممکن نشود، تم بی‌سروصدا و بدون انیمیشن
/// عوض می‌شود (هیچ‌وقت گیر نمی‌کند).
class ThemeReveal {
  ThemeReveal._();

  /// کلید RepaintBoundary ریشه — در builder متریال‌اپ ست می‌شود
  static final GlobalKey boundaryKey =
      GlobalKey(debugLabel: 'theme_reveal_boundary');

  static bool _running = false;

  /// [anchor] ویجتی است که انیمیشن از مرکزش شروع می‌شود (خودِ سوییچ)
  static Future<void> play({
    required BuildContext anchor,
    required VoidCallback apply,
  }) async {
    // مرکز ویجت لنگر (مختصات سراسری)
    final RenderObject? anchorRo = anchor.findRenderObject();
    if (anchorRo is! RenderBox || !anchorRo.hasSize) {
      apply();
      return;
    }
    final Offset center =
        anchorRo.localToGlobal(anchorRo.size.center(Offset.zero));

    // ── عکس‌برداری از نمای فعلی (قبل از تغییر تم) ──
    final BuildContext? boundaryCtx = boundaryKey.currentContext;
    if (boundaryCtx == null) {
      apply();
      return;
    }

    final RenderObject? rawBoundary = boundaryCtx.findRenderObject();
    if (rawBoundary is! RenderRepaintBoundary || !rawBoundary.attached) {
      apply();
      return;
    }

    // اگر فریم کامل رنگ نشده باشد یک فریم صبر می‌کنیم تا عکس سالم باشد
    if (rawBoundary.debugNeedsPaint) {
      await SchedulerBinding.instance.endOfFrame;
      if (!rawBoundary.attached) {
        apply();
        return;
      }
    }

    ui.Image? snapshot;
    try {
      snapshot = await rawBoundary.toImage(
        pixelRatio: _pixelRatio(anchor),
      );
    } catch (_) {
      snapshot = null;
    }

    if (snapshot == null) {
      apply();
      return;
    }

    // ── اجرا ──
    if (_running) {
      snapshot.dispose();
      apply();
      return;
    }
    _running = true;

    try {
      // تم عوض می‌شود؛ صفحه در فریم بعد با تم جدید رنگ می‌خورد
      apply();

      final OverlayState? overlay = Overlay.maybeOf(anchor, rootOverlay: true);
      if (overlay == null) {
        snapshot.dispose();
        return;
      }

      final Completer<void> done = Completer<void>();

      final OverlayEntry entry = OverlayEntry(
        builder: (BuildContext ctx) => Positioned.fill(
          child: _RevealLayer(
            snapshot: snapshot!,
            center: center,
            onFinished: () {
              if (!done.isCompleted) done.complete();
            },
          ),
        ),
      );

      overlay.insert(entry);

      // لایه خودش بعد از پایان انیمیشن علامت می‌دهد؛ آن‌وقت حذفش می‌کنیم
      await done.future;
      entry.remove();
    } finally {
      _running = false;
    }
  }

  static double _pixelRatio(BuildContext context) {
    final double? dpr = MediaQuery.maybeOf(context)?.devicePixelRatio;
    return (dpr ?? 3.0).clamp(2.0, 3.0);
  }
}

/// لایه‌ی روی رونما — عکس تم قدیمی که فقط «بیرونِ» دایره‌ی رو به رشد
/// دیده می‌شود؛ داخل دایره شفاف است و تم جدید از زیر پیدا می‌شود.
class _RevealLayer extends StatefulWidget {
  final ui.Image snapshot;
  final Offset center;
  final VoidCallback onFinished;

  const _RevealLayer({
    required this.snapshot,
    required this.center,
    required this.onFinished,
  });

  @override
  State<_RevealLayer> createState() => _RevealLayerState();
}

class _RevealLayerState extends State<_RevealLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 720),
  );

  @override
  void initState() {
    super.initState();

    _controller
      ..addStatusListener((AnimationStatus status) {
        if (status == AnimationStatus.completed) {
          widget.onFinished();
        }
      })
      ..forward();
  }

  @override
  void dispose() {
    widget.snapshot.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final Size size = constraints.biggest;

          // شعاع نهایی = دورترین گوشه صفحه از مرکز سوییچ
          final double maxRadius = _maxRadius(size, widget.center);

          return AnimatedBuilder(
            animation: _controller,
            builder: (BuildContext context, Widget? child) {
              return ClipPath(
                clipper: _OutsideCircleClipper(
                  center: widget.center,
                  radius: Curves.easeInOutCubic.transform(_controller.value) *
                      maxRadius,
                ),
                child: child,
              );
            },
            child: RawImage(
              image: widget.snapshot,
              fit: BoxFit.fill,
            ),
          );
        },
      ),
    );
  }

  static double _maxRadius(Size size, Offset center) {
    final double dx = math.max(center.dx, size.width - center.dx);
    final double dy = math.max(center.dy, size.height - center.dy);
    return math.sqrt(dx * dx + dy * dy);
  }
}

/// همه‌چیز به‌جز داخل دایره (قاعده‌ی even-odd)
class _OutsideCircleClipper extends CustomClipper<Path> {
  final Offset center;
  final double radius;

  const _OutsideCircleClipper({required this.center, required this.radius});

  @override
  Path getClip(Size size) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(Rect.fromCircle(center: center, radius: radius));
  }

  @override
  bool shouldReclip(_OutsideCircleClipper oldClipper) {
    return oldClipper.radius != radius || oldClipper.center != center;
  }
}
