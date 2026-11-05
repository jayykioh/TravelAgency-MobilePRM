import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/hotel_insight.dart';
import 'package:mobile/models/hotel_review.dart';
import 'package:mobile/models/room_quote.dart';
import 'package:mobile/utils/hotel_format.dart';

Map<String, dynamic> rate(
  String date,
  int cents, {
  String partner = 'p1',
  int available = 3,
  int minNights = 1,
  String currency = 'USD',
}) => {
  'id': '$partner-$date-$cents',
  'date': date,
  'price_cents': cents,
  'partner_id': partner,
  'available_rooms': available,
  'min_nights': minNights,
  'currency': currency,
  'refundable': true,
  'breakfast_included': false,
};

void main() {
  const room = {'id': 'r1', 'title': 'Deluxe'};
  final start = DateTime(2026, 3, 1);
  final end = DateTime(2026, 3, 3); // 2 nights

  RoomQuote? quote(
    List<Map<String, dynamic>> rates, {
    int rooms = 1,
    num? best,
  }) => buildRoomQuote(
    room: room,
    rates: rates,
    start: start,
    end: end,
    roomCount: rooms,
    guestCount: 2,
    hotelBestPriceCents: best,
  );

  test(
    'exact quote sums each night from the cheapest full-coverage partner',
    () {
      final q = quote([
        rate('2026-03-01', 10000),
        rate('2026-03-02', 12000),
        rate('2026-03-01', 9000, partner: 'p2'),
        rate('2026-03-02', 9500, partner: 'p2'),
        rate('2026-03-03', 1, partner: 'p2'), // checkout day is not a night
      ])!;
      expect(q.source, RateSource.exact);
      expect(q.partnerId, 'p2');
      expect(q.nights.map((n) => n.priceCents), [9000, 9500]);
      expect(q.subtotalCents, 18500);
      expect(q.averageNightlyCents, 9250);
    },
  );

  test('partner missing a night is not exact; falls back to latest rate', () {
    final q = quote([
      rate('2026-03-01', 10000),
      rate('2026-01-31', 7000, partner: 'p3'),
      rate('2026-01-31', 6000, partner: 'p4'),
    ])!;
    expect(q.source, RateSource.fallbackRate);
    expect(q.source.isReference, isTrue);
    // Latest known date is 2026-03-01 (10000), applied to every night.
    expect(q.nights.map((n) => n.priceCents), [10000, 10000]);
  });

  test('availability below room count and min nights block exact quote', () {
    final lowStock = quote([
      rate('2026-03-01', 10000, available: 1),
      rate('2026-03-02', 10000, available: 1),
    ], rooms: 2)!;
    expect(lowStock.source, RateSource.fallbackRate);

    final minNights = quote([
      rate('2026-03-01', 10000, minNights: 3),
      rate('2026-03-02', 10000, minNights: 3),
    ])!;
    expect(minNights.source, RateSource.fallbackRate);
  });

  test('no rates uses hotel best price; nothing at all is unbookable', () {
    final best = quote(const [], best: 6200)!;
    expect(best.source, RateSource.hotelBestPrice);
    expect(best.partnerId, isNull);
    expect(best.subtotalCents, 12400);
    expect(quote(const []), isNull);
  });

  test('room count multiplies subtotal; tax 10% and fee 5% like the web', () {
    final q = quote([
      rate('2026-03-01', 10001),
      rate('2026-03-02', 10000),
    ], rooms: 2)!;
    expect(q.subtotalCents, 40002);
    final price = q.breakdown;
    expect(price.taxCents, 4000);
    expect(price.feeCents, 2000);
    expect(price.totalCents, 46002);
  });

  test('quote matches only the stay it was built for', () {
    final q = quote([rate('2026-03-01', 1), rate('2026-03-02', 1)])!;
    expect(
      q.matches(start: start, end: end, roomCount: 1, guestCount: 2),
      isTrue,
    );
    expect(
      q.matches(start: start, end: end, roomCount: 2, guestCount: 2),
      isFalse,
    );
    expect(
      q.matches(
        start: start,
        end: DateTime(2026, 3, 4),
        roomCount: 1,
        guestCount: 2,
      ),
      isFalse,
    );
  });

  test('stayDates excludes checkout and crosses month boundaries', () {
    expect(stayDates(DateTime(2026, 1, 30), DateTime(2026, 2, 2)), [
      '2026-01-30',
      '2026-01-31',
      '2026-02-01',
    ]);
    expect(stayDates(end, start), isEmpty);
  });

  test('review summary never invents a rating', () {
    expect(
      ReviewSummary.from(
        reviews: const [],
        hotel: {'average_rating': 0, 'review_count': 0},
      ).hasReviews,
      isFalse,
    );
    final fromRows = ReviewSummary.from(
      reviews: [
        HotelReview.fromJson({'rating': 4}),
        HotelReview.fromJson({'rating': 5}),
      ],
      hotel: const {},
    );
    expect(fromRows.average, 4.5);
    expect(fromRows.count, 2);
    final fromHotel = ReviewSummary.from(
      reviews: const [],
      hotel: {'average_rating': 4.2, 'review_count': 31},
    );
    expect(fromHotel.count, 31);
  });

  test('insight parser requires success and main text', () {
    expect(HotelInsight.fromResponse({'success': false}), isNull);
    expect(
      HotelInsight.fromResponse({
        'success': true,
        'insights': {'mainInsight': ''},
      }),
      isNull,
    );
    final insight = HotelInsight.fromResponse({
      'success': true,
      'insights': {
        'title': 'AI Insight: Couples',
        'mainInsight': 'Great beach access.',
        'perfectFor': ['Couples', ''],
        'highlights': ['Pool'],
      },
    })!;
    expect(insight.perfectFor, ['Couples']);
    expect(insight.highlights, ['Pool']);
  });

  test('formatters handle jsonb address, policies and money', () {
    expect(
      hotelAddressText({'line1': 'Khem Beach', 'city': 'Phu Quoc'}),
      'Khem Beach, Phu Quoc',
    );
    expect(hotelAddressText(null), 'Việt Nam');
    expect(policyEntries({'check_in': '14:00', 'pets': false}), hasLength(2));
    expect(policyEntries({'check_in': '14:00'}).first.key, 'Nhận phòng');
    expect(formatMoney(12345, 'USD'), contains('123.45'));
  });
}
