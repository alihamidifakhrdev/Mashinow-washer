import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/jalali.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import 'dashboard_page.dart';
import 'scanner_page.dart';

/// کارت نوبت آنلاین (مشتری اپ/سایت)
class BookingCard extends StatelessWidget {
  final Booking booking;
  final VoidCallback? onTap;

  const BookingCard({super.key, required this.booking, this.onTap});

  @override
  Widget build(BuildContext context) {
    final DateTime? time = booking.displayTime;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.accentTint(),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.directions_car_filled_rounded,
                    color: AppColors.accent, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      booking.carModel.isEmpty
                          ? booking.carType
                          : '${booking.carType} ${booking.carModel}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'IRANYekan',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      time != null
                          ? '${Jalali.fullDate(time)} • ساعت ${Jalali.clock(time)}'
                          : 'بدون زمان مشخص',
                      style: TextStyle(
                        fontFamily: 'IRANYekan',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink2,
                      ),
                    ),
                  ],
                ),
              ),
              StatusChip(status: booking.status),
            ],
          ),
          if (booking.services.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final BookingService s in booking.services)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.fill,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      s.name,
                      style: TextStyle(
                        fontFamily: 'IRANYekan',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink2,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Text(
                'کد پیگیری: ${booking.trackingCode}',
                style: TextStyle(
                  fontFamily: 'IRANYekan',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink3,
                ),
              ),
              const Spacer(),
              Text(
                booking.sumPrices > 0 ? tomanLabel(booking.sumPrices) : '—',
                style: TextStyle(
                  fontFamily: 'IRANYekan',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// کارت نوبت حضوری (مهمان)
class GuestBookingCard extends StatelessWidget {
  final GuestBooking booking;
  final VoidCallback? onTap;

  const GuestBookingCard({super.key, required this.booking, this.onTap});

  @override
  Widget build(BuildContext context) {
    final DateTime? time = booking.displayTime;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  // سبز — هویت «مشتری حضوری» (نوبت‌های آنلاین آبی‌اند)
                  color: AppColors.successTint(),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.person_rounded,
                    color: AppColors.success, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      booking.customerName,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'IRANYekan',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      time != null
                          ? '${Jalali.fullDate(time)} • ساعت ${Jalali.clock(time)}'
                          : 'بدون زمان مشخص',
                      style: TextStyle(
                        fontFamily: 'IRANYekan',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink2,
                      ),
                    ),
                  ],
                ),
              ),
              StatusChip(status: booking.status),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'خودرو: ${booking.carModel}',
            style: TextStyle(
              fontFamily: 'IRANYekan',
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.ink2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Text(
                'مشتری حضوری',
                style: TextStyle(
                  fontFamily: 'IRANYekan',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.success,
                ),
              ),
              const Spacer(),
              Text(
                booking.services.isNotEmpty
                    ? tomanLabel(booking.services
                        .fold<int>(0, (int sum, BookingService s) => sum + s.price))
                    : '—',
                style: TextStyle(
                  fontFamily: 'IRANYekan',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// دیتیل نوبت (آنلاین یا حضوری) — صفحات داخلی
///
/// نوبت‌های آنلاینِ «رزرو شده» دکمه‌ی «تکمیل شد» دارند که فقط از «ساعت
/// شروعِ» نوبت فعال می‌شود — تا نوبتِ آینده از قبل تکمیل ثبت نشود و
/// کارواش‌دار نتواند الکی وضعیت عوض کند. بعد از تأییدِ دیالوگ، وضعیت
/// روی سرور به «انجام شده» تغییر می‌کند و قابل بازگشت نیست.
/// نوبت‌های حضوری در بک‌اند فیلد وضعیت ندارند → دکمه هم ندارند.
class OrderDetailPage extends StatefulWidget {
  final Booking? booking;
  final GuestBooking? guest;

  const OrderDetailPage({super.key, this.booking, this.guest});

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  late String _status;
  bool _marking = false;

  @override
  void initState() {
    super.initState();
    _status = widget.booking?.status ?? widget.guest?.status ?? 'reserved';
  }

  String get _title =>
      widget.booking != null ? 'جزئیات نوبت' : 'جزئیات نوبت حضوری';

  /// ساعت شروع مؤثر نوبت — مبنای قفل زمانی دکمه‌ی تکمیل
  DateTime? get _startTime =>
      widget.booking?.startTime ?? widget.booking?.displayTime;

  /// فقط نوبت آنلاینِ در وضعیت «رزرو شده» — حضوری در بک‌اند وضعیت ندارد
  bool get _showDoneButton =>
      widget.booking != null && _status == 'reserved';

  /// دکمه از «شروع نوبت» فعال می‌شود؛ اگر زمان نوبت نامعلوم بود
  /// محدودی نمی‌گذاریم (داده‌ی واقعی سرور همیشه start_time دارد)
  bool get _doneAllowed {
    final DateTime? start = _startTime;
    if (start == null) return true;
    return !start.isAfter(DateTime.now());
  }

  Future<void> _markDone() async {
    final Booking? b = widget.booking;
    if (b == null || _marking || !_doneAllowed) return;

    final DateTime? start = _startTime;
    final String code = b.trackingCode;

    // خلاصه‌ی هویت نوبت داخل دیالوگ — تا اشتباهی نوبت دیگری تأیید نشود
    final String summary = <String>[
      if (code.isNotEmpty) 'کد $code',
      if (start != null)
        '${Jalali.fullDate(start)} — ساعت ${Jalali.clock(start)}',
    ].join(' • ');

    final bool ok = await showIOSConfirm(
      context: context,
      title: 'تکمیل نوبت',
      message: (summary.isEmpty ? '' : '$summary\n\n') +
          'وضعیت این نوبت به «انجام شده» تغییر می‌کند؛ این عمل در سوابق '
          'ثبت می‌شود و قابل بازگشت نیست.',
      confirmText: 'تکمیل شد',
    );

    if (!ok || !mounted) return;

    setState(() => _marking = true);

    try {
      // PUT /api/carwash/carwash/bookings/{id}/status/ — دقت: «carwash» دوبار
      // می‌آید؛ اندپوینت در carwash/urls.py زیر پیشوند 'carwash/' و کل آن هم
      // زیر '/api/carwash/' سوار است (همان الگوی guest-booking/services).
      // سریالایزر فقط done/cancelled می‌پذیرد و اجازه‌ی تغییر نوبتِ کارواشِ
      // دیگر را نمی‌دهد.
      //
      // چرا PUT و نه PATCH؟ برخی هاست‌ها/لایه‌های امنیتی متد PATCH را برای
      // مسیرهای ناشناخته با ۴۰۵ رد می‌کنند. این اندپوینت DRF از نوع
      // UpdateAPIView است و PUT را هم کاملاً می‌پذیرد؛ سریالایزرش فقط فیلد
      // status دارد، پس «به‌روزرسانی کامل» هم با همین بدنه‌ی یک‌فیلدی معتبر
      // است. اگر سروری ۴۰۵ گفت (PUT را نپذیرفت)، همان یک‌بار با PATCH
      // امتحان می‌شود — خطای PATCH در آن حالت به بیرون می‌رود تا دیده شود.
      try {
        await Api.put(
          '/carwash/carwash/bookings/${b.id}/status/',
          data: <String, dynamic>{'status': 'done'},
        );
      } on ApiException catch (e) {
        if (e.statusCode != 405) rethrow;

        await Api.patch(
          '/carwash/carwash/bookings/${b.id}/status/',
          data: <String, dynamic>{'status': 'done'},
        );
      }

      if (!mounted) return;

      setState(() {
        _marking = false;
        _status = 'done';
      });

      showToast(context, 'نوبت «انجام شده» ثبت شد');
      // داشبورد و لیست نوبت‌ها خودشان تازه شوند
      DashboardRefresh.instance.bump();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _marking = false);
      showToast(context, e.message, error: true);
    }
  }

  Widget? _buildBottomBar() {
    if (!_showDoneButton) return null;

    // قفل زمانی — نوبت هنوز شروع نشده
    if (!_doneAllowed) {
      final DateTime start = _startTime!;

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const AppButton(
                text: 'تکمیل شد',
                icon: Icons.check_circle_rounded,
                type: AppButtonType.success,
                onPressed: null,
              ),
              const SizedBox(height: 8),
              Text(
                'از ${Jalali.fullDate(start)} — ساعت ${Jalali.clock(start)} فعال می‌شود',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'IRANYekan',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink3,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
        child: AppButton(
          text: 'تکمیل شد',
          icon: Icons.check_circle_rounded,
          type: AppButtonType.success,
          loading: _marking,
          onPressed: _marking ? null : _markDone,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget? bottomBar = _buildBottomBar();

    final List<BookingService> services =
        widget.booking?.services ?? widget.guest?.services ?? <BookingService>[];
    final DateTime? time =
        widget.booking?.displayTime ?? widget.guest?.displayTime;
    final String phone = widget.guest?.customerPhone ?? '';
    final String name =
        widget.guest?.customerName ?? widget.booking?.carModel ?? '';

    // کد نوبت — فقط نوبت‌های آنلاین از بک‌اند کد پیگیری دارند؛
    // حضوری‌ها کد ندارند و چیزی نشان داده نمی‌شود.
    final String? code =
        (widget.booking?.trackingCode ?? '').isNotEmpty
            ? widget.booking!.trackingCode
            : null;

    final int total = services.fold<int>(
      0,
      (int sum, BookingService s) => sum + s.price,
    );

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Text(_title),
        // در RTL، actions سمت «چپِ» هدر می‌نشیند — دکمه اسکن کد رزرو مشتری
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Tooltip(
              message: 'اسکن کد رزرو',
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (BuildContext c) => const ScannerPage(),
                    ),
                  );
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.blueTint(),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    Icons.qr_code_scanner_rounded,
                    color: AppColors.blue,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppCard(
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          widget.booking != null
                              ? '${widget.booking!.carType} ${widget.booking!.carModel}'
                              : name,
                          style: TextStyle(
                            fontFamily: 'IRANYekan',
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      StatusChip(status: _status),
                    ],
                  ),
                  if (widget.guest != null) ...<Widget>[
                    const SizedBox(height: 14),
                    _InfoRow(icon: Icons.person_rounded, text: name),
                    const SizedBox(height: 8),
                    _InfoRow(
                      icon: Icons.phone_rounded,
                      text: phone,
                      ltr: true,
                      onTap: phone.length >= 10
                          ? () => _call(context, phone)
                          : null,
                    ),
                  ],
                  if (widget.booking != null) ...<Widget>[
                    const SizedBox(height: 14),
                    _InfoRow(
                      icon: Icons.local_car_wash_rounded,
                      text: widget.booking!.serviceType,
                    ),
                  ],
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.event_rounded,
                    text: time != null
                        ? '${Jalali.fullDate(time)} — ساعت ${Jalali.clock(time)}'
                        : 'بدون زمان مشخص',
                  ),

                  // :: کد نوبت — متنِ خوانا (بدون بارکد) برای مقایسه‌ی چشمی با کد مشتری
                  if (code != null) ...<Widget>[
                    const SizedBox(height: 14),
                    _BookingCodeBlock(code: code),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'خدمات',
                    style: TextStyle(
                      fontFamily: 'IRANYekan',
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (services.isEmpty)
                    Text(
                      'خدمتی برای این نوبت ثبت نشده است',
                      style: TextStyle(
                        fontFamily: 'IRANYekan',
                        fontSize: 13,
                        color: AppColors.ink3,
                      ),
                    )
                  else
                    for (final BookingService s in services)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              s.name,
                              style: TextStyle(
                                fontFamily: 'IRANYekan',
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink2,
                              ),
                            ),
                          ),
                          Text(
                            tomanLabel(s.price),
                            style: TextStyle(
                              fontFamily: 'IRANYekan',
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Divider(height: 24),
                  Row(
                    children: <Widget>[
                      Text(
                        'مبلغ کل',
                        style: TextStyle(
                          fontFamily: 'IRANYekan',
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        total > 0 ? tomanLabel(total) : '—',
                        style: TextStyle(
                          fontFamily: 'IRANYekan',
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.accentDeep,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (widget.booking != null)
              AppCard(
                child: Column(
                  children: <Widget>[
                    _InfoRow(
                      icon: Icons.account_balance_wallet_rounded,
                      text:
                          'پرداخت: ${paymentMethodLabel(widget.booking!.paymentMethod)}',
                    ),
                  ],
                ),
              ),

            // زیر آخرین کارت کمی فضا — دکمه‌ی پایین صفحه روی محتوا نیفتد
            if (bottomBar != null) const SizedBox(height: 8),
          ],
        ),
      ),
      bottomNavigationBar: bottomBar,
    );
  }

  Future<void> _call(BuildContext context, String phone) async {
    // شماره را به فرمت بین‌المللی می‌بریم
    final String tel = phone.startsWith('0')
        ? '+98${phone.substring(1)}'
        : phone;

    try {
      final Uri uri = Uri(scheme: 'tel', path: tel);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('امکان تماس با $tel نیست')),
          );
        }
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('امکان تماس با $tel نیست')),
        );
      }
    }
  }
}

/// کد نوبت — فقط متن خوانا (بدون بارکد)؛ با لمس، کد کپی می‌شود تا
/// کارواش‌دار بتواند با کدی که مشتری نشان می‌دهد مقایسه‌ی چشمی کند.
class _BookingCodeBlock extends StatelessWidget {
  final String code;

  const _BookingCodeBlock({required this.code});

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: code));

    if (context.mounted) {
      showToast(context, 'کد نوبت کپی شد');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _copy(context),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.blueTint(),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.blue.withOpacity(0.18)),
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.pin_rounded, size: 20, color: AppColors.blue),
            const SizedBox(width: 10),
            Text(
              'کد نوبت',
              style: TextStyle(
                fontFamily: 'IRANYekan',
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.ink2,
              ),
            ),
            const Spacer(),
            Text(
              code,
              textDirection: TextDirection.ltr,
              style: TextStyle(
                fontFamily: 'IRANYekan',
                fontSize: 15.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.copy_rounded, size: 17, color: AppColors.blue),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool ltr;
  final VoidCallback? onTap;

  const _InfoRow({
    required this.icon,
    required this.text,
    this.ltr = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: onTap != null ? HitTestBehavior.opaque : HitTestBehavior.deferToChild,
      child: Row(
        children: <Widget>[
          Icon(icon, size: 19, color: AppColors.ink3),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              textDirection: ltr ? TextDirection.ltr : TextDirection.rtl,
              textAlign: ltr ? TextAlign.left : TextAlign.right,
              style: TextStyle(
                fontFamily: 'IRANYekan',
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppColors.ink2,
              ),
            ),
          ),
          if (onTap != null)
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.accentTint(),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Icon(Icons.phone_rounded,
                  color: AppColors.accent, size: 17),
            ),
        ],
      ),
    );
  }
}
