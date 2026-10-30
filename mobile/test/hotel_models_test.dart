import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/hotel.dart';
import 'package:mobile/models/hotel_booking.dart';
import 'package:mobile/models/hotel_rate.dart';
import 'package:mobile/models/hotel_room.dart';
import 'package:mobile/widgets/hotel_image.dart';

void main() {
  test('hotel maps Supabase price and images', () {
    final hotel = Hotel.fromJson({
      'id': 'h1',
      'name': 'TripC Resort',
      'best_price': 6200,
      'images': ['https://example.com/hotel.jpg'],
    });
    expect(hotel.id, 'h1');
    expect(hotel.bestPriceCents, 6200);
    expect(hotel.images, hasLength(1));
  });

  test('room and rate map capacity and cents', () {
    final room = HotelRoom.fromJson({
      'id': 'r1',
      'hotel_id': 'h1',
      'title': 'Deluxe',
      'capacity': 4,
    });
    final rate = HotelRate.fromJson({
      'price_cents': 12500,
      'currency': 'USD',
      'date': '2026-03-01',
    });
    expect(room.capacity, 4);
    expect(rate.priceCents, 12500);
    expect(rate.date, DateTime(2026, 3));
  });

  test('booking defaults to pending', () {
    final booking = HotelBooking.fromJson({'id': 'b1'});
    expect(booking.status, 'pending');
  });

  test('image parser supports object URL and fallback', () {
    expect(
      hotelImageUrl([
        {'image_url': 'https://example.com/room.jpg'},
      ]),
      'https://example.com/room.jpg',
    );
    expect(hotelImageUrl(const []), fallbackHotelImage);
  });
}
