import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mashinow_washer/core/extensions/build_context.dart';
import 'package:mashinow_washer/core/extensions/string.dart';
import 'package:mashinow_washer/core/formatters/formatters.dart';
import 'package:mashinow_washer/core/models/api_models.dart';
import 'package:mashinow_washer/core/network/server_error.dart';
import 'package:mashinow_washer/core/presentation/widgets/button.dart';
import 'package:mashinow_washer/core/presentation/widgets/text_field.dart';
import 'package:mashinow_washer/core/presentation/widgets/toast.dart';
import 'package:mashinow_washer/core/providers/app_auth.dart';
import 'package:mashinow_washer/features/dashboard/dashboard_providers.dart';
import 'package:mashinow_washer/features/washer_repository.dart';
import 'package:mashinow_washer/features/services/services_page.dart'
    show DraftService;

/// Registration wizard: owner info → carwash info → working hours → tariffs.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  // :: STEP 1 — OWNER
  final GlobalKey<FormState> _ownerFormKey = GlobalKey();
  final TextEditingController _firstName = TextEditingController();
  final TextEditingController _lastName = TextEditingController();
  final TextEditingController _nationalCode = TextEditingController();
  final TextEditingController _landline = TextEditingController();
  final TextEditingController _homeAddress = TextEditingController();
  String? _nationalCardPath;
  bool _ownerProfileExists = false;

  // :: STEP 2 — CAR WASH
  final GlobalKey<FormState> _carWashFormKey = GlobalKey();
  final TextEditingController _carWashName = TextEditingController();
  final TextEditingController _carWashPhone = TextEditingController();
  final TextEditingController _carWashAddress = TextEditingController();
  Province? _province;
  City? _city;
  String? _profileImagePath;
  String? _workspaceImagePath;

  // :: STEP 3 — WORKING HOURS
  final Map<int, bool> _dayEnabled = {};
  final Map<int, TimeOfDay> _dayStart = {};
  final Map<int, TimeOfDay> _dayEnd = {};

  // :: STEP 4 — SERVICES
  final List<DraftService> _serviceDrafts = [];

  // :: FLOW STATE
  int _step = 0;
  bool _loading = false;
  bool _initialized = false;

  static const _stepTitles = [
    'اطلاعات کارواش‌دار',
    'اطلاعات کارواش',
    'ساعات کاری',
    'تعرفه سرویس‌ها',
  ];

  @override
  void initState() {
    super.initState();
    _initWorkingHoursDefaults();
    _preloadState();
  }

  void _initWorkingHoursDefaults() {
    final now = DateTime.now();
    final saturday = _nextWeekday(now, DateTime.saturday);

    for (int i = 0; i < 7; i++) {
      final day = saturday.add(Duration(days: i));
      _dayEnabled[day.day] = day.weekday != DateTime.friday;
      _dayStart[day.day] = const TimeOfDay(hour: 9, minute: 0);
      _dayEnd[day.day] = const TimeOfDay(hour: 18, minute: 0);
    }
  }

  DateTime _nextWeekday(DateTime from, int weekday) {
    var day = DateTime(from.year, from.month, from.day);
    while (day.weekday != weekday) {
      day = day.add(const Duration(days: 1));
    }
    return day;
  }

  Future<void> _preloadState() async {
    final repository = ref.read(washerRepositoryProvider);

    // Prefill owner profile if it already exists (partial registration).
    try {
      final owner = await repository.getOwnerProfile();
      if (mounted) {
        setState(() {
          _ownerProfileExists = true;
          _firstName.text = owner.firstName;
          _lastName.text = owner.lastName;
          _nationalCode.text = owner.nationalCode ?? '';
          _landline.text = owner.phoneLandline ?? '';
          _homeAddress.text = owner.homeAddress ?? '';
        });
      }
    } catch (_) {/* 404 → first registration */}

    // Load existing services, if any.
    try {
      final services = await repository.getServices();
      if (mounted && services.isNotEmpty) {
        final vehicleTypes = await repository.getVehicleTypes();
        setState(() {
          _serviceDrafts.addAll(
            services
                .map((service) => DraftService(
                      id: service.id,
                      serviceTypeId: service.serviceType.id,
                      serviceTypeName: service.serviceType.name,
                      vehicleTypeId: _vehicleTypeIdFor(
                          vehicleTypes, service.vehicleType),
                      vehicleTypeName: service.vehicleType,
                      price: service.price,
                    ))
                .toList(),
          );
        });
      }
    } catch (_) {/* ignore */}

    if (mounted) setState(() => _initialized = true);
  }

  int _vehicleTypeIdFor(List<VehicleType> types, String name) {
    for (final type in types) {
      if (type.name == name) return type.id;
    }
    return -1;
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _nationalCode.dispose();
    _landline.dispose();
    _homeAddress.dispose();
    _carWashName.dispose();
    _carWashPhone.dispose();
    _carWashAddress.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // STEP NAVIGATION
  // -------------------------------------------------------------------------

  bool _validateStep() {
    switch (_step) {
      case 0:
        if (_ownerProfileExists) return true;
        if (!_ownerFormKey.currentState!.validate()) return false;
        if (_nationalCardPath == null) {
          Toast.error(context, title: 'تصویر کارت ملی الزامی است');
          return false;
        }
        return true;
      case 1:
        return _carWashFormKey.currentState!.validate();
      case 2:
        final anyEnabled = _dayEnabled.values.any((enabled) => enabled);
        if (!anyEnabled) {
          Toast.error(context, title: 'حداقل یک روز باید فعال باشد');
          return false;
        }
        return true;
      case 3:
        if (_serviceDrafts.isEmpty) {
          Toast.error(
            context,
            title: 'حداقل یک سرویس ثبت کنید',
            description: 'مشتری‌ها برای رزرو به تعرفه سرویس‌ها نیاز دارند.',
          );
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  Future<void> _next() async {
    if (!_validateStep()) return;

    setState(() => _loading = true);

    final repository = ref.read(washerRepositoryProvider);

    try {
      switch (_step) {
        case 0:
          if (!_ownerProfileExists) {
            await repository.createOwnerProfile(
              firstName: _firstName.text.trim(),
              lastName: _lastName.text.trim(),
              nationalCode: _nationalCode.text.trim().toEnglishDigits(),
              nationalCardPath: _nationalCardPath!,
              phoneLandline: _landline.text.trim().toEnglishDigits(),
              homeAddress: _homeAddress.text.trim(),
            );
            _ownerProfileExists = true;
          }
          break;

        case 1:
          await repository.createCarWash(
            name: _carWashName.text.trim(),
            phoneNumber: _carWashPhone.text.trim().toEnglishDigits(),
            address: _carWashAddress.text.trim(),
            province: _province?.id,
            city: _city?.id,
            profileImagePath: _profileImagePath,
            workspaceImagePath: _workspaceImagePath,
          );
          break;

        case 2:
          final saturday =
              _nextWeekday(DateTime.now(), DateTime.saturday);

          final items = <WorkingSessionSaveItem>[];
          for (int i = 0; i < 7; i++) {
            final day = saturday.add(Duration(days: i));
            if (_dayEnabled[day.day] != true) continue;

            final start = _dayStart[day.day]!;
            final end = _dayEnd[day.day]!;

            items.add(
              WorkingSessionSaveItem(
                start: DateTime(
                    day.year, day.month, day.day, start.hour, start.minute),
                end: DateTime(
                    day.year, day.month, day.day, end.hour, end.minute),
              ),
            );
          }

          if (items.isNotEmpty) {
            await repository.saveWorkingSessions(items);
          }
          break;

        case 3:
          // Resolve vehicle type ids.
          final vehicleTypes = await repository.getVehicleTypes();
          final payload = _serviceDrafts
              .map((draft) => ServiceSaveItem(
                    serviceTypeId: draft.serviceTypeId,
                    vehicleTypeId: draft.vehicleTypeId >= 0
                        ? draft.vehicleTypeId
                        : _vehicleTypeIdFor(
                            vehicleTypes, draft.vehicleTypeName),
                    price: draft.price,
                  ))
              .toList();
          await repository.saveServices(payload);
          break;
      }

      if (_step == 3) {
        // :: FINISH
        ref.read(appAuthProvider.notifier).completeProfile();
        ref.invalidate(carWashProfileProvider);
        ref.invalidate(todayBookingsProvider);

        if (mounted) {
          Toast.success(context, title: 'ثبت‌نام کامل شد؛ خوش آمدید!');
          context.go('/main');
        }
      } else if (mounted) {
        setState(() => _step += 1);
      }
    } on ServerError catch (error) {
      if (mounted) {
        Toast.error(
          context,
          title: 'ثبت اطلاعات ناموفق بود',
          description: error.message,
        );
      }
    } catch (error) {
      if (mounted) {
        Toast.error(
          context,
          title: 'ثبت اطلاعات ناموفق بود',
          description: error.toString(),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // -------------------------------------------------------------------------
  // IMAGE PICKERS
  // -------------------------------------------------------------------------

  Future<void> _pickImage(void Function(String path) onPicked) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (picked != null) {
      setState(() => onPicked(picked.path));
    }
  }

  // -------------------------------------------------------------------------
  // BUILD
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final types = context.types;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'ثبت‌نام کارواش',
          style: types.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
      ),
      body: !_initialized
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // :: PROGRESS
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            'مرحله ${(_step + 1).toString().toPersianDigits()} از ۴',
                            style: types.bodySmall
                                ?.copyWith(color: colors.outline),
                          ),
                          const Spacer(),
                          Text(
                            _stepTitles[_step],
                            style: types.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: (_step + 1) / 4,
                          minHeight: 8,
                          color: colors.primary,
                          backgroundColor:
                              colors.surfaceContainerHighest,
                        ),
                      ),
                    ],
                  ),
                ),

                // :: STEP CONTENT
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _buildStep(),
                  ),
                ),

                // :: NAVIGATION
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Row(
                      children: [
                        if (_step > 0)
                          Expanded(
                            child: OutlinedButton(
                              onPressed:
                                  _loading ? null : () => setState(() => _step -= 1),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text('مرحله قبل'),
                            ),
                          ),
                        if (_step > 0) const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: AppButton(
                            label: _step == 3 ? 'پایان و شروع' : 'مرحله بعد',
                            icon: _step == 3
                                ? Icons.rocket_launch_rounded
                                : Icons.arrow_forward_rounded,
                            onPressed: _loading ? null : _next,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _buildOwnerStep();
      case 1:
        return _buildCarWashStep();
      case 2:
        return _buildWorkingHoursStep();
      case 3:
        return _buildServicesStep();
      default:
        return const SizedBox.shrink();
    }
  }

  // STEP 1 — OWNER ----------------------------------------------------------------

  Widget _buildOwnerStep() {
    final colors = context.colors;
    final types = context.types;

    return ListView(
      key: const ValueKey(0),
      padding: const EdgeInsets.all(20),
      children: [
        if (_ownerProfileExists)
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xff16a34a).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Color(0xff16a34a), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'اطلاعات کارواش‌دار قبلا ثبت شده است. در صورت نیاز می‌توانید بعدا از بخش پروفایل ویرایش کنید.',
                    style: types.bodySmall?.copyWith(height: 1.6),
                  ),
                ),
              ],
            ),
          ),
        Form(
          key: _ownerFormKey,
          child: Column(
            children: [
              AppTextField(
                controller: _firstName,
                label: 'نام',
                icon: Icons.person_rounded,
                validator: (value) => (value?.trim().isEmpty ?? true)
                    ? 'نام را وارد کنید'
                    : null,
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
            ],
          ),
        ),
        const SizedBox(height: 20),

        // :: NATIONAL CARD IMAGE
        Text(
          'تصویر کارت ملی',
          style: types.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _ownerProfileExists
              ? null
              : () => _pickImage((path) => _nationalCardPath = path),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: 130,
            width: double.infinity,
            decoration: BoxDecoration(
              color: colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _nationalCardPath == null && !_ownerProfileExists
                    ? colors.error.withValues(alpha: 0.4)
                    : colors.outlineVariant,
              ),
            ),
            child: _nationalCardPath != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.file(
                      File(_nationalCardPath!),
                      fit: BoxFit.cover,
                    ),
                  )
                : _ownerProfileExists
                    ? Icon(Icons.verified_rounded,
                        size: 40, color: const Color(0xff16a34a))
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_rounded,
                              size: 36, color: colors.outline),
                          const SizedBox(height: 8),
                          Text(
                            'برای انتخاب تصویر بزنید',
                            style: types.bodySmall
                                ?.copyWith(color: colors.outline),
                          ),
                        ],
                      ),
          ),
        ),
      ],
    );
  }

  // STEP 2 — CAR WASH --------------------------------------------------------------

  Widget _buildCarWashStep() {
    final colors = context.colors;
    final provincesAsync = ref.watch(provincesProvider);

    final citiesAsync = _province == null
        ? null
        : ref.watch(citiesProvider(_province!.id));

    return ListView(
      key: const ValueKey(1),
      padding: const EdgeInsets.all(20),
      children: [
        Form(
          key: _carWashFormKey,
          child: Column(
            children: [
              AppTextField(
                controller: _carWashName,
                label: 'نام کارواش',
                icon: Icons.store_rounded,
                validator: (value) => (value?.trim().isEmpty ?? true)
                    ? 'نام کارواش را وارد کنید'
                    : null,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _carWashPhone,
                label: 'شماره تماس کارواش',
                type: AppTextFieldType.phone,
                icon: Icons.phone_rounded,
                validator: (value) {
                  final text = value?.trim().toEnglishDigits() ?? '';
                  if (text.isEmpty) return 'شماره تماس را وارد کنید';
                  if (!RegExp(r'^0\d{9,11}$').hasMatch(text)) {
                    return 'شماره تماس معتبر نیست';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // :: PROVINCE
              provincesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Text(
                  'خطا در دریافت استان‌ها: $error',
                  style: TextStyle(color: colors.error, fontSize: 12),
                ),
                data: (provinces) => DropdownButtonFormField<Province>(
                  initialValue: _province,
                  decoration: _dropdownDecoration(colors, 'استان'),
                  items: provinces
                      .map((province) => DropdownMenuItem(
                            value: province,
                            child: Text(
                              province.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() {
                    _province = value;
                    _city = null;
                  }),
                  validator: (value) =>
                      value == null ? 'استان را انتخاب کنید' : null,
                ),
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
                            .map((city) => DropdownMenuItem(
                                  value: city,
                                  child: Text(
                                    city.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ))
                            .toList(),
                        onChanged: (value) => setState(() => _city = value),
                        validator: (value) =>
                            value == null ? 'شهر را انتخاب کنید' : null,
                      ),
              const SizedBox(height: 12),

              AppTextField(
                controller: _carWashAddress,
                label: 'آدرس کارواش',
                icon: Icons.location_on_rounded,
                maxLines: 2,
                validator: (value) => (value?.trim().isEmpty ?? true)
                    ? 'آدرس را وارد کنید'
                    : null,
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // :: IMAGES (optional)
        Text(
          'تصاویر کارواش (اختیاری)',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _ImagePickerTile(
                icon: Icons.storefront_rounded,
                label: 'نمای کارواش',
                path: _profileImagePath,
                onTap: () =>
                    _pickImage((path) => _profileImagePath = path),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ImagePickerTile(
                icon: Icons.photo_camera_back_rounded,
                label: 'محیط کار',
                path: _workspaceImagePath,
                onTap: () =>
                    _pickImage((path) => _workspaceImagePath = path),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // STEP 3 — WORKING HOURS ------------------------------------------------------------

  Widget _buildWorkingHoursStep() {
    final colors = context.colors;
    final types = context.types;

    final saturday = _nextWeekday(DateTime.now(), DateTime.saturday);
    final days = List.generate(7, (i) => saturday.add(Duration(days: i)));

    return ListView(
      key: const ValueKey(2),
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(Icons.info_rounded, color: colors.primary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'روزهای کاری و ساعت شروع و پایان هر روز را مشخص کنید. مشتری‌ها فقط در این بازه‌ها می‌توانند رزرو کنند.',
                  style: types.bodySmall?.copyWith(height: 1.6),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...days.map((day) {
          final enabled = _dayEnabled[day.day] ?? false;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: enabled
                  ? colors.surfaceContainerHigh
                  : colors.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${Formatter.weekdayName(day)} — ${Formatter.jalaliDate(day)}',
                        style: types.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color:
                              enabled ? colors.onSurface : colors.outline,
                        ),
                      ),
                    ),
                    Switch(
                      value: enabled,
                      onChanged: (value) =>
                          setState(() => _dayEnabled[day.day] = value),
                    ),
                  ],
                ),
                if (enabled)
                  Row(
                    children: [
                      Expanded(
                        child: _TimeButton(
                          label: Formatter.timeOfDay(_dayStart[day.day]!),
                          isStart: true,
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: _dayStart[day.day]!,
                            );
                            if (picked != null) {
                              setState(() => _dayStart[day.day] = picked);
                            }
                          },
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('تا'),
                      ),
                      Expanded(
                        child: _TimeButton(
                          label: Formatter.timeOfDay(_dayEnd[day.day]!),
                          isStart: false,
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: _dayEnd[day.day]!,
                            );
                            if (picked != null) {
                              setState(() => _dayEnd[day.day] = picked);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // STEP 4 — SERVICES ----------------------------------------------------------------

  Widget _buildServicesStep() {
    final colors = context.colors;
    final types = context.types;

    final serviceTypesAsync = ref.watch(serviceTypesProvider);
    final vehicleTypesAsync = ref.watch(vehicleTypesProvider);

    return ListView(
      key: const ValueKey(3),
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'تعرفه خدمات خود را مشخص کنید',
          style: types.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'مثلاً: آب‌شوئی کامل — سواری — ۱۵۰٬۰۰۰ تومان',
          style: types.bodySmall?.copyWith(color: colors.outline),
        ),
        const SizedBox(height: 16),

        ..._serviceDrafts.asMap().entries.map(
              (entry) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.value.serviceTypeName,
                            style: types.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '${entry.value.vehicleTypeName} — ${Formatter.price(entry.value.price)} تومان',
                            style: types.bodySmall
                                ?.copyWith(color: colors.outline),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_rounded,
                          size: 20, color: colors.error),
                      onPressed: () => setState(
                        () => _serviceDrafts.removeAt(entry.key),
                      ),
                    ),
                  ],
                ),
              ),
            ),

        const SizedBox(height: 8),

        // :: ADD SERVICE BUTTON
        serviceTypesAsync.hasValue && vehicleTypesAsync.hasValue
            ? OutlinedButton.icon(
                onPressed: () => _addServiceSheet(
                  serviceTypesAsync.value!,
                  vehicleTypesAsync.value!,
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('افزودن سرویس'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              )
            : serviceTypesAsync.isLoading || vehicleTypesAsync.isLoading
                ? const Center(child: CircularProgressIndicator())
                : Text(
                    'خطا در دریافت لیست سرویس‌ها',
                    style: TextStyle(color: colors.error, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
      ],
    );
  }

  Future<void> _addServiceSheet(
    List<ServiceType> serviceTypes,
    List<VehicleType> vehicleTypes,
  ) async {
    final result = await showModalBottomSheet<DraftService>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => _OnboardingServiceSheet(
        serviceTypes: serviceTypes,
        vehicleTypes: vehicleTypes,
      ),
    );

    if (result != null) {
      setState(() => _serviceDrafts.add(result));
    }
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

// ---------------------------------------------------------------------------
// SUPPORT WIDGETS
// ---------------------------------------------------------------------------

class _ImagePickerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? path;
  final VoidCallback onTap;

  const _ImagePickerTile({
    required this.icon,
    required this.label,
    required this.path,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final types = context.types;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: path != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.file(File(path!), fit: BoxFit.cover),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 30, color: colors.outline),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: types.bodySmall?.copyWith(color: colors.outline),
                  ),
                ],
              ),
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  final String label;
  final bool isStart;
  final VoidCallback onTap;

  const _TimeButton({
    required this.label,
    required this.isStart,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isStart ? Icons.play_arrow_rounded : Icons.stop_rounded,
              size: 16,
              color: colors.primary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: colors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet for adding one service during onboarding.
class _OnboardingServiceSheet extends StatefulWidget {
  final List<ServiceType> serviceTypes;
  final List<VehicleType> vehicleTypes;

  const _OnboardingServiceSheet({
    required this.serviceTypes,
    required this.vehicleTypes,
  });

  @override
  State<_OnboardingServiceSheet> createState() =>
      _OnboardingServiceSheetState();
}

class _OnboardingServiceSheetState extends State<_OnboardingServiceSheet> {
  late ServiceType _serviceType;
  late VehicleType _vehicleType;
  final TextEditingController _price = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _serviceType = widget.serviceTypes.first;
    _vehicleType = widget.vehicleTypes.first;
  }

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final price = int.tryParse(_price.text.trim().toEnglishDigits()) ?? 0;

    Navigator.of(context).pop(
      DraftService(
        serviceTypeId: _serviceType.id,
        serviceTypeName: _serviceType.name,
        vehicleTypeId: _vehicleType.id,
        vehicleTypeName: _vehicleType.name,
        price: price,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final types = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'افزودن سرویس',
              style: types.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<ServiceType>(
              initialValue: _serviceType,
              decoration: InputDecoration(
                labelText: 'نوع سرویس',
                filled: true,
                fillColor: colors.surfaceContainerHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
              items: widget.serviceTypes
                  .map((type) => DropdownMenuItem(
                        value: type,
                        child:
                            Text(type.name, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _serviceType = value);
              },
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<VehicleType>(
              initialValue: _vehicleType,
              decoration: InputDecoration(
                labelText: 'نوع خودرو',
                filled: true,
                fillColor: colors.surfaceContainerHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
              items: widget.vehicleTypes
                  .map((type) => DropdownMenuItem(
                        value: type,
                        child:
                            Text(type.name, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _vehicleType = value);
              },
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _price,
              label: 'قیمت (تومان)',
              type: AppTextFieldType.price,
              icon: Icons.payments_rounded,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              validator: (value) {
                final text = value?.trim().toEnglishDigits() ?? '';
                if (text.isEmpty) return 'قیمت را وارد کنید';
                final price = int.tryParse(text);
                if (price == null || price <= 0) return 'قیمت معتبر نیست';
                return null;
              },
            ),
            const SizedBox(height: 20),
            AppButton(
              label: 'افزودن',
              icon: Icons.check_rounded,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
