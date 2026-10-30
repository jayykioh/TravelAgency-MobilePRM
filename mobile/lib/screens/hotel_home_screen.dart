import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/hotel_state.dart';
import '../widgets/filter_section.dart';
import '../widgets/hotel_card.dart';
import '../widgets/guest_selector.dart';
import 'auth_screen.dart';
import 'hotel_bookings_screen.dart';

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
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Handpicked stays',
                        style: TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    DropdownButton<String>(
                      value: state.sortBy,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(
                          value: 'recommended',
                          child: Text('Recommended'),
                        ),
                        DropdownMenuItem(
                          value: 'price_low',
                          child: Text('Price ↑'),
                        ),
                        DropdownMenuItem(
                          value: 'price_high',
                          child: Text('Price ↓'),
                        ),
                        DropdownMenuItem(
                          value: 'rating',
                          child: Text('Top rated'),
                        ),
                        DropdownMenuItem(
                          value: 'popular',
                          child: Text('Popular'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        state.sortBy = value;
                        final nextResults = state.hotels();
                        setState(() {
                          results = nextResults;
                        });
                      },
                    ),
                    IconButton.filledTonal(
                      onPressed: () async {
                        await showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => const HotelFilterSheet(),
                        );
                        final nextResults = state.hotels();
                        setState(() {
                          results = nextResults;
                        });
                      },
                      icon: const Icon(Icons.tune),
                    ),
                  ],
                ),
              ),
            ),
            if (snapshot.connectionState != ConnectionState.done)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (snapshot.hasError)
              SliverFillRemaining(
                child: Center(
                  child: Text('Không tải được khách sạn: ${snapshot.error}'),
                ),
              )
            else if ((snapshot.data ?? []).isEmpty)
              const SliverFillRemaining(
                child: Center(child: Text('Không có khách sạn phù hợp')),
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
