import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import 'widgets.dart';

/// مرحله «ثبت اطلاعات فردی» — برای step=waiting_for_owner_profile
/// POST carwash/carwash/owner/profile/create/ (فرم چندبخشی با عکس کارت ملی)
class OwnerProfilePage extends StatefulWidget {
  const OwnerProfilePage({super.key});

  @override
  State<OwnerProfilePage> createState() => _OwnerProfilePageState();
}

class _OwnerProfilePageState extends State<OwnerProfilePage> {
  final TextEditingController _firstName = TextEditingController();
  final TextEditingController _lastName = TextEditingController();
  final TextEditingController _nationalCode = TextEditingController();
  final TextEditingController _phoneLandline = TextEditingController();
  final TextEditingController _homeAddress = TextEditingController();

  File? _nationalCard;

  bool _loading = false;
  String? _error;

  SessionStore get _session => SessionScope.of(context);

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _nationalCode.dispose();
    _phoneLandline.dispose();
    _homeAddress.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String nationalCode = _nationalCode.text.trim();

    if (_firstName.text.trim().isEmpty ||
        _lastName.text.trim().isEmpty ||
        nationalCode.length != 10 ||
        _phoneLandline.text.trim().isEmpty ||
        _homeAddress.text.trim().isEmpty) {
      setState(() =>
          _error = 'همه فیلدها را کامل کنید (کد ملی باید ۱۰ رقم باشد)');
      return;
    }

    if (_nationalCard == null) {
      setState(() => _error = 'تصویر کارت ملی الزامی است');
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
      form.fields
        ..add(MapEntry('first_name', _firstName.text.trim()))
        ..add(MapEntry('last_name', _lastName.text.trim()))
        ..add(MapEntry('national_code', nationalCode))
        ..add(MapEntry('phone_landline', _phoneLandline.text.trim()))
        ..add(MapEntry('home_address', _homeAddress.text.trim()));

      final String fileName = _nationalCard!.path.split('/').last;
      form.files.add(
        MapEntry(
          'national_card_image',
          await MultipartFile.fromFile(
            _nationalCard!.path,
            filename: fileName.isEmpty ? 'national_card.jpg' : fileName,
          ),
        ),
      );

      await Api.postForm('/carwash/carwash/owner/profile/create/', form);

      // وضعیت را دوباره بگیر؛ AppGate خودش به مرحله بعد می‌رود
      await session.refreshProfileStatus();

      if (mounted) session.notifyUI();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      glyph: Icons.badge_rounded,
      glyphColor: AppColors.accent,
      glyphTint: AppColors.accentTint(),
      title: 'ثبت اطلاعات فردی',
      subtitle: 'مشخصات مالک کارواش را وارد کنید',
      stepLabel: 'مرحله ثبت نام',
      children: <Widget>[
        AppTextField(controller: _firstName, label: 'نام', hint: 'مثال: علی'),
        const SizedBox(height: 16),
        AppTextField(
            controller: _lastName, label: 'نام خانوادگی', hint: 'مثال: مجیدی'),
        const SizedBox(height: 16),
        AppTextField(
          controller: _nationalCode,
          label: 'کد ملی',
          hint: 'مثال: 0712654854',
          keyboard: TextInputType.number,
          ltr: true,
          maxLength: 10,
          digitsOnly: true,
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: _phoneLandline,
          label: 'شماره تماس',
          hint: 'مثال: 09152658452',
          keyboard: TextInputType.phone,
          ltr: true,
          maxLength: 11,
          digitsOnly: true,
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: _homeAddress,
          label: 'آدرس محل سکونت',
          maxLines: 3,
        ),
        const SizedBox(height: 20),
        ImagePickerTile(
          label: 'تصویر کارت ملی',
          required_: true,
          picked: _nationalCard,
          onChanged: (File? f) => setState(() => _nationalCard = f),
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
            ),
          ),
        ],
      ],
      bottomButton: AppButton(
        text: 'ثبت و ادامه',
        icon: Icons.arrow_back_rounded,
        loading: _loading,
        onPressed: _loading ? null : _submit,
      ),
    );
  }
}
