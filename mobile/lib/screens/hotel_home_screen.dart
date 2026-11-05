import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/hotel_state.dart';
import '../widgets/filter_section.dart';
import '../widgets/hotel_card.dart';
import '../widgets/guest_selector.dart';
import 'auth_screen.dart';
import 'hotel_bookings_screen.dart';
import 'rewards_vouchers_screen.dart';

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  Future<List<Map<String, dynamic>>>? results;
  final searchController = TextEditingController();
  final scrollController = ScrollController();
  @override
  void initState() {
    super.initState();
    results = context.read<HotelState>().hotels();
  }

  @override
  void dispose() {
    searchController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  /// Runs the real Supabase search and gives an immediate demo-friendly result.
  Future<void> runSearch() async {
    final state = context.read<HotelState>();
    state.city = searchController.text.trim();
    final request = state.hotels();
    setState(() {
      results = request;
    });
    try {
      final hotels = await request;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tìm thấy ${hotels.length} khách sạn phù hợp')),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (scrollController.hasClients) {
        await scrollController.animateTo(
          470,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOut,
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể tìm khách sạn: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<HotelState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('TripC · Khách sạn'),
        actions: [
          IconButton(
            tooltip: 'Tcent & Vouchers',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const RewardsVouchersScreen(),
              ),
            ),
            icon: const Icon(Icons.card_giftcard_rounded, color: Color(0xFFFF5E1F)),
          ),
          IconButton(
            tooltip: 'Đăng nhập',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const AuthScreen()),
            ),
            icon: const Icon(Icons.person_outline),
          ),
          IconButton(
            tooltip: 'Đơn của tôi',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const HistoryScreen()),
            ),
            icon: const Icon(Icons.receipt_long),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: results,
        builder: (context, snapshot) => CustomScrollView(
          controller: scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  SizedBox(
                    height: 500,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          'https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?q=85&w=1600&auto=format&fit=crop',
                          fit: BoxFit.cover,
                          errorBuilder: (_, error, stack) =>
                              Container(color: const Color(0xFF334155)),
                        ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: .35),
                                Colors.black.withValues(alpha: .08),
                                const Color(0xFFFCFAF8),
                              ],
                            ),
                          ),
                        ),
                        const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(text: 'Find Your '),
                                    TextSpan(
                                      text: 'Escape',
                                      style: TextStyle(
                                        color: Color(0xFFFF6A2A),
                                      ),
                                    ),
                                  ],
                                ),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 42,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                'Discover exquisite stays for your next getaway',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .96),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withValues(alpha: .16),
                            blurRadius: 30,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          TextField(
                            controller: searchController,
                            decoration: const InputDecoration(
                              labelText: 'Điểm đến',
                              hintText: 'Đà Nẵng, Hội An, Hà Nội…',
                              prefixIcon: Icon(
                                Icons.location_on_outlined,
                                color: Color(0xFFFF5E1F),
                              ),
                              border: InputBorder.none,
                            ),
                            onSubmitted: (_) => runSearch(),
                          ),
                          const Divider(),
                          Row(
                            children: [
                              Expanded(
                                child: Material(
                                  color: Colors.transparent,
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(
                                      Icons.calendar_month_outlined,
                                      color: Color(0xFFFF5E1F),
                                    ),
                                    title: const Text('NHẬN — TRẢ PHÒNG'),
                                    subtitle: Text(
                                      '${state.day(state.start)} → ${state.day(state.end)}',
                                    ),
                                    onTap: () async {
                                      final dates = await showDateRangePicker(
                                        context: context,
                                        firstDate: DateTime(2026),
                                        lastDate: DateTime(2027, 12, 31),
                                        initialDateRange: DateTimeRange(
                                          start: state.start,
                                          end: state.end,
                                        ),
                                      );
                                      if (dates != null &&
                                          dates.end.isAfter(dates.start)) {
                                        state.updateDates(dates);
                                      }
                                    },
                                  ),
                                ),
                              ),
                              const Flexible(child: GuestSelector()),
                            ],
                          ),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFFF5E1F),
                              ),
                              onPressed: runSearch,
                              icon: const Icon(Icons.search),
                              label: const Text('Tìm khách sạn'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 18)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const RewardsVouchersScreen(),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.stars_rounded, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Tcent Rewards & Vòng Quay May Mắn',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Quay thưởng mỗi ngày & đổi voucher giảm giá!',
                                style: TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 18)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Chỗ nghỉ nổi bật',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButton<String>(
                        value: state.sortBy,
                        underline: const SizedBox.shrink(),
                        icon: const Icon(Icons.swap_vert_rounded, size: 20, color: Color(0xFFFF5E1F)),
                        items: const [
                          DropdownMenuItem(
                            value: 'recommended',
                            child: Text('Đề xuất', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          ),
                          DropdownMenuItem(
                            value: 'price_low',
                            child: Text('Giá ↑', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          ),
                          DropdownMenuItem(
                            value: 'price_high',
                            child: Text('Giá ↓', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          ),
                          DropdownMenuItem(
                            value: 'rating',
                            child: Text('Đánh giá', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          ),
                          DropdownMenuItem(
                            value: 'popular',
                            child: Text('Phổ biến', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          state.updateSort(value);
                          final nextResults = state.hotels();
                          setState(() {
                            results = nextResults;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Badge.count(
                      count: state.activeFiltersCount,
                      isLabelVisible: state.hasActiveFilters,
                      backgroundColor: const Color(0xFFFF5E1F),
                      child: IconButton.filledTonal(
                        style: IconButton.styleFrom(
                          backgroundColor: state.hasActiveFilters
                              ? const Color(0xFFFFF7ED)
                              : const Color(0xFFF1F5F9),
                          foregroundColor: state.hasActiveFilters
                              ? const Color(0xFFFF5E1F)
                              : const Color(0xFF334155),
                        ),
                        onPressed: () async {
                          await showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => const HotelFilterSheet(),
                          );
                          final nextResults = state.hotels();
                          setState(() {
                            results = nextResults;
                          });
                        },
                        icon: const Icon(Icons.tune_rounded),
                        tooltip: 'Bộ lọc',
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Active filters chip bar
            if (state.hasActiveFilters)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    children: [
                      if (state.priceRange.start.round() > 50 || state.priceRange.end.round() < 1000)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InputChip(
                            label: Text(
                              '\$${state.priceRange.start.round()} - \$${state.priceRange.end.round()}${state.priceRange.end >= 1000 ? '+' : ''}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                            selected: true,
                            selectedColor: const Color(0xFFFFF7ED),
                            deleteIconColor: const Color(0xFFFF5E1F),
                            side: const BorderSide(color: Color(0xFFFFD5C2)),
                            onDeleted: () {
                              state.resetPriceRange();
                              setState(() => results = state.hotels());
                            },
                          ),
                        ),
                      for (final star in state.stars)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InputChip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('$star', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                const SizedBox(width: 2),
                                const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
                              ],
                            ),
                            selected: true,
                            selectedColor: const Color(0xFFFFF7ED),
                            deleteIconColor: const Color(0xFFFF5E1F),
                            side: const BorderSide(color: Color(0xFFFFD5C2)),
                            onDeleted: () {
                              state.removeStarFilter(star);
                              setState(() => results = state.hotels());
                            },
                          ),
                        ),
                      for (final amenity in state.amenities)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InputChip(
                            label: Text(
                              amenity,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                            selected: true,
                            selectedColor: const Color(0xFFFFF7ED),
                            deleteIconColor: const Color(0xFFFF5E1F),
                            side: const BorderSide(color: Color(0xFFFFD5C2)),
                            onDeleted: () {
                              state.removeAmenityFilter(amenity);
                              setState(() => results = state.hotels());
                            },
                          ),
                        ),
                      for (final type in state.propertyTypes)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InputChip(
                            label: Text(
                              type.toUpperCase(),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                            selected: true,
                            selectedColor: const Color(0xFFFFF7ED),
                            deleteIconColor: const Color(0xFFFF5E1F),
                            side: const BorderSide(color: Color(0xFFFFD5C2)),
                            onDeleted: () {
                              state.removePropertyTypeFilter(type);
                              setState(() => results = state.hotels());
                            },
                          ),
                        ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFDC2626),
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                        onPressed: () {
                          state.clearFilters();
                          setState(() => results = state.hotels());
                        },
                        icon: const Icon(Icons.clear_all_rounded, size: 16),
                        label: const Text('Xóa tất cả'),
                      ),
                    ],
                  ),
                ),
              ),

            if (snapshot.connectionState != ConnectionState.done)
              const SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Color(0xFFFF5E1F)),
                      SizedBox(height: 16),
                      Text(
                        'Đang tìm kiếm khách sạn phù hợp...',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (snapshot.hasError)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFEF2F2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.error_outline_rounded,
                            size: 44,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Không thể tải danh sách khách sạn',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFFF5E1F),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                          onPressed: runSearch,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Thử lại', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if ((snapshot.data ?? []).isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.search_off_rounded,
                            size: 52,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Không tìm thấy khách sạn phù hợp',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Thử thay đổi từ khóa điểm đến hoặc xóa các bộ lọc hiện tại để xem thêm kết quả.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 13, height: 1.4),
                        ),
                        if (state.hasActiveFilters) ...[
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFFF5E1F),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                            onPressed: () {
                              state.clearFilters();
                              setState(() => results = state.hotels());
                            },
                            icon: const Icon(Icons.clear_all_rounded, size: 18),
                            label: const Text('Xóa tất cả bộ lọc', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.builder(
                  itemCount: snapshot.data!.length,
                  itemBuilder: (_, index) =>
                      HotelCard(hotel: snapshot.data![index]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
