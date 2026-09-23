import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mashinow_washer/core/extensions/build_context.dart';
import 'package:mashinow_washer/core/presentation/widgets/sheets.dart';
import 'package:mashinow_washer/core/providers/app_auth.dart';
import 'package:mashinow_washer/core/providers/app_settings.dart';
import 'package:mashinow_washer/features/dashboard/dashboard_providers.dart';

/// Account tab: washer/carwash info cards, quick links, theme switch, logout.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final types = context.types;

    final appState = ref.watch(appAuthProvider);
    final ownerAsync = ref.watch(ownerProfileProvider);
    final carWashAsync = ref.watch(carWashProfileProvider);
    final themeMode = ref.watch(appSettingsProvider);

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 60, 16, 32),
        children: [
          // :: HEADER
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.storefront_rounded,
                    size: 42,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  carWashAsync.value?.name ?? 'کارواش شما',
                  style: types.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  appState.user?.phoneNumber ?? '',
                  style: types.bodySmall?.copyWith(color: colors.outline),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // :: RATING CARD
          if (carWashAsync.hasValue && carWashAsync.value != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  const Icon(Icons.star_rounded,
                      color: Color(0xfff59e0b), size: 26),
                  const SizedBox(width: 8),
                  Text(
                    (carWashAsync.value!.averageRating ?? 0)
                        .toStringAsFixed(1),
                    style: types.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => context.go('/main/ratings'),
                    child: const Text('مشاهده نظرات'),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // :: OWNER INFO
          ownerAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => const SizedBox.shrink(),
            data: (owner) => _InfoCard(
              icon: Icons.person_rounded,
              title: 'اطلاعات کارواش‌دار',
              subtitle: owner.fullName,
              onTap: () => context.go('/main/owner-profile'),
            ),
          ),
          const SizedBox(height: 10),

          // :: CARWASH INFO
          _InfoCard(
            icon: Icons.store_rounded,
            title: 'اطلاعات کارواش',
            subtitle: carWashAsync.value?.address ?? '—',
            onTap: () => context.go('/main/carwash-edit'),
          ),
          const SizedBox(height: 10),

          // :: WALLET
          _InfoCard(
            icon: Icons.account_balance_wallet_rounded,
            title: 'کیف پول',
            subtitle: 'موجودی و تراکنش‌ها',
            onTap: () => context.go('/main/wallet'),
          ),
          const SizedBox(height: 10),

          // :: WORKING HOURS
          _InfoCard(
            icon: Icons.schedule_rounded,
            title: 'ساعات کاری',
            subtitle: 'تعیین بازه‌های رزرو هفته',
            onTap: () => context.go('/main/working-hours'),
          ),
          const SizedBox(height: 10),

          // :: SERVICES
          _InfoCard(
            icon: Icons.design_services_rounded,
            title: 'سرویس‌ها و تعرفه‌ها',
            subtitle: 'مدیریت قیمت خدمات',
            onTap: () => context.go('/main?tab=services'),
          ),

          const SizedBox(height: 20),

          // :: THEME
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.dark_mode_rounded,
                        size: 22, color: colors.primary),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'حالت تاریک',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Switch(
                      value: themeMode == ThemeMode.dark ||
                          (themeMode == ThemeMode.system &&
                              context.isDarkMode),
                      onChanged: (enabled) {
                        ref.read(appSettingsProvider.notifier).setThemeMode(
                              enabled ? ThemeMode.dark : ThemeMode.light,
                            );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // :: LOGOUT
          OutlinedButton.icon(
            onPressed: () => _confirmLogout(context, ref),
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.error,
              side: BorderSide(color: colors.error.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.logout_rounded, size: 22),
            label: const Text(
              'خروج از حساب',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    final colors = context.colors;

    showAppSheet(
      context: context,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.logout_rounded,
                  size: 34, color: colors.error),
            ),
            const SizedBox(height: 16),
            const Text(
              'خروج از حساب کاربری؟',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
            const SizedBox(height: 8),
            Text(
              'برای ورود دوباره، کد تایید پیامکی دریافت می‌کنید.',
              textAlign: TextAlign.center,
              style: Theme.of(sheetContext)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: colors.outline),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('انصراف'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      Navigator.of(sheetContext).pop();
                      await ref.read(appAuthProvider.notifier).logout();
                      if (context.mounted) {
                        context.go('/login');
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.error,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('خروج'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final types = context.types;

    return Material(
      color: colors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 22, color: colors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style:
                          types.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: types.bodySmall?.copyWith(color: colors.outline),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_left_rounded, color: colors.outline),
            ],
          ),
        ),
      ),
    );
  }
}
