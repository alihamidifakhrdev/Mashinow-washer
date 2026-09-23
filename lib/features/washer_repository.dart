import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mashinow_washer/core/models/api_models.dart';
import 'package:mashinow_washer/core/network/server_error.dart';
import 'package:mashinow_washer/core/providers/dio.dart';

/// All washer-side backend calls in one repository.
class WasherRepository {
  final Dio _dio;

  const WasherRepository(this._dio);

  // -------------------------------------------------------------------------
  // REGISTRATION STATUS
  // -------------------------------------------------------------------------

  /// Returns true when both the owner profile and the car wash exist.
  Future<bool> isRegistrationComplete() async {
    // Preferred: the dedicated status endpoint.
    try {
      final response = await _dio.get('/status/profile-status/');
      final data = response.data;

      if (data is Map<String, dynamic> && data.containsKey('completed')) {
        return data['completed'] == true;
      }
    } on DioException {
      // Fall through to the 404-based fallback below.
    }

    // Fallback: probe both profiles directly.
    bool ownerOk = false;
    bool carwashOk = false;

    try {
      await _dio.get('/carwash/carwash/owner/profile/');
      ownerOk = true;
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      // 404 → not created yet. Anything else (401/500/…) rethrows.
      if (status != 404) {
        throw ServerError.fromDio(error);
      }
    }

    try {
      await _dio.get('/carwash/profile/');
      carwashOk = true;
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status != 404) {
        throw ServerError.fromDio(error);
      }
    }

    return ownerOk && carwashOk;
  }

  // -------------------------------------------------------------------------
  // OWNER PROFILE
  // -------------------------------------------------------------------------

  Future<OwnerProfile> getOwnerProfile() async {
    try {
      final response = await _dio.get('/carwash/carwash/owner/profile/');
      return OwnerProfile.fromJson(
        response.data as Map<String, dynamic>? ?? {},
      );
    } on DioException catch (error) {
      throw ServerError.fromDio(error);
    }
  }

  /// Creates the owner profile. [nationalCardPath] is a local image file.
  Future<OwnerProfile> createOwnerProfile({
    required String firstName,
    required String lastName,
    String? nationalCode,
    required String nationalCardPath,
    String? phoneLandline,
    String? homeAddress,
  }) async {
    final form = FormData.fromMap({
      'first_name': firstName,
      'last_name': lastName,
      'national_code': nationalCode,
      'phone_landline': phoneLandline,
      'home_address': homeAddress,
    });

    form.files.add(MapEntry(
      'national_card_image',
      await MultipartFile.fromFile(
        nationalCardPath,
        filename: 'national_card.jpg',
      ),
    ));

    try {
      final response =
          await _dio.post('/carwash/carwash/owner/profile/create/', data: form);
      return OwnerProfile.fromJson(
        response.data as Map<String, dynamic>? ?? {},
      );
    } on DioException catch (error) {
      throw ServerError.fromDio(error);
    }
  }

  /// Updates the owner profile (photo optional).
  Future<OwnerProfile> updateOwnerProfile({
    required String firstName,
    required String lastName,
    String? nationalCode,
    String? nationalCardPath,
    String? phoneLandline,
    String? homeAddress,
  }) async {
    final form = FormData.fromMap({
      'first_name': firstName,
      'last_name': lastName,
      'national_code': nationalCode,
      'phone_landline': phoneLandline,
      'home_address': homeAddress,
    });

    if (nationalCardPath != null) {
      form.files.add(MapEntry(
        'national_card_image',
        await MultipartFile.fromFile(
          nationalCardPath,
          filename: 'national_card.jpg',
        ),
      ));
    }

    try {
      final response =
          await _dio.put('/carwash/carwash/owner/profile/', data: form);
      return OwnerProfile.fromJson(
        response.data as Map<String, dynamic>? ?? {},
      );
    } on DioException catch (error) {
      throw ServerError.fromDio(error);
    }
  }

  // -------------------------------------------------------------------------
  // CAR WASH PROFILE
  // -------------------------------------------------------------------------

  Future<CarWash> getCarWashProfile() async {
    try {
      final response = await _dio.get('/carwash/profile/');
      return CarWash.fromJson(response.data as Map<String, dynamic>? ?? {});
    } on DioException catch (error) {
      throw ServerError.fromDio(error);
    }
  }

  Future<CarWash> createCarWash({
    required String name,
    required String phoneNumber,
    required String address,
    int? province,
    int? city,
    bool isMobile = false,
    String? profileImagePath,
    String? workspaceImagePath,
    String? licenseImagePath,
  }) async {
    final form = FormData.fromMap({
      'name': name,
      'phone_number': phoneNumber,
      'address': address,
      'province': province,
      'city': city,
      'is_mobile': isMobile,
    });

    Future<void> addFile(String field, String? path) async {
      if (path == null) return;
      form.files.add(MapEntry(
        field,
        await MultipartFile.fromFile(path, filename: '$field.jpg'),
      ));
    }

    await addFile('profile_image', profileImagePath);
    await addFile('workspace_image', workspaceImagePath);
    await addFile('license_image', licenseImagePath);

    try {
      final response = await _dio.post('/carwash/create/', data: form);
      return CarWash.fromJson(response.data as Map<String, dynamic>? ?? {});
    } on DioException catch (error) {
      throw ServerError.fromDio(error);
    }
  }

  Future<CarWash> updateCarWash({
    required String name,
    required String phoneNumber,
    required String address,
    int? province,
    int? city,
    bool? isMobile,
  }) async {
    try {
      final response = await _dio.put(
        '/carwash/profile/',
        data: {
          'name': name,
          'phone_number': phoneNumber,
          'address': address,
          'province': province,
          'city': city,
          'is_mobile': isMobile,
        },
      );
      return CarWash.fromJson(response.data as Map<String, dynamic>? ?? {});
    } on DioException catch (error) {
      throw ServerError.fromDio(error);
    }
  }

  // -------------------------------------------------------------------------
  // LOCATIONS
  // -------------------------------------------------------------------------

  Future<List<Province>> getProvinces() async {
    try {
      final response = await _dio.get('/carwash/provinces/');
      return normalizeList(response.data)
          .map(Province.fromJson)
          .toList(growable: false);
    } on DioException catch (error) {
      throw ServerError.fromDio(error);
    }
  }

  Future<List<City>> getCities({required int provinceId}) async {
    try {
      final response = await _dio.get(
        '/carwash/cities/',
        queryParameters: {'province_id': provinceId},
      );
      return normalizeList(response.data)
          .map(City.fromJson)
          .toList(growable: false);
    } on DioException catch (error) {
      throw ServerError.fromDio(error);
    }
  }

  // -------------------------------------------------------------------------
  // SERVICE CATALOGS + CAR WASH SERVICES
  // -------------------------------------------------------------------------

  Future<List<ServiceType>> getServiceTypes() async {
    try {
      final response = await _dio.get('/carwash/admin/services/');
      return normalizeList(response.data)
          .map(ServiceType.fromJson)
          .toList(growable: false);
    } on DioException catch (error) {
      throw ServerError.fromDio(error);
    }
  }

  Future<List<VehicleType>> getVehicleTypes() async {
    try {
      final response = await _dio.get('/carwash/admin/vehicle-types/');
      return normalizeList(response.data)
          .map(VehicleType.fromJson)
          .toList(growable: false);
    } on DioException catch (error) {
      throw ServerError.fromDio(error);
    }
  }

  Future<List<CarWashService>> getServices() async {
    try {
      final response = await _dio.get('/carwash/carwash/services/');
      return normalizeList(response.data)
          .map(CarWashService.fromJson)
          .toList(growable: false);
    } on DioException catch (error) {
      throw ServerError.fromDio(error);
    }
  }

  /// Rewrites the full service list ("بازنویسی کامل سرویس‌ها").
  Future<List<CarWashService>> saveServices(List<ServiceSaveItem> items) async {
    final payload = items
        .map((item) => {
              'service_type_id': item.serviceTypeId,
              'vehicle_type_id': item.vehicleTypeId,
              'price': item.price,
            })
        .toList();

    try {
      await _dio.put('/carwash/carwash/services/', data: payload);
    } on DioException catch (error) {
      final status = error.response?.statusCode;

      // Some backends expect a single upsert object instead of a list.
      if (status == 400 && payload.isNotEmpty) {
        try {
          for (final item in payload) {
            await _dio.put('/carwash/carwash/services/', data: item);
          }
        } on DioException catch (fallbackError) {
          throw ServerError.fromDio(fallbackError);
        }
      } else {
        throw ServerError.fromDio(error);
      }
    }

    return getServices();
  }

  // -------------------------------------------------------------------------
  // BOOKINGS
  // -------------------------------------------------------------------------

  Future<List<Booking>> getBookings({DateTime? date}) async {
    try {
      final response = await _dio.get(
        '/carwash/bookings/',
        queryParameters: date == null
            ? null
            : {
                'date': '${date.year.toString().padLeft(4, '0')}-'
                    '${date.month.toString().padLeft(2, '0')}-'
                    '${date.day.toString().padLeft(2, '0')}',
              },
      );
      return normalizeList(response.data)
          .map(Booking.fromJson)
          .toList(growable: false);
    } on DioException catch (error) {
      throw ServerError.fromDio(error);
    }
  }

  Future<void> updateBookingStatus({
    required int bookingId,
    required String status,
  }) async {
    try {
      await _dio.put(
        '/carwash/carwash/bookings/$bookingId/status/',
        data: {'status': status},
      );
    } on DioException catch (error) {
      throw ServerError.fromDio(error);
    }
  }

  // -------------------------------------------------------------------------
  // TIME SLOTS + GUEST BOOKINGS
  // -------------------------------------------------------------------------

  Future<List<TimeSlot>> getTimeSlots() async {
    try {
      final response = await _dio.get('/carwash/time-slots/');
      return normalizeList(response.data)
          .map(TimeSlot.fromJson)
          .toList(growable: false);
    } on DioException catch (error) {
      throw ServerError.fromDio(error);
    }
  }

  Future<void> createGuestBooking({
    required String customerName,
    required String customerPhone,
    required String carModel,
    required int timeSlotId,
    required List<int> serviceIds,
  }) async {
    try {
      await _dio.post(
        '/carwash/carwash/guest-booking/create/',
        data: {
          'customer_name': customerName,
          'customer_phone': customerPhone,
          'car_model': carModel,
          'time_slot': timeSlotId,
          'service_ids': serviceIds,
        },
      );
    } on DioException catch (error) {
      throw ServerError.fromDio(error);
    }
  }

  Future<List<GuestBooking>> getGuestBookings() async {
    try {
      final response = await _dio.get('/carwash/carwash/guest-bookings/');
      return normalizeList(response.data)
          .map(GuestBooking.fromJson)
          .toList(growable: false);
    } on DioException catch (error) {
      throw ServerError.fromDio(error);
    }
  }

  // -------------------------------------------------------------------------
  // WORKING SESSIONS
  // -------------------------------------------------------------------------

  Future<List<WorkingSession>> getWorkingSessions() async {
    try {
      final response = await _dio.get('/carwash/working-sessions/');
      return normalizeList(response.data)
          .map(WorkingSession.fromJson)
          .toList(growable: false);
    } on DioException catch (error) {
      throw ServerError.fromDio(error);
    }
  }

  /// Bulk-creates working sessions for the coming days.
  Future<void> saveWorkingSessions(List<WorkingSessionSaveItem> items) async {
    final payload = items
        .map((item) => {
              'start_datetime': item.start.toUtc().toIso8601String(),
              'end_datetime': item.end.toUtc().toIso8601String(),
            })
        .toList();

    try {
      await _dio.post('/carwash/working-sessions/create/', data: payload);
    } on DioException catch (error) {
      throw ServerError.fromDio(error);
    }
  }

  // -------------------------------------------------------------------------
  // WALLET
  // -------------------------------------------------------------------------

  Future<Wallet> getWallet() async {
    try {
      final response = await _dio.get('/wallet/wallet/');
      return Wallet.fromJson(response.data as Map<String, dynamic>? ?? {});
    } on DioException catch (error) {
      throw ServerError.fromDio(error);
    }
  }

  // -------------------------------------------------------------------------
  // RATINGS
  // -------------------------------------------------------------------------

  Future<List<CarWashRating>> getRatings({required int carWashId}) async {
    try {
      final response =
          await _dio.get('/rating/carwash/$carWashId/ratings/');
      return normalizeList(response.data)
          .map(CarWashRating.fromJson)
          .toList(growable: false);
    } on DioException catch (error) {
      throw ServerError.fromDio(error);
    }
  }

  // -------------------------------------------------------------------------
  // WEEKLY STATS (defensive parsing — response shape may vary)
  // -------------------------------------------------------------------------

  Future<List<StatEntry>> getWeeklyStats() async {
    try {
      final response = await _dio.get('/carwash/carwash/stats/weekly/');
      return StatEntry.parse(response.data);
    } on DioException catch (error) {
      throw ServerError.fromDio(error);
    }
  }
}

/// A single service row to save.
class ServiceSaveItem {
  final int serviceTypeId;
  final int vehicleTypeId;
  final int price;

  const ServiceSaveItem({
    required this.serviceTypeId,
    required this.vehicleTypeId,
    required this.price,
  });
}

/// A single working session to save.
class WorkingSessionSaveItem {
  final DateTime start;
  final DateTime end;

  const WorkingSessionSaveItem({required this.start, required this.end});
}

/// One key/value stat row (defensively parsed).
class StatEntry {
  final String label;
  final String displayValue;

  const StatEntry({required this.label, required this.displayValue});

  static const _labels = {
    'weeks_active': 'هفته‌های فعال',
    'avg_daily_income': 'میانگین درآمد روزانه',
    'most_popular_service': 'محبوب‌ترین سرویس',
    'customer_satisfaction': 'رضایت مشتری',
    'bookings': 'رزروها',
    'bookings_count': 'تعداد رزرو',
    'total_bookings': 'کل رزروها',
    'count': 'تعداد',
    'income': 'درآمد',
    'total_income': 'کل درآمد',
    'revenue': 'درآمد',
    'done': 'انجام‌شده',
    'cancelled': 'لغوشده',
    'reserved': 'رزروشده',
  };

  static List<StatEntry> parse(dynamic body) {
    final entries = <StatEntry>[];

    String? displayValue(Object? value) {
      if (value is num) {
        if (value == value.roundToDouble()) {
          return value.round().toString();
        }
        return value.toStringAsFixed(1);
      }
      if (value is String && value.trim().isNotEmpty) return value.trim();
      return null;
    }

    if (body is Map<String, dynamic>) {
      body.forEach((key, value) {
        final text = displayValue(value);
        if (text != null) {
          entries.add(
            StatEntry(label: _labels[key] ?? key, displayValue: text),
          );
        }
      });
    } else if (body is List) {
      for (final item in body) {
        if (item is Map<String, dynamic>) {
          final label = item['label'] ?? item['name'] ?? item['title'];
          final value = item['value'] ?? item['count'] ?? item['amount'];
          final text = displayValue(value);
          if (label is String && text != null) {
            entries.add(StatEntry(label: label, displayValue: text));
          }
        }
      }
    }

    return entries;
  }
}

final washerRepositoryProvider = Provider<WasherRepository>(
  (ref) => WasherRepository(ref.watch(dioProvider)),
);
