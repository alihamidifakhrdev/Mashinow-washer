import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mashinow_washer/core/extensions/build_context.dart';
import 'package:mashinow_washer/core/extensions/string.dart';
import 'package:mashinow_washer/core/formatters/formatters.dart';
import 'package:mashinow_washer/core/models/api_models.dart';
import 'package:mashinow_washer/core/presentation/widgets/view_state.dart';
import 'package:mashinow_washer/features/dashboard/dashboard_providers.dart';

/// Washer home: greeting header, today's stats, today's queue and quick
/// actions — designed to fit mostly above the fold with minimal scrolling.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final types = context.types;

    final profileAsync = ref.watch(carWashProfileProvider);
    final bookingsAsync = ref.watch(todayBookingsProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            ref.refresh(carWashProfileProvider.future),
            ref.refresh(todayBookingsProvider.future),
          ]);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // :: HEADER
            SliverAppBar(
              pinned: false,
              expandedHeight: 132,
              collapsedHeight: 132,
              automaticallyImplyLeading: false,
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(28),
                ),
              ),
              flexibleSpace: SafeArea(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'سلام 👋',
                              style: types.titleMedium?.copyWith(
                                color: colors.onPrimary.withValues(alpha: 0.85),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => context.go('/main/wallet'),
                            icon: const Icon(Icons.account_balance_wallet_rounded,
                                size: 26),
                          ),
                        ],
                      ),
                      profileAsync.when(
                        loading: () => Text(
                          'کارواش شما',
                          style: types.headlineSmall?.copyWith(
                            color: colors.onPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        error: (error, _) => Text(
                          'کارواش شما',
                          style: types.headlineSmall?.copyWith(
                            color: colors.onPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        data: (carWash) => Text(
                          carWash.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: types.headlineSmall?.copyWith(
                            color: colors.onPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // :: CONTENT
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // :: TODAY STATS
                  bookingsAsync.when(
                    loading: () => const _StatsCardPlaceholder(),
                    error: (error, _) => const SizedBox.shrink(),
                    data: (bookings) => _TodayStats(bookings: bookings),
                  ),

                  const SizedBox(height: 16),

                  // :: QUICK ACTIONS
                  _QuickActions(),

                  const SizedBox(height: 16),

                  // :: WEEKLY STATS
                  const _WeeklyStatsCard(),

                  const SizedBox(height: 20),

                  // :: TODAY QUEUE
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'نوبت‌های امروز',
                          style: types.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.go('/main?tab=bookings'),
                        child: const Text('همه رزروها'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  bookingsAsync.when(
                    loading: () => const PageLoading(),
                    error: (error, _) => ViewState<List<Booking>>(
                      loading: false,
                      error: error,
                      data: const [],
                      onRetry: () =>
                          ref.refresh(todayBookingsProvider.future),
                      builder: (_) => const SizedBox.shrink(),
                    ),
                    data: (bookings) {
                      final reserved =
                          bookings.where((b) => b.isReserved).toList();

                      if (reserved.isEmpty) {
                        return _EmptyQueue(
                          onAction: () => context.go('/main/guest-booking'),
                        );
                      }

                      return Column(
                        children: reserved
                            .map((booking) => _QueueCard(booking: booking))
                            .toList(),
                      );
                    },
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TODAY STATS
// ---------------------------------------------------------------------------

class _TodayStats extends StatelessWidget {
  final List<Booking> bookings;

  const _TodayStats({required this.bookings});

  @override
  Widget build(BuildContext context) {
    final reserved = bookings.where((b) => b.isReserved).length;
    final done = bookings.where((b) => b.isDone).length;
    final income = bookings
        .where((b) => b.isDone)
        .fold<int>(0, (sum, b) => sum + b.totalPrice);

    return Row(
      children: [
        Expanded(
          child: _StatTile(
            icon: Icons.event_available_rounded,
            label: 'در انتظار',
            value: reserved.toString().toPersianDigits(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            icon: Icons.task_alt_rounded,
            label: 'انجام‌شده',
            value: done.toString().toPersianDigits(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            icon: Icons.payments_rounded,
            label: 'درآمد امروز',
            value: Formatter.price(income),
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final types = context.types;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: colors.primary),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: types.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: types.bodySmall?.copyWith(color: colors.outline),
          ),
        ],
      ),
    );
  }
}

class _StatsCardPlaceholder extends StatelessWidget {
  const _StatsCardPlaceholder();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: 96,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Center(
        child: CircularProgressIndicator(color: colors.primary),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// WEEKLY STATS
// ---------------------------------------------------------------------------

class _WeeklyStatsCard extends ConsumerWidget {
  const _WeeklyStatsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final types = context.types;

    final statsAsync = ref.watch(weeklyStatsProvider);

    return statsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (error, _) => const SizedBox.shrink(),
      data: (stats) {
        if (stats.isEmpty) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.insights_rounded,
                      size: 18, color: colors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'عملکرد هفته',
                    style:
                        types.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 20,
                runSpacing: 8,
                children: stats
                    .map(
                      (stat) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            stat.displayValue,
                            style: types.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: colors.primary,
                            ),
                          ),
                          Text(
                            stat.label,
                            style:
                                types.bodySmall?.copyWith(color: colors.outline),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// QUICK ACTIONS
// ---------------------------------------------------------------------------

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final types = context.types;

    Widget action(String label, IconData icon, Color tint, VoidCallback onTap) {
      return Expanded(
        child: Material(
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: tint.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 24, color: tint),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: types.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        action(
          'رزرو حضوری',
          Icons.person_add_alt_rounded,
          const Color(0xff005afe),
          () => context.go('/main/guest-booking'),
        ),
        const SizedBox(width: 12),
        action(
          'ساعات کاری',
          Icons.schedule_rounded,
          const Color(0xff16a34a),
          () => context.go('/main/working-hours'),
        ),
        const SizedBox(width: 12),
        action(
          'تعرفه سرویس‌ها',
          Icons.design_services_rounded,
          const Color(0xffea580c),
          () => context.go('/main?tab=services'),
        ),
        const SizedBox(width: 12),
        action(
          'کیف پول',
          Icons.account_balance_wallet_rounded,
          const Color(0xff7c3aed),
          () => context.go('/main/wallet'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// QUEUE
// ---------------------------------------------------------------------------

class _EmptyQueue extends StatelessWidget {
  final VoidCallback onAction;

  const _EmptyQueue({required this.onAction});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final types = context.types;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(Icons.local_car_wash_rounded,
              size: 44, color: colors.outline),
          const SizedBox(height: 12),
          Text(
            'امروز نوبتی ندارید',
            style: types.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'برای مشتری حضوری، همین حالا یک رزرو ثبت کنید',
            style: types.bodySmall?.copyWith(color: colors.outline),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('ثبت رزرو حضوری'),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueCard extends StatelessWidget {
  final Booking booking;

  const _QueueCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final types = context.types;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          // :: TIME
          Container(
            width: 64,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Text(
                  Formatter.time(booking.startTime),
                  style: types.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // :: INFO
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.car.model,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: types.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  booking.services
                      .map((service) => service.serviceType.name)
                      .join(' + '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: types.bodySmall?.copyWith(color: colors.outline),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // :: PRICE
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Formatter.price(booking.totalPrice),
                style: types.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colors.primary,
                ),
              ),
              Text(
                'تومان',
                style: types.bodySmall?.copyWith(color: colors.outline),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
