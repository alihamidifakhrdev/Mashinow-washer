import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mashinow_washer/core/extensions/build_context.dart';
import 'package:mashinow_washer/core/models/api_models.dart';
import 'package:mashinow_washer/core/network/server_error.dart';
import 'package:mashinow_washer/core/presentation/widgets/button.dart';
import 'package:mashinow_washer/core/presentation/widgets/text_field.dart';
import 'package:mashinow_washer/core/presentation/widgets/toast.dart';
import 'package:mashinow_washer/core/presentation/widgets/view_state.dart';
import 'package:mashinow_washer/features/dashboard/dashboard_providers.dart';
import 'package:mashinow_washer/features/washer_repository.dart';

/// Edit the car wash profile (name, phone, province/city, address).
class CarWashEditPage extends ConsumerStatefulWidget {
  const CarWashEditPage({super.key});

  @override
  ConsumerState<CarWashEditPage> createState() => _CarWashEditPageState();
}

class _CarWashEditPageState extends ConsumerState<CarWashEditPage> {
  final GlobalKey<FormState> _formKey = GlobalKey();

  final TextEditingController _name = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _address = TextEditingController();

  final ButtonController _saveButton = ButtonController();

  bool _initialized = false;
  Province? _province;
  City? _city;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    _saveButton.setLoading();

    final repository = ref.read(washerRepositoryProvider);

    try {
      await repository.updateCarWash(
        name: _name.text.trim(),
        phoneNumber: _phone.text.trim(),
        address: _address.text.trim(),
        province: _province?.id,
        city: _city?.id,
      );

      ref.invalidate(carWashProfileProvider);
      ref.invalidate(todayBookingsProvider);
      _saveButton.setSuccess();

      if (mounted) {
        Toast.success(context, title: 'اطلاعات کارواش ذخیره شد');
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
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final carWashAsync = ref.watch(carWashProfileProvider);
    final provincesAsync = ref.watch(provincesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'اطلاعات کارواش',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        centerTitle: true,
      ),
      body: carWashAsync.when(
        loading: () => const PageLoading(),
        error: (error, _) => ViewState<CarWash>(
          loading: false,
          error: error,
          onRetry: () => ref.refresh(carWashProfileProvider.future),
          builder: (_) => const SizedBox.shrink(),
        ),
        data: (carWash) {
          final provinces = provincesAsync.value ?? const <Province>[];

          if (!_initialized && provinces.isNotEmpty) {
            _initialized = true;
            _name.text = carWash.name;
            _phone.text = carWash.phoneNumber;
            _address.text = carWash.address;

            final matchedProvince = provinces
                .where((province) => province.id == carWash.province)
                .toList();
            _province =
                matchedProvince.isNotEmpty ? matchedProvince.first : null;

            if (_province != null) {
              // Cities load asynchronously; preselect once available.
              ref.listen(citiesProvider(_province!.id), (_, next) {
                final cities = next.value;
                if (cities == null || _city != null || !mounted) return;
                final matched = cities
                    .where((city) => city.id == carWash.city)
                    .toList();
                if (matched.isNotEmpty) {
                  setState(() => _city = matched.first);
                }
              });
            }
          }

          final citiesAsync = _province == null
              ? null
              : ref.watch(citiesProvider(_province!.id));

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                AppTextField(
                  controller: _name,
                  label: 'نام کارواش',
                  icon: Icons.store_rounded,
                  validator: (value) => (value?.trim().isEmpty ?? true)
                      ? 'نام کارواش را وارد کنید'
                      : null,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _phone,
                  label: 'شماره تماس کارواش',
                  type: AppTextFieldType.phone,
                  icon: Icons.phone_rounded,
                  validator: (value) => (value?.trim().isEmpty ?? true)
                      ? 'شماره تماس را وارد کنید'
                      : null,
                ),
                const SizedBox(height: 16),

                // :: PROVINCE
                DropdownButtonFormField<Province>(
                  initialValue: _province,
                  decoration: _dropdownDecoration(colors, 'استان'),
                  items: provinces
                      .map(
                        (province) => DropdownMenuItem(
                          value: province,
                          child: Text(
                            province.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() {
                    _province = value;
                    _city = null;
                  }),
                  validator: (value) =>
                      value == null ? 'استان را انتخاب کنید' : null,
                ),
                const SizedBox(height: 12),

                // :: CITY
                if (_province != null)
                  (citiesAsync == null || citiesAsync.isLoading)
                      ? const Center(child: CircularProgressIndicator())
                      : DropdownButtonFormField<City>(
                          initialValue: _city,
                          decoration: _dropdownDecoration(colors, 'شهر'),
                          items: (citiesAsync.value ?? const <City>[])
                              .map(
                                (city) => DropdownMenuItem(
                                  value: city,
                                  child: Text(
                                    city.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => setState(() => _city = value),
                          validator: (value) =>
                              value == null ? 'شهر را انتخاب کنید' : null,
                        ),
                const SizedBox(height: 12),

                AppTextField(
                  controller: _address,
                  label: 'آدرس',
                  icon: Icons.location_on_rounded,
                  maxLines: 2,
                  validator: (value) => (value?.trim().isEmpty ?? true)
                      ? 'آدرس را وارد کنید'
                      : null,
                ),

                const SizedBox(height: 28),
                AppButton(
                  label: 'ذخیره',
                  icon: Icons.save_rounded,
                  controller: _saveButton,
                  onPressed: _saving ? null : _save,
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  InputDecoration _dropdownDecoration(ColorScheme colors, String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: colors.surfaceContainerHigh,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }
}
