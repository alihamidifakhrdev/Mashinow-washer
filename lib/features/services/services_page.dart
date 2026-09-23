import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mashinow_washer/core/extensions/build_context.dart';
import 'package:mashinow_washer/core/extensions/string.dart';
import 'package:mashinow_washer/core/formatters/formatters.dart';
import 'package:mashinow_washer/core/models/api_models.dart';
import 'package:mashinow_washer/core/network/server_error.dart';
import 'package:mashinow_washer/core/presentation/widgets/button.dart';
import 'package:mashinow_washer/core/presentation/widgets/sheets.dart';
import 'package:mashinow_washer/core/presentation/widgets/text_field.dart';
import 'package:mashinow_washer/core/presentation/widgets/toast.dart';
import 'package:mashinow_washer/core/presentation/widgets/view_state.dart';
import 'package:mashinow_washer/features/dashboard/dashboard_providers.dart';
import 'package:mashinow_washer/features/washer_repository.dart';

/// A draft row while editing (before being saved to the backend).
class DraftService {
  final int? id;
  final int serviceTypeId;
  final String serviceTypeName;
  final int vehicleTypeId;
  final String vehicleTypeName;
  final int price;

  const DraftService({
    this.id,
    required this.serviceTypeId,
    required this.serviceTypeName,
    required this.vehicleTypeId,
    required this.vehicleTypeName,
    required this.price,
  });
}

/// Manage car wash services and their prices (rewrite-style save).
class ServicesPage extends ConsumerStatefulWidget {
  const ServicesPage({super.key});

  @override
  ConsumerState<ServicesPage> createState() => _ServicesPageState();
}

class _ServicesPageState extends ConsumerState<ServicesPage> {
  List<DraftService>? _drafts;
  bool _dirty = false;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final types = context.types;

    final servicesAsync = ref.watch(carWashServicesProvider);
    final serviceTypesAsync = ref.watch(serviceTypesProvider);
    final vehicleTypesAsync = ref.watch(vehicleTypesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'سرویس‌ها و تعرفه‌ها',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        centerTitle: true,
      ),
      floatingActionButton: servicesAsync.hasValue &&
              serviceTypesAsync.hasValue &&
              vehicleTypesAsync.hasValue
          ? FloatingActionButton.extended(
              heroTag: 'add_service_fab',
              onPressed: () => _openEditor(
                serviceTypesAsync.value!,
                vehicleTypesAsync.value!,
                null,
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('افزودن سرویس'),
            )
          : null,
      body: servicesAsync.when(
        loading: () => const PageLoading(),
        error: (error, _) => ViewState<List<CarWashService>>(
          loading: false,
          error: error,
          data: const [],
          onRetry: () => ref.refresh(carWashServicesProvider.future),
          builder: (_) => const SizedBox.shrink(),
        ),
        data: (services) {
          // Initialize drafts once per load.
          _drafts ??= services
              .map((service) => DraftService(
                    id: service.id,
                    serviceTypeId: service.serviceType.id,
                    serviceTypeName: service.serviceType.name,
                    vehicleTypeId: -1,
                    vehicleTypeName: service.vehicleType,
                    price: service.price,
                  ))
              .toList();

          if (_drafts!.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 60),
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHigh,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.design_services_rounded,
                          size: 44, color: colors.outline),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'هنوز سرویسی ندارید',
                      style: types.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'برای اینکه مشتری‌ها بتوانند رزرو کنند،\nحداقل یک سرویس با قیمت ثبت کنید.',
                      textAlign: TextAlign.center,
                      style:
                          types.bodySmall?.copyWith(color: colors.outline),
                    ),
                  ],
                ),
              ],
            );
          }

          return Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    setState(() {
                      _drafts = null;
                      _dirty = false;
                    });
                    final _ = await ref.refresh(carWashServicesProvider.future);
                  },
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    itemCount: _drafts!.length,
                    itemBuilder: (context, index) {
                      final draft = _drafts![index];
                      return _ServiceRow(
                        draft: draft,
                        onEdit: () => _openEditor(
                          serviceTypesAsync.value ?? const [],
                          vehicleTypesAsync.value ?? const [],
                          draft,
                        ),
                        onDelete: () => setState(() {
                          _drafts!.removeAt(index);
                          _dirty = true;
                        }),
                      );
                    },
                  ),
                ),
              ),
              if (_dirty)
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: AppButton(
                      label: 'ذخیره تغییرات',
                      icon: Icons.save_rounded,
                      onPressed: _saving ? null : _save,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openEditor(
    List<ServiceType> serviceTypes,
    List<VehicleType> vehicleTypes,
    DraftService? existing,
  ) async {
    if (serviceTypes.isEmpty || vehicleTypes.isEmpty) {
      Toast.error(
        context,
        title: 'لیست انواع سرویس یا خودرو در دسترس نیست',
        description: 'اتصال اینترنت را بررسی کرده و دوباره تلاش کنید.',
      );
      return;
    }

    final result = await showAppSheet<DraftService>(
      context: context,
      scrollControlled: true,
      builder: (context) => _ServiceEditorSheet(
        serviceTypes: serviceTypes,
        vehicleTypes: vehicleTypes,
        existing: existing,
      ),
    );

    if (result == null) return;

    setState(() {
      final index =
          _drafts!.indexWhere((draft) => draft.id != null && draft.id == result.id);
      if (index >= 0) {
        _drafts![index] = result;
      } else {
        _drafts!.add(result);
      }
      _dirty = true;
    });
  }

  Future<void> _save() async {
    if (_drafts!.isEmpty) {
      Toast.error(context, title: 'حداقل یک سرویس لازم است');
      return;
    }

    setState(() => _saving = true);

    final repository = ref.read(washerRepositoryProvider);

    // Resolve vehicle type ids by name where needed.
    final vehicleTypes =
        ref.read(vehicleTypesProvider).value ?? const <VehicleType>[];

    final items = _drafts!
        .map((draft) {
          final vehicleTypeId = draft.vehicleTypeId >= 0
              ? draft.vehicleTypeId
              : _findVehicleTypeId(vehicleTypes, draft.vehicleTypeName);
          return ServiceSaveItem(
            serviceTypeId: draft.serviceTypeId,
            vehicleTypeId: vehicleTypeId,
            price: draft.price,
          );
        })
        .toList();

    try {
      final saved = await repository.saveServices(items);

      if (mounted) {
        Toast.success(context, title: 'تعرفه‌ها ذخیره شد');
        setState(() {
          _drafts = saved
              .map((service) => DraftService(
                    id: service.id,
                    serviceTypeId: service.serviceType.id,
                    serviceTypeName: service.serviceType.name,
                    vehicleTypeId: -1,
                    vehicleTypeName: service.vehicleType,
                    price: service.price,
                  ))
              .toList();
          _dirty = false;
          _saving = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        Toast.error(
          context,
          title: 'ذخیره نشد',
          description: error is ServerError ? error.message : error.toString(),
        );
      }
    }
  }

  int _findVehicleTypeId(List<VehicleType> types, String name) {
    final match = types.where((type) => type.name == name).toList();
    return match.isNotEmpty ? match.first.id : (types.isEmpty ? 1 : types.first.id);
  }
}

class _ServiceRow extends StatelessWidget {
  final DraftService draft;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ServiceRow({
    required this.draft,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final types = context.types;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.local_car_wash_rounded,
              size: 22,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  draft.serviceTypeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: types.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  draft.vehicleTypeName,
                  style: types.bodySmall?.copyWith(color: colors.outline),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${Formatter.price(draft.price)} تومان',
            style: types.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: colors.primary,
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_rounded, size: 20),
            color: colors.outline,
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_rounded, size: 20),
            color: colors.error,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// EDITOR SHEET
// ---------------------------------------------------------------------------

class _ServiceEditorSheet extends StatefulWidget {
  final List<ServiceType> serviceTypes;
  final List<VehicleType> vehicleTypes;
  final DraftService? existing;

  const _ServiceEditorSheet({
    required this.serviceTypes,
    required this.vehicleTypes,
    this.existing,
  });

  @override
  State<_ServiceEditorSheet> createState() => _ServiceEditorSheetState();
}

class _ServiceEditorSheetState extends State<_ServiceEditorSheet> {
  late ServiceType _serviceType;
  late VehicleType _vehicleType;
  final TextEditingController _priceController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _serviceType = widget.serviceTypes.firstWhere(
      (type) => type.id == widget.existing?.serviceTypeId,
      orElse: () => widget.serviceTypes.first,
    );
    _vehicleType = widget.vehicleTypes.firstWhere(
      (type) => type.name == widget.existing?.vehicleTypeName,
      orElse: () => widget.vehicleTypes.first,
    );
    _priceController.text = widget.existing != null
        ? widget.existing!.price.toString().toPersianDigits()
        : '';
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final price =
        int.tryParse(_priceController.text.trim().toEnglishDigits()) ?? 0;

    Navigator.of(context).pop(
      DraftService(
        id: widget.existing?.id,
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
    final colors = context.colors;
    final types = context.types;

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
              widget.existing == null ? 'سرویس جدید' : 'ویرایش سرویس',
              style: types.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 20),

            // :: SERVICE TYPE
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
                  .map(
                    (type) => DropdownMenuItem(
                      value: type,
                      child: Text(type.name, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _serviceType = value);
              },
            ),
            const SizedBox(height: 14),

            // :: VEHICLE TYPE
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
                  .map(
                    (type) => DropdownMenuItem(
                      value: type,
                      child: Text(type.name, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _vehicleType = value);
              },
            ),
            const SizedBox(height: 14),

            // :: PRICE
            AppTextField(
              controller: _priceController,
              label: 'قیمت (تومان)',
              hint: 'مثلاً ۱۵۰۰۰۰',
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
              label: 'تایید',
              icon: Icons.check_rounded,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
