import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mashinow_washer/core/constants/drawables.dart';
import 'package:mashinow_washer/core/providers/app_auth.dart';
import 'package:mashinow_washer/features/dashboard/dashboard_providers.dart';

/// Decides where to go after launch: login, onboarding or dashboard.
class SplashScreenPage extends ConsumerStatefulWidget {
  const SplashScreenPage({super.key});

  @override
  ConsumerState<SplashScreenPage> createState() => _SplashScreenPageState();
}

class _SplashScreenPageState extends ConsumerState<SplashScreenPage> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Restore tokens (if any) from secure storage.
    await ref.read(appAuthProvider.notifier).restoreSession();

    final status = ref.read(appAuthProvider).status;

    if (status != AuthStatus.authenticated) {
      // Router redirect handles sending us to /login.
      return;
    }

    // Logged-in → check whether the washer already completed registration
    // (owner profile + carwash profile exist on the backend).
    try {
      await ref.read(profileStatusProvider.future);
    } catch (_) {
      // Network issues should not trap the user on splash; the router
      // redirect will route to onboarding where they can retry.
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colors.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              isDark ? Drawables.imageLogoTypeDark : Drawables.imageLogoTypeLight,
              width: 220,
              fit: BoxFit.fitWidth,
            ),
            const SizedBox(height: 32),
            Text(
              'اپلیکیشن کارواش‌دار',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.outline,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              height: 28,
              width: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.6,
                color: colors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
