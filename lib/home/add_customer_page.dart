import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/jalali.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import 'dashboard_page.dart';

/// ثبت مشتری حضوری — carwash/carwash/guest-booking/create/
/// (همان فرم addCustomer سایت)
///
/// ابتدا «تاریخ» انتخاب می‌شود (تقویم شمسیِ باتم‌شیت — روزهای بدون بازه
/// خاموش‌اند) و بعد از تأیید تاریخ، «نقشه‌ی ساعت روز» همان روز باز
/// می‌شود؛ ساعت‌ها داخل شیت بر اساس صبح/ظهر/عصر/شب گروه می‌شوند و
/// ساعت‌های پر شده یا گذشته کم‌رنگ و خط‌خورده دیده می‌شوند.
class AddCustomerPage extends StatefulWidget {
  const AddCustomerPage({super.key});

  @override
  State<AddCustomerPage> createState() => _AddCustomerPageState();
}

class _AddCustomerPageState extends State<AddCustomerPage> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _carModel = TextEditingController();

  List<CarwashService> _services = <CarwashService>[];
  List<TimeSlot> _allSlots = <TimeSlot>[];
  List<TimeSlot> _slots = <TimeSlot>[];

  /// آیا سرور اصلاً بازه‌ای (در هر تاریخی) برای این کارواش دارد؟
  /// برای پیام مناسب وقتی روزِ انتخابی بازه‌ای ندارد.
  bool _hasAnySlots = false;

  /// روزِ انتخاب‌شده برای نوبت — پیش‌فرض امروز
  /// (فقط مؤلفه‌های تاریخ معتبرند؛ ساعت صفر است)
  DateTime _selectedDate =
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

  final Set<int> _selectedServices = <int>{};
  TimeSlot? _selectedSlot;

  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _carModel.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final List<dynamic> results = await Future.wait(<Future<dynamic>>[
        Api.get('/carwash/carwash/services/'),
        Api.get('/carwash/time-slots/'),
      ]);

      if (!mounted) return;

      setState(() {
        _services = (results[0] as List? ?? <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(CarwashService.fromJson)
            .toList();

        // ⚠️ بک‌اند «همه‌ی» بازه‌های هفته (به‌ازای هر روزِ فعال یک سشن) را
        // برمی‌گرداند؛ این صفحه نقشه‌ی ساعت «امروز» را نشان می‌دهد — بدون
        // این فیلتر ۷ روز روی هم افتاده و صبح مثلاً ۲۸ خانه تکراری دیده می‌شد.
        final List<TimeSlot> all = (results[1] as List? ?? <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(TimeSlot.fromJson)
            .toList();

        _allSlots = all;
        _hasAnySlots = all.isNotEmpty;
        _slots = _slotsForDate(all, _selectedDate);

        // اگر شیار انتخاب‌شده قبلی دیگر آزاد نبود، پاک شود
        if (_selectedSlot != null) {
          final bool stillFree = _slots.any((TimeSlot s) =>
              s.id == _selectedSlot!.id &&
              !s.isReserved &&
              s.end.isAfter(DateTime.now()));
          if (!stillFree) _selectedSlot = null;
        }

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

  /// فقط بازه‌های «روزِ داده‌شده» + حذف تکراری‌های هم‌ساعت:
  ///
  /// ۱) فیلتر تاریخ — سرور بازه‌های کل هفته را می‌فرستد؛ این صفحه
  ///    نقشه‌ی ساعتِ روزِ انتخاب‌شده را نشان می‌دهد.
  /// ۲) اگر برای یک ساعت چند ردیف تکراری روی سرور باشد (ذخیره‌ی مکرر)،
  ///    فقط یکی نمایش داده می‌شود؛ اگر هر کدام رزروشده باشد همان محافظه‌کارانه
  ///    انتخاب می‌شود تا ساعتِ اشغال‌شده به‌صورت آزاد دیده نشود و دوباره‌رزرو نشود.
  List<TimeSlot> _slotsForDate(List<TimeSlot> all, DateTime date) {
    final Iterable<TimeSlot> day = all.where((TimeSlot s) =>
        s.start.year == date.year &&
        s.start.month == date.month &&
        s.start.day == date.day);

    final Map<String, TimeSlot> byClock = <String, TimeSlot>{};
    for (final TimeSlot s in day) {
      final String key = _clockLabel(s.start);
      final TimeSlot? seen = byClock[key];
      if (seen == null || (s.isReserved && !seen.isReserved)) {
        byClock[key] = s;
      }
    }

    return byClock.values.toList()
      ..sort((TimeSlot a, TimeSlot b) => a.start.compareTo(b.start));
  }

  /// انتخاب تاریخ — تقویم شمسی در باتم‌شیت؛ بعد از تأیید، نقشه‌ی ساعت
  /// همان روز به‌صورت خودکار باز می‌شود
  Future<void> _pickDate() async {
    final DateTime? picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (BuildContext sheetContext) => _DatePickerSheet(
        allSlots: _allSlots,
        selectedDate: _selectedDate,
      ),
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
        // بازه‌ی انتخاب‌شده مال تاریخ قبلی است — برای روز تازه باید
        // ساعت دوباره انتخاب شود
        _selectedSlot = null;

        // ⚠️ نقشه‌ی ساعت باید برای «روزِ تازه» بازمحاسبه شود.
        // قبلاً این خط نبود و شیتِ ساعت همیشه نقشه‌ی «امروز»
        // (محاسبه‌شده در _load) را نشان می‌داد؛ نتیجه: بعد از انتخاب
        // فردا، ساعت‌های گذشته‌ی امروز خط‌خورده دیده می‌شدند و همه
        // «پر شده» به نظر می‌رسیدند؛ بدتر از آن، نوبت روی شناسه‌ی
        // بازه‌ی «امروز» ثبت می‌شد!
        _slots = _slotsForDate(_allSlots, picked);
      });

      await _pickSlot();
    }
  }

  Future<void> _pickSlot() async {
    final TimeSlot? picked = await showModalBottomSheet<TimeSlot>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (BuildContext sheetContext) => _TimeSlotSheet(
        slots: _slots,
        hasAnySlots: _hasAnySlots,
        initialSelected: _selectedSlot,
        dateLabel: Jalali.shortDate(_selectedDate),
      ),
    );

    if (picked != null) {
      setState(() => _selectedSlot = picked);
    }
  }

  Future<void> _submit() async {
    final String phone = normalizeDigits(_phone.text).trim();

    if (_name.text.trim().isEmpty ||
        phone.length != 11 ||
        _carModel.text.trim().isEmpty) {
      showToast(
          context, 'نام، شماره تماس (۱۱ رقم) و مدل خودرو را کامل کنید',
          error: true);
      return;
    }

    if (_selectedSlot == null) {
      showToast(context, 'یک ساعت خالی را انتخاب کنید', error: true);
      return;
    }

    if (_selectedServices.isEmpty) {
      showToast(context, 'حداقل یک خدمت را انتخاب کنید', error: true);
      return;
    }

    setState(() => _saving = true);

    try {
      await Api.post(
        '/carwash/carwash/guest-booking/create/',
        data: <String, dynamic>{
          'customer_name': _name.text.trim(),
          'customer_phone': phone,
          'car_model': _carModel.text.trim(),
          'time_slot': _selectedSlot!.id,
          'service_ids': _selectedServices.toList(),
        },
      );

      if (!mounted) return;
      showToast(context, 'نوبت حضوری با موفقیت ثبت شد');

      // داشبورد بلافاصله نوبت جدید را در «آخرین نوبت‌ها» نشان بدهد
      DashboardRefresh.instance.bump();

      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showToast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('ثبت مشتری حضوری')),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _error != null
              ? ListView(
                  children: <Widget>[
                    const SizedBox(height: 80),
                    EmptyState(
                      icon: Icons.wifi_off_rounded,
                      title: 'خطا در دریافت اطلاعات',
                      message: _error!,
                    ),
                  ],
                )
              : LayoutBuilder(
                  builder:
                      (BuildContext context, BoxConstraints constraints) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                            minHeight: constraints.maxHeight - 32),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              AppTextField(
                                controller: _name,
                                label: 'نام مشتری',
                                hint: 'مثال: علی رضایی',
                              ),
                              const SizedBox(height: 16),
                              AppTextField(
                                controller: _phone,
                                label: 'شماره تماس',
                                hint: 'مثال: 09152685548',
                                keyboard: TextInputType.phone,
                                ltr: true,
                                maxLength: 11,
                                digitsOnly: true,
                              ),
                              const SizedBox(height: 16),
                              AppTextField(
                                controller: _carModel,
                                label: 'مدل خودرو',
                                hint: 'مثال: پژو ۲۰۶',
                              ),
                              const SizedBox(height: 24),

                              // :: انتخاب تاریخ — روزی که نوبت برایش ثبت می‌شود
                              _DateField(
                                date: _selectedDate,
                                onTap: _pickDate,
                              ),
                              const SizedBox(height: 12),

                              // :: انتخاب ساعت — فیلد بازکننده‌ی نقشه ساعت روز
                              _SlotField(
                                slot: _selectedSlot,
                                onTap: _pickSlot,
                              ),
                              const SizedBox(height: 24),

                              // :: انتخاب خدمات
                              Padding(
                                padding: const EdgeInsets.only(
                                    bottom: 12, right: 4),
                                child: Text(
                                  'خدمات',
                                  style: TextStyle(
                                    fontFamily: 'IRANYekan',
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.ink2,
                                  ),
                                ),
                              ),
                              if (_services.isEmpty)
                                const AppCard(
                                  child: EmptyState(
                                    icon: Icons.list_alt_rounded,
                                    title: 'خدمتی ثبت نشده است',
                                    message:
                                        'اول از تب «تنظیمات» خدمات و تعرفه‌های کارواش را ثبت کنید.',
                                  ),
                                )
                              else
                                for (final CarwashService s in _services)
                                  _serviceRow(s),
                              const SizedBox(height: 90),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
      bottomNavigationBar: _loading || _error != null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: AppButton(
                  text: 'ثبت نوبت',
                  icon: Icons.check_rounded,
                  // سبز — ادامه‌ی هویت دکمه‌ی سبز «مشتری حضوری»
                  type: AppButtonType.success,
                  loading: _saving,
                  onPressed: _saving ? null : _submit,
                ),
              ),
            ),
    );
  }

  Widget _serviceRow(CarwashService s) {
    final bool selected = _selectedServices.contains(s.id);

    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      onTap: () => setState(() {
        if (selected) {
          _selectedServices.remove(s.id);
        } else {
          _selectedServices.add(s.id);
        }
      }),
      child: Row(
        children: <Widget>[
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: selected ? AppColors.accent : AppColors.fill2,
              borderRadius: BorderRadius.circular(8),
            ),
            child: selected
                ? const Icon(Icons.check_rounded,
                    color: Colors.white, size: 17)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  s.serviceTypeName,
                  style: TextStyle(
                    fontFamily: 'IRANYekan',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                if (s.vehicleTypeName.isNotEmpty)
                  Text(
                    s.vehicleTypeName,
                    style: TextStyle(
                      fontFamily: 'IRANYekan',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.ink3,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            s.price > 0 ? tomanLabel(s.price) : '—',
            style: TextStyle(
              fontFamily: 'IRANYekan',
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: AppColors.accentDeep,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// انتخاب ساعت — نقشه‌ی ساعت روز
// ════════════════════════════════════════════════════════════════════

String _clockLabel(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

class _DayPeriod {
  final String label;
  final IconData icon;

  const _DayPeriod(this.label, this.icon);
}

const List<_DayPeriod> _kPeriods = <_DayPeriod>[
  _DayPeriod('صبح', Icons.wb_twilight_rounded),
  _DayPeriod('ظهر', Icons.wb_sunny_rounded),
  _DayPeriod('عصر', Icons.wb_cloudy_rounded),
  _DayPeriod('شب', Icons.nightlight_rounded),
];

int _periodIndex(DateTime t) {
  final int h = t.hour;
  if (h < 12) return 0;
  if (h < 16) return 1;
  if (h < 20) return 2;
  return 3;
}

/// فیلد نمایش انتخاب ساعت داخل فرم
class _SlotField extends StatelessWidget {
  final TimeSlot? slot;
  final VoidCallback onTap;

  const _SlotField({required this.slot, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final TimeSlot? s = slot;
    final bool has = s != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.fill,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: has ? AppColors.accentTint() : AppColors.blueTint(),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  has ? Icons.event_available_rounded : Icons.schedule_rounded,
                  color: has ? AppColors.accent : AppColors.blue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'انتخاب ساعت',
                      style: TextStyle(
                        fontFamily: 'IRANYekan',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      has
                          ? '${_clockLabel(s.start)} تا ${_clockLabel(s.end)} — ${_kPeriods[_periodIndex(s.start)].label}'
                          : 'برای دیدن ساعت‌های آزاد بزنید',
                      style: TextStyle(
                        fontFamily: 'IRANYekan',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: has ? AppColors.ink : AppColors.ink2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.expand_more_rounded,
                  size: 22, color: AppColors.ink3),
            ],
          ),
        ),
      ),
    );
  }
}

/// باتم‌شیت نقشه‌ی ساعت روز — گروه‌بندی صبح/ظهر/عصر/شب
///
/// بازه‌های «گذشته» (ساعتی که امروز از آن گذشته) مثل رزروشده‌ها کم‌رنگ و
/// خط‌خورده نمایش داده می‌شوند و قابل انتخاب نیستند.
class _TimeSlotSheet extends StatefulWidget {
  final List<TimeSlot> slots;

  /// آیا سرور اصلاً بازه‌ای برای کارواش دارد؟ (برای پیام خالی بهتر)
  final bool hasAnySlots;
  final TimeSlot? initialSelected;

  /// برچسب کوتاه روزِ در حال نمایش (مثل «۵ مهر»)
  final String dateLabel;

  const _TimeSlotSheet({
    required this.slots,
    required this.hasAnySlots,
    required this.initialSelected,
    required this.dateLabel,
  });

  @override
  State<_TimeSlotSheet> createState() => _TimeSlotSheetState();
}

class _TimeSlotSheetState extends State<_TimeSlotSheet> {
  TimeSlot? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSelected;
  }

  static bool _isPast(TimeSlot s) => s.end.isBefore(DateTime.now());

  int get _freeCount => widget.slots
      .where((TimeSlot s) => !s.isReserved && !_isPast(s))
      .length;

  @override
  Widget build(BuildContext context) {
    final List<TimeSlot> sorted = widget.slots;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.80,
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // :: دستگیره
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 42,
              height: 4.5,
              decoration: BoxDecoration(
                color: AppColors.fill2,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),

          // :: تیتر + وضعیت
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 16, 12),
            child: Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.blueTint(),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(Icons.schedule_rounded,
                      color: AppColors.blue, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'انتخاب ساعت نوبت',
                        style: TextStyle(
                          fontFamily: 'IRANYekan',
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$_freeCount ساعت آزاد از ${sorted.length} بازه — ${widget.dateLabel}',
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
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded,
                      size: 22, color: AppColors.ink3),
                ),
              ],
            ),
          ),

          // :: نقشه ساعت‌ها
          Flexible(
            child: sorted.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 36),
                    child: Text(
                      widget.hasAnySlots
                          ? 'برای این تاریخ بازه‌ی زمانی ثبت نشده است؛ ساعت‌های کاری را از «تنظیمات ← زمان‌های کاری» به‌روزرسانی کنید تا بازه‌های این روز ساخته شود.'
                          : 'بازه‌ی زمانی ثبت نشده است؛ از «تنظیمات ← زمان‌های کاری» بازه بسازید.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'IRANYekan',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink3,
                        height: 1.9,
                      ),
                    ),
                  )
                : ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
                    children: <Widget>[
                      for (int p = 0; p < _kPeriods.length; p++)
                        _buildPeriodSection(_kPeriods[p], p, sorted),
                    ],
                  ),
          ),

          // :: نوار تأیید
          Container(
            padding: EdgeInsets.fromLTRB(20, 12, 20,
                12 + MediaQuery.of(context).padding.bottom),
            decoration: BoxDecoration(
              color: AppColors.card,
              border: Border(
                top: BorderSide(color: AppColors.fill2, width: 1),
              ),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'ساعت انتخابی',
                        style: TextStyle(
                          fontFamily: 'IRANYekan',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _selected != null
                            ? '${_clockLabel(_selected!.start)} تا ${_clockLabel(_selected!.end)}'
                            : 'هنوز انتخاب نشده',
                        style: TextStyle(
                          fontFamily: 'IRANYekan',
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: _selected != null
                              ? AppColors.ink
                              : AppColors.ink3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _selected == null
                      ? null
                      : () => Navigator.of(context).pop(_selected),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.fill2,
                    disabledForegroundColor: AppColors.ink3,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: 'IRANYekan',
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: const Text('تایید'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSection(_DayPeriod period, int index, List<TimeSlot> all) {
    final List<TimeSlot> slots =
        all.where((TimeSlot s) => _periodIndex(s.start) == index).toList();

    if (slots.isEmpty) return const SizedBox.shrink();

    final int free = slots
        .where((TimeSlot s) => !s.isReserved && !_isPast(s))
        .length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // :: سرگروه
          Row(
            children: <Widget>[
              Icon(period.icon, size: 17, color: AppColors.ink3),
              const SizedBox(width: 7),
              Text(
                period.label,
                style: TextStyle(
                  fontFamily: 'IRANYekan',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: free > 0
                      ? AppColors.accentTint(0.10)
                      : AppColors.fill2,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  free > 0 ? '$free آزاد' : 'پر شده',
                  style: TextStyle(
                    fontFamily: 'IRANYekan',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: free > 0 ? AppColors.accentDeep : AppColors.ink3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // :: خانه‌های ساعت
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.65,
            children: <Widget>[
              for (final TimeSlot slot in slots)
                _SlotCell(
                  slot: slot,
                  selected: _selected?.id == slot.id,
                  // رزروشده و ساعتی که از آن گذشته باشد قابل انتخاب نیست
                  onTap: slot.isReserved || _isPast(slot)
                      ? null
                      : () => setState(() => _selected = slot),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// هر خانه‌ی ساعت — آزاد / انتخاب‌شده / رزروشده یا گذشته (خط‌خورده)
class _SlotCell extends StatelessWidget {
  final TimeSlot slot;
  final bool selected;
  final VoidCallback? onTap;

  const _SlotCell({
    required this.slot,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool past = slot.end.isBefore(DateTime.now());
    final bool free = !slot.isReserved && !past;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent
              : free
                  ? AppColors.chipSurface
                  : AppColors.fill,
          borderRadius: BorderRadius.circular(12),
          border: free && !selected
              ? Border.all(color: AppColors.fill2)
              : null,
          boxShadow: selected
              ? <BoxShadow>[
                  BoxShadow(
                    color: AppColors.accent.withOpacity(0.32),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                    spreadRadius: -3,
                  ),
                ]
              : null,
        ),
        child: Text(
          _clockLabel(slot.start),
          style: TextStyle(
            fontFamily: 'IRANYekan',
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: selected
                ? Colors.white
                : free
                    ? AppColors.ink2
                    : AppColors.ink3,
            decoration: free ? null : TextDecoration.lineThrough,
            decorationColor: AppColors.ink3,
            decorationThickness: 1.8,
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// انتخاب تاریخ — تقویم شمسی
// ════════════════════════════════════════════════════════════════════

/// فیلد نمایش انتخاب تاریخ داخل فرم
class _DateField extends StatelessWidget {
  final DateTime date;
  final VoidCallback onTap;

  const _DateField({required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final bool isToday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.fill,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.accentTint(),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.event_rounded,
                  color: AppColors.accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'انتخاب تاریخ',
                      style: TextStyle(
                        fontFamily: 'IRANYekan',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isToday
                          ? 'امروز — ${Jalali.fullDate(date)}'
                          : Jalali.fullDate(date),
                      style: TextStyle(
                        fontFamily: 'IRANYekan',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.expand_more_rounded,
                  size: 22, color: AppColors.ink3),
            ],
          ),
        ),
      ),
    );
  }
}

/// کلید روز برای نقشه‌ی دسترس‌پذیری تقویم
String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

/// اولین روزِ ماهِ شمسی که تاریخِ داده‌شده در آن است
/// (رو به عقب می‌رود تا روزِ شمسی ۱ پیدا شود)
DateTime _jalaliMonthStart(DateTime anyDayInMonth) {
  DateTime c = DateTime(anyDayInMonth.year, anyDayInMonth.month, anyDayInMonth.day);
  while (Jalali.fromDateTime(c).day != 1) {
    c = c.subtract(const Duration(days: 1));
  }
  return c;
}

/// تعداد روزهای ماه شمسی (۲۹ تا ۳۱)
int _jalaliMonthLength(DateTime monthStart) {
  final int month = Jalali.fromDateTime(monthStart).month;
  DateTime c = monthStart;
  int len = 0;
  while (Jalali.fromDateTime(c).month == month) {
    len++;
    c = c.add(const Duration(days: 1));
  }
  return len;
}

const List<String> _kWeekdayShort = <String>[
  'ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج',
];

/// باتم‌شیت تقویم شمسی — انتخاب روزِ نوبت
///
/// - روزهای گذشته و روزهای بدون بازه خاموش‌اند
/// - زیر روزهای دارای بازه‌ی آزاد نقطه‌ی سبز می‌افتد
/// - جابه‌جایی ماه فقط در محدوده‌ی «امروز تا آخرین روزِ دارای بازه»
///   ممکن است (بک‌اند موقع ذخیره‌ی زمان‌های کاری حدود یک هفته بازه می‌سازد)
class _DatePickerSheet extends StatefulWidget {
  final List<TimeSlot> allSlots;
  final DateTime selectedDate;

  const _DatePickerSheet({
    required this.allSlots,
    required this.selectedDate,
  });

  @override
  State<_DatePickerSheet> createState() => _DatePickerSheetState();
}

class _DatePickerSheetState extends State<_DatePickerSheet> {
  late DateTime _selected;
  late DateTime _monthStart;

  /// امروز (بدون ساعت)
  late final DateTime _today;

  /// ماهِ امروز — عقب‌تر از این نمی‌توان رفت
  late final DateTime _minMonth;

  /// آخرین روزِ دارای بازه — جلوتر از ماهِ این روز نمی‌توان رفت
  late final DateTime? _maxDay;

  /// روزهایی که حداقل یک بازه دارند (امروز به بعد)
  final Map<String, bool> _hasSlots = <String, bool>{};

  /// روزهایی که حداقل یک بازه‌ی آزادِ قابل انتخاب دارند
  final Map<String, bool> _hasFree = <String, bool>{};

  @override
  void initState() {
    super.initState();

    final DateTime now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    _selected = widget.selectedDate;
    _monthStart = _jalaliMonthStart(_selected);
    _minMonth = _jalaliMonthStart(_today);

    DateTime? maxDay;
    for (final TimeSlot s in widget.allSlots) {
      final DateTime day = DateTime(s.start.year, s.start.month, s.start.day);
      if (day.isBefore(_today)) continue; // روزهای گذشته قابل انتخاب نیستند

      final String key = _dayKey(day);
      _hasSlots[key] = true;

      final bool free = !s.isReserved && !s.end.isBefore(now);
      _hasFree[key] = (_hasFree[key] ?? false) || free;

      if (maxDay == null || day.isAfter(maxDay)) {
        maxDay = day;
      }
    }
    _maxDay = maxDay;
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool get _canGoPrev => _monthStart.isAfter(_minMonth);

  bool get _canGoNext =>
      _maxDay != null &&
      _jalaliMonthStart(_maxDay!).isAfter(_monthStart);

  void _goPrevMonth() {
    if (!_canGoPrev) return;
    setState(() {
      _monthStart = _jalaliMonthStart(_monthStart.subtract(const Duration(days: 1)));
    });
  }

  void _goNextMonth() {
    if (!_canGoNext) return;
    setState(() {
      _monthStart =
          _monthStart.add(Duration(days: _jalaliMonthLength(_monthStart)));
    });
  }

  @override
  Widget build(BuildContext context) {
    final Jalali jMonth = Jalali.fromDateTime(_monthStart);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.80,
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // :: دستگیره
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 42,
              height: 4.5,
              decoration: BoxDecoration(
                color: AppColors.fill2,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),

          // :: تیتر + وضعیت
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 16, 12),
            child: Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.blueTint(),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(Icons.event_rounded,
                      color: AppColors.blue, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'انتخاب تاریخ نوبت',
                        style: TextStyle(
                          fontFamily: 'IRANYekan',
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _maxDay != null
                            ? 'بازه‌های رزرو تا ${Jalali.shortDate(_maxDay!)} ساخته شده‌اند'
                            : 'هنوز بازه‌ای برای رزرو ساخته نشده است',
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
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded,
                      size: 22, color: AppColors.ink3),
                ),
              ],
            ),
          ),

          // :: نوار ماه
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: <Widget>[
                IconButton(
                  onPressed: _canGoPrev ? _goPrevMonth : null,
                  icon: Icon(Icons.chevron_right_rounded, size: 26),
                  color: AppColors.ink2,
                  disabledColor: AppColors.ink3.withOpacity(0.25),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '${Jalali.months[jMonth.month - 1]} ${jMonth.year}',
                      style: TextStyle(
                        fontFamily: 'IRANYekan',
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _canGoNext ? _goNextMonth : null,
                  icon: Icon(Icons.chevron_left_rounded, size: 26),
                  color: AppColors.ink2,
                  disabledColor: AppColors.ink3.withOpacity(0.25),
                ),
              ],
            ),
          ),

          // :: هدر روزهای هفته + گرید ماه
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
              children: <Widget>[
                GridView.count(
                  crossAxisCount: 7,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.92,
                  children: <Widget>[
                    for (int i = 0; i < 7; i++)
                      Center(
                        child: Text(
                          _kWeekdayShort[i],
                          style: TextStyle(
                            fontFamily: 'IRANYekan',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink3,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                _buildMonthGrid(),
              ],
            ),
          ),

          // :: نوار تأیید
          Container(
            padding: EdgeInsets.fromLTRB(20, 12, 20,
                12 + MediaQuery.of(context).padding.bottom),
            decoration: BoxDecoration(
              color: AppColors.card,
              border: Border(
                top: BorderSide(color: AppColors.fill2, width: 1),
              ),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'تاریخ انتخابی',
                        style: TextStyle(
                          fontFamily: 'IRANYekan',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        Jalali.fullDate(_selected),
                        style: TextStyle(
                          fontFamily: 'IRANYekan',
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(_selected),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: 'IRANYekan',
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: const Text('تایید'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthGrid() {
    final int monthLen = _jalaliMonthLength(_monthStart);
    final int lead = Jalali.persianWeekday(_monthStart) - 1; // شنبه=۱

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 0.92,
      children: <Widget>[
        for (int i = 0; i < lead; i++)
          const SizedBox.shrink(),
        for (int i = 0; i < monthLen; i++)
          _buildDayCell(_monthStart.add(Duration(days: i))),
      ],
    );
  }

  Widget _buildDayCell(DateTime day) {
    final bool isPast = day.isBefore(_today);
    final bool hasSlots = _hasSlots[_dayKey(day)] ?? false;
    final bool hasFree = _hasFree[_dayKey(day)] ?? false;
    final bool enabled = !isPast && hasSlots;
    final bool selected = _isSameDay(day, _selected);
    final bool isToday = _isSameDay(day, _today);

    return _DayCell(
      dayNumber: Jalali.fromDateTime(day).day,
      enabled: enabled,
      isToday: isToday,
      selected: selected,
      // نقطه‌ی زیر عدد: سبز = بازه‌ی آزاد دارد؛ خاکستری = همه‌ی بازه‌ها پر
      dot: hasFree
          ? _DayDot.free
          : (hasSlots ? _DayDot.busy : _DayDot.none),
      onTap: enabled && !selected
          ? () => setState(() => _selected = day)
          : null,
    );
  }
}

enum _DayDot { none, free, busy }

/// هر خانه‌ی روز در تقویم
class _DayCell extends StatelessWidget {
  final int dayNumber;
  final bool enabled;
  final bool isToday;
  final bool selected;
  final _DayDot dot;
  final VoidCallback? onTap;

  const _DayCell({
    required this.dayNumber,
    required this.enabled,
    required this.isToday,
    required this.selected,
    required this.dot,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color numberColor = selected
        ? Colors.white
        : enabled
            ? AppColors.ink2
            : AppColors.ink3.withOpacity(0.45);

    final Color? dotColor = selected
        ? Colors.white.withOpacity(0.85)
        : dot == _DayDot.free
            ? AppColors.success
            : dot == _DayDot.busy
                ? AppColors.ink3.withOpacity(0.40)
                : null;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent
              : enabled
                  ? AppColors.chipSurface
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: selected
              ? null
              : isToday
                  ? Border.all(color: AppColors.accent, width: 1.6)
                  : enabled
                      ? Border.all(color: AppColors.fill2)
                      : null,
          boxShadow: selected
              ? <BoxShadow>[
                  BoxShadow(
                    color: AppColors.accent.withOpacity(0.32),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                    spreadRadius: -3,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              '$dayNumber',
              style: TextStyle(
                fontFamily: 'IRANYekan',
                fontSize: 13.5,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                color: numberColor,
              ),
            ),
            const SizedBox(height: 3),
            Container(
              width: 5,
              height: 5,
              decoration: dotColor != null
                  ? BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
