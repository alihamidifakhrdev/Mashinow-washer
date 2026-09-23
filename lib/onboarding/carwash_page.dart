import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/models.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import 'widgets.dart';

/// مرحله «ثبت اطلاعات کارواش» — برای step=waiting_for_profile_data
/// POST carwash/create/ (فرم چندبخشی با عکس‌ها)
class CarwashRegisterPage extends StatefulWidget {
  const CarwashRegisterPage({super.key});

  @override
  State<CarwashRegisterPage> createState() => _CarwashRegisterPageState();
}

class _CarwashRegisterPageState extends State<CarwashRegisterPage> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _address = TextEditingController();

  List<Province> _provinces = <Province>[];
  List<City> _cities = <City>[];
  Province? _province;
  City? _city;

  File? _profileImage;
  File? _licenseImage;
  File? _workspaceImage;
  File? _workspaceImageOptional;

  bool _loading = false;
  bool _loadingLookups = true;
  String? _error;

  SessionStore get _session => SessionScope.of(context);

  @override
  void initState() {
    super.initState();
    _loadLookups();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _loadLookups() async {
    try {
      final dynamic provinces = await Api.get('/carwash/provinces/');

      if (!mounted) return;

      setState(() {
        _provinces = provinces is List
            ? provinces
                .whereType<Map<String, dynamic>>()
                .map(Province.fromJson)
                .toList()
            : <Province>[];
        _loadingLookups = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingLookups = false;
        _error = 'دریافت فهرست استان‌ها ناموفق بود: ${e.message}';
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
      final dynamic cities =
          await Api.get('/carwash/cities', query: <String, dynamic>{
        'province_id': province.id,
      });

      if (!mounted) return;
      setState(() {
        _cities = cities is List
            ? cities
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

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty ||
        _phone.text.trim().isEmpty ||
        _address.text.trim().isEmpty ||
        _province == null ||
        _city == null ||
        _profileImage == null ||
        _licenseImage == null ||
        _workspaceImage == null) {
      setState(() =>
          _error = 'همه فیلدهای ستاره‌دار و سه عکس الزامی را کامل کنید');
      return;
    }

    // نشست را قبل از هر await می‌گیریم
    final SessionStore session = _session;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final FormData form = FormData();
      // «شماره مجوز» متنی حذف شد: بک‌اند ستون license_number را حذف
      // کرده (مهاجرت 0005) و فقط عکس مجوز (license_image) را نگه می‌دارد؛
      // مقدار متنی بی‌صدا دور ریخته می‌شد و بعداً هم برنمی‌گشت.
      // ⚠️ نام فایل‌های multipart باید دقیقاً با فیلدهای
      // CarWashSerializer یکی باشد؛ قبلاً carwash_photo و optional_image
      // فرستاده می‌شد که در سریالایزر وجود ندارد و عکس‌های محیط کارواش
      // بی‌صدا گم می‌شدند — حالا workspace_image و
      // workspace_image_optional فرستاده می‌شوند.
      form.fields
        ..add(MapEntry('name', _name.text.trim()))
        ..add(MapEntry('address', _address.text.trim()))
        ..add(MapEntry('phone_number', _phone.text.trim()))
        ..add(MapEntry('province', _province!.id.toString()))
        ..add(MapEntry('city', _city!.id.toString()));

      form.files.add(MapEntry(
        'profile_image',
        await MultipartFile.fromFile(
          _profileImage!.path,
          filename: 'profile.jpg',
        ),
      ));
      form.files.add(MapEntry(
        'license_image',
        await MultipartFile.fromFile(
          _licenseImage!.path,
          filename: 'license.jpg',
        ),
      ));
      form.files.add(MapEntry(
        'workspace_image',
        await MultipartFile.fromFile(
          _workspaceImage!.path,
          filename: 'workspace.jpg',
        ),
      ));
      if (_workspaceImageOptional != null) {
        form.files.add(MapEntry(
          'workspace_image_optional',
          await MultipartFile.fromFile(
            _workspaceImageOptional!.path,
            filename: 'workspace2.jpg',
          ),
        ));
      }

      await Api.postForm('/carwash/create/', form);

      await session.refreshProfileStatus();

      if (mounted) session.notifyUI();
    } on ApiException catch (e) {
      if (!mounted) return;

      final Map<String, List<String>>? fields = e.fieldErrors;
      String message = e.message;
      if (fields != null && fields.isNotEmpty) {
        message = fields.values.map((List<String> l) => l.join(' ')).join('\n');
      }

      setState(() {
        _loading = false;
        _error = message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      glyph: Icons.storefront_rounded,
      glyphColor: AppColors.accent,
      glyphTint: AppColors.accentTint(),
      title: 'ثبت اطلاعات کارواش',
      subtitle: 'اطلاعات و مدارک کارواش خود را وارد کنید',
      stepLabel: 'مرحله ثبت نام',
      children: <Widget>[
        AppTextField(
            controller: _name, label: 'نام کارواش', hint: 'مثال: کارواش پاک'),
        const SizedBox(height: 16),
        AppTextField(
          controller: _phone,
          label: 'تلفن ثابت',
          hint: 'مثال: 02188765432',
          keyboard: TextInputType.phone,
          ltr: true,
          digitsOnly: true,
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: _address,
          label: 'آدرس کامل کارواش',
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        _buildProvinceSelect(),
        const SizedBox(height: 16),
        _buildCitySelect(),
        const SizedBox(height: 20),
        ImagePickerTile(
          label: 'تصویر پروفایل',
          required_: true,
          picked: _profileImage,
          onChanged: (File? f) => setState(() => _profileImage = f),
        ),
        const SizedBox(height: 16),
        ImagePickerTile(
          label: 'عکس محیط کارواش',
          required_: true,
          picked: _workspaceImage,
          onChanged: (File? f) => setState(() => _workspaceImage = f),
        ),
        const SizedBox(height: 16),
        ImagePickerTile(
          label: 'عکس دوم محیط',
          picked: _workspaceImageOptional,
          onChanged: (File? f) => setState(() => _workspaceImageOptional = f),
        ),
        const SizedBox(height: 16),
        ImagePickerTile(
          label: 'تصویر مجوز',
          required_: true,
          picked: _licenseImage,
          onChanged: (File? f) => setState(() => _licenseImage = f),
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: 16),
          Text(
            _error!,
            style: TextStyle(
              fontFamily: 'IRANYekan',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.red,
              height: 1.8,
            ),
          ),
        ],
      ],
      bottomButton: AppButton(
        text: _loadingLookups ? 'در حال دریافت اطلاعات...' : 'ثبت اطلاعات',
        loading: _loading || _loadingLookups,
        onPressed: _loading || _loadingLookups ? null : _submit,
      ),
    );
  }

  Widget _buildProvinceSelect() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: 8, right: 4),
          child: Text(
            'استان *',
            style: TextStyle(
              fontFamily: 'IRANYekan',
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppColors.ink2,
            ),
          ),
        ),
        AppSelectField<Province>(
          value: _province,
          labelOf: (Province p) => p.name,
          items: _provinces,
          hint: 'انتخاب استان',
          sheetTitle: 'استان',
          enabled: !_loadingLookups,
          onChanged: (Province p) => _onProvinceChanged(p),
        ),
      ],
    );
  }

  Widget _buildCitySelect() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: 8, right: 4),
          child: Text(
            'شهر *',
            style: TextStyle(
              fontFamily: 'IRANYekan',
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppColors.ink2,
            ),
          ),
        ),
        AppSelectField<City>(
          value: _city,
          labelOf: (City c) => c.name,
          items: _cities,
          hint: _province == null ? 'اول استان را انتخاب کنید' : 'انتخاب شهر',
          sheetTitle: 'شهر',
          onChanged: (City c) => setState(() => _city = c),
        ),
      ],
    );
  }
}
