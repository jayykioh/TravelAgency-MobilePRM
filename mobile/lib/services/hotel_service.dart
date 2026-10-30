import 'package:supabase_flutter/supabase_flutter.dart';

import 'dart:convert';

import 'package:http/http.dart' as http;

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

  Future<List<Map<String, dynamic>>> roomsFor({
    required String hotelId,
    required DateTime start,
    required DateTime end,
    required int guests,
  }) async {
    final roomRows = await client
        .from('hotel_rooms')
        .select()
        .eq('hotel_id', hotelId)
        .eq('status', 'active')
        .gte('capacity', guests);
    if (roomRows.isEmpty) return [];
    final ids = roomRows.map((room) => room['id']).whereType<String>().toList();
    final allRates = await client
        .from('hotel_rates')
        .select()
        .inFilter('room_id', ids)
        .order('date', ascending: false);
    return roomRows.map((room) {
      final roomRates = allRates
          .where((rate) => '${rate['room_id']}' == '${room['id']}')
          .toList();
      final selectedRates = roomRates.where((rate) {
        final value = DateTime.tryParse('${rate['date']}');
        return value != null && !value.isBefore(start) && value.isBefore(end);
      }).toList();
      final usable = selectedRates.isNotEmpty ? selectedRates : roomRates;
      usable.sort(
        (a, b) => ((a['price_cents'] as num?)?.toInt() ?? 0).compareTo(
          (b['price_cents'] as num?)?.toInt() ?? 0,
        ),
      );
      return <String, dynamic>{
        ...room,
        '_rate': usable.isEmpty ? null : usable.first,
        '_usedFallbackRate': selectedRates.isEmpty,
      };
    }).toList();
  }

  Future<Map<String, dynamic>> createBooking(Map<String, dynamic> payload) =>
      client.from('hotel_bookings').insert(payload).select().single();

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

  /// Reads the profile through the existing Supabase schema and current RLS.
  Future<Map<String, dynamic>?> currentProfile() async {
    final user = auth.currentUser;
    if (user == null) return null;
    final byId = await client
        .from('users')
        .select()
        .eq('id', user.id)
        .maybeSingle();
    if (byId != null) return byId;
    if (user.email == null) return null;
    return client.from('users').select().eq('email', user.email!).maybeSingle();
  }

  Future<Map<String, dynamic>> updateCurrentProfile(
    Map<String, dynamic> values,
  ) async {
    final user = auth.currentUser;
    if (user == null) throw const AuthException('Vui lòng đăng nhập');
    final profile = await currentProfile();
    if (profile == null) {
      return client
          .from('users')
          .insert({'id': user.id, 'email': user.email, ...values})
          .select()
          .single();
    }
    return client
        .from('users')
        .update(values)
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
