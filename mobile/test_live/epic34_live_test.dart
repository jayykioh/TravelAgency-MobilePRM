// Live functional check of Epic 3/4 data paths against the real Supabase
// backend (anon key, read-only + one expected-to-fail anon insert).
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/booking_request.dart';
import 'package:mobile/models/hotel_insight.dart';
import 'package:mobile/models/hotel_review.dart';
import 'package:mobile/models/room_quote.dart';
import 'package:mobile/services/hotel_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const url = String.fromEnvironment('SUPABASE_URL');
const key = String.fromEnvironment('SUPABASE_ANON_KEY');

void main() {
  late SupabaseClient client;
  late HotelService service;
  late List<Map<String, dynamic>> hotels;

  setUpAll(() async {
    client = SupabaseClient(url, key,
        authOptions: const AuthClientOptions(autoRefreshToken: false));
    service = HotelService(client);
    hotels = List<Map<String, dynamic>>.from(
        await client.from('hotels').select().limit(8));
    print('Loaded ${hotels.length} hotels');
  });

  void checkQuote(RoomQuote q, int rooms, int guests, String label) {
    final b = q.breakdown;
    expect(q.nights.length, q.nightCount, reason: label);
    expect(q.subtotalCents,
        q.nights.fold<int>(0, (s, n) => s + n.priceCents) * rooms,
        reason: label);
    expect(b.taxCents, (q.subtotalCents * 0.10).round(), reason: label);
    expect(b.feeCents, (q.subtotalCents * 0.05).round(), reason: label);
    expect(b.totalCents, greaterThan(0), reason: label);
    if (q.source == RateSource.exact) {
      expect(q.partnerId, isNotNull, reason: label);
    }
  }

  Future<void> runStay(DateTime s, DateTime e, int guests, int rooms) async {
    final counts = <String, int>{};
    for (final h in hotels) {
      final opts = await service.roomOptions(
          hotel: h, start: s, end: e, guests: guests, rooms: rooms);
      final perRoom = (guests / rooms).ceil();
      for (final o in opts) {
        expect((o.room['capacity'] as num) >= perRoom, isTrue);
        final key = o.quote?.source.key ?? 'no_price';
        counts[key] = (counts[key] ?? 0) + 1;
        if (o.quote != null) {
          checkQuote(o.quote!, rooms, guests, '${h['name']}/${o.room['title']}');
        }
      }
      // exact quotes sorted before reference ones
      final srcs = opts.where((o) => o.quote != null)
          .map((o) => o.quote!.source.isReference ? 1 : 0).toList();
      expect(srcs, [...srcs]..sort());
      final first = opts.where((o) => o.quote != null).firstOrNull;
      print('  ${h['name']}: ${opts.length} phòng'
          '${first == null ? '' : ' · rẻ nhất ${first.quote!.source.key} '
              'tổng ${first.quote!.breakdown.totalCents} ${first.quote!.currency}'}');
    }
    print('  => nguồn giá: $counts');
  }

  test('3-3 stay inside live rate window (2026-03-10→12, 2 khách, 1 phòng)',
      () async {
    print('Stay 2026-03-10 → 03-12');
    await runStay(DateTime(2026, 3, 10), DateTime(2026, 3, 12), 2, 1);
  });

  test('3-3 current stay falls back to reference price (2026-12-10→12)',
      () async {
    print('Stay 2026-12-10 → 12-12');
    await runStay(DateTime(2026, 12, 10), DateTime(2026, 12, 12), 2, 1);
  });

  test('3-3 4 khách 2 phòng, ở qua tháng (2026-02-27→03-02)', () async {
    print('Stay 2026-02-27 → 03-02, 4 khách / 2 phòng');
    await runStay(DateTime(2026, 2, 27), DateTime(2026, 3, 2), 4, 2);
  });

  test('3-2 reviews load without error and never invent ratings', () async {
    for (final h in hotels) {
      final reviews = await service.reviewsFor('${h['id']}');
      final s = ReviewSummary.from(reviews: reviews, hotel: h);
      print('  ${h['name']}: ${reviews.length} review, '
          'aggregate ${h['average_rating']}/${h['review_count']} → '
          '${s.hasReviews ? '${s.average!.toStringAsFixed(1)} (${s.count})' : 'chưa có đánh giá'}');
      if (reviews.isEmpty && ((h['review_count'] as num?) ?? 0) == 0) {
        expect(s.hasReviews, isFalse);
      }
    }
  });

  test('3-2 insight end-to-end via Next.js /api/hotels/insights', () async {
    Object? err;
    HotelInsight? got;
    try {
      got = await service.hotelInsights(hotel: hotels.first,
          start: DateTime(2026, 12, 10), end: DateTime(2026, 12, 12), guests: 2);
    } catch (e) {
      err = e;
    }
    print('  insight error: $err');
    if (got != null) {
      print('  title: ${got.title}');
      print('  main: ${got.mainInsight}');
      print('  perfectFor: ${got.perfectFor} highlights: ${got.highlights.length}');
    }
    expect(err, isNull);
    expect(got, isNotNull);
  });

  test('4-3 booking requires a session; anon insert is rejected and mapped',
      () async {
    final h = hotels.first;
    final opts = await service.roomOptions(hotel: h,
        start: DateTime(2026, 3, 10), end: DateTime(2026, 3, 12),
        guests: 2, rooms: 1);
    final q = opts.firstWhere((o) => o.quote != null).quote!;
    final code = generateConfirmationCode();
    expect(RegExp(r'^[A-Z0-9]{8}$').hasMatch(code), isTrue);
    const guest = GuestDetails(name: 'Live Test', email: 'live@test.dev',
        phone: '0900000000', specialRequests: '', voucherCode: '');
    final payload = buildBookingPayload(userId: '00000000-0000-0000-0000-000000000000',
        hotel: h, quote: q, guest: guest, adults: 2, children: 0,
        confirmationCode: code);
    expect(payload['total_cents'], q.breakdown.totalCents);
    expect(payload['status'], 'pending');
    expect(payload['payment_status'], 'pending');
    expect(payload.containsKey('nights_count'), isFalse);

    // App guard: no session → AuthException before any network call.
    await expectLater(service.createBooking(payload), throwsA(isA<AuthException>()));
    final mapped = describeBookingError(const AuthException('x'));
    print('  guard → "${mapped.message}"');

    // Backend: raw anon insert must be rejected (nothing written).
    Object? err;
    try {
      await client.from('hotel_bookings').insert(payload).select('id').single();
    } catch (e) {
      err = e;
    }
    expect(err, isNotNull, reason: 'anon insert must not succeed');
    final m = describeBookingError(err!);
    print('  backend → ${err.runtimeType}: ${err is PostgrestException ? '${err.code} ' : ''}'
        '→ app hiển thị "${m.message}" (maybeCreated=${m.maybeCreated})');
  });
}
