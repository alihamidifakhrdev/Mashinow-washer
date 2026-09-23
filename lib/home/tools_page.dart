import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import 'booking_card.dart';

/// تب «ابزارها» — جعبه‌ابزار روزمره‌ی کارواش‌دار، بدون مزاحمت:
///  ۱) ماشین‌حساب تعرفه (جمع زنده‌ی قیمت خدمات واقعی)
///  ۲) جستجوی سریع نوبت با کد پیگیری
///  ۳) معرفی کارواش (اشتراک واتساپ/پیامک)
class ToolsPage extends StatefulWidget {
  ToolsPage({super.key});

  @override
  State<ToolsPage> createState() => _ToolsPageState();
}

class _ToolsPageState extends State<ToolsPage> {
  // ماشین‌حساب تعرفه
  List<CarwashService> _services = <CarwashService>[];
  final Set<int> _selected = <int>{};
  bool _servicesLoading = true;
  String? _servicesError;

  // جستجوی نوبت
  final TextEditingController _codeController = TextEditingController();
  bool _searching = false;

  // پروفایل (برای متن‌ها و معرفی)
  CarwashProfile? _profile;

  @override
  void initState() {
    super.initState();
    _loadServices();
    _loadProfile();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadServices() async {
    setState(() {
      _servicesLoading = true;
      _servicesError = null;
    });

    try {
      final dynamic data = await Api.get('/carwash/carwash/services/');

      if (!mounted) return;

      setState(() {
        _services = (data as List? ?? <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(CarwashService.fromJson)
            .toList();
        _servicesLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _servicesLoading = false;
        _servicesError = e.message;
      });
    }
  }

  Future<void> _loadProfile() async {
    try {
      final dynamic data = await Api.get('/carwash/profile');

      if (!mounted) return;

      if (data is Map<String, dynamic>) {
        setState(() => _profile = CarwashProfile.fromJson(data));
      }
    } on ApiException catch (_) {
      // بی‌صدا — این بخش حیاتی نیست
    }
  }

  // ── ماشین‌حساب تعرفه ──

  int get _totalPrice {
    int sum = 0;
    for (final CarwashService s in _services) {
      if (_selected.contains(s.id)) {
        sum += s.price;
      }
    }
    return sum;
  }

  Future<void> _copyInvoice() async {
    if (_selected.isEmpty) {
      showToast(context, 'اول چند خدمت را انتخاب کنید', error: true);
      return;
    }

    final StringBuffer buf = StringBuffer('صورت‌حساب کارواش');
    if (_profile?.name.isNotEmpty == true) {
      buf.write(' ${_profile!.name}');
    }
    buf.write(':\n');

    for (final CarwashService s in _services) {
      if (_selected.contains(s.id)) {
        buf.write('• ${s.serviceTypeName}');
        if (s.vehicleTypeName.isNotEmpty) {
          buf.write(' (${s.vehicleTypeName})');
        }
        buf.write(': ${tomanLabel(s.price)}\n');
      }
    }

    buf.write('جمع کل: ${tomanLabel(_totalPrice)}');

    await Clipboard.setData(ClipboardData(text: buf.toString()));

    if (!mounted) return;
    showToast(context, 'صورت‌حساب کپی شد');
  }

  // ── جستجوی نوبت ──

  Future<void> _searchBooking() async {
    final String code =
        normalizeDigits(_codeController.text).trim().toUpperCase();

    if (code.isEmpty) {
      showToast(context, 'کد پیگیری را وارد کنید', error: true);
      return;
    }

    setState(() => _searching = true);

    try {
      final List<dynamic> results = await Future.wait(<Future<dynamic>>[
        Api.get('/carwash/bookings/'),
        Api.get('/carwash/carwash/guest-bookings/'),
      ]);

      if (!mounted) return;

      final List<Booking> bookings = (results[0] as List? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(Booking.fromJson)
          .toList();

      final List<GuestBooking> guests =
          (results[1] as List? ?? <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(GuestBooking.fromJson)
              .toList();

      for (final Booking b in bookings) {
        if (normalizeDigits(b.trackingCode).trim().toUpperCase() == code) {
          setState(() => _searching = false);
          _openDetail(booking: b);
          return;
        }
      }

      for (final GuestBooking g in guests) {
        if (normalizeDigits(g.trackingCode).trim().toUpperCase() == code) {
          setState(() => _searching = false);
          _openDetail(guest: g);
          return;
        }
      }

      setState(() => _searching = false);
      showToast(context, 'نوبتی با این کد پیگیری پیدا نشد', error: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _searching = false);
      showToast(context, e.message, error: true);
    }
  }

  void _openDetail({Booking? booking, GuestBooking? guest}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            OrderDetailPage(booking: booking, guest: guest),
      ),
    );
  }

  Future<void> _copyText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));

    if (!mounted) return;
    showToast(context, 'متن کپی شد');
  }

  // ── معرفی کارواش ──

  String get _shareText {
    final String name = _profile?.name ?? 'کارواش ما';
    final String address = _profile?.address ?? '';
    final String phone = _profile?.phoneNumber ?? '';

    return 'سلام! $name در خدمت شماست.'
        '${address.isNotEmpty ? '\n📍 $address' : ''}'
        '${phone.isNotEmpty ? '\n☎ $phone' : ''}'
        '\nبرای رزرو نوبت، اپ ماشینو را نصب کنید. 🚗';
  }

  Future<void> _shareWhatsApp() async {
    final Uri uri = Uri.parse(
      'https://wa.me/?text=${Uri.encodeComponent(_shareText)}',
    );

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      showToast(context, 'واتساپ باز نشد', error: true);
    }
  }

  Future<void> _shareSms() async {
    final Uri uri = Uri.parse(
      'sms:?body=${Uri.encodeComponent(_shareText)}',
    );

    try {
      await launchUrl(uri);
    } catch (_) {
      if (!mounted) return;
      showToast(context, 'پیامک باز نشد', error: true);
    }
  }

  // ── UI ──

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 150),
      children: <Widget>[
        Text(
          'ابزارها',
          style: TextStyle(
            fontFamily: 'IRANYekan',
            fontSize: 21,
            fontWeight: FontWeight.w900,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'ابزارهای کوچک و پرکاربردِ هر روز کارواش',
          style: TextStyle(
            fontFamily: 'IRANYekan',
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.ink3,
          ),
        ),
        const SizedBox(height: 18),

        // :: ۱) ماشین‌حساب تعرفه
        _ToolSection(
          icon: Icons.calculate_rounded,
          color: AppColors.blue,
          tint: AppColors.blueTint(),
          title: 'ماشین‌حساب تعرفه',
          subtitle: 'قیمت خدمات را برای مشتری سریع جمع بزنید',
          child: _buildCalculator(),
        ),

        // :: ۲) جستجوی نوبت — لهجه سبز برای تنوع کنار آبی
        _ToolSection(
          icon: Icons.manage_search_rounded,
          color: AppColors.success,
          tint: AppColors.successTint(),
          title: 'جستجوی نوبت با کد',
          subtitle: 'کد پیگیری را وارد کنید و نوبت را باز کنید',
          child: _buildSearch(),
        ),

        // :: ۳) معرفی کارواش
        _ToolSection(
          icon: Icons.share_rounded,
          color: AppColors.blue,
          tint: AppColors.blueTint(),
          title: 'معرفی کارواش',
          subtitle: 'برای مشتری‌ها واتساپ یا پیامک بفرستید',
          child: _buildShare(),
        ),
      ],
    );
  }

  Widget _buildCalculator() {
    if (_servicesLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2.6),
          ),
        ),
      );
    }

    if (_servicesError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: <Widget>[
            Text(
              _servicesError!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'IRANYekan',
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: AppColors.ink3,
                height: 1.8,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _loadServices,
              icon: Icon(Icons.refresh_rounded,
                  size: 17, color: AppColors.blue),
              label: Text(
                'تلاش مجدد',
                style: TextStyle(
                  fontFamily: 'IRANYekan',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.blue,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_services.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'هنوز خدمتی ثبت نشده است؛ از «تنظیمات ← خدمات و تعرفه‌ها» اضافه کنید.',
          style: TextStyle(
            fontFamily: 'IRANYekan',
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: AppColors.ink3,
            height: 1.9,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final CarwashService s in _services)
          _CalculatorRow(
            service: s,
            selected: _selected.contains(s.id),
            onTap: () => setState(() {
              if (_selected.contains(s.id)) {
                _selected.remove(s.id);
              } else {
                _selected.add(s.id);
              }
            }),
          ),
        const SizedBox(height: 12),

        // جمع زنده + دکمه کپی
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.blueTint(0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: <Widget>[
              Icon(Icons.receipt_rounded,
                  size: 18, color: AppColors.blue),
              const SizedBox(width: 8),
              Text(
                '${_selected.length} خدمت',
                style: TextStyle(
                  fontFamily: 'IRANYekan',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink2,
                ),
              ),
              const Spacer(),
              Text(
                _selected.isEmpty ? '—' : tomanLabel(_totalPrice),
                style: TextStyle(
                  fontFamily: 'IRANYekan',
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: AppColors.blue,
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _copyInvoice,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.blue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const <Widget>[
                      Icon(Icons.copy_rounded,
                          color: Colors.white, size: 15),
                      SizedBox(width: 6),
                      Text(
                        'کپی',
                        style: TextStyle(
                          fontFamily: 'IRANYekan',
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.visiblePassword,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
          inputFormatters: <TextInputFormatter>[
            // کد پیگیری حروف + رقم است (مثلاً MS140312)
            SmartCodeInputFormatter(maxLength: 24),
          ],
          style: TextStyle(
            fontFamily: 'IRANYekan',
            fontSize: 15.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: AppColors.ink,
          ),
          decoration: InputDecoration(
            hintText: 'مثلاً MS140312',
            hintStyle: TextStyle(
              fontFamily: 'IRANYekan',
              fontSize: 13,
              color: AppColors.ink3,
            ),
            filled: true,
            fillColor: AppColors.fill,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: const BorderSide(color: Colors.transparent),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(color: AppColors.success, width: 1.6),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 46,
          child: ElevatedButton.icon(
            onPressed: _searching ? null : _searchBooking,
            icon: _searching
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : const Icon(Icons.search_rounded, size: 20),
            label: const Text('جستجو'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.successTint(0.5),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              textStyle: const TextStyle(
                fontFamily: 'IRANYekan',
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShare() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.fill,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.blueTint(),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.local_car_wash_rounded,
                    size: 21, color: AppColors.blue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _profile?.name ?? 'کارواش شما',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'IRANYekan',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _copyText(_shareText),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.copy_rounded,
                      size: 16, color: AppColors.blue),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Expanded(
              child: _ShareButton(
                icon: Icons.chat_rounded,
                label: 'واتساپ',
                color: const Color(0xFF25D366),
                onTap: _shareWhatsApp,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ShareButton(
                icon: Icons.sms_rounded,
                label: 'پیامک',
                color: AppColors.blue,
                onTap: _shareSms,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// قاب هر ابزار — آیکون + تیتر + محتوا داخل کارت
class _ToolSection extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color tint;
  final String title;
  final String subtitle;
  final Widget child;

  const _ToolSection({
    required this.icon,
    required this.color,
    required this.tint,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'IRANYekan',
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: 'IRANYekan',
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.ink3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _CalculatorRow extends StatelessWidget {
  final CarwashService service;
  final bool selected;
  final VoidCallback onTap;

  const _CalculatorRow({
    required this.service,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: <Widget>[
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: selected ? AppColors.blue : AppColors.fill2,
                borderRadius: BorderRadius.circular(7),
              ),
              child: selected
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 15)
                  : null,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                service.serviceTypeName,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'IRANYekan',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.ink : AppColors.ink2,
                ),
              ),
            ),
            Text(
              service.price > 0 ? tomanLabel(service.price) : '—',
              style: TextStyle(
                fontFamily: 'IRANYekan',
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: selected ? AppColors.blue : AppColors.ink3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ShareButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'IRANYekan',
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
