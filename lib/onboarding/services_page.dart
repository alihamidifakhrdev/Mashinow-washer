import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/models.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../core/ui.dart';

/// مرحله «خدمات و تعرفه‌ها» — برای step=waiting_for_services
/// و همین صفحه از تب «تنظیمات» هم برای ویرایش باز می‌شود.
///
/// هر خدمت می‌تواند برای «چند نوع خودرو» با قیمت‌های جدا ثبت شود
/// (بک‌اند unique_together روی سه‌گانه carwash/service_type/vehicle_type دارد).
///
/// GET carwash/admin/services → فهرست خدمات سراسری
/// GET carwash/admin/vehicle-types/ → فهرست انواع خودرو
/// GET carwash/carwash/services/ → خدمات فعلی کارواش
/// PUT carwash/carwash/services/ → جایگزینی کل فهرست
class ServicesSetupPage extends StatefulWidget {
  final bool asManage;

  const ServicesSetupPage({super.key, this.asManage = false});

  @override
  State<ServicesSetupPage> createState() => _ServicesSetupPageState();
}

/// یک ردیف «نوع خودرو + قیمت» داخل کارت خدمت
class _VehiclePriceEntry {
  VehicleType vehicle;
  final TextEditingController price;

  _VehiclePriceEntry({required this.vehicle, required this.price});

  void dispose() {
    price.dispose();
  }
}

class _ServiceRowState {
  final AdminService service;
  bool selected;

  /// یک آیتم به‌ازای هر نوع خودروی این خدمت
  final List<_VehiclePriceEntry> entries;

  _ServiceRowState({
    required this.service,
    required this.selected,
    required this.entries,
  });
}

class _ServicesSetupPageState extends State<ServicesSetupPage> {
  List<_ServiceRowState> _rows = <_ServiceRowState>[];
  List<VehicleType> _vehicleTypes = <VehicleType>[];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  SessionStore get _session => SessionScope.of(context);

  /// خودروی پیش‌فرض: سدان (id=1) مثل سایت، وگرنه اولین گزینه
  VehicleType get _fallbackVehicle => _vehicleTypes.firstWhere(
        (VehicleType v) => v.id == 1,
        orElse: () => _vehicleTypes.isNotEmpty
            ? _vehicleTypes.first
            : const VehicleType(id: 0, name: '—'),
      );

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final _ServiceRowState row in _rows) {
      for (final _VehiclePriceEntry entry in row.entries) {
        entry.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final List<dynamic> results = await Future.wait(<Future<dynamic>>[
        Api.get('/carwash/admin/services'),
        Api.get('/carwash/admin/vehicle-types/'),
        Api.get('/carwash/carwash/services/'),
      ]);

      if (!mounted) return;

      final List<AdminService> adminServices =
          (results[0] as List? ?? <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(AdminService.fromJson)
              .toList();

      _vehicleTypes = (results[1] as List? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(VehicleType.fromJson)
          .toList();

      final List<CarwashService> current =
          (results[2] as List? ?? <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(CarwashService.fromJson)
              .toList();

      final List<_ServiceRowState> rows = <_ServiceRowState>[];
      for (final AdminService admin in adminServices) {
        // همه‌ی رکوردهای موجودِ این خدمت (هر نوع خودرو یک رکورد)
        final List<CarwashService> existing = current
            .where((CarwashService c) => c.serviceTypeId == admin.id)
            .toList();

        final List<_VehiclePriceEntry> entries = <_VehiclePriceEntry>[];
        for (final CarwashService c in existing) {
          // نام نوع خودرو را به آبجکت لیست مپ می‌کنیم
          final VehicleType? match = _vehicleTypes
              .where((VehicleType v) => v.name == c.vehicleTypeName)
              .firstOrNull;
          entries.add(_VehiclePriceEntry(
            vehicle: match ?? _fallbackVehicle,
            price: TextEditingController(
              text: c.price > 0 ? c.price.toString() : '',
            ),
          ));
        }

        // خدمت بدون رکورد فعلی → یک ردیف خالی با پیش‌فرض
        if (entries.isEmpty) {
          entries.add(_VehiclePriceEntry(
            vehicle: _fallbackVehicle,
            price: TextEditingController(),
          ));
        }

        rows.add(_ServiceRowState(
          service: admin,
          selected: existing.isNotEmpty,
          entries: entries,
        ));
      }

      setState(() {
        _rows = rows;
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

  /// اولین نوع خودرویی که هنوز در این کارت انتخاب نشده است
  VehicleType _nextFreeVehicle(_ServiceRowState row) {
    final Set<int> used =
        row.entries.map((_VehiclePriceEntry e) => e.vehicle.id).toSet();
    return _vehicleTypes.firstWhere(
      (VehicleType v) => !used.contains(v.id),
      orElse: () => _fallbackVehicle,
    );
  }

  void _addEntry(_ServiceRowState row) {
    setState(() {
      row.entries.add(_VehiclePriceEntry(
        vehicle: _nextFreeVehicle(row),
        price: TextEditingController(),
      ));
    });
  }

  void _removeEntry(_ServiceRowState row, _VehiclePriceEntry entry) {
    // همیشه حداقل یک ردیف می‌ماند
    if (row.entries.length <= 1) return;

    setState(() {
      row.entries.remove(entry);
    });
    entry.dispose();
  }

  Future<void> _save() async {
    final List<Map<String, dynamic>> payload = <Map<String, dynamic>>[];
    final List<String> problems = <String>[];

    for (final _ServiceRowState row in _rows) {
      if (!row.selected) continue;

      // تکراری نبودن نوع خودرو داخل همان خدمت
      bool rowHasProblem = false;
      final Set<int> seenVehicles = <int>{};
      for (final _VehiclePriceEntry entry in row.entries) {
        if (!seenVehicles.add(entry.vehicle.id)) {
          problems.add(
              '«${row.service.name}»: نوع خودرو «${entry.vehicle.name}» تکراری است');
          rowHasProblem = true;
        }
      }
      if (rowHasProblem) continue;

      for (final _VehiclePriceEntry entry in row.entries) {
        final String priceText =
            entry.price.text.replaceAll(',', '').trim();

        if (priceText.isEmpty) {
          problems.add(
              '«${row.service.name}» (${entry.vehicle.name}): قیمت وارد نشده است');
          continue;
        }

        final int price = int.tryParse(priceText) ?? 0;
        if (price <= 0) {
          problems.add(
              '«${row.service.name}» (${entry.vehicle.name}): قیمت معتبر نیست');
          continue;
        }

        payload.add(<String, dynamic>{
          'service_type_id': row.service.id.toString(),
          'vehicle_type_id': entry.vehicle.id,
          'price': price,
        });
      }
    }

    if (problems.isNotEmpty) {
      showToast(context, problems.first, error: true);
      return;
    }

    if (payload.isEmpty) {
      showToast(context, 'حداقل یک خدمت را انتخاب و قیمتش را وارد کنید',
          error: true);
      return;
    }

    // نشست را قبل از هر await می‌گیریم
    final SessionStore session = _session;

    setState(() => _saving = true);

    try {
      await Api.put('/carwash/carwash/services/', data: payload);

      if (!mounted) return;

      if (widget.asManage) {
        showToast(context, 'خدمات و تعرفه‌ها ذخیره شد');
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
            ? _ErrorRetryView(message: _error!, onRetry: _load)
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
                            ..._rows.map(_buildRow),
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
        appBar: AppBar(title: const Text('خدمات و تعرفه‌ها')),
        body: body,
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: AppButton(
              text: 'ذخیره تغییرات',
              loading: _saving,
              onPressed: _loading || _saving ? null : _save,
            ),
          ),
        ),
      );
    }

    return AuthScaffold(
      glyph: Icons.list_alt_rounded,
      glyphColor: AppColors.accent,
      glyphTint: AppColors.accentTint(),
      title: 'خدمات و تعرفه‌ها',
      subtitle:
          'خدمات فعال کارواش را انتخاب کنید؛ هر خدمت را می‌توانید برای چند نوع خودرو با قیمت جدا ثبت کنید (ریال)',
      stepLabel: 'مرحله ثبت نام',
      children: _loading || _error != null
          ? <Widget>[SizedBox(height: 300, child: body)]
          : <Widget>[..._rows.map(_buildRow)],
      bottomButton: _loading || _error != null
          ? null
          : AppButton(
              text: 'ثبت خدمات',
              loading: _saving,
              onPressed: _saving ? null : _save,
            ),
    );
  }

  Widget _buildRow(_ServiceRowState row) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // :: چک‌باکس + نام خدمت + تعداد نوع خودرو
          InkWell(
            onTap: () => setState(() => row.selected = !row.selected),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Row(
              children: <Widget>[
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color:
                        row.selected ? AppColors.accent : AppColors.fill2,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: row.selected
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 17)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    row.service.name,
                    style: TextStyle(
                      fontFamily: 'IRANYekan',
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color:
                          row.selected ? AppColors.ink : AppColors.ink3,
                    ),
                  ),
                ),
                if (row.selected && row.entries.length > 1)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.accentTint(),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${row.entries.length} نوع خودرو',
                      style: TextStyle(
                        fontFamily: 'IRANYekan',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accentDeep,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // :: ردیف‌های «نوع خودرو + قیمت» — یکی به‌ازای هر نوع خودرو
          Opacity(
            opacity: row.selected ? 1 : 0.45,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (int i = 0; i < row.entries.length; i++)
                  _buildEntryRow(row, row.entries[i]),
                // :: افزودن نوع خودروی دیگر
                if (row.selected)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: TextButton.icon(
                        onPressed:
                            row.entries.length >= _vehicleTypes.length
                                ? null
                                : () => _addEntry(row),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          foregroundColor: AppColors.accent,
                        ),
                        icon: const Icon(Icons.add_circle_outline_rounded,
                            size: 17),
                        label: Text(
                          'افزودن نوع خودرو',
                          style: TextStyle(
                            fontFamily: 'IRANYekan',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryRow(_ServiceRowState row, _VehiclePriceEntry entry) {
    final bool canRemove = row.entries.length > 1;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: AppSelectField<VehicleType>(
              compact: true,
              value: entry.vehicle,
              labelOf: (VehicleType v) => v.name,
              items: _vehicleTypes,
              hint: 'نوع خودرو',
              sheetTitle: 'نوع خودرو',
              enabled: row.selected,
              onChanged: (VehicleType v) {
                setState(() => entry.vehicle = v);
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: entry.price,
              enabled: row.selected,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.left,
              textDirection: TextDirection.ltr,
              style: TextStyle(
                fontFamily: 'IRANYekan',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
              decoration: InputDecoration(
                hintText: 'قیمت (ریال)',
                hintStyle: TextStyle(
                  fontFamily: 'IRANYekan',
                  fontSize: 12.5,
                  color: AppColors.ink3,
                ),
                filled: true,
                fillColor: AppColors.fill,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 13),
                enabledBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppRadius.sm + 2),
                  borderSide:
                      const BorderSide(color: Colors.transparent),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppRadius.sm + 2),
                  borderSide: BorderSide(
                      color: AppColors.accent, width: 1.4),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppRadius.sm + 2),
                  borderSide:
                      const BorderSide(color: Colors.transparent),
                ),
              ),
            ),
          ),
          if (canRemove) ...<Widget>[
            const SizedBox(width: 4),
            _RemoveEntryButton(
              onTap: row.selected ? () => _removeEntry(row, entry) : null,
            ),
          ],
        ],
      ),
    );
  }
}

/// دکمه حذف ردیف نوع خودرو — کوچک و بی‌جنجاب
class _RemoveEntryButton extends StatelessWidget {
  final VoidCallback? onTap;

  const _RemoveEntryButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.fill,
          ),
          child: Icon(
            Icons.close_rounded,
            size: 15,
            color: onTap != null ? AppColors.ink2 : AppColors.ink3,
          ),
        ),
      ),
    );
  }
}

class _ErrorRetryView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorRetryView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.wifi_off_rounded,
      title: 'خطا در دریافت اطلاعات',
      message: message,
    );
  }
}

// دکمه تلاش مجدد زیر حالت خطا — جدا تا در همه صفحه‌ها قابل استفاده باشد
