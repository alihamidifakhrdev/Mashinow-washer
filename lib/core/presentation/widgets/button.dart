import 'package:flutter/material.dart';

/// Drives an [AppButton] into loading / success states from the outside.
class ButtonController {
  _AppButtonState? _state;

  bool get isMounted => _state != null;

  void setLoading() => _state?._setLoading();

  void setSuccess() => _state?._setSuccess();

  void reset() => _state?._reset();

  void _attach(_AppButtonState state) => _state = state;

  void _detach(_AppButtonState state) {
    if (_state == state) _state = null;
  }
}

/// A filled button with built-in loading and success states, optionally
/// driven by a [ButtonController].
class AppButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expanded;
  final ButtonStyle? style;
  final ButtonController? controller;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expanded = true,
    this.style,
    this.controller,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _loading = false;
  bool _succeeded = false;

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
  }

  @override
  void didUpdateWidget(covariant AppButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    super.dispose();
  }

  void _setLoading() {
    if (mounted) setState(() => _loading = true);
  }

  void _setSuccess() {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _succeeded = true;
    });
    Future.delayed(const Duration(seconds: 2), _reset);
  }

  void _reset() {
    if (mounted) {
      setState(() {
        _loading = false;
        _succeeded = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    Widget content;

    if (_loading) {
      content = SizedBox(
        height: 22,
        width: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.6,
          valueColor: AlwaysStoppedAnimation<Color>(colors.onPrimary),
        ),
      );
    } else if (_succeeded) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded, size: 22),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'انجام شد',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
    } else if (widget.icon != null) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(widget.icon, size: 22),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
    } else {
      content = Text(
        widget.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      );
    }

    final button = FilledButton(
      onPressed: (_loading || _succeeded) ? null : widget.onPressed,
      style: widget.style ??
          FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
      child: content,
    );

    if (!widget.expanded) return button;

    return SizedBox(
      width: double.infinity,
      child: button,
    );
  }
}
