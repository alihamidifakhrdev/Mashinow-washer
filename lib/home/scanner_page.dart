import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/api.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import 'booking_card.dart';

/// اسکنر کد رزرو مشتری — دوربین واقعی با طراحی مینیمال و حرفه‌ای:
///  - قاب «افقی» هم‌نسبتِ بارکد خطی Code128 (پهن و کوتاه)
///  - دور قاب، تاری (بلور) + تیرگی با پنجره‌ی شفاف — بارکد داخل قاب
///    کاملاً واضح و روشن دیده می‌شود
///  - رمزگشایی روی «کل تصویر» انجام می‌شود، نه فقط داخل قاب:
///    پارامتر scanWindow پکیج (فیلترِ «کل جعبه‌ی بارکد باید داخل پنجره
///    باشد») در کد نیتیو اندروید و iOS جعبه‌ی بارکدِ پهنِ Code128 را به‌دلیل
///    عدم تطابق دستگاهِ مختصات (باگ شناخته‌شده‌ی خود پکیج — TODO در
///    سورس) بی‌صدا دور می‌ریخت و «هیچی نمی‌شد»؛ قاب فقط راهنمای دیداری است
///  - چراغ قوه و ورود دستی کد به عنوان پشتیبان (حروف + رقم)
///  - بعد از خواندن کد، نوبت متناظر پیدا شده و جزئیاتش باز می‌شود
class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

enum _ScanPhase { scanning, processing, found, error }

class _ScannerPageState extends State<ScannerPage>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    // رزولوشن جریان تحلیل — پیش‌فرضِ پکیج روی اندروید ۶۴۰×۴۸۰ است که خودِ
    // سورس پکیج می‌گوید «برای MLKit کم است». بارکد پهن Code128 حدود ~۱۸۰
    // ماژول دارد؛ در ۴۸۰ پیکسلِ عرض فقط ~۱.۸ پیکسل به هر ماژول می‌رسد که
    // مرز شکست رمزگشاست. با ۱۰۸۰ عرضِ چرخیده، هر ماژول ~۴ پیکسل می‌گیرد.
    // (اندازه «عمودی» داده می‌شود؛ نیتیو خودش برای حالت افقی برمی‌گرداند.
    // iOS این پارامتر را نادیده می‌گیرد و از .photo حداکثر می‌گیرد.)
    cameraResolution: const Size(1080, 1920),
  );

  late final AnimationController _lineController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  _ScanPhase _phase = _ScanPhase.scanning;
  String _errorMessage = '';
  String _foundCode = '';

  bool _torchOn = false;

  Booking? _foundBooking;
  GuestBooking? _foundGuest;

  @override
  void dispose() {
    _lineController.dispose();
    _controller.dispose();
    super.dispose();
  }

  // ── تشخیص کد ──

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_phase != _ScanPhase.scanning) return;

    final String? raw = capture.barcodes.isNotEmpty
        ? capture.barcodes.first.rawValue
        : null;

    if (raw == null || raw.trim().isEmpty) return;

    setState(() => _phase = _ScanPhase.processing);

    try {
      await _controller.stop();
    } catch (_) {}

    await _lookup(raw.trim());
  }

  /// جستجوی نوبت با کد پیگیری — مستقیم، و اگر کد داخل آدرس/متن باشد
  /// نسخه‌ی بدون علامت‌ها را هم امتحان می‌کند
  Future<void> _lookup(String code) async {
    final List<String> candidates = <String>[
      normalizeDigits(code).trim().toUpperCase(),
      normalizeDigits(code)
          .replaceAll(RegExp(r'[^0-9a-zA-Z]'), '')
          .toUpperCase(),
    ].toSet().toList();

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
        final String c = normalizeDigits(b.trackingCode).trim().toUpperCase();
        if (candidates.contains(c)) {
          _onFound(booking: b);
          return;
        }
      }

      for (final GuestBooking g in guests) {
        final String c = normalizeDigits(g.trackingCode).trim().toUpperCase();
        if (candidates.contains(c)) {
          _onFound(guest: g);
          return;
        }
      }

      setState(() {
        _phase = _ScanPhase.error;
        _errorMessage =
            'نوبتی با این کد پیدا نشد.\nاز کد روی تصویر مشتری مطمئن شوید یا کد را دستی وارد کنید.';
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _ScanPhase.error;
        _errorMessage = e.message;
      });
    }
  }

  void _onFound({Booking? booking, GuestBooking? guest}) {
    setState(() {
      _phase = _ScanPhase.found;
      _foundBooking = booking;
      _foundGuest = guest;
      _foundCode = normalizeDigits(
              booking?.trackingCode ?? guest?.trackingCode ?? '')
          .trim();
    });

    Timer(const Duration(milliseconds: 850), () {
      if (!mounted) return;

      final Booking? b = _foundBooking;
      final GuestBooking? g = _foundGuest;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (BuildContext context) =>
              OrderDetailPage(booking: b, guest: g),
        ),
      );
    });
  }

  Future<void> _restart() async {
    setState(() => _phase = _ScanPhase.scanning);

    try {
      await _controller.start();
    } catch (_) {}
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();
    } catch (_) {}

    if (!mounted) return;
    setState(() => _torchOn = !_torchOn);
  }

  // ── ورود دستی کد ──

  Future<void> _openManualEntry() async {
    // دوربین موقتاً متوقف شود تا هنگام تایپ، اسکن خودکار فعال نشود
    try {
      await _controller.stop();
    } catch (_) {}

    if (!mounted) return;

    final TextEditingController input = TextEditingController();

    final String? code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                18,
                24,
                26 + MediaQuery.of(sheetContext).padding.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'ورود دستی کد رزرو',
                          style: TextStyle(
                            fontFamily: 'IRANYekan',
                            fontSize: 16.5,
                            fontWeight: FontWeight.w900,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: Icon(Icons.close_rounded,
                            size: 22, color: AppColors.ink3),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: input,
                    autofocus: true,
                    keyboardType: TextInputType.visiblePassword,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.ltr,
                    inputFormatters: <TextInputFormatter>[
                      // کد پیگیری «حروف + رقم» است (مثلاً MS140312) —
                      // فرمتر مخصوص همان: نرمال‌سازی ارقام فارسی + بزرگ‌کردن حروف
                      SmartCodeInputFormatter(maxLength: 24),
                    ],
                    style: TextStyle(
                      fontFamily: 'IRANYekan',
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: AppColors.ink,
                    ),
                    decoration: InputDecoration(
                      hintText: 'کد پیگیری — مثلاً MS140312',
                      hintStyle: TextStyle(
                        fontFamily: 'IRANYekan',
                        fontSize: 13.5,
                        color: AppColors.ink3,
                      ),
                      filled: true,
                      fillColor: AppColors.fill,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 15),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: const BorderSide(color: Colors.transparent),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide:
                            BorderSide(color: AppColors.blue, width: 1.6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        final String v =
                            normalizeDigits(input.text).trim();
                        if (v.isEmpty) {
                          showToast(
                              sheetContext, 'کد را وارد کنید', error: true);
                          return;
                        }
                        Navigator.of(sheetContext).pop(v);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.blue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                        textStyle: const TextStyle(
                          fontFamily: 'IRANYekan',
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: const Text('جستجوی نوبت'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (code == null || code.isEmpty) {
      // لغو شد → دوربین و اسکن از سر گرفته شود
      await _restart();
      return;
    }

    if (!mounted) return;
    setState(() => _phase = _ScanPhase.processing);

    // دوربین هنگام باز شدن شیت متوقف شده است
    await _lookup(code);
  }

  // ── UI ──

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final Size size = constraints.biggest;

          // :: قاب افقی — هم‌نسبتِ بارکد خطی (کد ۱۲۸ پهن و کوتاه است)
          final double frameW = math.min(size.width * 0.86, 360);
          final double frameH = frameW / 2.1;
          final Rect frame = Rect.fromCenter(
            center: Offset(size.width / 2, size.height * 0.42),
            width: frameW,
            height: frameH,
          );

          // پنجره‌ی رمزگشایی «حذف» شد — کد نیتیو پکیج (هر دو پلتفرم)
          // جعبه‌ی بارکد را با contains() در برابر پنجره می‌سنجد و در
          // اندروید مختصات جعبه با مختصات تصویر قاطی می‌شود (باگ
          // شناخته‌شده)؛ بارکد پهن Code128 که حتی یک پیکسل بیرون بزند
          // بی‌صدا دور ریخته می‌شد. رمزگشایی روی کل قاب انجام می‌شود و
          // قاب فقط نقش راهنمای دیداری دارد. کد‌های تصادفی هم به
          // «نوبتی با این کد پیدا نشد» می‌رسند که بی‌خطر است.

          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              // :: دوربین — رمزگشایی روی کل تصویر (scanWindow حذف شد —
              // فیلتر پنجره در نیتیو با مختصاتِ جعبه‌ی بارکد نمی‌خواند)
              MobileScanner(
                controller: _controller,
                onDetect: _onDetect,
                errorBuilder: (
                  BuildContext ctx,
                  MobileScannerException error,
                  Widget? child,
                ) {
                  return _CameraErrorView(
                    onManual: _openManualEntry,
                    onRetry: _restart,
                  );
                },
              ),

              // :: تاری + تیرگی دور صفحه؛ پنجره‌ی وسط شفاف و واضح می‌ماند
              _BlurDim(cutout: frame),

              // :: هدر
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 20, 0),
                    child: Row(
                      children: <Widget>[
                        IconButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.white, size: 26),
                        ),
                        const Expanded(
                          child: Text(
                            'اسکن کد رزرو',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'IRANYekan',
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                ),
              ),

              // :: قاب گوشه‌ها + خط اسکن — دقیقاً روی لبه‌ی پنجره
              Positioned.fromRect(
                rect: frame,
                child: _ScanFrame(lineController: _lineController),
              ),

              // :: زیرنویس راهنما — چسبیده به پایین قاب
              Positioned(
                top: frame.bottom + 20,
                left: 28,
                right: 28,
                child: const Text(
                  'کد بارکد روی تصویر مشتری را داخل قاب بگیرید',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'IRANYekan',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
              ),

              // :: دکمه‌های پایین
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 26,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    _CircleAction(
                      icon: _torchOn
                          ? Icons.flash_on_rounded
                          : Icons.flash_off_rounded,
                      label: _torchOn ? 'خاموش' : 'چراغ',
                      onTap: _toggleTorch,
                    ),
                    const SizedBox(width: 14),
                    _CircleAction(
                      icon: Icons.keyboard_alt_rounded,
                      label: 'ورود دستی',
                      onTap: _openManualEntry,
                    ),
                  ],
                ),
              ),

              // :: حالت‌های روی دوربین
              if (_phase == _ScanPhase.processing) _buildProcessing(),
              if (_phase == _ScanPhase.found) _buildFound(),
              if (_phase == _ScanPhase.error) _buildError(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProcessing() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(
                color: AppColors.blue,
                strokeWidth: 3.2,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'در حال جستجوی نوبت...',
              style: TextStyle(
                fontFamily: 'IRANYekan',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFound() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.4, end: 1),
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutBack,
              builder: (BuildContext ctx, double scale, Widget? child) {
                return Transform.scale(scale: scale, child: child);
              },
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: AppColors.success.withOpacity(0.45),
                      blurRadius: 26,
                      offset: const Offset(0, 8),
                      spreadRadius: -4,
                    ),
                  ],
                ),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 46),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'نوبت پیدا شد!',
              style: TextStyle(
                fontFamily: 'IRANYekan',
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'کد: $_foundCode',
              style: TextStyle(
                fontFamily: 'IRANYekan',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: AppColors.redTint(0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.search_off_rounded,
                      color: AppColors.red, size: 30),
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'IRANYekan',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink2,
                    height: 1.9,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    TextButton.icon(
                      onPressed: _restart,
                      icon: Icon(Icons.refresh_rounded,
                          size: 19, color: AppColors.blue),
                      label: Text(
                        'اسکن مجدد',
                        style: TextStyle(
                          fontFamily: 'IRANYekan',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.blue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    TextButton.icon(
                      // شیت ورود دستی، دوربین را خودش مدیریت می‌کند
                      onPressed: _openManualEntry,
                      icon: Icon(Icons.keyboard_alt_rounded,
                          size: 19, color: AppColors.accent),
                      label: Text(
                        'ورود دستی کد',
                        style: TextStyle(
                          fontFamily: 'IRANYekan',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// لایه‌ی تاری + تیرگی با پنجره‌ی شفاف — دور صفحه را محو و تیره می‌کند
/// اما خودِ قاب (مستطیل افقی) کاملاً واضح می‌ماند. کات‌اوت گردِ نرم دارد.
class _BlurDim extends StatelessWidget {
  final Rect cutout;

  const _BlurDim({required this.cutout});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ClipPath(
        // فقط «بیرونِ» قاب کلیپ می‌شود؛ پس بلور هم فقط همان‌جا اعمال می‌شود
        clipper: _OutsideCutoutClipper(cutout: cutout),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
          child: Container(color: Colors.black.withOpacity(0.45)),
        ),
      ),
    );
  }
}

/// همه‌چیز به‌جز داخلِ مستطیل گرد قاب
class _OutsideCutoutClipper extends CustomClipper<Path> {
  final Rect cutout;

  const _OutsideCutoutClipper({required this.cutout});

  @override
  Path getClip(Size size) {
    return Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()
        ..addRRect(
          RRect.fromRectAndRadius(cutout, const Radius.circular(16)),
        ),
    );
  }

  @override
  bool shouldReclip(_OutsideCutoutClipper oldClipper) =>
      oldClipper.cutout != cutout;
}

/// قاب اسکن — چهار گوشه‌ی نازک و کم‌گرد + خط اسکن متحرک
/// (والد آن را با Positioned.fromRect دقیقاً روی پنجره‌ی شفاف می‌نشاند)
class _ScanFrame extends StatelessWidget {
  final AnimationController? lineController;

  const _ScanFrame({this.lineController});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          _corner(Alignment.topLeft, const BorderRadius.only(
            topLeft: Radius.circular(14),
          )),
          _corner(Alignment.topRight, const BorderRadius.only(
            topRight: Radius.circular(14),
          )),
          _corner(Alignment.bottomLeft, const BorderRadius.only(
            bottomLeft: Radius.circular(14),
          )),
          _corner(Alignment.bottomRight, const BorderRadius.only(
            bottomRight: Radius.circular(14),
          )),

          // خط اسکن متحرک — از بالا تا پایین قاب (نسبی، مستقل از اندازه)
          if (lineController != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 13, 22, 13),
              child: AnimatedBuilder(
                animation: lineController!,
                builder: (BuildContext ctx, Widget? child) {
                  final double t = lineController!.value;
                  return Align(
                    alignment: Alignment(0, -1.0 + 2.0 * t),
                    child: child!,
                  );
                },
                child: Container(
                  height: 2.6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    color: Colors.white,
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: AppColors.blue.withOpacity(0.85),
                        blurRadius: 16,
                        spreadRadius: 0.5,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _corner(Alignment alignment, BorderRadius radius) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: Colors.white, width: 3),
        ),
      ),
    );
  }
}

/// دکمه گرد پایین اسکنر — فقط سطح نیمه‌شفاف، بدون هیچ استروکی
class _CircleAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _CircleAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.16),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, color: Colors.white, size: 19),
            const SizedBox(width: 7),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'IRANYekan',
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// خطای دوربین (مثل رد دسترسی) — با راه‌حل ورود دستی
class _CameraErrorView extends StatelessWidget {
  final VoidCallback onManual;
  final VoidCallback onRetry;

  const _CameraErrorView({required this.onManual, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0E1512),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.no_photography_rounded,
                    color: Colors.white54, size: 32),
              ),
              const SizedBox(height: 18),
              const Text(
                'دوربین در دسترس نیست',
                style: TextStyle(
                  fontFamily: 'IRANYekan',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'اجازه‌ی دسترسی به دوربین را بدهید یا کد رزرو را دستی وارد کنید.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'IRANYekan',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white54,
                  height: 1.9,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  TextButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded,
                        size: 19, color: Color(0xFF5E86FF)),
                    label: const Text(
                      'تلاش مجدد',
                      style: TextStyle(
                        fontFamily: 'IRANYekan',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF5E86FF),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  TextButton.icon(
                    onPressed: onManual,
                    icon: const Icon(Icons.keyboard_alt_rounded,
                        size: 19, color: Color(0xFF5E86FF)),
                    label: const Text(
                      'ورود دستی کد',
                      style: TextStyle(
                        fontFamily: 'IRANYekan',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF5E86FF),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
