import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/hotel_service.dart';

/// UI state shared by search, detail, checkout and booking history screens.
class HotelState extends ChangeNotifier {
  HotelState({HotelService? service}) {
    _service = service;
  }

  HotelService? _service;
  HotelService get service =>
      _service ??= HotelService(Supabase.instance.client);

  SupabaseClient get db => service.client;
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

  /// Stable owner key for guest demo bookings when no Supabase session exists.
  final String guestOwnerRef =
      'DEMO-${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';

  String get bookingOwnerRef => service.auth.currentUser?.id ?? guestOwnerRef;

  int get nights =>
      DateUtils.dateOnly(end).difference(DateUtils.dateOnly(start)).inDays;
  String day(DateTime value) => service.day(value);

  void updateGuests(int value) {
    guests = value;
    notifyListeners();
  }

  void updateGuestConfig({int? adults, int? childGuests, int? roomCount}) {
    if (adults != null) guests = adults.clamp(1, 10);
    if (childGuests != null) children = childGuests.clamp(0, 10);
    if (roomCount != null) rooms = roomCount.clamp(1, 4);
    notifyListeners();
  }

  void updateDates(DateTimeRange value) {
    start = DateUtils.dateOnly(value.start);
    end = DateUtils.dateOnly(value.end);
    notifyListeners();
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

  Future<List<Map<String, dynamic>>> roomsFor(String hotelId) =>
      service.roomsFor(
        hotelId: hotelId,
        start: DateUtils.dateOnly(start),
        end: DateUtils.dateOnly(end),
        guests: guests + children,
      );
}
