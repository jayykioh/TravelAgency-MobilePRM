class Hotel {
  const Hotel({required this.data});

  final Map<String, dynamic> data;

  factory Hotel.fromJson(Map<String, dynamic> json) => Hotel(data: json);

  String get id => '${data['id']}';
  String get name => '${data['name'] ?? ''}';
  List<dynamic> get images => data['images'] as List? ?? const [];
  double? get bestPriceCents => (data['best_price'] as num?)?.toDouble();
  Map<String, dynamic> toJson() => Map<String, dynamic>.from(data);
}
