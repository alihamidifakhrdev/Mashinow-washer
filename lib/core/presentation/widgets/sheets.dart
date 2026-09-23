import 'package:flutter/material.dart';

/// Shows a rounded bottom sheet with the given [builder].
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool scrollControlled = false,
  bool isDismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isDismissible: isDismissible,
    isScrollControlled: scrollControlled,
    enableDrag: isDismissible,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: builder,
  );
}

/// Standard page app bar with a back button and centered title.
AppBar appBar(String title, {List<Widget>? actions, bool? centerTitle}) {
  return AppBar(
    title: Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
    ),
    centerTitle: centerTitle ?? true,
    actions: actions,
  );
}
