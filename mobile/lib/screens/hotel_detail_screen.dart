import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/hotel_state.dart';
import '../widgets/hotel_image.dart';
import 'hotel_checkout_screen.dart';

class DetailScreen extends StatelessWidget {
  const DetailScreen({super.key, required this.hotel});
  final Map<String, dynamic> hotel;
  @override
  Widget build(BuildContext context) {
    final state = context.read<HotelState>();
    final rawImages = hotel['images'] as List? ?? const [];
    final images = rawImages.isEmpty
        ? <String>[fallbackHotelImage]
        : rawImages.map((image) => hotelImageUrl([image])).toList();
    return Scaffold(
      appBar: AppBar(title: Text('${hotel['name']}')),
      body: FutureBuilder(
        future: state.roomsFor('${hotel['id']}'),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rooms = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SizedBox(
                height: 300,
                child: PageView.builder(
                  itemCount: images.length,
                  itemBuilder: (_, index) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Image.network(
                        images[index],
                        fit: BoxFit.cover,
                        errorBuilder: (_, error, stack) => Image.network(
                          fallbackHotelImage,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Chip(label: Text('★ ${hotel['star_rating'] ?? '—'}')),
                  const Spacer(),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.favorite_border),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.share_outlined),
                  ),
                ],
              ),
              Text(
                '${hotel['description'] ?? ''}',
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
              Text(
                '${hotel['address'] ?? 'Vietnam'}',
                style: const TextStyle(color: Color(0xFF64748B)),
              ),
              if (hotel['policies'] != null) ...[
                const SizedBox(height: 18),
                const Text(
                  'Property policies',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                Text(
                  '${hotel['policies']}',
                  style: const TextStyle(height: 1.5),
                ),
              ],
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFF1EA), Color(0xFFFFFBF8)],
                  ),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.auto_awesome, color: Color(0xFFFF5E1F)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI Travel Insight',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                          Text(
                            'A premium stay with highly rated facilities and convenient access to local highlights.',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Amenity Highlights',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: (hotel['amenities'] as List? ?? [])
                    .take(12)
                    .map(
                      (amenity) => Chip(
                        avatar: const Icon(Icons.star_outline, size: 17),
                        label: Text('$amenity'),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 28),
              const Text(
                'Guest Reviews',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              ),
              Text(
                '★ ${hotel['average_rating'] ?? '—'} · ${hotel['review_count'] ?? 0} reviews',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Chọn loại phòng',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              if (rooms.isEmpty) const Text('Không có phòng phù hợp số khách.'),
              for (final room in rooms) _RoomCard(hotel: hotel, room: room),
            ],
          );
        },
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.hotel, required this.room});
  final Map<String, dynamic> hotel;
  final Map<String, dynamic> room;

  @override
  Widget build(BuildContext context) {
    final rate = room['_rate'] as Map<String, dynamic>?;
    final fallbackPrice = (hotel['best_price'] as num?)?.toInt() ?? 10000;
    final priceCents = (rate?['price_cents'] as num?)?.toInt() ?? fallbackPrice;
    final normalizedPrice = priceCents / 100;
    final currency = '${rate?['currency'] ?? 'USD'}';
    final pricedRoom = <String, dynamic>{
      ...room,
      '_priceCents': priceCents,
      '_currency': currency,
      '_partnerId': rate?['partner_id'],
    };
    return Container(
      margin: const EdgeInsets.only(top: 14),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.network(
            hotelImageUrl(room['images']),
            width: double.infinity,
            height: 190,
            fit: BoxFit.cover,
            errorBuilder: (_, error, stack) => Container(
              height: 190,
              color: const Color(0xFFFFE1D5),
              child: const Icon(Icons.bed_outlined, size: 60),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${room['title'] ?? 'Room'}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '${room['bed_type'] ?? ''} · ${room['size_sqm'] ?? '—'} m² · Tối đa ${room['capacity']} khách',
                ),
                if ((room['amenities'] as List? ?? []).isNotEmpty)
                  Text((room['amenities'] as List).take(5).join(' · ')),
                Text(
                  '${rate?['breakfast_included'] == true ? 'Breakfast included' : 'Room only'} · ${rate?['refundable'] == true ? 'Refundable' : 'Cancellation policy applies'}',
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
                if (room['_usedFallbackRate'] == true)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'Giá tham khảo gần nhất',
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$normalizedPrice $currency / đêm',
                        style: const TextStyle(
                          color: Color(0xFFFF5E1F),
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5E1F),
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              BookingScreen(hotel: hotel, room: pricedRoom),
                        ),
                      ),
                      child: const Text('Reserve'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
