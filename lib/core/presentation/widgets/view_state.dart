import 'package:flutter/material.dart';

/// Renders loading / error / empty / content states for async data.
class ViewState<T> extends StatelessWidget {
  final bool loading;
  final Object? error;
  final bool isEmpty;
  final String? emptyMessage;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;
  final VoidCallback? onRetry;
  final Widget Function(T data) builder;
  final T? data;

  const ViewState({
    super.key,
    required this.loading,
    required this.builder,
    this.data,
    this.error,
    this.isEmpty = false,
    this.emptyMessage,
    this.emptyActionLabel,
    this.onEmptyAction,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (loading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: CircularProgressIndicator(color: colors.primary),
        ),
      );
    }

    if (error != null) {
      return _Message(
        icon: Icons.wifi_off_rounded,
        title: 'خطا در دریافت اطلاعات',
        message: error.toString(),
        actionLabel: 'تلاش مجدد',
        onAction: onRetry,
      );
    }

    if (isEmpty) {
      return _Message(
        icon: Icons.inbox_rounded,
        title: 'موردی نیست',
        message: emptyMessage ?? 'در حال حاضر چیزی برای نمایش وجود ندارد.',
        actionLabel: emptyActionLabel,
        onAction: onEmptyAction,
      );
    }

    final value = data;
    if (value == null) {
      return const SizedBox.shrink();
    }

    return builder(value);
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _Message({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final types = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: colors.outline),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: types.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: types.bodyMedium?.copyWith(color: colors.outline),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: Text(actionLabel!),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Simple full-page loading indicator.
class PageLoading extends StatelessWidget {
  const PageLoading({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: CircularProgressIndicator(color: colors.primary),
      ),
    );
  }
}
