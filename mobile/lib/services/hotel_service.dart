import 'package:supabase_flutter/supabase_flutter.dart';

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/hotel_insight.dart';
import '../models/hotel_review.dart';
import '../models/room_quote.dart';

/// Repository for all Hotel Supabase reads/writes and rate fallback rules.
class HotelService {
  HotelService(this.client);

  final SupabaseClient client;

  GoTrueClient get auth => client.auth;

  static const apiBaseUrl = String.fromEnvironment('APP_API_BASE_URL');

  String day(DateTime value) => value.toIso8601String().substring(0, 10);

  Future<List<Map<String, dynamic>>> searchHotels({
    required String city,
    required DateTime start,
    required DateTime end,
    required int guests,
    required RangeValuesData priceRange,
    required Set<int> stars,
    required Set<String> amenities,
    required Set<String> propertyTypes,
  }) async {
    var found = await client.from('hotels').select().limit(50);
    found = found.where((hotel) {
      final keyword = city.trim().toLowerCase();
      if (keyword.isNotEmpty &&
          !'${hotel['name']} ${hotel['address']}'.toLowerCase().contains(
            keyword,
          )) {
        return false;
      }
      final star = (hotel['star_rating'] as num?)?.toInt() ?? 0;
      if (stars.isNotEmpty && !stars.contains(star)) return false;
      if (propertyTypes.isNotEmpty &&
          !propertyTypes.contains('${hotel['property_type']}'.toLowerCase())) {
        return false;
      }
      final values = (hotel['amenities'] as List? ?? [])
          .map((item) => '$item'.toLowerCase())
          .toList();
      if (amenities.any(
        (wanted) => !values.any((value) => value.contains(wanted)),
      )) {
        return false;
      }
      final rawPrice = (hotel['best_price'] as num?)?.toDouble();
      if (rawPrice != null) {
        final price = rawPrice / 100;
        if (price < priceRange.start || price > priceRange.end) return false;
      }
      return true;
    }).toList();
    if (found.isEmpty) return [];

    final hotelIds = found.map((h) => h['id']).whereType<String>().toList();
    final rooms = await client
        .from('hotel_rooms')
        .select('id,hotel_id,capacity')
        .inFilter('hotel_id', hotelIds)
        .eq('status', 'active')
        .gte('capacity', guests);
    if (rooms.isEmpty) return [];
    final roomIds = rooms.map((r) => r['id']).whereType<String>().toList();
    final rates = await client
        .from('hotel_rates')
        .select('room_id,date,available_rooms')
        .inFilter('room_id', roomIds)
        .gte('date', day(start))
        .lt('date', day(end))
        .gt('available_rooms', 0);
    if (rates.isEmpty) {
      return found
          .map(
            (hotel) => <String, dynamic>{...hotel, '_hasAvailability': false},
          )
          .toList();
    }
    final nights = end.difference(start).inDays;
    final datesByRoom = <String, Set<String>>{};
    for (final rate in rates) {
      datesByRoom
          .putIfAbsent('${rate['room_id']}', () => <String>{})
          .add('${rate['date']}');
    }
    final availableRooms = datesByRoom.entries
        .where((entry) => entry.value.length == nights)
        .map((entry) => entry.key)
        .toSet();
    final availableHotels = rooms
        .where((room) => availableRooms.contains('${room['id']}'))
        .map((room) => '${room['hotel_id']}')
        .toSet();
    return found
        .where((hotel) => availableHotels.contains('${hotel['id']}'))
        .map((hotel) => <String, dynamic>{...hotel, '_hasAvailability': true})
        .toList();
  }

  /// Active rooms that fit the party, each priced for the stay with
  /// [buildRoomQuote]. Rates come only from existing `hotel_rates` rows.
  Future<List<RoomOption>> roomOptions({
    required Map<String, dynamic> hotel,
    required DateTime start,
    required DateTime end,
    required int guests,
    required int rooms,
  }) async {
    final perRoom = (guests / (rooms < 1 ? 1 : rooms)).ceil();
    final roomRows = await client
        .from('hotel_rooms')
        .select()
        .eq('hotel_id', '${hotel['id']}')
        .eq('status', 'active')
        .gte('capacity', perRoom)
        .order('capacity');
    if (roomRows.isEmpty) return [];
    final ids = roomRows.map((room) => room['id']).whereType<String>().toList();
    const columns =
        'id,room_id,partner_id,date,price_cents,currency,available_rooms,'
        'min_nights,refundable,breakfast_included,cancellation_policy,rate_plan';
    // Rates for the requested stay (exact quotes).
    final stayRates = await client
        .from('hotel_rates')
        .select(columns)
        .inFilter('room_id', ids)
        .gte('date', day(start))
        .lt('date', day(end));
    // Most recent known rates (reference fallback when the stay is uncovered).
    final latestRates = await client
        .from('hotel_rates')
        .select(columns)
        .inFilter('room_id', ids)
        .order('date', ascending: false)
        .limit(ids.length * 20);
    final seen = <String>{};
    final ratesByRoom = <String, List<Map<String, dynamic>>>{};
    for (final rate in [...stayRates, ...latestRates]) {
      if (!seen.add('${rate['id']}')) continue;
      ratesByRoom.putIfAbsent('${rate['room_id']}', () => []).add(rate);
    }
    final options = roomRows.map((room) {
      final quote = buildRoomQuote(
        room: room,
        rates: ratesByRoom['${room['id']}'] ?? const [],
        start: start,
        end: end,
        roomCount: rooms,
        guestCount: guests,
        hotelBestPriceCents: hotel['best_price'] as num?,
      );
      return RoomOption(room: room, quote: quote);
    }).toList();
    options.sort((a, b) {
      if (a.quote == null) return b.quote == null ? 0 : 1;
      if (b.quote == null) return -1;
      final exact = (a.quote!.source.isReference ? 1 : 0).compareTo(
        b.quote!.source.isReference ? 1 : 0,
      );
      if (exact != 0) return exact;
      return a.quote!.subtotalCents.compareTo(b.quote!.subtotalCents);
    });
    return options;
  }

  /// Approved/published reviews for a hotel from the existing unified
  /// `reviews` table (the legacy `hotel_reviews` table is absent on the live
  /// backend). Read-only.
  Future<List<HotelReview>> reviewsFor(String hotelId) async {
    final rows = await client
        .from('reviews')
        .select('id,rating,title,comment,is_verified,created_at')
        .eq('entity_id', hotelId)
        .eq('status', 'published')
        .order('created_at', ascending: false)
        .limit(10);
    return rows.map(HotelReview.fromJson).toList();
  }

  /// Calls the existing public web route `POST /api/hotels/insights`.
  /// Returns null when the route answers without a usable insight.
  Future<HotelInsight?> hotelInsights({
    required Map<String, dynamic> hotel,
    required DateTime start,
    required DateTime end,
    required int guests,
  }) async {
    if (apiBaseUrl.isEmpty) {
      throw StateError('Thiếu APP_API_BASE_URL');
    }
    final response = await http
        .post(
          Uri.parse('$apiBaseUrl/api/hotels/insights'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'hotel': {
              'id': hotel['id'],
              'name': hotel['name'],
              'description': hotel['description'],
              'star_rating': hotel['star_rating'],
              'amenities': hotel['amenities'],
              'address': hotel['address'],
              'best_price': hotel['best_price'],
            },
            'checkIn': day(start),
            'checkOut': day(end),
            'guests': guests,
          }),
        )
        .timeout(const Duration(seconds: 60));
    if (response.statusCode >= 400) {
      throw StateError('Insights API ${response.statusCode}');
    }
    return HotelInsight.fromResponse(jsonDecode(response.body));
  }

  /// Inserts a pending booking request under the current user's session and
  /// returns the stored row. Success requires a real backend id.
  Future<Map<String, dynamic>> createBooking(
    Map<String, dynamic> payload,
  ) async {
    final user = auth.currentUser;
    if (user == null || payload['user_uuid'] != user.id) {
      throw const AuthException('Vui lòng đăng nhập để đặt phòng');
    }
    final row = await client
        .from('hotel_bookings')
        .insert(payload)
        .select(
          'id,confirmation_code,status,payment_status,total_cents,currency',
        )
        .single();
    final id = row['id'];
    if (id == null || '$id'.isEmpty) {
      throw StateError('Backend không trả về mã đơn');
    }
    return row;
  }

  Future<List<Map<String, dynamic>>> bookingsFor(String userId) => client
      .from('hotel_bookings')
      .select(
        '*,hotels:hotel_id(name,images,address),hotel_rooms:room_id(title)',
      )
      .eq('external_user_ref', userId)
      .order('created_at', ascending: false);

  Future<void> cancelBooking(String bookingId) async {
    await client
        .from('hotel_bookings')
        .update({
          'status': 'cancelled',
          'cancelled_at': DateTime.now().toIso8601String(),
          'cancellation_reason': 'Cancelled by customer',
        })
        .eq('id', bookingId)
        .eq('status', 'pending');
  }

  /// Reads the profile strictly for the current authenticated user session.
  /// Does not fallback to querying by email to prevent returning unverified identity.
  Future<Map<String, dynamic>?> currentProfile() async {
    final user = auth.currentUser;
    if (user == null) return null;
    return client.from('users').select().eq('id', user.id).maybeSingle();
  }

  /// Updates supported profile fields (name, bio, city, country, phone_number).
  Future<Map<String, dynamic>> updateCurrentProfile(
    Map<String, dynamic> values,
  ) async {
    final user = auth.currentUser;
    if (user == null) throw const AuthException('Vui lòng đăng nhập');

    // Only allow supported and verified profile fields
    const allowedFields = {'name', 'bio', 'city', 'country', 'phone_number'};
    final safeValues = <String, dynamic>{
      for (final entry in values.entries)
        if (allowedFields.contains(entry.key)) entry.key: entry.value,
    };

    final profile = await currentProfile();
    if (profile == null) {
      try {
        return await client
            .from('users')
            .insert({'id': user.id, 'email': user.email, ...safeValues})
            .select()
            .single();
      } catch (e) {
        throw StateError(
          'Chưa thể khởi tạo hồ sơ trên backend hiện tại: $e. Backend có thể yêu cầu định danh Clerk hoặc quyền RLS.',
        );
      }
    }
    return client
        .from('users')
        .update(safeValues)
        .eq('id', profile['id'])
        .select()
        .single();
  }

  Future<List<Map<String, dynamic>>> notifications() async {
    final user = auth.currentUser;
    if (user == null) return [];
    return client
        .from('notifications')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(50);
  }

  Future<void> markNotificationRead(String id) async {
    final user = auth.currentUser;
    if (user == null) throw const AuthException('Vui lòng đăng nhập');
    await client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', id)
        .eq('user_id', user.id);
  }

  Future<void> markAllNotificationsRead() async {
    final user = auth.currentUser;
    if (user == null) throw const AuthException('Vui lòng đăng nhập');
    await client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', user.id);
  }

  /// Calls the existing Next.js chat route. It never embeds server AI secrets.
  Future<String> sendChat(List<Map<String, String>> messages) async {
    if (apiBaseUrl.isEmpty) {
      throw StateError(
        'Thiếu APP_API_BASE_URL để gọi API chat hiện hữu của Next.js.',
      );
    }
    final token = auth.currentSession?.accessToken;
    final response = await http.post(
      Uri.parse('$apiBaseUrl/api/chat/messages'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'messages': messages}),
    );
    if (response.statusCode >= 400) {
      throw StateError('Chat API ${response.statusCode}: ${response.body}');
    }
    final lines = const LineSplitter().convert(response.body);
    final buffer = StringBuffer();
    for (final line in lines) {
      if (!line.startsWith('data: ') || line == 'data: [DONE]') continue;
      final value = jsonDecode(line.substring(6));
      if (value is Map && value['content'] != null) {
        buffer.write(value['content']);
      }
    }
    if (buffer.isEmpty) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['content'] != null) {
        return '${decoded['content']}';
      }
    }
    return buffer.toString();
  }
}

class RangeValuesData {
  const RangeValuesData(this.start, this.end);
  final double start;
  final double end;
}
