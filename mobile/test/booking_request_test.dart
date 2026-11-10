import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/booking_request.dart';
import 'package:mobile/models/room_quote.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

RoomQuote sampleQuote({RateSource source = RateSource.exact}) => RoomQuote(
  room: const {'id': 'room-1', 'title': 'Deluxe'},
  start: DateTime(2026, 3, 1),
  end: DateTime(2026, 3, 3),
  roomCount: 2,
  guestCount: 3,
  nights: const [
    NightRate(date: '2026-03-01', priceCents: 10000),
    NightRate(date: '2026-03-02', priceCents: 12000),
  ],
  currency: 'USD',
  source: source,
  partnerId: source == RateSource.exact ? 'partner-1' : null,
);

void main() {
  group('GuestValidators', () {
    test('name', () {
      expect(GuestValidators.name(''), isNotNull);
      expect(GuestValidators.name(' A '), isNotNull);
      expect(GuestValidators.name('Nguyễn Văn A'), isNull);
    });
    test('email', () {
      expect(GuestValidators.email('a@b'), isNotNull);
      expect(GuestValidators.email('guest@tripc.vn'), isNull);
    });
    test('phone', () {
      expect(GuestValidators.phone('123'), isNotNull);
      expect(GuestValidators.phone('abc12345678'), isNotNull);
      expect(GuestValidators.phone('+84 912 345 678'), isNull);
      expect(GuestValidators.phone('0912-345-678'), isNull);
    });
    test('special requests length', () {
      expect(GuestValidators.specialRequests('x' * 501), isNotNull);
      expect(GuestValidators.specialRequests(''), isNull);
    });
  });

  test('confirmation code uses the web alphabet and length', () {
    final code = generateConfirmationCode(Random(1));
    expect(code, matches(RegExp(r'^[A-Z0-9]{8}$')));
  });

  test('payload binds ownership to the authenticated user and prices', () {
    final payload = buildBookingPayload(
      userId: 'auth-user-1',
      hotel: const {'id': 'hotel-1'},
      quote: sampleQuote(),
      guest: const GuestDetails(
        name: ' Guest ',
        email: 'g@tripc.vn',
        phone: '0912345678',
        voucherCode: 'summer',
      ),
      adults: 2,
      children: 1,
      confirmationCode: 'ABCD1234',
    );
    expect(payload['user_uuid'], 'auth-user-1');
    expect(payload['external_user_ref'], 'auth-user-1');
    expect('${payload['external_user_ref']}', isNot(startsWith('DEMO-')));
    expect(payload['partner_id'], 'partner-1');
    expect(payload['check_in_date'], '2026-03-01');
    expect(payload['check_out_date'], '2026-03-03');
    expect(payload['guest_name'], 'Guest');
    expect(payload['special_requests'], isNull);
    // (10000 + 12000) * 2 rooms = 44000; tax 4400; fee 2200.
    expect(payload['tax_cents'], 4400);
    expect(payload['fees_cents'], 2200);
    expect(payload['total_cents'], 50600);
    // Nightly rate covers both rooms so the DB pricing check
    // (total = nightly * nights + tax + fees - discount) holds.
    expect(payload['nightly_rate_cents'], 22000);
    expect(
      payload['nightly_rate_cents'] * 2 +
          payload['tax_cents'] +
          payload['fees_cents'] -
          payload['discount_cents'],
      payload['total_cents'],
    );
    expect(payload['status'], 'pending');
    expect(payload['payment_status'], 'pending');
    expect(payload['guest_count'], {'adults': 2, 'children': 1, 'rooms': 2});
    final metadata = payload['metadata'] as Map;
    expect(metadata['rate_source'], 'exact');
    expect(metadata['voucher_code'], 'SUMMER');
    expect(metadata['voucher_applied'], isFalse);
    expect(metadata['nightly'], hasLength(2));
    expect(payload.containsKey('nights_count'), isFalse);
  });

  test('payload records reference-price source', () {
    final payload = buildBookingPayload(
      userId: 'u',
      hotel: const {'id': 'h'},
      quote: sampleQuote(source: RateSource.fallbackRate),
      guest: const GuestDetails(name: 'Ab', email: 'a@b.co', phone: '12345678'),
      adults: 1,
      children: 0,
      confirmationCode: 'X',
    );
    expect((payload['metadata'] as Map)['rate_source'], 'fallback_rate');
    expect(payload['partner_id'], isNull);
  });

  test(
    'payload sets partner_id to null when reference price has partnerId',
    () {
      final quoteWithPartner = RoomQuote(
        room: const {'id': 'room-1', 'title': 'Deluxe'},
        start: DateTime(2026, 11, 5),
        end: DateTime(2026, 11, 8),
        roomCount: 1,
        guestCount: 2,
        nights: const [
          NightRate(date: '2026-11-05', priceCents: 9000),
          NightRate(date: '2026-11-06', priceCents: 9000),
          NightRate(date: '2026-11-07', priceCents: 9000),
        ],
        currency: 'USD',
        source: RateSource.fallbackRate,
        partnerId: 'unverified-partner-uuid',
      );
      final payload = buildBookingPayload(
        userId: 'user-123',
        hotel: const {'id': 'hotel-abc'},
        quote: quoteWithPartner,
        guest: const GuestDetails(
          name: 'James Bond',
          email: 'bond@mi6.gov.uk',
          phone: '0123456789',
        ),
        adults: 2,
        children: 0,
        confirmationCode: 'BOND0007',
      );
      expect(payload['partner_id'], isNull);
      expect((payload['metadata'] as Map)['rate_source'], 'fallback_rate');
    },
  );

  test('payload strips whitespace and empty partner_id', () {
    final quote = RoomQuote(
      room: const {'id': 'room-1', 'title': 'Deluxe'},
      start: DateTime(2026, 11, 5),
      end: DateTime(2026, 11, 6),
      roomCount: 1,
      guestCount: 2,
      nights: const [NightRate(date: '2026-11-05', priceCents: 9000)],
      currency: 'USD',
      source: RateSource.exact,
      partnerId: '   ',
    );
    final payload = buildBookingPayload(
      userId: 'user-123',
      hotel: const {'id': 'hotel-abc'},
      quote: quote,
      guest: const GuestDetails(
        name: 'James Bond',
        email: 'bond@mi6.gov.uk',
        phone: '0123456789',
      ),
      adults: 2,
      children: 0,
      confirmationCode: 'BOND0007',
    );
    expect(payload['partner_id'], isNull);
  });

  test('payload refuses a missing user id', () {
    expect(
      () => buildBookingPayload(
        userId: '',
        hotel: const {'id': 'h'},
        quote: sampleQuote(),
        guest: const GuestDetails(name: 'Ab', email: 'a@b.co', phone: '1'),
        adults: 1,
        children: 0,
        confirmationCode: 'X',
      ),
      throwsArgumentError,
    );
  });

  group('describeBookingError', () {
    test('RLS denial is explicit and not created', () {
      final e = describeBookingError(
        const PostgrestException(message: 'denied', code: '42501'),
      );
      expect(e.message, contains('RLS'));
      expect(e.maybeCreated, isFalse);
    });
    test('duplicate code means it may already exist', () {
      final e = describeBookingError(
        const PostgrestException(message: 'dup', code: '23505'),
      );
      expect(e.maybeCreated, isTrue);
    });
    test('network loss warns about duplicates; no raw payload', () {
      final e = describeBookingError(
        Exception('ClientException: Failed host lookup secret-body'),
      );
      expect(e.maybeCreated, isTrue);
      expect(e.message, isNot(contains('secret-body')));
    });
    test('auth exception asks to sign in again', () {
      expect(
        describeBookingError(const AuthException('x')).message,
        contains('đăng nhập'),
      );
    });
  });

  group('voucher discount pricing', () {
    test('discount comes off the room total before tax and fee', () {
      final price = sampleQuote().breakdownWithDiscount(4000);
      // 44000 - 4000 = 40000; tax 4000; fee 2000.
      expect(price.discountCents, 4000);
      expect(price.taxCents, 4000);
      expect(price.feeCents, 2000);
      expect(price.totalCents, 46000);
    });

    test('discount never exceeds the room total', () {
      final price = sampleQuote().breakdownWithDiscount(999999999);
      expect(price.discountCents, 44000);
      expect(price.totalCents, 0);
    });

    test('payload stores the same discounted total the user saw', () {
      final payload = buildBookingPayload(
        userId: 'u',
        hotel: const {'id': 'h'},
        quote: sampleQuote(),
        guest: const GuestDetails(
          name: 'Ab',
          email: 'a@b.co',
          phone: '12345678',
          voucherCode: 'hotel20',
          discountCents: 4000,
          discountUsd: 40,
        ),
        adults: 2,
        children: 0,
        confirmationCode: 'X',
      );
      expect(payload['discount_cents'], 4000);
      expect(payload['tax_cents'], 4000);
      expect(payload['total_cents'], 46000);
      expect((payload['metadata'] as Map)['voucher_applied'], isTrue);
    });

    test('uneven nightly prices still satisfy the DB pricing check', () {
      final quote = RoomQuote(
        room: const {'id': 'r'},
        start: DateTime(2026, 3, 1),
        end: DateTime(2026, 3, 4),
        roomCount: 1,
        guestCount: 2,
        nights: const [
          NightRate(date: '2026-03-01', priceCents: 10000),
          NightRate(date: '2026-03-02', priceCents: 10000),
          NightRate(date: '2026-03-03', priceCents: 12000),
        ],
        currency: 'USD',
        source: RateSource.exact,
      );
      final payload = buildBookingPayload(
        userId: 'u',
        hotel: const {'id': 'h'},
        quote: quote,
        guest: const GuestDetails(
          name: 'Ab',
          email: 'a@b.co',
          phone: '12345678',
        ),
        adults: 2,
        children: 0,
        confirmationCode: 'X',
      );
      expect(payload['total_cents'], quote.breakdown.totalCents);
      expect(
        payload['nightly_rate_cents'] * 3 +
            payload['tax_cents'] +
            payload['fees_cents'] -
            payload['discount_cents'],
        payload['total_cents'],
      );
    });
  });
}
