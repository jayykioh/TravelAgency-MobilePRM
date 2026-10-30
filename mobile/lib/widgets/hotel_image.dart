const fallbackHotelImage =
    'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=1600&q=80';

String hotelImageUrl(dynamic value, {String fallback = fallbackHotelImage}) {
  if (value is List && value.isNotEmpty) {
    final first = value.first;
    if (first is String && first.isNotEmpty) return first;
    if (first is Map) {
      final candidate = first['url'] ?? first['image_url'];
      if (candidate is String && candidate.isNotEmpty) return candidate;
    }
  }
  if (value is String && value.isNotEmpty) return value;
  return fallback;
}
