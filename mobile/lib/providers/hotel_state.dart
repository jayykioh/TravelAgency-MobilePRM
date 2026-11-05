import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/hotel_insight.dart';
import '../models/hotel_review.dart';
import '../models/room_quote.dart';
import '../screens/auth_screen.dart';
import '../services/hotel_service.dart';

/// UI state shared by search, detail, checkout and booking history screens.
class HotelState extends ChangeNotifier {
  HotelState({HotelService? service}) {
    _service = service;
    _initAuthListener();
  }

  HotelService? _service;
  HotelService get service =>
      _service ??= HotelService(Supabase.instance.client);

  SupabaseClient get db => service.client;
  StreamSubscription<AuthState>? _authSubscription;

  void _initAuthListener() {
    try {
      _authSubscription = service.auth.onAuthStateChange.listen((data) {
        notifyListeners();
      });
    } catch (_) {
      // Supabase is not initialized in some unit test environments.
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  /// Active Supabase user if logged in.
  User? get currentUser {
    try {
      return service.auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  /// Active Supabase session if authenticated.
  Session? get currentSession {
    try {
      return service.auth.currentSession;
    } catch (_) {
      return null;
    }
  }

  /// True if current session exists with an authenticated user.
  bool get isAuthenticated => currentUser != null;

  /// Distinguish guest checkout from authenticated user session.
  bool get isGuestBooking => !isAuthenticated;

  /// Authenticated user identifier (empty when guest).
  String get authenticatedUserId => currentUser?.id ?? '';

  DateTime start = DateTime.now().add(const Duration(days: 1));
  DateTime end = DateTime.now().add(const Duration(days: 2));
  int guests = 2;
  int children = 0;
  int rooms = 1;
  String city = '';
  RangeValues priceRange = const RangeValues(50, 1000);
  final Set<int> stars = <int>{};
  final Set<String> amenities = <String>{};
  final Set<String> propertyTypes = <String>{};
  String sortBy = 'recommended';

  /// Number of active filters applied to the search.
  int get activeFiltersCount {
    int count = 0;
    if (priceRange.start.round() > 50 || priceRange.end.round() < 1000) count++;
    count += stars.length;
    count += amenities.length;
    count += propertyTypes.length;
    return count;
  }

  /// True if any custom filter is active.
  bool get hasActiveFilters => activeFiltersCount > 0;

  /// Clears all active filters back to default.
  void clearFilters() {
    priceRange = const RangeValues(50, 1000);
    stars.clear();
    amenities.clear();
    propertyTypes.clear();
    notifyListeners();
  }

  void removeStarFilter(int star) {
    stars.remove(star);
    notifyListeners();
  }

  void removeAmenityFilter(String amenity) {
    amenities.remove(amenity);
    notifyListeners();
  }

  void removePropertyTypeFilter(String type) {
    propertyTypes.remove(type);
    notifyListeners();
  }

  void resetPriceRange() {
    priceRange = const RangeValues(50, 1000);
    notifyListeners();
  }

  void updateSort(String newSort) {
    sortBy = newSort;
    notifyListeners();
  }

  /// Retained guest checkout draft state across auth/back navigations.
  String draftGuestName = '';
  String draftGuestEmail = '';
  String draftGuestPhone = '';
  String draftSpecialRequests = '';
  String draftVoucherCode = '';

  void saveGuestDraft({
    String? name,
    String? email,
    String? phone,
    String? specialRequests,
    String? voucherCode,
  }) {
    if (name != null) draftGuestName = name;
    if (email != null) draftGuestEmail = email;
    if (phone != null) draftGuestPhone = phone;
    if (specialRequests != null) draftSpecialRequests = specialRequests;
    if (voucherCode != null) draftVoucherCode = voucherCode;
    notifyListeners();
  }

  void clearGuestDraft() {
    draftGuestName = '';
    draftGuestEmail = '';
    draftGuestPhone = '';
    draftSpecialRequests = '';
    draftVoucherCode = '';
    notifyListeners();
  }

  /// Navigates to auth screen if user is not logged in and returns whether logged in.
  Future<bool> requireAuth(BuildContext context, {String? reason}) async {
    if (isAuthenticated) return true;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AuthScreen(reasonMessage: reason)),
    );
    return result == true && isAuthenticated;
  }

  /// Stable owner key for guest demo bookings when no Supabase session exists.
  final String guestOwnerRef =
      'DEMO-${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';

  String get bookingOwnerRef =>
      isAuthenticated ? currentUser!.id : guestOwnerRef;

  int get nights =>
      DateUtils.dateOnly(end).difference(DateUtils.dateOnly(start)).inDays;
  String day(DateTime value) => service.day(value);

  void updateGuests(int value) {
    guests = value;
    _dropStaleSelection();
    notifyListeners();
  }

  void updateGuestConfig({int? adults, int? childGuests, int? roomCount}) {
    if (adults != null) guests = adults.clamp(1, 10);
    if (childGuests != null) children = childGuests.clamp(0, 10);
    if (roomCount != null) rooms = roomCount.clamp(1, 4);
    _dropStaleSelection();
    notifyListeners();
  }

  void updateDates(DateTimeRange value) {
    start = DateUtils.dateOnly(value.start);
    end = DateUtils.dateOnly(value.end);
    _dropStaleSelection();
    notifyListeners();
  }

  /// Total people in the party (adults + children).
  int get totalGuests => guests + children;

  // ---- Selected hotel / room / quote (Epic 3-4) ---------------------------

  Map<String, dynamic>? selectedHotel;
  RoomQuote? selectedQuote;

  /// Confirmation code reused across retries of the same request so a lost
  /// response cannot silently create a second booking (unique constraint).
  String? pendingConfirmationCode;

  bool isSelectedRoom(String hotelId, String roomId) =>
      '${selectedHotel?['id']}' == hotelId && selectedQuote?.roomId == roomId;

  /// True when the selected quote was computed for the current stay.
  bool get selectedQuoteIsCurrent {
    final quote = selectedQuote;
    return quote != null &&
        quote.matches(
          start: DateUtils.dateOnly(start),
          end: DateUtils.dateOnly(end),
          roomCount: rooms,
          guestCount: totalGuests,
        );
  }

  void selectRoom(Map<String, dynamic> hotel, RoomQuote quote) {
    final changed =
        '${selectedHotel?['id']}' != '${hotel['id']}' ||
        selectedQuote?.roomId != quote.roomId;
    selectedHotel = hotel;
    selectedQuote = quote;
    if (changed) pendingConfirmationCode = null;
    notifyListeners();
  }

  void clearRoomSelection() {
    selectedHotel = null;
    selectedQuote = null;
    pendingConfirmationCode = null;
    notifyListeners();
  }

  void _dropStaleSelection() {
    if (selectedQuote != null && !selectedQuoteIsCurrent) {
      selectedQuote = null;
      pendingConfirmationCode = null;
    }
  }

  /// Called after the backend returned a real booking id.
  void completeBooking() {
    selectedQuote = null;
    pendingConfirmationCode = null;
    clearGuestDraft();
  }

  Future<List<Map<String, dynamic>>> hotels() async {
    final values = await service.searchHotels(
      city: city,
      start: start,
      end: end,
      guests: guests + children,
      priceRange: RangeValuesData(priceRange.start, priceRange.end),
      stars: stars,
      amenities: amenities,
      propertyTypes: propertyTypes,
    );
    double number(Map<String, dynamic> value, String key) =>
        (value[key] as num?)?.toDouble() ?? 0;
    switch (sortBy) {
      case 'price_low':
        values.sort(
          (a, b) => number(a, 'best_price').compareTo(number(b, 'best_price')),
        );
      case 'price_high':
        values.sort(
          (a, b) => number(b, 'best_price').compareTo(number(a, 'best_price')),
        );
      case 'rating':
        values.sort(
          (a, b) => number(
            b,
            'average_rating',
          ).compareTo(number(a, 'average_rating')),
        );
      case 'popular':
        values.sort(
          (a, b) =>
              number(b, 'review_count').compareTo(number(a, 'review_count')),
        );
    }
    return values;
  }

  Future<List<RoomOption>> roomOptionsFor(Map<String, dynamic> hotel) =>
      service.roomOptions(
        hotel: hotel,
        start: DateUtils.dateOnly(start),
        end: DateUtils.dateOnly(end),
        guests: totalGuests,
        rooms: rooms,
      );

  Future<List<HotelReview>> reviewsFor(String hotelId) =>
      service.reviewsFor(hotelId);

  Future<HotelInsight?> insightsFor(Map<String, dynamic> hotel) =>
      service.hotelInsights(
        hotel: hotel,
        start: DateUtils.dateOnly(start),
        end: DateUtils.dateOnly(end),
        guests: totalGuests,
      );

  Future<Map<String, dynamic>?> currentProfile() async {
    if (!isAuthenticated) return null;
    return service.currentProfile();
  }

  Future<Map<String, dynamic>> createBooking(Map<String, dynamic> payload) =>
      service.createBooking(payload);
}
