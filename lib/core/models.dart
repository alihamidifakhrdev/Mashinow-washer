import 'jalali.dart';

/// مدل‌های داده — عین شکل پاسخ‌های واقعی بک‌اند (با تست زنده تأیید شده)

class ProfileStatus {
  final String role;
  final String step;
  final bool completed;

  const ProfileStatus({
    required this.role,
    required this.step,
    required this.completed,
  });

  factory ProfileStatus.fromJson(Map<String, dynamic> json) => ProfileStatus(
        role: (json['role'] ?? '') as String,
        step: (json['step'] ?? '') as String,
        completed: (json['completed'] ?? false) as bool,
      );
}

class BookingService {
  final int id;
  final String name;
  final int price; // ریال

  const BookingService({required this.id, required this.name, required this.price});

  factory BookingService.fromJson(Map<String, dynamic> json) {
    final dynamic serviceType = json['service_type'];

    return BookingService(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: serviceType is Map<String, dynamic>
          ? ((serviceType['name'] ?? '') as String)
          : ((serviceType ?? '') is String ? (serviceType as String) : ''),
      price: ((json['price'] as num?) ?? 0).toInt(),
    );
  }
}

/// نوبت آنلاین (مشتریِ اپ/سایت)
class Booking {
  final int id;
  final String carType;
  final String carModel;
  final String serviceType;
  final String status; // reserved | done | cancelled
  final DateTime? startTime;
  final DateTime? endTime;
  final String paymentMethod;
  final List<BookingService> services;
  final bool isMobileService;
  final String customerAddress;
  final double? travelFee;
  final String trackingCode;
  final DateTime? createdAt;

  const Booking({
    required this.id,
    required this.carType,
    required this.carModel,
    required this.serviceType,
    required this.status,
    required this.startTime,
    required this.endTime,
    required this.paymentMethod,
    required this.services,
    required this.isMobileService,
    required this.customerAddress,
    required this.travelFee,
    required this.trackingCode,
    required this.createdAt,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    final dynamic car = json['car'];
    final Map<String, dynamic> carMap =
        car is Map<String, dynamic> ? car : <String, dynamic>{};

    return Booking(
      id: (json['id'] as num?)?.toInt() ?? 0,
      carType: (carMap['car_type'] ?? '') as String,
      carModel: (carMap['car_model'] ?? '') as String,
      serviceType: (json['service_type'] ?? '') as String,
      status: (json['status'] ?? 'reserved') as String,
      startTime: parseServerDate(json['start_time'] as String?),
      endTime: parseServerDate(json['end_time'] as String?),
      paymentMethod: (json['payment_method'] ?? '') as String,
      services: _parseServices(json['services']),
      isMobileService: (json['is_mobile_service'] ?? false) == true,
      customerAddress: (json['customer_address'] ?? '') as String,
      travelFee: (json['travel_fee'] as num?)?.toDouble(),
      trackingCode: (json['tracking_code'] ?? '') as String,
      createdAt: parseServerDate(json['created_at'] as String?),
    );
  }

  /// زمان مؤثر نمایش — اولویت با start_time
  DateTime? get displayTime => startTime ?? createdAt;

  int get totalPrice {
    int sum = sumPrices;
    if (travelFee != null && travelFee! > 0) {
      sum += travelFee!.round();
    }
    return sum;
  }

  int get sumPrices {
    int sum = 0;
    for (final s in services) {
      sum += s.price;
    }
    return sum;
  }
}

/// نوبت حضوری (مهمان)
class GuestBooking {
  final int id;
  final String customerName;
  final String customerPhone;
  final String carModel;
  final String status;
  final DateTime? slotStart;
  final DateTime? slotEnd;
  final List<BookingService> services;
  final String trackingCode;
  final DateTime? createdAt;

  const GuestBooking({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.carModel,
    required this.status,
    required this.slotStart,
    required this.slotEnd,
    required this.services,
    required this.trackingCode,
    required this.createdAt,
  });

  factory GuestBooking.fromJson(Map<String, dynamic> json) {
    final dynamic slot = json['time_slot'];
    final Map<String, dynamic> slotMap =
        slot is Map<String, dynamic> ? slot : <String, dynamic>{};

    return GuestBooking(
      id: (json['id'] as num?)?.toInt() ?? 0,
      customerName: (json['customer_name'] ?? '') as String,
      customerPhone: (json['customer_phone'] ?? '') as String,
      carModel: (json['car_model'] ?? '') as String,
      status: (json['status'] ?? 'reserved') as String,
      // بک‌اند ممکن است زمان را داخل آبجکت time_slot یا مستقیم روی خود نوبت
      // بفرستد — همه حالت‌ها پشتیبانی می‌شود تا نوبت حضوری همیشه نمایش داده شود
      slotStart: parseServerDate(slotMap['start_time'] as String?) ??
          parseServerDate(slotMap['start_datetime'] as String?) ??
          parseServerDate(json['start_time'] as String?) ??
          parseServerDate(json['start_datetime'] as String?) ??
          parseServerDate(json['date'] as String?) ??
          parseServerDate(json['time_slot'] is String
              ? json['time_slot'] as String?
              : null),
      slotEnd: parseServerDate(slotMap['end_time'] as String?) ??
          parseServerDate(slotMap['end_datetime'] as String?) ??
          parseServerDate(json['end_time'] as String?) ??
          parseServerDate(json['end_datetime'] as String?),
      services: _parseServices(json['services']),
      trackingCode: (json['tracking_code'] ?? '') as String,
      createdAt: parseServerDate(json['created_at'] as String?),
    );
  }

  DateTime? get displayTime => slotStart ?? createdAt;
}

List<BookingService> _parseServices(dynamic raw) {
  if (raw is! List) return const [];

  return raw
      .whereType<Map<String, dynamic>>()
      .map(BookingService.fromJson)
      .toList();
}

/// نوع خدمت سراسری (carwash/admin/services)
class AdminService {
  final int id;
  final String name;

  const AdminService({required this.id, required this.name});

  factory AdminService.fromJson(Map<String, dynamic> json) => AdminService(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: (json['name'] ?? '') as String,
      );
}

/// خدمت ثبت‌شده کارواش (carwash/carwash/services/)
class CarwashService {
  final int id;
  final int serviceTypeId;
  final String serviceTypeName;
  final String vehicleTypeName;
  final int price; // ریال

  const CarwashService({
    required this.id,
    required this.serviceTypeId,
    required this.serviceTypeName,
    required this.vehicleTypeName,
    required this.price,
  });

  factory CarwashService.fromJson(Map<String, dynamic> json) {
    final dynamic st = json['service_type'];
    final Map<String, dynamic> stMap =
        st is Map<String, dynamic> ? st : <String, dynamic>{};

    return CarwashService(
      id: (json['id'] as num?)?.toInt() ?? 0,
      serviceTypeId: (stMap['id'] as num?)?.toInt() ?? 0,
      serviceTypeName: (stMap['name'] ?? '') as String,
      vehicleTypeName: (json['vehicle_type'] ?? '') as String,
      price: ((json['price'] as num?) ?? 0).toInt(),
    );
  }
}

class VehicleType {
  final int id;
  final String name;

  const VehicleType({required this.id, required this.name});

  factory VehicleType.fromJson(Map<String, dynamic> json) => VehicleType(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: (json['name'] ?? '') as String,
      );
}

class WorkingSession {
  final int id;
  final DateTime start;
  final DateTime end;

  const WorkingSession({required this.id, required this.start, required this.end});

  factory WorkingSession.fromJson(Map<String, dynamic> json) =>
      WorkingSession(
        id: (json['id'] as num?)?.toInt() ?? 0,
        start: parseServerDate(json['start_datetime'] as String?) ?? DateTime.now(),
        end: parseServerDate(json['end_datetime'] as String?) ?? DateTime.now(),
      );
}

class TimeSlot {
  final int id;
  final DateTime start;
  final DateTime end;
  final bool isReserved;

  const TimeSlot({
    required this.id,
    required this.start,
    required this.end,
    required this.isReserved,
  });

  factory TimeSlot.fromJson(Map<String, dynamic> json) => TimeSlot(
        id: (json['id'] as num?)?.toInt() ?? 0,
        start: parseServerDate(json['start_time'] as String?) ?? DateTime.now(),
        end: parseServerDate(json['end_time'] as String?) ?? DateTime.now(),
        isReserved: (json['is_reserved'] ?? false) == true,
      );
}

class WalletTransaction {
  final int id;
  final int amount;
  final String type;
  final String description;
  final DateTime? createdAt;

  const WalletTransaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.description,
    required this.createdAt,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) =>
      WalletTransaction(
        id: (json['id'] as num?)?.toInt() ?? 0,
        amount: ((json['amount'] as num?) ?? 0).toInt(),
        type: (json['transaction_type'] ?? '') as String,
        description: (json['description'] ?? '') as String,
        createdAt: parseServerDate(json['created_at'] as String?),
      );
}

class Wallet {
  final int balance; // ریال
  final List<WalletTransaction> transactions;

  const Wallet({required this.balance, required this.transactions});

  factory Wallet.fromJson(Map<String, dynamic> json) => Wallet(
        balance: ((json['balance'] as num?) ?? 0).toInt(),
        transactions: (json['transactions'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(WalletTransaction.fromJson)
            .toList(),
      );
}

class CarwashProfile {
  final int id;
  final String name;
  final String phoneNumber;
  final int province;
  final int city;
  final String address;
  final double averageRating;
  final bool isActive;

  const CarwashProfile({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.province,
    required this.city,
    required this.address,
    required this.averageRating,
    required this.isActive,
  });

  factory CarwashProfile.fromJson(Map<String, dynamic> json) =>
      CarwashProfile(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: (json['name'] ?? '') as String,
        phoneNumber: (json['phone_number'] ?? '') as String,
        // «شماره مجوز» حذف شد: بک‌اند ستون license_number را حذف کرده
        // (مهاجرت 0005) و فقط عکس مجوز (license_image) را برمی‌گرداند.
        province: (json['province'] as num?)?.toInt() ?? 0,
        city: (json['city'] as num?)?.toInt() ?? 0,
        address: (json['address'] ?? '') as String,
        averageRating: ((json['average_rating'] as num?) ?? 0).toDouble(),
        isActive: (json['is_active'] ?? true) == true,
      );
}

class Province {
  final int id;
  final String name;

  const Province({required this.id, required this.name});

  factory Province.fromJson(Map<String, dynamic> json) => Province(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: (json['name'] ?? '') as String,
      );
}

class City {
  final int id;
  final String name;

  const City({required this.id, required this.name});

  factory City.fromJson(Map<String, dynamic> json) => City(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: (json['name'] ?? '') as String,
      );
}
