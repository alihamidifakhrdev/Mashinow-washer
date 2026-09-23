import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mashinow_washer/core/extensions/build_context.dart';
import 'package:mashinow_washer/core/extensions/string.dart';
import 'package:mashinow_washer/core/formatters/formatters.dart';
import 'package:mashinow_washer/core/models/api_models.dart';
import 'package:mashinow_washer/core/network/server_error.dart';
import 'package:mashinow_washer/core/presentation/widgets/button.dart';
import 'package:mashinow_washer/core/presentation/widgets/text_field.dart';
import 'package:mashinow_washer/core/presentation/widgets/toast.dart';
import 'package:mashinow_washer/core/presentation/widgets/view_state.dart';
import 'package:mashinow_washer/features/dashboard/dashboard_providers.dart';
import 'package:mashinow_washer/features/washer_repository.dart';

/// Registers a walk-in (guest) booking: customer name/phone, car model,
/// time slot and selected services.
class GuestBookingPage extends ConsumerStatefulWidget {
  const GuestBookingPage({super.key});

  @override
  ConsumerState<GuestBookingPage> createState() => _GuestBookingPageState();
}

class _GuestBookingPageState extends ConsumerState<GuestBookingPage> {
  final GlobalKey<FormState> _formKey = GlobalKey();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _carModelController = TextEditingController();

  final ButtonController _saveButton = ButtonController();

  TimeSlot? _selectedSlot;
  final Set<int> _selectedServiceIds = {};

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _carModelController.dispose();
    super.dispose();
  }

  int get _totalPrice {
    final services =
        ref.read(carWashServicesProvider).value ?? <CarWashService>[];
    var total = 0;
    for (final service in services) {
      if (_selectedServiceIds.contains(service.id)) {
        total += service.price;
      }
    }
    return total;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_selectedSlot == null) {
      Toast.error(context, title: 'ساعت مراجعه را انتخاب کنید');
      return;
    }

    if (_selectedServiceIds.isEmpty) {
      Toast.error(context, title: 'حداقل یک سرویس را انتخاب کنید');
      return;
    }

    _saveButton.setLoading();

    final repository = ref.read(washerRepositoryProvider);

    try {
      await repository.createGuestBooking(
        customerName: _nameController.text.trim(),
        customerPhone: _phoneController.text.trim().toEnglishDigits(),
        carModel: _carModelController.text.trim(),
        timeSlotId: _selectedSlot!.id,
        serviceIds: _selectedServiceIds.toList(),
      );

      _saveButton.setSuccess();

      if (mounted) {
        Toast.success(context, title: 'رزرو حضوری ثبت شد');
        ref.invalidate(guestBookingsProvider);
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) context.go('/main');
        });
      }
    } catch (error) {
      _saveButton.reset();
      if (mounted) {
        Toast.error(
          context,
          title: 'ثبت رزرو ناموفق بود',
          description: error is ServerError ? error.message : error.toString(),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final types = context.types;

    final slotsAsync = ref.watch(timeSlotsProvider);
    final servicesAsync = ref.watch(carWashServicesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'رزرو مشتری حضوری',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // :: CUSTOMER INFO
            Text('اطلاعات مشتری', style: types.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            AppTextField(
              controller: _nameController,
              label: 'نام و نام خانوادگی',
              hint: 'مثلاً علی رضایی',
              icon: Icons.person_rounded,
              textInputAction: TextInputAction.next,
              validator: (value) =>
                  (value?.trim().isEmpty ?? true) ? 'نام مشتری را وارد کنید' : null,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _phoneController,
              label: 'شماره موبایل',
              hint: '۰۹۱۲۳۴۵۶۷۸۹',
              type: AppTextFieldType.phone,
              icon: Icons.phone_rounded,
              textInputAction: TextInputAction.next,
              validator: (value) {
                final text = value?.trim().toEnglishDigits() ?? '';
                if (text.isEmpty) return 'شماره موبایل را وارد کنید';
                if (!RegExp(r'^09\d{9}$').hasMatch(text)) {
                  return 'شماره موبایل معتبر نیست';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _carModelController,
              label: 'خودرو',
              hint: 'مثلاً پژو ۲۰۶',
              icon: Icons.directions_car_rounded,
              textInputAction: TextInputAction.done,
              validator: (value) =>
                  (value?.trim().isEmpty ?? true) ? 'مدل خودرو را وارد کنید' : null,
            ),

            const SizedBox(height: 24),

            // :: TIME SLOT
            Text('ساعت مراجعه', style: types.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            slotsAsync.when(
              loading: () => const PageLoading(),
              error: (error, _) => ViewState<List<TimeSlot>>(
                loading: false,
                error: error,
                data: const [],
                onRetry: () => ref.refresh(timeSlotsProvider.future),
                builder: (_) => const SizedBox.shrink(),
              ),
              data: (slots) {
                final available =
                    slots.where((slot) => !slot.isReserved).toList()
                      ..sort((a, b) => a.startTime.compareTo(b.startTime));

                if (available.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'ساعت آزادی باقی نمانده است. ابتدا ساعات کاری این هفته را تعیین کنید.',
                      style: types.bodySmall?.copyWith(color: colors.outline),
                    ),
                  );
                }

                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: available
                      .map((slot) => _SlotChip(
                            slot: slot,
                            selected: _selectedSlot?.id == slot.id,
                            onTap: () => setState(() => _selectedSlot = slot),
                          ))
                      .toList(),
                );
              },
            ),

            const SizedBox(height: 24),

            // :: SERVICES
            Text('سرویس‌ها', style: types.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            servicesAsync.when(
              loading: () => const PageLoading(),
              error: (error, _) => ViewState<List<CarWashService>>(
                loading: false,
                error: error,
                data: const [],
                onRetry: () => ref.refresh(carWashServicesProvider.future),
                builder: (_) => const SizedBox.shrink(),
              ),
              data: (services) {
                if (services.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'هنوز سرویسی ثبت نکرده‌اید. از تب «سرویس‌ها» تعرفه‌ها را اضافه کنید.',
                      style: types.bodySmall?.copyWith(color: colors.outline),
                    ),
                  );
                }

                return Column(
                  children: services
                      .map((service) => _ServiceCheckTile(
                            service: service,
                            checked: _selectedServiceIds.contains(service.id),
                            onChanged: (checked) => setState(() {
                              if (checked) {
                                _selectedServiceIds.add(service.id);
                              } else {
                                _selectedServiceIds.remove(service.id);
                              }
                            }),
                          ))
                      .toList(),
                );
              },
            ),

            const SizedBox(height: 28),

            // :: TOTAL + SAVE
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Text(
                    'مبلغ کل',
                    style: types.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  Text(
                    '${_selectedServiceIds.isEmpty ? '۰' : Formatter.price(_totalPrice)} تومان',
                    style: types.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppButton(
              label: 'ثبت رزرو',
              icon: Icons.check_circle_rounded,
              controller: _saveButton,
              onPressed: _save,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _SlotChip extends StatelessWidget {
  final TimeSlot slot;
  final bool selected;
  final VoidCallback onTap;

  const _SlotChip({
    required this.slot,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? colors.primary : colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? colors.primary : colors.outlineVariant,
          ),
        ),
        child: Text(
          Formatter.time(slot.startTime),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected ? colors.onPrimary : colors.onSurface,
          ),
        ),
      ),
    );
  }
}

class _ServiceCheckTile extends StatelessWidget {
  final CarWashService service;
  final bool checked;
  final ValueChanged<bool> onChanged;

  const _ServiceCheckTile({
    required this.service,
    required this.checked,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final types = context.types;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: CheckboxListTile(
        value: checked,
        onChanged: (value) => onChanged(value ?? false),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        controlAffinity: ListTileControlAffinity.leading,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          '${service.serviceType.name} (${service.vehicleType})',
          style: types.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${Formatter.price(service.price)} تومان',
          style: types.bodySmall?.copyWith(color: colors.primary),
        ),
      ),
    );
  }
}
