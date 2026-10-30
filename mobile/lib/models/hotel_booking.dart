class HotelBooking {
  const HotelBooking({required this.data});

  final Map<String, dynamic> data;

  factory HotelBooking.fromJson(Map<String, dynamic> json) =>
      HotelBooking(data: json);

  String get id => '${data['id']}';
  String get status => '${data['status'] ?? 'pending'}';
  String get confirmationCode => '${data['confirmation_code'] ?? ''}';
  Map<String, dynamic> toJson() => Map<String, dynamic>.from(data);
}
