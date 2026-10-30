class HotelReview {
  const HotelReview({required this.data});

  final Map<String, dynamic> data;

  factory HotelReview.fromJson(Map<String, dynamic> json) =>
      HotelReview(data: json);

  double get rating => (data['overall_rating'] as num?)?.toDouble() ?? 0;
  String get comment => '${data['comment'] ?? ''}';
  String get title => '${data['title'] ?? ''}';
  Map<String, dynamic> toJson() => Map<String, dynamic>.from(data);
}
