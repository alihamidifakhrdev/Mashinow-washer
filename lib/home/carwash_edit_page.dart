import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../core/ui.dart';

/// ویرایش اطلاعات کارواش — PUT carwash/profile/ (قرارداد با تست زنده تأیید شده)
class CarwashEditPage extends StatefulWidget {
  const CarwashEditPage({super.key});

  @override
  State<CarwashEditPage> createState() => _CarwashEditPageState();
}

class _CarwashEditPageState extends State<CarwashEditPage> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _address = TextEditingController();

  List<Province> _provinces = <Province>[];
  List<City> _cities = <City>[];
  Province? _province;
  City? _city;

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
    _address.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final dynamic profileData = await Api.get('/carwash/profile');
      final dynamic provincesData = await Api.get('/carwash/provinces/');

      if (!mounted) return;

      if (profileData is! Map<String, dynamic>) {
        throw const ApiException('اطلاعات کارواش دریافت نشد');
      }

      final CarwashProfile profile = CarwashProfile.fromJson(profileData);

      _provinces = provincesData is List
          ? provincesData
              .whereType<Map<String, dynamic>>()
              .map(Province.fromJson)
              .toList()
          : <Province>[];

      _province = _provinces
          .where((Province p) => p.id == profile.province)
          .firstOrNull;

      _name.text = profile.name;
      _phone.text = profile.phoneNumber;
      _address.text = profile.address;

      // شهر فعلی را از استان مربوطه بگیر
      if (_province != null) {
        final dynamic citiesData = await Api.get(
          '/carwash/cities',
          query: <String, dynamic>{'province_id': _province!.id},
        );

        if (!mounted) return;

        _cities = citiesData is List
            ? citiesData
                .whereType<Map<String, dynamic>>()
                .map(City.fromJson)
                .toList()
            : <City>[];

        _city =
            _cities.where((City c) => c.id == profile.city).firstOrNull;
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

  Future<void> _onProvinceChanged(Province? province) async {
    setState(() {
      _province = province;
      _city = null;
      _cities = <City>[];
    });

    if (province == null) return;

    try {
      final dynamic citiesData = await Api.get(
        '/carwash/cities',
        query: <String, dynamic>{'province_id': province.id},
      );

      if (!mounted) return;
      setState(() {
        _cities = citiesData is List
            ? citiesData
                .whereType<Map<String, dynamic>>()
                .map(City.fromJson)
                .toList()
            : <City>[];
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      showToast(context, e.message, error: true);
    }
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _phone.text.trim().isEmpty) {
      showToast(context, 'نام کارواش و تلفن الزامی است', error: true);
      return;
    }

    setState(() => _saving = true);

    try {
      // فیلد «شماره مجوز» حذف شد: بک‌اند این ستون را حذف کرده
      // (مهاجرت 0005) و فقط license_image (عکس مجوز) را نگه می‌دارد؛
      // CarWashUpdateSerializer هیچ فیلد مجوزی ندارد و مقدار ارسالی
      // بی‌صدا دور ریخته می‌شد. عکس مجوز فقط هنگام ثبت اولیه آپلود
      // می‌شود و در همین فرم ویرایش هم قابل تغییر نیست.
      await Api.put(
        '/carwash/profile/',
        data: <String, dynamic>{
          'name': _name.text.trim(),
          'phone_number': _phone.text.trim(),
          'address': _address.text.trim(),
          if (_province != null) 'province': _province!.id,
          if (_city != null) 'city': _city!.id,
        },
      );

      if (!mounted) return;
      showToast(context, 'تغییرات ذخیره شد');
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
      appBar: AppBar(title: const Text('ویرایش اطلاعات کارواش')),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _error != null
              ? ListView(
                  children: <Widget>[
                    const SizedBox(height: 100),
                    EmptyState(
                      icon: Icons.wifi_off_rounded,
                      title: 'خطا در دریافت اطلاعات',
                      message: _error!,
                    ),
                  ],
                )
              : LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
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
                                label: 'نام کارواش',
                              ),
                              const SizedBox(height: 16),
                              AppTextField(
                                controller: _phone,
                                label: 'تلفن',
                                keyboard: TextInputType.phone,
                                ltr: true,
                              ),
                              const SizedBox(height: 16),
                              AppTextField(
                                controller: _address,
                                label: 'آدرس',
                                maxLines: 3,
                              ),
                              const SizedBox(height: 16),
                              _buildDropdown<Province>(
                                label: 'استان',
                                value: _province,
                                items: _provinces,
                                itemName: (Province p) => p.name,
                                onChanged: (Province p) =>
                                    _onProvinceChanged(p),
                              ),
                              const SizedBox(height: 16),
                              _buildDropdown<City>(
                                label: 'شهر',
                                value: _city,
                                items: _cities,
                                itemName: (City c) => c.name,
                                hint: _province == null
                                    ? 'اول استان را انتخاب کنید'
                                    : 'انتخاب شهر',
                                onChanged: (City c) => setState(() => _city = c),
                              ),
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
                  text: 'ذخیره تغییرات',
                  loading: _saving,
                  onPressed: _saving ? null : _save,
                ),
              ),
            ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) itemName,
    required ValueChanged<T> onChanged,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: 8, right: 4),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'IRANYekan',
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppColors.ink2,
            ),
          ),
        ),
        AppSelectField<T>(
          value: value,
          labelOf: itemName,
          items: items,
          hint: hint,
          sheetTitle: label,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
