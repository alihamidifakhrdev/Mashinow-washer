import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mashinow_washer/core/extensions/build_context.dart';
import 'package:mashinow_washer/core/extensions/string.dart';
import 'package:mashinow_washer/core/formatters/formatters.dart';
import 'package:mashinow_washer/core/models/api_models.dart';
import 'package:mashinow_washer/core/network/server_error.dart';
import 'package:mashinow_washer/core/presentation/widgets/toast.dart';
import 'package:mashinow_washer/core/presentation/widgets/view_state.dart';
import 'package:mashinow_washer/features/dashboard/dashboard_providers.dart';
import 'package:mashinow_washer/features/washer_repository.dart';
import 'package:url_launcher/url_launcher.dart';

enum _BookingsTab { today, upcoming, history }

/// Bookings management: today's queue, upcoming reservations and history,
/// plus walk-in (guest) bookings — with quick status actions on each card.
class BookingsPage extends ConsumerStatefulWidget {
  const BookingsPage({super.key});

  @override
  ConsumerState<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends ConsumerState<BookingsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await Future.wait([
      ref.refresh(todayBookingsProvider.future),
      ref.refresh(allBookingsProvider.future),
      ref.refresh(guestBookingsProvider.future),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final types = context.types;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'رزروها',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: colors.primary,
          labelColor: colors.primary,
          unselectedLabelColor: colors.outline,
          labelStyle:
              types.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          tabs: const [
            Tab(text: 'امروز'),
            Tab(text: 'آینده'),
            Tab(text: 'تاریخچه'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: TabBarView(
          controller: _tabController,
          children: [
            _BookingsList(tab: _BookingsTab.today, onRefresh: _refresh),
            _BookingsList(tab: _BookingsTab.upcoming, onRefresh: _refresh),
            _GuestBookingsList(onRefresh: _refresh),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ONLINE BOOKINGS LIST
// ---------------------------------------------------------------------------

class _BookingsList extends ConsumerWidget {
  final _BookingsTab tab;
  final Future<void> Function() onRefresh;

  const _BookingsList({required this.tab, required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayAsync = ref.watch(todayBookingsProvider);
    final allAsync = ref.watch(allBookingsProvider);

    return todayAsync.when(
      loading: () => const PageLoading(),
      error: (error, _) => ViewState<List<Booking>>(
        loading: false,
        error: error,
        data: const [],
        onRetry: onRefresh,
        builder: (_) => const SizedBox.shrink(),
      ),
      data: (todayBookings) {
        return allAsync.when(
          loading: () => const PageLoading(),
          error: (error, _) => ViewState<List<Booking>>(
            loading: false,
            error: error,
            data: const [],
            onRetry: onRefresh,
            builder: (_) => const SizedBox.shrink(),
          ),
          data: (allBookings) {
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);

            List<Booking> bookings;
            switch (tab) {
              case _BookingsTab.today:
                bookings = todayBookings;
                break;
              case _BookingsTab.upcoming:
                bookings = allBookings
                    .where((b) =>
                        b.isReserved &&
                        DateTime(b.startTime.year, b.startTime.month,
                                b.startTime.day)
                            .isAfter(today))
                    .toList()
                  ..sort((a, b) => a.startTime.compareTo(b.startTime));
                break;
              case _BookingsTab.history:
                bookings = allBookings
                    .where((b) => !b.isReserved)
                    .toList()
                  ..sort((a, b) => b.startTime.compareTo(a.startTime));
                break;
            }

            if (bookings.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 80),
                  _EmptyHint(
                    icon: Icons.event_busy_rounded,
                    title: 'رزروهایی نیست',
                    message: 'به محض ثبت رزرو جدید، اینجا نمایش داده می‌شود.',
                  ),
                ],
              );
            }

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: bookings.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: BookingCard(
                  booking: bookings[index],
                  onChanged: onRefresh,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyHint({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final types = context.types;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHigh,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 40, color: colors.outline),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          style: types.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: types.bodySmall?.copyWith(color: colors.outline),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// BOOKING CARD
// ---------------------------------------------------------------------------

class BookingCard extends ConsumerWidget {
  final Booking booking;
  final Future<void> Function() onChanged;

  const BookingCard({
    super.key,
    required this.booking,
    required this.onChanged,
  });

  Future<void> _updateStatus(
    BuildContext context,
    WidgetRef ref,
    String status,
  ) async {
    final repository = ref.read(washerRepositoryProvider);

    try {
      await repository.updateBookingStatus(
        bookingId: booking.id,
        status: status,
      );

      if (context.mounted) {
        Toast.success(
          context,
          title: status == 'done' ? 'رزرو انجام شد' : 'رزرو لغو شد',
        );
      }

      await onChanged();
    } catch (error) {
      if (context.mounted) {
        Toast.error(
          context,
          title: 'خطا در تغییر وضعیت',
          description:
              error is ServerError ? error.message : error.toString(),
        );
      }
    }
  }

  Future<void> _callCustomer(BuildContext context) async {
    // The booking payload does not expose the customer phone number,
    // so show the tracking code instead for now.
    if (context.mounted) {
      Toast.info(
        context,
        title: 'کد پیگیری: ${booking.trackingCode ?? '—'}',
        description: 'شماره تماس مشتری در این نسخه نمایش داده نمی‌شود.',
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final types = context.types;

    final statusColor = booking.isDone
        ? const Color(0xff16a34a)
        : booking.isCancelled
            ? colors.error
            : const Color(0xff005afe);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // :: HEADER ROW
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  Formatter.bookingStatus(booking.status),
                  style: types.bodySmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                Formatter.jalaliDate(booking.startTime),
                style: types.bodySmall?.copyWith(color: colors.outline),
              ),
              const SizedBox(width: 6),
              Text(
                Formatter.time(booking.startTime),
                style: types.bodySmall?.copyWith(color: colors.outline),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // :: CAR + TRACKING
          Row(
            children: [
              Icon(Icons.directions_car_rounded,
                  size: 22, color: colors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${booking.car.model} (${booking.car.type})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: types.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (booking.trackingCode != null) ...[
                const SizedBox(width: 8),
                Text(
                  'کد: ${booking.trackingCode!}',
                  style: types.bodySmall?.copyWith(
                    color: colors.outline,
                    fontFamily: 'Vazirmatn',
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 10),

          // :: SERVICES
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: booking.services
                .map(
                  (service) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${service.serviceType.name} — ${Formatter.price(service.price)}',
                      style: types.bodySmall,
                    ),
                  ),
                )
                .toList(),
          ),

          const SizedBox(height: 12),

          // :: PAYMENT + TOTAL
          Row(
            children: [
              Icon(
                booking.paymentMethod == 'wallet'
                    ? Icons.account_balance_wallet_rounded
                    : Icons.payments_rounded,
                size: 18,
                color: colors.outline,
              ),
              const SizedBox(width: 6),
              Text(
                Formatter.paymentMethod(booking.paymentMethod),
                style: types.bodySmall?.copyWith(color: colors.outline),
              ),
              const Spacer(),
              Text(
                '${Formatter.price(booking.totalPrice)} تومان',
                style: types.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colors.primary,
                ),
              ),
            ],
          ),

          // :: ACTIONS
          if (booking.isReserved) ...[
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _updateStatus(context, ref, 'done'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xff16a34a),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 20),
                    label: const Text('انجام شد'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _updateStatus(context, ref, 'cancelled'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.error,
                      side: BorderSide(color: colors.error.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    label: const Text('لغو'),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.outlined(
                  onPressed: () => _callCustomer(context),
                  icon: const Icon(Icons.phone_rounded, size: 20),
                  style: IconButton.styleFrom(
                    foregroundColor: colors.primary,
                    side: BorderSide(color: colors.primary.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// GUEST BOOKINGS LIST (history tab)
// ---------------------------------------------------------------------------

class _GuestBookingsList extends ConsumerWidget {
  final Future<void> Function() onRefresh;

  const _GuestBookingsList({required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guestAsync = ref.watch(guestBookingsProvider);

    return guestAsync.when(
      loading: () => const PageLoading(),
      error: (error, _) => ViewState<List<GuestBooking>>(
        loading: false,
        error: error,
        data: const [],
        onRetry: onRefresh,
        builder: (_) => const SizedBox.shrink(),
      ),
      data: (bookings) {
        if (bookings.isEmpty) {
          return ListView(
            children: const [
              SizedBox(height: 80),
              _EmptyHint(
                icon: Icons.person_off_rounded,
                title: 'رزرو حضوری ثبت نشده',
                message:
                    'مشتری‌هایی که بدون اپ ثبت می‌کنید، در تاریخچه می‌آیند.',
              ),
            ],
          );
        }

        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: bookings.length,
          itemBuilder: (context, index) {
            final booking = bookings[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _GuestBookingCard(booking: booking),
            );
          },
        );
      },
    );
  }
}

class _GuestBookingCard extends StatelessWidget {
  final GuestBooking booking;

  const _GuestBookingCard({required this.booking});

  Future<void> _call(BuildContext context) async {
    final phone = booking.customerPhone.toEnglishDigits();
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final types = context.types;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xff7c3aed).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'حضوری',
                  style: types.bodySmall?.copyWith(
                    color: const Color(0xff7c3aed),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${Formatter.jalaliDate(booking.timeSlot.startTime)} — ${Formatter.time(booking.timeSlot.startTime)}',
                style: types.bodySmall?.copyWith(color: colors.outline),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.person_rounded, size: 20, color: colors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  booking.customerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      types.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: () => _call(context),
                icon: const Icon(Icons.phone_rounded, size: 20),
                color: colors.primary,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.directions_car_rounded,
                  size: 18, color: colors.outline),
              const SizedBox(width: 8),
              Text(
                booking.carModel,
                style: types.bodySmall?.copyWith(color: colors.outline),
              ),
              const Spacer(),
              Text(
                '${Formatter.price(booking.totalPrice)} تومان',
                style: types.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colors.primary,
                ),
              ),
            ],
          ),
          if (booking.services.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: booking.services
                  .map(
                    (service) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        service.serviceType.name,
                        style: types.bodySmall,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}
