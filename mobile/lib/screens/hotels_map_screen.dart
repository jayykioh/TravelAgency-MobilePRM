import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../providers/hotel_state.dart';
import '../widgets/hotel_image.dart';
import 'hotel_detail_screen.dart';

/// OpenStreetMap using address.lat/address.lng from Supabase hotels.
class HotelsMapScreen extends StatefulWidget {
  const HotelsMapScreen({super.key});
  @override
  State<HotelsMapScreen> createState() => _HotelsMapScreenState();
}

class _HotelsMapScreenState extends State<HotelsMapScreen> {
  Future<List<Map<String, dynamic>>>? request;
  Map<String, dynamic>? selected;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    request ??= context.read<HotelState>().hotels();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('HotelsMap')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: request,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _MapError(error: snapshot.error, onRetry: _reload);
        }
        final hotels = snapshot.data ?? [];
        final positioned = hotels
            .where((hotel) => _point(hotel) != null)
            .toList();
        if (positioned.isEmpty) {
          return const Center(
            child: Text('Không có khách sạn chứa address.lat/address.lng'),
          );
        }
        final points = positioned.map(_point).whereType<LatLng>().toList();
        return Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCameraFit: CameraFit.bounds(
                  bounds: LatLngBounds.fromPoints(points),
                  padding: const EdgeInsets.fromLTRB(50, 50, 50, 180),
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.tripc.mobile',
                  errorTileCallback: (_, error, stackTrace) {},
                ),
                MarkerLayer(
                  markers: [
                    for (final hotel in positioned)
                      Marker(
                        point: _point(hotel)!,
                        width: 88,
                        height: 44,
                        child: Tooltip(
                          message: '${hotel['name']}',
                          child: InkWell(
                            onTap: () => setState(() => selected = hotel),
                            borderRadius: BorderRadius.circular(22),
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: selected?['id'] == hotel['id']
                                    ? const Color(0xFF0F172A)
                                    : const Color(0xFFFF5E1F),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: Text(
                                _price(hotel),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 18,
              child: selected == null
                  ? _hint(positioned.length, hotels.length)
                  : _hotelCard(selected!),
            ),
          ],
        );
      },
    ),
  );

  void _reload() =>
      setState(() => request = context.read<HotelState>().hotels());

  Widget _hint(int mapped, int total) => Card(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        '$mapped/$total khách sạn có tọa độ thật. Chạm marker để xem nhanh.',
        textAlign: TextAlign.center,
      ),
    ),
  );

  Widget _hotelCard(Map<String, dynamic> hotel) => Card(
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
    child: InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DetailScreen(hotel: hotel)),
      ),
      child: Row(
        children: [
          Image.network(
            hotelImageUrl(hotel['images']),
            width: 112,
            height: 105,
            fit: BoxFit.cover,
            errorBuilder: (_, error, stackTrace) => Container(
              width: 112,
              height: 105,
              color: const Color(0xFFE2E8F0),
              child: const Icon(Icons.hotel),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${hotel['name']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    _addressText(hotel),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _price(hotel),
                    style: const TextStyle(
                      color: Color(0xFFFF5E1F),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 10),
            child: Icon(Icons.chevron_right),
          ),
        ],
      ),
    ),
  );

  LatLng? _point(Map<String, dynamic> hotel) {
    final address = hotel['address'];
    final lat = _number(
      hotel['latitude'] ??
          hotel['lat'] ??
          (address is Map ? address['lat'] : null),
    );
    final lng = _number(
      hotel['longitude'] ??
          hotel['lng'] ??
          (address is Map ? address['lng'] : null),
    );
    if (lat == null || lng == null || lat.abs() > 90 || lng.abs() > 180) {
      return null;
    }
    return LatLng(lat, lng);
  }

  double? _number(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value');
  String _price(Map<String, dynamic> hotel) =>
      '\$${(((hotel['best_price'] as num?) ?? 0) / 100).toStringAsFixed(0)}';
  String _addressText(Map<String, dynamic> hotel) {
    final address = hotel['address'];
    if (address is Map) {
      return '${address['line1'] ?? ''}, ${address['city'] ?? ''}';
    }
    return '$address';
  }
}

class _MapError extends StatelessWidget {
  const _MapError({required this.error, required this.onRetry});
  final Object? error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.map_outlined, size: 58),
          const SizedBox(height: 12),
          Text(
            'Không tải được HotelsMap.\n$error',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    ),
  );
}
