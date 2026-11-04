/// AI insight returned by the existing web route `POST /api/hotels/insights`.
class HotelInsight {
  const HotelInsight({
    required this.title,
    required this.mainInsight,
    this.perfectFor = const [],
    this.highlights = const [],
    this.bestTimeToVisit,
    this.localTips = const [],
  });

  final String title;
  final String mainInsight;
  final List<String> perfectFor;
  final List<String> highlights;
  final String? bestTimeToVisit;
  final List<String> localTips;

  /// Parses the route response (`{success, insights}`). Returns null when the
  /// payload has no usable insight text.
  static HotelInsight? fromResponse(dynamic body) {
    if (body is! Map) return null;
    final raw = body['insights'];
    if (body['success'] != true || raw is! Map) return null;
    List<String> list(dynamic value) => value is List
        ? value.map((e) => '$e'.trim()).where((e) => e.isNotEmpty).toList()
        : const [];
    final main = '${raw['mainInsight'] ?? ''}'.trim();
    if (main.isEmpty) return null;
    final best = '${raw['bestTimeToVisit'] ?? ''}'.trim();
    return HotelInsight(
      title: '${raw['title'] ?? 'AI Insight'}'.trim(),
      mainInsight: main,
      perfectFor: list(raw['perfectFor']),
      highlights: list(raw['highlights']),
      bestTimeToVisit: best.isEmpty ? null : best,
      localTips: list(raw['localTips']),
    );
  }
}
