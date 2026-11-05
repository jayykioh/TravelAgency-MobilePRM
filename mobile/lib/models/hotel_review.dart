class HotelReview {
  const HotelReview({required this.data});

  final Map<String, dynamic> data;

  factory HotelReview.fromJson(Map<String, dynamic> json) =>
      HotelReview(data: json);

  /// Unified `reviews.rating`, or legacy `hotel_reviews.overall_rating`.
  double get rating =>
      ((data['rating'] ?? data['overall_rating']) as num?)?.toDouble() ?? 0;
  String get comment => '${data['comment'] ?? ''}';
  String get title => '${data['title'] ?? ''}';
  bool get isVerified => data['is_verified'] == true;
  DateTime? get createdAt => DateTime.tryParse('${data['created_at']}');
  Map<String, dynamic> toJson() => Map<String, dynamic>.from(data);
}

/// Review summary shown on hotel detail. Uses loaded reviews when present,
/// otherwise the aggregate stored on the hotel row. Never invents a rating.
class ReviewSummary {
  const ReviewSummary({required this.average, required this.count});

  final double? average;
  final int count;

  bool get hasReviews => count > 0 && average != null && average! > 0;

  factory ReviewSummary.from({
    required List<HotelReview> reviews,
    required Map<String, dynamic> hotel,
  }) {
    final hotelCount = (hotel['review_count'] as num?)?.toInt() ?? 0;
    final hotelAverage = (hotel['average_rating'] as num?)?.toDouble();
    if (hotelCount > 0 && (hotelAverage ?? 0) > 0) {
      return ReviewSummary(average: hotelAverage, count: hotelCount);
    }
    final rated = reviews.where((r) => r.rating > 0).toList();
    if (rated.isEmpty) return const ReviewSummary(average: null, count: 0);
    final sum = rated.fold<double>(0, (s, r) => s + r.rating);
    return ReviewSummary(average: sum / rated.length, count: rated.length);
  }
}
