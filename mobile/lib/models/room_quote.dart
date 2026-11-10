/// Where the displayed nightly price comes from.
enum RateSource {
  /// One partner has a rate with availability for every night of the stay.
  exact,

  /// No full-stay rate exists; the most recent known room rate is shown as a
  /// reference price. Availability is not confirmed.
  fallbackRate,

  /// The room has no rates at all; the hotel's `best_price` is shown as a
  /// reference price (same source the web booking sidebar uses).
  hotelBestPrice,
}

extension RateSourceX on RateSource {
  String get key => switch (this) {
    RateSource.exact => 'exact',
    RateSource.fallbackRate => 'fallback_rate',
    RateSource.hotelBestPrice => 'hotel_best_price',
  };

  bool get isReference => this != RateSource.exact;
}

class NightRate {
  const NightRate({required this.date, required this.priceCents});
  final String date;
  final int priceCents;

  Map<String, dynamic> toJson() => {'date': date, 'price_cents': priceCents};
}

/// Price rules mirrored from the existing web hotel checkout
/// (`BookingSidebar.tsx`, `checkout.service.ts`): 10% tax and 5% service fee
/// on the room total. A voucher discount is taken off the room total before
/// tax and fee are applied. Amounts are integer cents.
class PriceBreakdown {
  const PriceBreakdown({
    required this.subtotalCents,
    required this.taxCents,
    required this.feeCents,
    this.discountCents = 0,
  });

  /// [discountCents] is clamped to `0..subtotalCents`.
  factory PriceBreakdown.fromSubtotal(
    int subtotalCents, {
    int discountCents = 0,
  }) {
    final discount = discountCents.clamp(0, subtotalCents);
    final taxable = subtotalCents - discount;
    return PriceBreakdown(
      subtotalCents: subtotalCents,
      discountCents: discount,
      taxCents: (taxable * taxRate).round(),
      feeCents: (taxable * serviceFeeRate).round(),
    );
  }

  static const taxRate = 0.10;
  static const serviceFeeRate = 0.05;

  final int subtotalCents;
  final int discountCents;
  final int taxCents;
  final int feeCents;

  /// Room total after the voucher discount (the base for tax and fee).
  int get discountedSubtotalCents => subtotalCents - discountCents;
  int get totalCents => discountedSubtotalCents + taxCents + feeCents;
}

/// A priced room for a specific stay (dates + room count + guests).
class RoomQuote {
  const RoomQuote({
    required this.room,
    required this.start,
    required this.end,
    required this.roomCount,
    required this.guestCount,
    required this.nights,
    required this.currency,
    required this.source,
    this.partnerId,
    this.rate,
  });

  final Map<String, dynamic> room;
  final DateTime start;
  final DateTime end;
  final int roomCount;
  final int guestCount;
  final List<NightRate> nights;
  final String currency;
  final RateSource source;
  final String? partnerId;

  /// The representative rate row (for breakfast/refundable flags). Only
  /// meaningful when it came from `hotel_rates`.
  final Map<String, dynamic>? rate;

  String get roomId => '${room['id']}';
  String get roomTitle => '${room['title'] ?? 'Phòng'}';
  int get nightCount => nights.length;

  int get stayCentsPerRoom =>
      nights.fold(0, (sum, night) => sum + night.priceCents);
  int get subtotalCents => stayCentsPerRoom * roomCount;

  /// Average nightly price per room, rounded to cents.
  int get averageNightlyCents =>
      nights.isEmpty ? 0 : (stayCentsPerRoom / nights.length).round();

  PriceBreakdown get breakdown => PriceBreakdown.fromSubtotal(subtotalCents);

  /// [breakdown] with a voucher discount (minor units of [currency]).
  PriceBreakdown breakdownWithDiscount(int discountCents) =>
      PriceBreakdown.fromSubtotal(subtotalCents, discountCents: discountCents);

  bool? get breakfastIncluded =>
      rate == null ? null : rate!['breakfast_included'] == true;
  bool? get refundable => rate == null ? null : rate!['refundable'] == true;

  /// True when this quote was computed for the given stay. Used to stop a
  /// stale quote from reaching checkout after dates/guests/rooms changed.
  bool matches({
    required DateTime start,
    required DateTime end,
    required int roomCount,
    required int guestCount,
  }) =>
      _sameDay(this.start, start) &&
      _sameDay(this.end, end) &&
      this.roomCount == roomCount &&
      this.guestCount == guestCount;

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

String isoDay(DateTime value) => DateTime(
  value.year,
  value.month,
  value.day,
).toIso8601String().substring(0, 10);

List<String> stayDates(DateTime start, DateTime end) {
  final first = DateTime(start.year, start.month, start.day);
  final last = DateTime(end.year, end.month, end.day);
  final days = <String>[];
  for (
    var d = first;
    d.isBefore(last);
    d = DateTime(d.year, d.month, d.day + 1)
  ) {
    days.add(isoDay(d));
  }
  return days;
}

/// Builds a quote for [room] from its `hotel_rates` rows.
///
/// 1. Exact: the cheapest partner that has a rate with `available_rooms > 0`
///    (and `min_nights` satisfied) for every night in `[start, end)`.
/// 2. Fallback: the cheapest rate on the most recent known date, applied to
///    each night, flagged as a reference price.
/// 3. Hotel best price: when the room has no rates, `hotels.best_price`.
///
/// Returns null when no price source exists; the room must not be bookable.
RoomQuote? buildRoomQuote({
  required Map<String, dynamic> room,
  required List<Map<String, dynamic>> rates,
  required DateTime start,
  required DateTime end,
  required int roomCount,
  required int guestCount,
  num? hotelBestPriceCents,
}) {
  final dates = stayDates(start, end);
  if (dates.isEmpty) return null;

  RoomQuote quote({
    required List<NightRate> nights,
    required String currency,
    required RateSource source,
    String? partnerId,
    Map<String, dynamic>? rate,
  }) => RoomQuote(
    room: room,
    start: start,
    end: end,
    roomCount: roomCount,
    guestCount: guestCount,
    nights: nights,
    currency: currency,
    source: source,
    partnerId: partnerId,
    rate: rate,
  );

  int price(Map<String, dynamic> rate) =>
      (rate['price_cents'] as num?)?.toInt() ?? 0;
  String day(Map<String, dynamic> rate) => '${rate['date']}'.length >= 10
      ? '${rate['date']}'.substring(0, 10)
      : '${rate['date']}';

  // 1. Exact partner coverage.
  final wanted = dates.toSet();
  final byPartner = <String, Map<String, Map<String, dynamic>>>{};
  for (final rate in rates) {
    final date = day(rate);
    if (!wanted.contains(date)) continue;
    if (((rate['available_rooms'] as num?)?.toInt() ?? 0) < roomCount) continue;
    final minNights = (rate['min_nights'] as num?)?.toInt() ?? 1;
    if (minNights > dates.length) continue;
    final partner = '${rate['partner_id'] ?? ''}';
    final perDate = byPartner.putIfAbsent(partner, () => {});
    final existing = perDate[date];
    if (existing == null || price(rate) < price(existing)) perDate[date] = rate;
  }
  Map<String, Map<String, dynamic>>? best;
  String? bestPartner;
  var bestTotal = 0;
  byPartner.forEach((partner, perDate) {
    if (perDate.length != dates.length) return;
    final currencies = perDate.values.map((r) => '${r['currency'] ?? 'USD'}');
    if (currencies.toSet().length != 1) return;
    final total = perDate.values.fold(0, (sum, r) => sum + price(r));
    if (best == null || total < bestTotal) {
      best = perDate;
      bestPartner = partner;
      bestTotal = total;
    }
  });
  if (best != null) {
    final chosen = best!;
    final first = chosen[dates.first]!;
    return quote(
      nights: [
        for (final date in dates)
          NightRate(date: date, priceCents: price(chosen[date]!)),
      ],
      currency: '${first['currency'] ?? 'USD'}',
      source: RateSource.exact,
      partnerId: bestPartner!.isEmpty ? null : bestPartner,
      rate: first,
    );
  }

  // 2. Most recent known rate as a reference.
  final priced = rates.where((r) => price(r) > 0).toList();
  if (priced.isNotEmpty) {
    final latest = priced
        .map(day)
        .reduce((a, b) => a.compareTo(b) >= 0 ? a : b);
    final onLatest = priced.where((r) => day(r) == latest).toList()
      ..sort((a, b) => price(a).compareTo(price(b)));
    final ref = onLatest.first;
    final partner = ref['partner_id'];
    return quote(
      nights: [
        for (final date in dates) NightRate(date: date, priceCents: price(ref)),
      ],
      currency: '${ref['currency'] ?? 'USD'}',
      source: RateSource.fallbackRate,
      partnerId: partner == null ? null : '$partner',
      rate: ref,
    );
  }

  // 3. Hotel best price (USD cents) as a reference.
  final bestPrice = hotelBestPriceCents?.toInt() ?? 0;
  if (bestPrice > 0) {
    return quote(
      nights: [
        for (final date in dates) NightRate(date: date, priceCents: bestPrice),
      ],
      currency: 'USD',
      source: RateSource.hotelBestPrice,
    );
  }
  return null;
}

/// A room shown on hotel detail with its quote (null when unpriced).
class RoomOption {
  const RoomOption({required this.room, this.quote});
  final Map<String, dynamic> room;
  final RoomQuote? quote;

  String get id => '${room['id']}';
  bool get isBookable => quote != null;
}
