import 'package:flutter/material.dart';

import '../screens/hotel_detail_screen.dart';
import 'hotel_image.dart';

class HotelCard extends StatelessWidget {
  const HotelCard({super.key, required this.hotel});

  final Map<String, dynamic> hotel;

  String get image {
    return hotelImageUrl(hotel['images']);
  }

  String get address {
    final value = hotel['address'];
    if (value is Map) {
      return [
        value['line1'],
        value['district'],
        value['city'],
      ].where((part) => part != null && '$part'.trim().isNotEmpty).join(', ');
    }
    return value == null ? 'Việt Nam' : '$value';
  }

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 20),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(30),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .07),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => DetailScreen(hotel: hotel)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Image.network(
                image,
                height: 230,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, error, stack) => Container(
                  height: 230,
                  color: const Color(0xFFFFE1D5),
                  child: const Icon(Icons.hotel, size: 60),
                ),
              ),
              Positioned(
                top: 14,
                left: 14,
                child: Chip(
                  backgroundColor: Colors.white.withValues(alpha: .94),
                  label: Text(
                    '★ ${hotel['star_rating'] ?? '—'}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const Positioned(
                top: 14,
                right: 14,
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(Icons.favorite_border, color: Color(0xFFFF5E1F)),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${hotel['name']}',
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 17,
                      color: Color(0xFFFF5E1F),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        address,
                        style: const TextStyle(color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (hotel['_hasAvailability'] == false)
                  const Chip(
                    avatar: Icon(Icons.schedule, size: 17),
                    label: Text('Chưa có giá cho ngày đã chọn'),
                  )
                else
                  const Chip(label: Text('Có phòng')),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'From ${((hotel['best_price'] as num?) ?? 0) / 100} USD / night',
                        style: const TextStyle(
                          color: Color(0xFFFF5E1F),
                          fontSize: 18,
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
                          builder: (_) => DetailScreen(hotel: hotel),
                        ),
                      ),
                      child: const Text('Xem khách sạn'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
