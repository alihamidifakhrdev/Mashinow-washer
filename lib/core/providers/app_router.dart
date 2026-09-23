import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mashinow_washer/core/constants/route_names.dart';
import 'package:mashinow_washer/core/providers/app_auth.dart';
import 'package:mashinow_washer/features/auth/login_page.dart';
import 'package:mashinow_washer/features/bookings/guest_booking_page.dart';
import 'package:mashinow_washer/features/onboarding/onboarding_page.dart';
import 'package:mashinow_washer/features/profile/carwash_edit_page.dart';
import 'package:mashinow_washer/features/profile/owner_profile_page.dart';
import 'package:mashinow_washer/features/profile/ratings_page.dart';
import 'package:mashinow_washer/features/shell/main_shell.dart';
import 'package:mashinow_washer/features/splash/splash_page.dart';
import 'package:mashinow_washer/features/wallet/wallet_page.dart';
import 'package:mashinow_washer/features/working_hours/working_hours_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  // A simple counter notifier: bumped whenever auth state changes so
  // GoRouter re-evaluates its redirect.
  final refresh = ValueNotifier<int>(0);

  ref.listen(appAuthProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) =>
        _redirect(ref.read(appAuthProvider), state),
    routes: [
      // :: SPLASH
      GoRoute(
        path: '/',
        name: RouteNames.splashScreen,
        builder: (_, __) => const SplashScreenPage(),
      ),

      // :: LOGIN
      GoRoute(
        path: '/login',
        name: RouteNames.login,
        builder: (_, __) => const LoginPage(),
      ),

      // :: ONBOARDING (owner + carwash registration wizard)
      GoRoute(
        path: '/onboarding',
        name: RouteNames.onboarding,
        builder: (_, __) => const OnboardingPage(),
      ),

      // :: MAIN SHELL (dashboard / bookings / services / profile tabs)
      GoRoute(
        path: '/main',
        name: RouteNames.main,
        builder: (_, state) {
          final tab = state.uri.queryParameters['tab'];
          return MainShellPage(initialTab: tab);
        },
        routes: [
          GoRoute(
            path: 'guest-booking',
            name: RouteNames.guestBooking,
            builder: (_, __) => const GuestBookingPage(),
          ),
          GoRoute(
            path: 'working-hours',
            name: RouteNames.workingHours,
            builder: (_, __) => const WorkingHoursPage(),
          ),
          GoRoute(
            path: 'wallet',
            name: RouteNames.wallet,
            builder: (_, __) => const WalletPage(),
          ),
          GoRoute(
            path: 'ratings',
            name: RouteNames.ratings,
            builder: (_, __) => const RatingsPage(),
          ),
          GoRoute(
            path: 'owner-profile',
            name: RouteNames.ownerProfile,
            builder: (_, __) => const OwnerProfilePage(),
          ),
          GoRoute(
            path: 'carwash-edit',
            name: RouteNames.carwashEdit,
            builder: (_, __) => const CarWashEditPage(),
          ),
        ],
      ),
    ],
  );
});

String? _redirect(AppState auth, GoRouterState state) {
  final location = state.uri.path;
  final isLoggingIn = location == '/login';
  final isOnSplash = location == '/';

  switch (auth.status) {
    case AuthStatus.uninitialized:
      return isOnSplash ? null : '/';

    case AuthStatus.unauthenticated:
      if (isLoggingIn) return null;
      return '/login';

    case AuthStatus.authenticated:
      if (isLoggingIn) {
        return auth.profileCompleted ? '/main' : '/onboarding';
      }

      if (isOnSplash) {
        return auth.profileCompleted ? '/main' : '/onboarding';
      }

      // Not onboarded yet → force the wizard (except while on it).
      if (!auth.profileCompleted && location != '/onboarding') {
        return '/onboarding';
      }

      // Fully onboarded → never stay on onboarding/splash.
      if (auth.profileCompleted &&
          (location == '/onboarding' || isOnSplash)) {
        return '/main';
      }

      return null;
  }
}
