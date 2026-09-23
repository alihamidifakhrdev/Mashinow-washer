// Data models for the washer (car wash owner) side of the Mashinow API.
// All models use manual JSON serialization — no code generation required.

// ---------------------------------------------------------------------------
// OWNER PROFILE
// ---------------------------------------------------------------------------

class OwnerProfile {
  final String firstName;
  final String lastName;
  final String? nationalCode;
  final String? nationalCardImage;
  final String? phoneLandline;
  final String? homeAddress;
  final String status;

  const OwnerProfile({
    required this.firstName,
    required this.lastName,
    this.nationalCode,
    this.nationalCardImage,
    this.phoneLandline,
    this.homeAddress,
    this.status = 'pending',
  });

  factory OwnerProfile.fromJson(Map<String, dynamic> json) => OwnerProfile(
        firstName: json['first_name'] as String? ?? '',
        lastName: json['last_name'] as String? ?? '',
        nationalCode: json['national_code'] as String?,
        nationalCardImage: json['national_card_image'] as String?,
        phoneLandline: json['phone_landline'] as String?,
        homeAddress: json['home_address'] as String?,
        status: json['status'] as String? ?? 'pending',
      );

  String get fullName => '$firstName $lastName'.trim();

  bool get isApproved => status == 'approved';
}

// ---------------------------------------------------------------------------
// CAR WASH
// ---------------------------------------------------------------------------

class CarWash {
  final int id;
  final String name;
  final String phoneNumber;
  final int? province;
  final int? city;
  final String address;
  final String? profileImage;
  final String? workspaceImage;
  final String? licenseImage;
  final bool isMobile;
  final bool isActive;
  final double? averageRating;
  final int? minPrice;
  final int? maxPrice;

  const CarWash({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.province,
    this.city,
    required this.address,
    this.profileImage,
    this.workspaceImage,
    this.licenseImage,
    this.isMobile = false,
    this.isActive = true,
    this.averageRating,
    this.minPrice,
    this.maxPrice,
  });

  factory CarWash.fromJson(Map<String, dynamic> json) => CarWash(
        id: json['id'] as int? ?? 0,
        name: json['name'] as String? ?? '',
        phoneNumber: json['phone_number'] as String? ?? '',
        province: json['province'] as int?,
        city: json['city'] as int?,
        address: json['address'] as String? ?? '',
        profileImage: json['profile_image'] as String?,
        workspaceImage: json['workspace_image'] as String?,
        licenseImage: json['license_image'] as String?,
        isMobile: json['is_mobile'] as bool? ?? false,
        isActive: json['is_active'] as bool? ?? true,
        averageRating: (json['average_rating'] as num?)?.toDouble(),
        minPrice: json['min_price'] as int?,
        maxPrice: json['max_price'] as int?,
      );
}

// ---------------------------------------------------------------------------
// LOCATIONS
// ---------------------------------------------------------------------------

class Province {
  final int id;
  final String name;

  const Province({required this.id, required this.name});

  factory Province.fromJson(Map<String, dynamic> json) => Province(
        id: json['id'] as int? ?? 0,
        name: json['name'] as String? ?? '',
      );
}

class City {
  final int id;
  final String name;
  final int province;

  const City({
    required this.id,
    required this.name,
    required this.province,
  });

  factory City.fromJson(Map<String, dynamic> json) => City(
        id: json['id'] as int? ?? 0,
        name: json['name'] as String? ?? '',
        province: json['province'] as int? ?? 0,
      );
}

// ---------------------------------------------------------------------------
// SERVICES
// ---------------------------------------------------------------------------

class ServiceType {
  final int id;
  final String name;

  const ServiceType({required this.id, required this.name});

  factory ServiceType.fromJson(Map<String, dynamic> json) => ServiceType(
        id: json['id'] as int? ?? 0,
        name: json['name'] as String? ?? '',
      );
}

class VehicleType {
  final int id;
  final String name;

  const VehicleType({required this.id, required this.name});

  factory VehicleType.fromJson(Map<String, dynamic> json) => VehicleType(
        id: json['id'] as int? ?? 0,
        name: json['name'] as String? ?? '',
      );
}

class CarWashService {
  final int id;
  final ServiceType serviceType;
  final String vehicleType;
  final int price;

  const CarWashService({
    required this.id,
    required this.serviceType,
    required this.vehicleType,
    required this.price,
  });

  factory CarWashService.fromJson(Map<String, dynamic> json) => CarWashService(
        id: json['id'] as int? ?? 0,
        serviceType:
            ServiceType.fromJson(json['service_type'] as Map<String, dynamic>? ?? {}),
        vehicleType: json['vehicle_type'] as String? ?? '',
        price: json['price'] as int? ?? 0,
      );
}

// ---------------------------------------------------------------------------
// BOOKINGS
// ---------------------------------------------------------------------------

class BookingCar {
  final int id;
  final String type;
  final String model;

  const BookingCar({
    required this.id,
    required this.type,
    required this.model,
  });

  factory BookingCar.fromJson(Map<String, dynamic> json) => BookingCar(
        id: json['id'] as int? ?? 0,
        type: json['car_type'] as String? ?? '',
        model: json['car_model'] as String? ?? '',
      );
}

class Booking {
  final int id;
  final String? trackingCode;
  final String serviceType;
  final String status;
  final BookingCar car;
  final DateTime date;
  final DateTime startTime;
  final DateTime endTime;
  final String paymentMethod;
  final List<CarWashService> services;
  final bool isMobileService;
  final String? customerAddress;
  final DateTime createdAt;

  const Booking({
    required this.id,
    this.trackingCode,
    required this.serviceType,
    required this.status,
    required this.car,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.paymentMethod,
    required this.services,
    this.isMobileService = false,
    this.customerAddress,
    required this.createdAt,
  });

  factory Booking.fromJson(Map<String, dynamic> json) => Booking(
        id: json['id'] as int? ?? 0,
        trackingCode: json['tracking_code'] as String?,
        serviceType: json['service_type'] as String? ?? '',
        status: json['status'] as String? ?? 'reserved',
        car: BookingCar.fromJson(json['car'] as Map<String, dynamic>? ?? {}),
        date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
        startTime:
            DateTime.tryParse(json['start_time'] as String? ?? '') ?? DateTime.now(),
        endTime:
            DateTime.tryParse(json['end_time'] as String? ?? '') ?? DateTime.now(),
        paymentMethod: json['payment_method'] as String? ?? 'in_place',
        services: (json['services'] as List<dynamic>? ?? [])
            .map((item) => CarWashService.fromJson(item as Map<String, dynamic>))
            .toList(),
        isMobileService: json['is_mobile_service'] as bool? ?? false,
        customerAddress: json['customer_address'] as String?,
        createdAt:
            DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      );

  int get totalPrice =>
      services.fold(0, (sum, service) => sum + service.price);

  bool get isReserved => status == 'reserved';
  bool get isDone => status == 'done';
  bool get isCancelled => status == 'cancelled';
}

// ---------------------------------------------------------------------------
// GUEST BOOKINGS
// ---------------------------------------------------------------------------

class TimeSlot {
  final int id;
  final DateTime startTime;
  final DateTime endTime;
  final bool isReserved;

  const TimeSlot({
    required this.id,
    required this.startTime,
    required this.endTime,
    this.isReserved = false,
  });

  factory TimeSlot.fromJson(Map<String, dynamic> json) => TimeSlot(
        id: json['id'] as int? ?? 0,
        startTime:
            DateTime.tryParse(json['start_time'] as String? ?? '') ?? DateTime.now(),
        endTime:
            DateTime.tryParse(json['end_time'] as String? ?? '') ?? DateTime.now(),
        isReserved: json['is_reserved'] as bool? ?? false,
      );
}

class GuestBooking {
  final int id;
  final String customerName;
  final String customerPhone;
  final String carModel;
  final TimeSlot timeSlot;
  final List<CarWashService> services;
  final DateTime createdAt;

  const GuestBooking({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.carModel,
    required this.timeSlot,
    required this.services,
    required this.createdAt,
  });

  factory GuestBooking.fromJson(Map<String, dynamic> json) => GuestBooking(
        id: json['id'] as int? ?? 0,
        customerName: json['customer_name'] as String? ?? '',
        customerPhone: json['customer_phone'] as String? ?? '',
        carModel: json['car_model'] as String? ?? '',
        timeSlot:
            TimeSlot.fromJson(json['time_slot'] as Map<String, dynamic>? ?? {}),
        services: (json['services'] as List<dynamic>? ?? [])
            .map((item) => CarWashService.fromJson(item as Map<String, dynamic>))
            .toList(),
        createdAt:
            DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      );

  int get totalPrice =>
      services.fold(0, (sum, service) => sum + service.price);
}

// ---------------------------------------------------------------------------
// WORKING SESSIONS
// ---------------------------------------------------------------------------

class WorkingSession {
  final int id;
  final DateTime startTime;
  final DateTime endTime;

  const WorkingSession({
    required this.id,
    required this.startTime,
    required this.endTime,
  });

  factory WorkingSession.fromJson(Map<String, dynamic> json) => WorkingSession(
        id: json['id'] as int? ?? 0,
        startTime: DateTime.tryParse(json['start_datetime'] as String? ?? '') ??
            DateTime.now(),
        endTime: DateTime.tryParse(json['end_datetime'] as String? ?? '') ??
            DateTime.now(),
      );
}

// ---------------------------------------------------------------------------
// WALLET
// ---------------------------------------------------------------------------

class WalletTransaction {
  final int id;
  final int amount;
  final String transactionType;
  final String? description;
  final DateTime createdAt;

  const WalletTransaction({
    required this.id,
    required this.amount,
    required this.transactionType,
    this.description,
    required this.createdAt,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) =>
      WalletTransaction(
        id: json['id'] as int? ?? 0,
        amount: json['amount'] as int? ?? 0,
        transactionType: json['transaction_type'] as String? ?? '',
        description: json['description'] as String?,
        createdAt:
            DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      );

  bool get isIncome => amount >= 0;
}

class Wallet {
  final int id;
  final int balance;
  final List<WalletTransaction> transactions;

  const Wallet({
    required this.id,
    required this.balance,
    required this.transactions,
  });

  factory Wallet.fromJson(Map<String, dynamic> json) => Wallet(
        id: json['id'] as int? ?? 0,
        balance: json['balance'] as int? ?? 0,
        transactions: (json['transactions'] as List<dynamic>? ?? [])
            .map((item) =>
                WalletTransaction.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
}

// ---------------------------------------------------------------------------
// RATINGS
// ---------------------------------------------------------------------------

class CarWashRating {
  final int id;
  final int rating;
  final String? comment;
  final DateTime createdAt;

  const CarWashRating({
    required this.id,
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  factory CarWashRating.fromJson(Map<String, dynamic> json) => CarWashRating(
        id: json['id'] as int? ?? 0,
        rating: (json['rating'] as num?)?.toInt() ?? 0,
        comment: json['comment'] as String?,
        createdAt:
            DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      );
}

// ---------------------------------------------------------------------------
// HELPERS
// ---------------------------------------------------------------------------

/// Normalizes a JSON body that may be a list, a single object or a wrapped
/// object ({'results': [...]}) into a list of maps.
List<Map<String, dynamic>> normalizeList(dynamic body) {
  if (body is List) {
    return body
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }
  if (body is Map<String, dynamic>) {
    final results = body['results'] ?? body['data'];
    if (results is List) {
      return results
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
    }
    return [body];
  }
  return const [];
}
