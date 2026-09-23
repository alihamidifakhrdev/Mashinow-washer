import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/jalali.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import 'booking_card.dart';

/// اعلان «دیتای داشبورد عوض شد» — بعد از ثبت مشتری حضوری (یا هر تغییر
/// نوبت) از هر جای اپ صدا زده می‌شود تا داشبورد خودش را رفرش کند.
class DashboardRefresh extends ChangeNotifier {
  DashboardRefresh._();

  static final DashboardRefresh instance = DashboardRefresh._();

  void bump() => notifyListeners();
}

/// داشبورد — نمای کلی امروز، آمار هفته، درآمد و آخرین نوبت‌ها
/// (همان محاسبات سایت) — نوبت‌های آنلاین و حضوری با هم نشان داده می‌شوند
class DashboardPage extends StatefulWidget {
  final VoidCallback onGoToOrders;

  const DashboardPage({super.key, required this.onGoToOrders});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with WidgetsBindingObserver {
  List<Booking> _bookings = <Booking>[];
  List<GuestBooking> _guests = <GuestBooking>[];
  CarwashProfile? _profile;

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // رفرش خودکار وقتی نوبت جدیدی از جای دیگری ثبت شد (مثل مشتری حضوری)
    DashboardRefresh.instance.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    DashboardRefresh.instance.removeListener(_load);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // برگشتن به اپ → داده‌ها تازه شوند
    if (state == AppLifecycleState.resumed) {
      _load();
    }
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
        Api.get('/carwash/profile'),
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

        _profile = results[2] is Map<String, dynamic>
            ? CarwashProfile.fromJson(
                results[2] as Map<String, dynamic>)
            : null;

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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: AppColors.accent));
    }

    if (_error != null) {
      return RefreshIndicator(
        color: AppColors.accent,
        onRefresh: _load,
        child: ListView(
          children: <Widget>[
            const SizedBox(height: 120),
            EmptyState(
              icon: Icons.wifi_off_rounded,
              title: 'خطا در دریافت اطلاعات',
              message: _error!,
            ),
          ],
        ),
      );
    }

    // کپی محلی برای type-promotion — فیلدهای غیر final در Dart قابل promotion نیستند
    final CarwashProfile? profile = _profile;

    final List<Booking> todayBookings = _bookings
        .where((Booking b) => _isToday(b.displayTime))
        .toList();
    final List<GuestBooking> todayGuests = _guests
        .where((GuestBooking g) => _isToday(g.displayTime))
        .toList();

    final List<Booking> weekBookings = _bookings
        .where((Booking b) => _isThisWeek(b.displayTime))
        .toList();

    int weekRevenue = 0;
    for (final Booking b in weekBookings) {
      weekRevenue += b.sumPrices;
    }

    int totalRevenue = 0;
    for (final Booking b in _bookings) {
      totalRevenue += b.sumPrices;
    }

    // محبوب‌ترین خدمت
    final Map<String, int> serviceCount = <String, int>{};
    for (final Booking b in _bookings) {
      for (final BookingService s in b.services) {
        if (s.name.isNotEmpty) {
          serviceCount[s.name] = (serviceCount[s.name] ?? 0) + 1;
        }
      }
    }

    String popularService = '—';
    int maxCount = 0;
    serviceCount.forEach((String name, int count) {
      if (count > maxCount) {
        maxCount = count;
        popularService = name;
      }
    });

    final int todayCount = todayBookings.length + todayGuests.length;

    // :: آخرین نوبت‌ها — نوبت‌های آنلاین + حضوری با هم؛
    // اول نزدیک‌ترین نوبت‌های پیش‌رو (نزدیک‌ترین اول)، بعد نوبت‌های گذشته
    // (تازه‌ترین اول) — حداکثر ۵ مورد
    final DateTime now = DateTime.now();

    final List<dynamic> all = <dynamic>[..._bookings, ..._guests];

    DateTime? timeOf(dynamic item) {
      if (item is Booking) return item.displayTime;
      if (item is GuestBooking) return item.displayTime;
      return null;
    }

    final List<dynamic> upcoming = all
        .where((dynamic x) {
          final DateTime? t = timeOf(x);
          return t != null && !t.isBefore(now);
        })
        .toList()
      ..sort((dynamic a, dynamic b) =>
          timeOf(a)!.compareTo(timeOf(b)!));

    final List<dynamic> past = all
        .where((dynamic x) {
          final DateTime? t = timeOf(x);
          return t == null || t.isBefore(now);
        })
        .toList()
      ..sort((dynamic a, dynamic b) =>
          timeOf(b)?.compareTo(timeOf(a) ?? now) ?? 0);

    final List<dynamic> latest =
        <dynamic>[...upcoming, ...past].take(5).toList();

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        // پدینگ پایین برای نوار ناوبری شناور + دکمه مشتری حضوری
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 160),
        children: <Widget>[
          // :: سربرگ خوش‌آمد
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'سلام${profile?.name.isNotEmpty == true ? '، ${profile!.name}' : ''}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'IRANYekan',
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      Jalali.fullDate(DateTime.now()),
                      style: TextStyle(
                        fontFamily: 'IRANYekan',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink2,
                      ),
                    ),
                  ],
                ),
              ),
              if (profile != null && profile.averageRating > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.successTint(),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.star_rounded,
                          color: AppColors.success, size: 17),
                      const SizedBox(width: 4),
                      Text(
                        profile.averageRating.toStringAsFixed(1),
                        style: TextStyle(
                          fontFamily: 'IRANYekan',
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),

          // :: کاشی‌های آمار — شطرنجی سبز و آبی برند
          Row(
            children: <Widget>[
              Expanded(
                child: StatTile(
                  title: 'نوبت‌های امروز',
                  value: todayCount.toString(),
                  icon: Icons.today_rounded,
                  color: AppColors.success,
                  tint: AppColors.successTint(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  title: 'نوبت‌های این هفته',
                  value: weekBookings.length.toString(),
                  icon: Icons.date_range_rounded,
                  color: AppColors.blue,
                  tint: AppColors.blueTint(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: StatTile(
                  title: 'درآمد این هفته',
                  value: toToman(weekRevenue),
                  icon: Icons.trending_up_rounded,
                  color: AppColors.blue,
                  tint: AppColors.blueTint(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  title: 'درآمد کل',
                  value: toToman(totalRevenue),
                  icon: Icons.account_balance_wallet_rounded,
                  color: AppColors.success,
                  tint: AppColors.successTint(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // :: خدمت محبوب
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.successTint(),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.local_fire_department_rounded,
                      color: AppColors.success, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'محبوب‌ترین خدمت',
                        style: TextStyle(
                          fontFamily: 'IRANYekan',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        popularService,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'IRANYekan',
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: widget.onGoToOrders,
                  child: Text(
                    'همه نوبت‌ها',
                    style: TextStyle(
                      fontFamily: 'IRANYekan',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // :: آخرین نوبت‌ها (آنلاین + حضوری)
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'آخرین نوبت‌ها',
                  style: TextStyle(
                    fontFamily: 'IRANYekan',
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
              TextButton(
                onPressed: widget.onGoToOrders,
                child: Text(
                  'مشاهده همه',
                  style: TextStyle(
                    fontFamily: 'IRANYekan',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ],
          ),
          if (latest.isEmpty)
            AppCard(
              child: EmptyState(
                icon: Icons.coffee_rounded,
                title: 'هنوز نوبتی ثبت نشده است',
                message:
                    'وقت آزاد است؛ با دکمه «مشتری حضوری» می‌توانید اولین مشتری را ثبت کنید.',
              ),
            )
          else
            for (final dynamic item in latest)
              if (item is Booking)
                BookingCard(
                  booking: item,
                  onTap: () => _openBooking(item),
                )
              else if (item is GuestBooking)
                GuestBookingCard(
                  booking: item,
                  onTap: () => _openGuest(item),
                ),
        ],
      ),
    );
  }

  void _openBooking(Booking b) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => OrderDetailPage(booking: b),
      ),
    );
  }

  void _openGuest(GuestBooking g) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => OrderDetailPage(guest: g),
      ),
    );
  }
}
