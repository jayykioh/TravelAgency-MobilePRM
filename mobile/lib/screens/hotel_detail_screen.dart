import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/hotel_insight.dart';
import '../models/hotel_review.dart';
import '../models/room_quote.dart';
import '../providers/hotel_state.dart';
import '../utils/hotel_format.dart';
import '../widgets/guest_selector.dart';
import '../widgets/hotel_image.dart';
import 'hotel_checkout_screen.dart';

const _brand = Color(0xFFFF5E1F);
const _muted = Color(0xFF64748B);
const _border = Color(0xFFE2E8F0);

/// Hotel detail: gallery, content, AI insight, reviews, rooms/rates and the
/// reserve summary bar (Epic 3).
class DetailScreen extends StatefulWidget {
  const DetailScreen({super.key, required this.hotel});
  final Map<String, dynamic> hotel;

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late Future<List<RoomOption>> _rooms;
  late Future<List<HotelReview>> _reviews;
  String _stayKey = '';

  Map<String, dynamic> get hotel => widget.hotel;

  @override
  void initState() {
    super.initState();
    final state = context.read<HotelState>();
    _reviews = state.reviewsFor('${hotel['id']}');
    _loadRooms(state);
  }

  String _keyOf(HotelState s) =>
      '${s.day(s.start)}|${s.day(s.end)}|${s.guests}|${s.children}|${s.rooms}';

  void _loadRooms(HotelState state) {
    _stayKey = _keyOf(state);
    _rooms = state.roomOptionsFor(hotel);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<HotelState>();
    if (_keyOf(state) != _stayKey) _loadRooms(state);
    final selected =
        '${state.selectedHotel?['id']}' == '${hotel['id']}' &&
            state.selectedQuoteIsCurrent
        ? state.selectedQuote
        : null;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 320,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            title: Text(
              '${hotel['name'] ?? ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: _Gallery(images: hotel['images']),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            sliver: SliverList.list(
              children: [
                _Header(hotel: hotel, reviews: _reviews),
                const SizedBox(height: 16),
                _StayCard(state: state),
                const SizedBox(height: 20),
                _Description(text: '${hotel['description'] ?? ''}'.trim()),
                _InsightCard(hotel: hotel),
                _Amenities(values: hotel['amenities']),
                _Policies(value: hotel['policies']),
                _ReviewsSection(
                  hotel: hotel,
                  future: _reviews,
                  onRetry: () {
                    setState(
                      () => _reviews = state.reviewsFor('${hotel['id']}'),
                    );
                  },
                ),
                const SizedBox(height: 28),
                _RoomsSection(
                  hotel: hotel,
                  future: _rooms,
                  selected: selected,
                  onRetry: () => setState(() => _loadRooms(state)),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _ReserveBar(hotel: hotel, quote: selected),
    );
  }
}

// ---- 3-1 Gallery & content -------------------------------------------------

class _Gallery extends StatefulWidget {
  const _Gallery({required this.images});
  final dynamic images;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  int index = 0;

  List<String> get urls {
    final raw = widget.images is List ? widget.images as List : const [];
    final list = raw
        .map((image) => hotelImageUrl([image], fallback: ''))
        .where((url) => url.isNotEmpty)
        .toList();
    return list.isEmpty ? [fallbackHotelImage] : list;
  }

  @override
  Widget build(BuildContext context) {
    final images = urls;
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          itemCount: images.length,
          onPageChanged: (value) => setState(() => index = value),
          itemBuilder: (_, i) => GestureDetector(
            onTap: () => _openViewer(context, images, i),
            child: Image.network(
              images[i],
              fit: BoxFit.cover,
              errorBuilder: (_, error, stack) => Container(
                color: const Color(0xFFFFE1D5),
                child: const Icon(Icons.hotel, size: 64, color: _brand),
              ),
            ),
          ),
        ),
        if (images.length > 1)
          Positioned(
            right: 16,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${index + 1}/${images.length}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
      ],
    );
  }

  void _openViewer(BuildContext context, List<String> images, int initial) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          body: PageView.builder(
            controller: PageController(initialPage: initial),
            itemCount: images.length,
            itemBuilder: (_, i) => InteractiveViewer(
              child: Center(
                child: Image.network(
                  images[i],
                  fit: BoxFit.contain,
                  errorBuilder: (_, error, stack) => const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white54,
                    size: 64,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.hotel, required this.reviews});
  final Map<String, dynamic> hotel;
  final Future<List<HotelReview>> reviews;

  @override
  Widget build(BuildContext context) {
    final stars = (hotel['star_rating'] as num?)?.toInt() ?? 0;
    final type = '${hotel['property_type'] ?? ''}'.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${hotel['name'] ?? ''}',
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (stars > 0)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  stars,
                  (_) => const Icon(Icons.star, size: 16, color: Colors.amber),
                ),
              ),
            if (type.isNotEmpty)
              Text(
                type[0].toUpperCase() + type.substring(1),
                style: const TextStyle(color: _muted),
              ),
            FutureBuilder<List<HotelReview>>(
              future: reviews,
              builder: (context, snapshot) {
                final summary = ReviewSummary.from(
                  reviews: snapshot.data ?? const [],
                  hotel: hotel,
                );
                if (!summary.hasReviews) return const SizedBox.shrink();
                return Text(
                  '★ ${summary.average!.toStringAsFixed(1)} · ${summary.count} đánh giá',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.place_outlined, size: 18, color: _muted),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                hotelAddressText(hotel['address']),
                style: const TextStyle(color: _muted),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StayCard extends StatelessWidget {
  const _StayCard({required this.state});
  final HotelState state;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _border),
    ),
    child: Column(
      children: [
        ListTile(
          leading: const Icon(Icons.calendar_month_outlined, color: _brand),
          title: Text(
            '${formatDay(state.start)} → ${formatDay(state.end)}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text('${state.nights} đêm'),
          trailing: TextButton(
            onPressed: () async {
              final now = DateUtils.dateOnly(DateTime.now());
              final picked = await showDateRangePicker(
                context: context,
                firstDate: now,
                lastDate: now.add(const Duration(days: 365)),
                initialDateRange: DateTimeRange(
                  start: state.start.isBefore(now) ? now : state.start,
                  end: state.end.isAfter(state.start)
                      ? state.end
                      : state.start.add(const Duration(days: 1)),
                ),
              );
              if (picked != null && picked.duration.inDays >= 1) {
                state.updateDates(picked);
              }
            },
            child: const Text('Đổi ngày'),
          ),
        ),
        const Divider(height: 1),
        const GuestSelector(),
      ],
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );
}

class _Description extends StatefulWidget {
  const _Description({required this.text});
  final String text;

  @override
  State<_Description> createState() => _DescriptionState();
}

class _DescriptionState extends State<_Description> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.text.isEmpty) return const SizedBox.shrink();
    final long = widget.text.length > 280;
    return _Section(
      title: 'Giới thiệu',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.text,
            maxLines: expanded || !long ? null : 5,
            overflow: expanded || !long ? null : TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, height: 1.5),
          ),
          if (long)
            TextButton(
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              onPressed: () => setState(() => expanded = !expanded),
              child: Text(expanded ? 'Thu gọn' : 'Xem thêm'),
            ),
        ],
      ),
    );
  }
}

class _Amenities extends StatelessWidget {
  const _Amenities({required this.values});
  final dynamic values;

  @override
  Widget build(BuildContext context) {
    final list = (values is List ? values as List : const [])
        .map((e) => '$e'.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (list.isEmpty) return const SizedBox.shrink();
    return _Section(
      title: 'Tiện ích nổi bật',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: list
            .take(16)
            .map(
              (amenity) => Chip(
                avatar: const Icon(Icons.check_circle_outline, size: 16),
                label: Text(amenity),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _Policies extends StatelessWidget {
  const _Policies({required this.value});
  final dynamic value;

  @override
  Widget build(BuildContext context) {
    final entries = policyEntries(value);
    if (entries.isEmpty) return const SizedBox.shrink();
    return _Section(
      title: 'Chính sách khách sạn',
      child: Column(
        children: [
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(
                      entry.key,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Expanded(child: Text(entry.value)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---- 3-2 AI insight & reviews ---------------------------------------------

class _InsightCard extends StatefulWidget {
  const _InsightCard({required this.hotel});
  final Map<String, dynamic> hotel;

  @override
  State<_InsightCard> createState() => _InsightCardState();
}

class _InsightCardState extends State<_InsightCard> {
  late Future<HotelInsight?> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<HotelState>().insightsFor(widget.hotel);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF1EA), Color(0xFFFFFBF8)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: FutureBuilder<HotelInsight?>(
        future: _future,
        builder: (context, snapshot) {
          final header = Row(
            children: [
              const Icon(Icons.auto_awesome, color: _brand),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  snapshot.data?.title ?? 'AI Travel Insight',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          );
          if (snapshot.connectionState != ConnectionState.done) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                header,
                const SizedBox(height: 12),
                const LinearProgressIndicator(color: _brand),
                const SizedBox(height: 8),
                const Text(
                  'Đang phân tích khách sạn…',
                  style: TextStyle(color: _muted),
                ),
              ],
            );
          }
          final insight = snapshot.data;
          if (snapshot.hasError || insight == null) {
            final missingUrl = '${snapshot.error}'.contains('APP_API_BASE_URL');
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                header,
                const SizedBox(height: 8),
                Text(
                  missingUrl
                      ? 'AI insight chưa khả dụng: app chưa cấu hình APP_API_BASE_URL.'
                      : 'Chưa tải được AI insight cho khách sạn này.',
                  style: const TextStyle(color: _muted),
                ),
                if (!missingUrl)
                  TextButton.icon(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    onPressed: () => setState(() {
                      _future = context.read<HotelState>().insightsFor(
                        widget.hotel,
                      );
                    }),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Thử lại'),
                  ),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              const SizedBox(height: 10),
              Text(insight.mainInsight, style: const TextStyle(height: 1.45)),
              if (insight.perfectFor.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: insight.perfectFor
                      .map(
                        (e) => Chip(
                          visualDensity: VisualDensity.compact,
                          backgroundColor: Colors.white,
                          label: Text(e, style: const TextStyle(fontSize: 12)),
                        ),
                      )
                      .toList(),
                ),
              ],
              for (final item in insight.highlights)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('•  ', style: TextStyle(color: _brand)),
                      Expanded(child: Text(item)),
                    ],
                  ),
                ),
              if (insight.bestTimeToVisit != null) ...[
                const SizedBox(height: 8),
                Text(
                  '⏰ ${insight.bestTimeToVisit}',
                  style: const TextStyle(color: _muted),
                ),
              ],
              const SizedBox(height: 8),
              const Text(
                'Nội dung do AI tạo, chỉ mang tính tham khảo.',
                style: TextStyle(fontSize: 11, color: _muted),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _ReviewsSection extends StatelessWidget {
  const _ReviewsSection({
    required this.hotel,
    required this.future,
    required this.onRetry,
  });
  final Map<String, dynamic> hotel;
  final Future<List<HotelReview>> future;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => _Section(
    title: 'Đánh giá của khách',
    child: FutureBuilder<List<HotelReview>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator(color: _brand)),
          );
        }
        if (snapshot.hasError) {
          return Row(
            children: [
              const Expanded(
                child: Text(
                  'Không tải được đánh giá.',
                  style: TextStyle(color: _muted),
                ),
              ),
              TextButton(onPressed: onRetry, child: const Text('Thử lại')),
            ],
          );
        }
        final reviews = snapshot.data ?? const <HotelReview>[];
        final summary = ReviewSummary.from(reviews: reviews, hotel: hotel);
        if (!summary.hasReviews && reviews.isEmpty) {
          return const Text(
            'Khách sạn chưa có đánh giá.',
            style: TextStyle(color: _muted),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (summary.hasReviews)
              Row(
                children: [
                  Text(
                    summary.average!.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'trên 5 · ${summary.count} đánh giá',
                    style: const TextStyle(color: _muted),
                  ),
                ],
              ),
            if (reviews.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 150,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: reviews.length,
                  separatorBuilder: (_, i) => const SizedBox(width: 10),
                  itemBuilder: (_, i) => _ReviewCard(review: reviews[i]),
                ),
              ),
            ],
          ],
        );
      },
    ),
  );
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});
  final HotelReview review;

  @override
  Widget build(BuildContext context) => Container(
    width: 260,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.star, size: 16, color: Colors.amber),
            Text(
              ' ${review.rating.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            if (review.isVerified)
              const Text(
                'Đã lưu trú',
                style: TextStyle(fontSize: 11, color: Colors.green),
              ),
            if (review.createdAt != null)
              Text(
                '  ${formatDay(review.createdAt!)}',
                style: const TextStyle(fontSize: 11, color: _muted),
              ),
          ],
        ),
        if (review.title.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            review.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
        const SizedBox(height: 4),
        Expanded(
          child: Text(
            review.comment,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF334155)),
          ),
        ),
      ],
    ),
  );
}

// ---- 3-3 Rooms & rate fallback / 3-4 selection ----------------------------

class _RoomsSection extends StatelessWidget {
  const _RoomsSection({
    required this.hotel,
    required this.future,
    required this.selected,
    required this.onRetry,
  });
  final Map<String, dynamic> hotel;
  final Future<List<RoomOption>> future;
  final RoomQuote? selected;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Chọn loại phòng',
        style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
      ),
      FutureBuilder<List<RoomOption>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator(color: _brand)),
            );
          }
          if (snapshot.hasError) {
            return _Notice(
              icon: Icons.cloud_off_outlined,
              text: 'Không tải được danh sách phòng và giá.',
              action: TextButton(
                onPressed: onRetry,
                child: const Text('Thử lại'),
              ),
            );
          }
          final options = snapshot.data ?? const <RoomOption>[];
          if (options.isEmpty) {
            return const _Notice(
              icon: Icons.bed_outlined,
              text:
                  'Không có phòng phù hợp với số khách/số phòng đã chọn. Hãy thử giảm số khách mỗi phòng hoặc tăng số phòng.',
            );
          }
          final anyReference = options.any(
            (o) => o.quote?.source.isReference ?? false,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (anyReference)
                const _Notice(
                  icon: Icons.info_outline,
                  text:
                      'Một số phòng chưa có giá cho đúng ngày bạn chọn. Giá hiển thị là giá tham khảo gần nhất; phòng trống chưa được xác nhận.',
                ),
              for (final option in options)
                _RoomCard(
                  hotel: hotel,
                  option: option,
                  selected: selected?.roomId == option.id,
                ),
            ],
          );
        },
      ),
    ],
  );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text, this.action});
  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF7ED),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFFFD5C2)),
    ),
    child: Row(
      children: [
        Icon(icon, color: const Color(0xFFC2410C)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(color: Color(0xFF9A3412))),
        ),
        ?action,
      ],
    ),
  );
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({
    required this.hotel,
    required this.option,
    required this.selected,
  });
  final Map<String, dynamic> hotel;
  final RoomOption option;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final room = option.room;
    final quote = option.quote;
    final specs = [
      if ('${room['bed_type'] ?? ''}'.isNotEmpty) '${room['bed_type']}',
      if (room['size_sqm'] != null) '${room['size_sqm']} m²',
      'Tối đa ${room['capacity'] ?? '—'} khách',
      if ('${room['view_type'] ?? ''}'.isNotEmpty) 'View ${room['view_type']}',
    ];
    final amenities =
        (room['amenities'] is List ? room['amenities'] as List : [])
            .take(5)
            .join(' · ');
    return GestureDetector(
      onTap: quote == null
          ? null
          : () => context.read<HotelState>().selectRoom(hotel, quote),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(top: 14),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? _brand : _border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.network(
              hotelImageUrl(
                room['images'],
                fallback: hotelImageUrl(hotel['images']),
              ),
              width: double.infinity,
              height: 160,
              fit: BoxFit.cover,
              errorBuilder: (_, error, stack) => Container(
                height: 160,
                color: const Color(0xFFFFE1D5),
                child: const Icon(Icons.bed_outlined, size: 56),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${room['title'] ?? 'Phòng'}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (selected)
                        const Icon(Icons.check_circle, color: _brand),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    specs.join(' · '),
                    style: const TextStyle(color: _muted),
                  ),
                  if (amenities.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(amenities, style: const TextStyle(fontSize: 13)),
                  ],
                  if (quote != null && quote.source == RateSource.exact) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: [
                        _Tag(
                          quote.breakfastIncluded == true
                              ? 'Gồm bữa sáng'
                              : 'Không gồm bữa sáng',
                        ),
                        _Tag(
                          quote.refundable == true
                              ? 'Có hoàn hủy'
                              : 'Áp dụng chính sách hủy',
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (quote == null)
                    const Text(
                      'Chưa có giá cho phòng này',
                      style: TextStyle(color: _muted),
                    )
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (quote.source.isReference)
                                const Text(
                                  'Giá tham khảo',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFFC2410C),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              Text(
                                '${formatMoney(quote.averageNightlyCents, quote.currency)} / đêm',
                                style: const TextStyle(
                                  color: _brand,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                '${formatMoney(quote.subtotalCents, quote.currency)} · ${quote.nightCount} đêm × ${quote.roomCount} phòng (chưa thuế, phí)',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: _muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        selected
                            ? const OutlinedButton(
                                onPressed: null,
                                child: Text('Đã chọn'),
                              )
                            : FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: _brand,
                                ),
                                onPressed: () => context
                                    .read<HotelState>()
                                    .selectRoom(hotel, quote),
                                child: const Text('Chọn'),
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
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(text, style: const TextStyle(fontSize: 12)),
  );
}

class _ReserveBar extends StatelessWidget {
  const _ReserveBar({required this.hotel, required this.quote});
  final Map<String, dynamic> hotel;
  final RoomQuote? quote;

  @override
  Widget build(BuildContext context) {
    final q = quote;
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: q == null
                ? const Text(
                    'Chọn một phòng để tiếp tục',
                    style: TextStyle(color: _muted),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        q.roomTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        formatMoney(q.breakdown.totalCents, q.currency),
                        style: const TextStyle(
                          color: _brand,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '${q.nightCount} đêm · ${q.roomCount} phòng · gồm thuế & phí',
                        style: const TextStyle(fontSize: 12, color: _muted),
                      ),
                    ],
                  ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 50,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _brand),
              onPressed: q == null
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => GuestDetailsScreen(hotel: hotel),
                      ),
                    ),
              child: const Text('Đặt phòng'),
            ),
          ),
        ],
      ),
    );
  }
}
