class HotelRoom {
  const HotelRoom({required this.data});

  final Map<String, dynamic> data;

  factory HotelRoom.fromJson(Map<String, dynamic> json) =>
      HotelRoom(data: json);

  String get id => '${data['id']}';
  String get hotelId => '${data['hotel_id']}';
  String get title => '${data['title'] ?? 'Room'}';
  int get capacity => (data['capacity'] as num?)?.toInt() ?? 0;
  Map<String, dynamic> toJson() => Map<String, dynamic>.from(data);
}
