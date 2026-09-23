import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mashinow_washer/core/extensions/build_context.dart';
import 'package:mashinow_washer/core/extensions/string.dart';
import 'package:mashinow_washer/core/network/server_error.dart';
import 'package:mashinow_washer/core/presentation/widgets/button.dart';
import 'package:mashinow_washer/core/presentation/widgets/text_field.dart';
import 'package:mashinow_washer/core/presentation/widgets/toast.dart';
import 'package:mashinow_washer/core/presentation/widgets/view_state.dart';
import 'package:mashinow_washer/features/dashboard/dashboard_providers.dart';
import 'package:mashinow_washer/features/washer_repository.dart';

/// Edit the washer's personal (owner) profile.
class OwnerProfilePage extends ConsumerStatefulWidget {
  const OwnerProfilePage({super.key});

  @override
  ConsumerState<OwnerProfilePage> createState() => _OwnerProfilePageState();
}

class _OwnerProfilePageState extends ConsumerState<OwnerProfilePage> {
  final GlobalKey<FormState> _formKey = GlobalKey();

  final TextEditingController _firstName = TextEditingController();
  final TextEditingController _lastName = TextEditingController();
  final TextEditingController _nationalCode = TextEditingController();
  final TextEditingController _landline = TextEditingController();
  final TextEditingController _homeAddress = TextEditingController();

  final ButtonController _saveButton = ButtonController();

  String? _newCardImagePath;
  bool _initialized = false;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _nationalCode.dispose();
    _landline.dispose();
    _homeAddress.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1600,
    );

    if (picked != null) {
      setState(() => _newCardImagePath = picked.path);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    _saveButton.setLoading();

    final repository = ref.read(washerRepositoryProvider);

    try {
      await repository.updateOwnerProfile(
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        nationalCode: _nationalCode.text.trim().toEnglishDigits(),
        nationalCardPath: _newCardImagePath,
        phoneLandline: _landline.text.trim().toEnglishDigits(),
        homeAddress: _homeAddress.text.trim(),
      );

      ref.invalidate(ownerProfileProvider);
      _saveButton.setSuccess();

      if (mounted) {
        Toast.success(context, title: 'اطلاعات ذخیره شد');
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) context.go('/main?tab=profile');
        });
      }
    } catch (error) {
      _saveButton.reset();
      if (mounted) {
        Toast.error(
          context,
          title: 'ذخیره نشد',
          description: error is ServerError ? error.message : error.toString(),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final types = context.types;

    final ownerAsync = ref.watch(ownerProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'اطلاعات کارواش‌دار',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        centerTitle: true,
      ),
      body: ownerAsync.when(
        loading: () => const PageLoading(),
        error: (error, _) => ViewState(
          loading: false,
          error: error,
          onRetry: () => ref.refresh(ownerProfileProvider.future),
          builder: (_) => const SizedBox.shrink(),
        ),
        data: (owner) {
          if (!_initialized) {
            _initialized = true;
            _firstName.text = owner.firstName;
            _lastName.text = owner.lastName;
            _nationalCode.text = owner.nationalCode ?? '';
            _landline.text = owner.phoneLandline ?? '';
            _homeAddress.text = owner.homeAddress ?? '';
          }

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // :: NATIONAL CARD
                Center(
                  child: Column(
                    children: [
                      InkWell(
                        onTap: _pickImage,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 150,
                          height: 100,
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: colors.outlineVariant),
                          ),
                          child: _newCardImagePath != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Image.file(
                                    File(_newCardImagePath!),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.badge_rounded,
                                      size: 40,
                                    ),
                                  ),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.badge_rounded,
                                        size: 34, color: colors.outline),
                                    const SizedBox(height: 6),
                                    Text(
                                      'تصویر کارت ملی',
                                      style: types.bodySmall
                                          ?.copyWith(color: colors.outline),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'برای تغییر، تصویر جدیدی انتخاب کنید',
                        style: types.bodySmall?.copyWith(
                          color: colors.outline,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                AppTextField(
                  controller: _firstName,
                  label: 'نام',
                  icon: Icons.person_rounded,
                  validator: (value) =>
                      (value?.trim().isEmpty ?? true) ? 'نام را وارد کنید' : null,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _lastName,
                  label: 'نام خانوادگی',
                  icon: Icons.person_outline_rounded,
                  validator: (value) => (value?.trim().isEmpty ?? true)
                      ? 'نام خانوادگی را وارد کنید'
                      : null,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _nationalCode,
                  label: 'کد ملی',
                  type: AppTextFieldType.number,
                  icon: Icons.badge_rounded,
                  validator: (value) {
                    final text = value?.trim().toEnglishDigits() ?? '';
                    if (text.isEmpty) return null;
                    if (!RegExp(r'^\d{10}$').hasMatch(text)) {
                      return 'کد ملی باید ۱۰ رقم باشد';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _landline,
                  label: 'تلفن ثابت (اختیاری)',
                  type: AppTextFieldType.phone,
                  icon: Icons.phone_rounded,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _homeAddress,
                  label: 'آدرس منزل (اختیاری)',
                  icon: Icons.home_rounded,
                  maxLines: 2,
                ),

                const SizedBox(height: 28),
                AppButton(
                  label: 'ذخیره',
                  icon: Icons.save_rounded,
                  controller: _saveButton,
                  onPressed: _save,
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}
