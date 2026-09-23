import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/jalali.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import 'booking_card.dart';
import 'dashboard_page.dart';

enum _OrderFilter { all, today, week, reserved, done, cancelled }

/// نوبت‌ها — آنلاین و حضوری با فیلتر
class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  List<Booking> _bookings = <Booking>[];
  List<GuestBooking> _guests = <GuestBooking>[];

  bool _loading = true;
  String? _error;
  _OrderFilter _filter = _OrderFilter.all;

  @override
  void initState() {
    super.initState();
    // رفرش خودکار وقتی نوبتی از جای دیگری عوض شد (مثل «تکمیل شد» در جزئیات)
    DashboardRefresh.instance.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    DashboardRefresh.instance.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final List<dynamic> results = await Future.wait(<Future<dynamic>>[
        Api.get('/carwash/bookings/'),
        Api.get('/carwash/carwash/guest-bookings/'),
      ]);

      if (!mounted) return;

      setState(() {
        _bookings = (results[0] as List? ?? <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(Booking.fromJson)
            .toList();

        _guests = (results[1] as List? ?? <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(GuestBooking.fromJson)
            .toList();

        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  bool _isToday(DateTime? t) {
    if (t == null) return false;
    final DateTime now = DateTime.now();
    return t.year == now.year && t.month == now.month && t.day == now.day;
  }

  bool _isThisWeek(DateTime? t) {
    if (t == null) return false;

    final DateTime start = Jalali.startOfWeek(DateTime.now());
    final DateTime end = start.add(const Duration(days: 7));

    return !t.isBefore(start) && t.isBefore(end);
  }

  bool _matchFilter(String status, DateTime? time) {
    switch (_filter) {
      case _OrderFilter.all:
        return true;
      case _OrderFilter.today:
        return _isToday(time);
      case _OrderFilter.week:
        return _isThisWeek(time);
      case _OrderFilter.reserved:
        return status == 'reserved';
      case _OrderFilter.done:
        return status == 'done';
      case _OrderFilter.cancelled:
        return status == 'cancelled';
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Booking> bookings = _bookings
        .where((Booking b) => _matchFilter(b.status, b.displayTime))
        .toList();
    final List<GuestBooking> guests = _guests
        .where((GuestBooking g) => _matchFilter(g.status, g.displayTime))
        .toList();

    return Column(
      children: <Widget>[
        // :: هدر + فیلترها
        Container(
          color: AppColors.canvas,
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'نوبت‌ها',
                style: TextStyle(
                  fontFamily: 'IRANYekan',
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: <Widget>[
                    _filterChip(_OrderFilter.all, 'همه'),
                    const SizedBox(width: 8),
                    _filterChip(_OrderFilter.today, 'امروز'),
                    const SizedBox(width: 8),
                    _filterChip(_OrderFilter.week, 'این هفته'),
                    const SizedBox(width: 8),
                    _filterChip(_OrderFilter.reserved, 'رزرو شده'),
                    const SizedBox(width: 8),
                    _filterChip(_OrderFilter.done, 'انجام شده'),
                    const SizedBox(width: 8),
                    _filterChip(_OrderFilter.cancelled, 'لغو شده'),
                  ],
                ),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),

        // :: لیست
        Expanded(
          child: _loading
              ? Center(
                  child: CircularProgressIndicator(color: AppColors.accent))
              : _error != null
                  ? ListView(
                      children: <Widget>[
                        const SizedBox(height: 100),
                        EmptyState(
                          icon: Icons.wifi_off_rounded,
                          title: 'خطا در دریافت نوبت‌ها',
                          message: _error!,
                        ),
                      ],
                    )
                  : RefreshIndicator(
                      color: AppColors.accent,
                      onRefresh: _load,
                      child: bookings.isEmpty && guests.isEmpty
                          ? ListView(
                              children: <Widget>[
                                const SizedBox(height: 100),
                                EmptyState(
                                  icon: Icons.event_busy_rounded,
                                  title: 'نوبتی پیدا نشد',
                                  message:
                                      'برای فیلتر دیگری امتحان کنید یا با دکمه «مشتری حضوری» نوبت جدید ثبت کنید.',
                                ),
                              ],
                            )
                          : ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 160),
                              children: <Widget>[
                                for (final Booking b in bookings)
                                  BookingCard(
                                    booking: b,
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (BuildContext context) =>
                                            OrderDetailPage(booking: b),
                                      ),
                                    ),
                                  ),
                                for (final GuestBooking g in guests)
                                  GuestBookingCard(
                                    booking: g,
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (BuildContext context) =>
                                            OrderDetailPage(guest: g),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                    ),
        ),
      ],
    );
  }

  Widget _filterChip(_OrderFilter value, String label) {
    final bool selected = _filter == value;

    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.chipSurface,
          borderRadius: BorderRadius.circular(99),
          boxShadow: selected
              ? buttonShadow
              : <BoxShadow>[
                  BoxShadow(
                    color: const Color(0xFF101828).withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'IRANYekan',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.ink2,
          ),
        ),
      ),
    );
  }
}
