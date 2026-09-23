import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/jalali.dart';
import '../core/models.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../core/ui.dart';

/// مرحله «زمان‌های کاری» — برای step=waiting_for_timeslots
/// (همین صفحه از تب «تنظیمات» هم برای ویرایش باز می‌شود)
///
/// GET carwash/working-sessions/ → جلسات فعلی
/// POST carwash/working-sessions/create/ (اولین بار) / PUT carwash/working-sessions/ (ویرایش)
class WorkingHoursPage extends StatefulWidget {
  final bool asManage;

  const WorkingHoursPage({super.key, this.asManage = false});

  @override
  State<WorkingHoursPage> createState() => _WorkingHoursPageState();
}

class _WorkingHoursPageState extends State<WorkingHoursPage> {
  /// برای هر روز هفته (۱=شنبه .. ۷=جمعه): فعال؟ از چه ساعتی تا چه ساعتی
  final Map<int, bool> _enabled = <int, bool>{};
  final Map<int, String> _start = <int, String>{};
  final Map<int, String> _end = <int, String>{};

  /// گزینه‌های ساعت — اگر جلسه‌ای قبلا با ساعتی خارج از این فهرست ثبت شده
  /// باشد (مثل دیتای تست ۰۹:۰۰ تا ۲۱:۰۰) همان ساعت هم به گزینه‌ها اضافه
  /// می‌شود تا Dropdown خطای runtime ندهد.
  final List<String> _startOptions = <String>[
    '08:00:00',
    '09:00:00',
    '10:00:00',
    '11:00:00',
    '12:00:00',
  ];

  final List<String> _endOptions = <String>[
    '13:00:00',
    '14:00:00',
    '15:00:00',
    '16:00:00',
    '17:00:00',
    '18:00:00',
    '19:00:00',
    '20:00:00',
    '21:00:00',
  ];

  void _ensureOption(List<String> options, String value) {
    if (!options.contains(value)) {
      options.add(value);
      options.sort();
    }
  }

  bool _loading = true;
  bool _saving = false;
  bool _hasExisting = false;
  String? _error;

  SessionStore get _session => SessionScope.of(context);

  @override
  void initState() {
    super.initState();

    for (int i = 1; i <= 7; i++) {
      _enabled[i] = false;
      _start[i] = '08:00:00';
      _end[i] = '17:00:00';
    }

    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final dynamic data = await Api.get('/carwash/working-sessions/');

      if (!mounted) return;

      final List<WorkingSession> sessions = data is List
          ? data
              .whereType<Map<String, dynamic>>()
              .map(WorkingSession.fromJson)
              .toList()
          : <WorkingSession>[];

      _hasExisting = sessions.isNotEmpty;

      for (final WorkingSession s in sessions) {
        final int weekday = Jalali.persianWeekday(s.start);
        _enabled[weekday] = true;
        _start[weekday] =
            '${s.start.hour.toString().padLeft(2, '0')}:${s.start.minute.toString().padLeft(2, '0')}:00';
        _end[weekday] =
            '${s.end.hour.toString().padLeft(2, '0')}:${s.end.minute.toString().padLeft(2, '0')}:00';

        _ensureOption(_startOptions, _start[weekday]!);
        _ensureOption(_endOptions, _end[weekday]!);
      }

      setState(() => _loading = false);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  Future<void> _save() async {
    final List<Map<String, String>> payload = <Map<String, String>>[];

    for (int i = 1; i <= 7; i++) {
      if (_enabled[i] != true) continue;

      final DateTime date = Jalali.nextDateOfPersianWeekday(i);
      final String iso = Jalali.isoDate(date);

      payload.add(<String, String>{
        'start_datetime': '${iso}T${_start[i]}',
        'end_datetime': '${iso}T${_end[i]}',
      });
    }

    if (payload.isEmpty) {
      showToast(context, 'حداقل یک روز از هفته را فعال کنید', error: true);
      return;
    }

    // نشست را قبل از هر await می‌گیریم
    final SessionStore session = _session;

    setState(() => _saving = true);

    try {
      if (_hasExisting) {
        await Api.put('/carwash/working-sessions/', data: payload);
      } else {
        await Api.post('/carwash/working-sessions/create/', data: payload);
      }

      if (!mounted) return;

      if (widget.asManage) {
        showToast(context, 'زمان‌های کاری ذخیره شد');
        Navigator.of(context).pop();
        return;
      }

      await session.refreshProfileStatus();
      session.notifyUI();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showToast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget body = _loading
        ? Center(child: CircularProgressIndicator(color: AppColors.accent))
        : _error != null
            ? EmptyState(
                icon: Icons.wifi_off_rounded,
                title: 'خطا در دریافت اطلاعات',
                message: _error!,
              )
            : LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minHeight: constraints.maxHeight - 32),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            for (int i = 1; i <= 7; i++) _buildDayRow(i),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );

    if (widget.asManage) {
      return Scaffold(
        backgroundColor: AppColors.canvas,
        appBar: AppBar(title: const Text('زمان‌های کاری')),
        body: body,
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: AppButton(
              text: 'ذخیره زمان‌های کاری',
              loading: _saving,
              onPressed: _loading || _saving ? null : _save,
            ),
          ),
        ),
      );
    }

    return AuthScaffold(
      glyph: Icons.schedule_rounded,
      glyphColor: AppColors.accent,
      glyphTint: AppColors.accentTint(),
      title: 'زمان‌های کاری',
      subtitle: 'روزها و ساعات کاری کارواش خود را مشخص کنید',
      stepLabel: 'مرحله ثبت نام',
      children: _loading || _error != null
          ? <Widget>[SizedBox(height: 300, child: body)]
          : <Widget>[for (int i = 1; i <= 7; i++) _buildDayRow(i)],
      bottomButton: _loading || _error != null
          ? null
          : AppButton(
              text: 'ذخیره زمان‌های کاری',
              loading: _saving,
              onPressed: _saving ? null : _save,
            ),
    );
  }

  Widget _buildDayRow(int dayIndex) {
    final bool active = _enabled[dayIndex] == true;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      child: Opacity(
        opacity: active ? 1 : 0.55,
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                GestureDetector(
                  onTap: () =>
                      setState(() => _enabled[dayIndex] = !active),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: active ? AppColors.accent : AppColors.fill2,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: active
                        ? const Icon(Icons.check_rounded,
                            color: Colors.white, size: 18)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  Jalali.weekdays[dayIndex - 1],
                  style: TextStyle(
                    fontFamily: 'IRANYekan',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: active ? AppColors.ink : AppColors.ink3,
                  ),
                ),
                const Spacer(),
                if (active)
                  Text(
                    'از ${_labelOf(_start[dayIndex]!)} تا ${_labelOf(_end[dayIndex]!)}',
                    style: TextStyle(
                      fontFamily: 'IRANYekan',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent,
                    ),
                  ),
              ],
            ),
            if (active)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: _HourDropdown(
                        label: 'از ساعت',
                        value: _start[dayIndex]!,
                        options: _startOptions,
                        onChanged: (String v) =>
                            setState(() => _start[dayIndex] = v),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _HourDropdown(
                        label: 'تا ساعت',
                        value: _end[dayIndex]!,
                        options: _endOptions,
                        onChanged: (String v) =>
                            setState(() => _end[dayIndex] = v),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _labelOf(String hhmmss) {
    // «08:00:00» → «۸:۰۰» — ارقام با فونت یکان‌بخ فارسی دیده می‌شوند
    final List<String> parts = hhmmss.split(':');
    final int h = int.tryParse(parts[0]) ?? 0;
    final int m = int.tryParse(parts[1]) ?? 0;
    return '$h:${m.toString().padLeft(2, '0')}';
  }
}

class _HourDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  const _HourDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  static String _fmt(String hhmmss) =>
      hhmmss.length >= 5 ? hhmmss.substring(0, 5) : hhmmss;

  Future<void> _open(BuildContext context) async {
    final String? picked = await showAppSelectSheet<String>(
      context: context,
      title: label,
      items: options,
      labelOf: _fmt,
      selected: value,
    );

    if (picked != null) {
      onChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _open(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.fill,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'IRANYekan',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink3,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _fmt(value),
                      style: TextStyle(
                        fontFamily: 'IRANYekan',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.expand_more_rounded,
                  size: 20, color: AppColors.ink3),
            ],
          ),
        ),
      ),
    );
  }
}
