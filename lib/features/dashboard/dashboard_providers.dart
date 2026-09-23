import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mashinow_washer/core/models/api_models.dart';
import 'package:mashinow_washer/core/providers/app_auth.dart';
import 'package:mashinow_washer/features/washer_repository.dart';

/// Checks backend registration state (owner profile + carwash) and syncs it
/// into [AppAuth.profileCompleted] so the router can redirect properly.
final profileStatusProvider = FutureProvider<bool>((ref) async {
  final repository = ref.watch(washerRepositoryProvider);

  final complete = await repository.isRegistrationComplete();

  if (complete) {
    ref.read(appAuthProvider.notifier).completeProfile();
  }

  return complete;
});

/// The washer's car wash profile.
final carWashProfileProvider = FutureProvider<CarWash>((ref) {
  final repository = ref.watch(washerRepositoryProvider);
  return repository.getCarWashProfile();
});

/// Today's bookings for the dashboard queue.
final todayBookingsProvider = FutureProvider<List<Booking>>((ref) {
  final repository = ref.watch(washerRepositoryProvider);
  final now = DateTime.now();
  return repository.getBookings(
    date: DateTime(now.year, now.month, now.day),
  );
});

/// All upcoming/all bookings.
final allBookingsProvider = FutureProvider<List<Booking>>((ref) {
  final repository = ref.watch(washerRepositoryProvider);
  return repository.getBookings();
});

/// Walk-in (guest) bookings.
final guestBookingsProvider = FutureProvider<List<GuestBooking>>((ref) {
  final repository = ref.watch(washerRepositoryProvider);
  return repository.getGuestBookings();
});

/// Weekly stats (defensively parsed key/values).
final weeklyStatsProvider = FutureProvider<List<StatEntry>>((ref) {
  final repository = ref.watch(washerRepositoryProvider);
  return repository.getWeeklyStats();
});

/// Bookable time slots.
final timeSlotsProvider = FutureProvider<List<TimeSlot>>((ref) {
  final repository = ref.watch(washerRepositoryProvider);
  return repository.getTimeSlots();
});

/// Service type catalog.
final serviceTypesProvider = FutureProvider<List<ServiceType>>((ref) {
  final repository = ref.watch(washerRepositoryProvider);
  return repository.getServiceTypes();
});

/// Vehicle type catalog.
final vehicleTypesProvider = FutureProvider<List<VehicleType>>((ref) {
  final repository = ref.watch(washerRepositoryProvider);
  return repository.getVehicleTypes();
});

/// Car wash services of the current washer.
final carWashServicesProvider = FutureProvider<List<CarWashService>>((ref) {
  final repository = ref.watch(washerRepositoryProvider);
  return repository.getServices();
});

/// Wallet summary.
final walletProvider = FutureProvider<Wallet>((ref) {
  final repository = ref.watch(washerRepositoryProvider);
  return repository.getWallet();
});

/// Working sessions of the current washer.
final workingSessionsProvider = FutureProvider<List<WorkingSession>>((ref) {
  final repository = ref.watch(washerRepositoryProvider);
  return repository.getWorkingSessions();
});

/// Provinces list.
final provincesProvider = FutureProvider<List<Province>>((ref) {
  final repository = ref.watch(washerRepositoryProvider);
  return repository.getProvinces();
});

/// Cities of a province.
final citiesProvider =
    FutureProvider.family<List<City>, int>((ref, provinceId) {
  final repository = ref.watch(washerRepositoryProvider);
  return repository.getCities(provinceId: provinceId);
});

/// Owner profile.
final ownerProfileProvider = FutureProvider<OwnerProfile>((ref) {
  final repository = ref.watch(washerRepositoryProvider);
  return repository.getOwnerProfile();
});

/// Ratings of the washer's car wash.
final ratingsProvider = FutureProvider.family<List<CarWashRating>, int>(
  (ref, carWashId) {
    final repository = ref.watch(washerRepositoryProvider);
    return repository.getRatings(carWashId: carWashId);
  },
);

/// Owner-side bookings for an arbitrary date.
final bookingsByDateProvider =
    FutureProvider.family<List<Booking>, DateTime>((ref, date) {
  final repository = ref.watch(washerRepositoryProvider);
  return repository.getBookings(date: date);
});
