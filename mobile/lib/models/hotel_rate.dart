class HotelRate {
  const HotelRate({required this.data});

  final Map<String, dynamic> data;

  factory HotelRate.fromJson(Map<String, dynamic> json) =>
      HotelRate(data: json);

  int get priceCents => (data['price_cents'] as num?)?.toInt() ?? 0;
  String get currency => '${data['currency'] ?? 'USD'}';
  DateTime? get date => DateTime.tryParse('${data['date']}');
  Map<String, dynamic> toJson() => Map<String, dynamic>.from(data);
}
