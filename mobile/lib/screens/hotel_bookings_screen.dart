import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/hotel_state.dart';
import '../widgets/hotel_image.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String status = 'all';
  @override
  Widget build(BuildContext context) {
    final state = context.read<HotelState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Đơn khách sạn của tôi')),
      body: FutureBuilder(
        future: state.service.bookingsFor(state.bookingOwnerRef),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Không đọc được đơn: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data!.isEmpty) {
            return const Center(child: Text('Chưa có đơn đặt phòng'));
          }
          final visible = status == 'all'
              ? snapshot.data!
              : snapshot.data!
                    .where((booking) => booking['status'] == status)
                    .toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                  ),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'WELCOME BACK',
                      style: TextStyle(color: Colors.white54),
                    ),
                    const Text(
                      'Your journeys',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${snapshot.data!.length} hotel bookings',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['all', 'pending', 'confirmed', 'cancelled']
                      .map(
                        (value) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(value.toUpperCase()),
                            selected: status == value,
                            onSelected: (_) => setState(() => status = value),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 16),
              if (visible.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: Text('Không có đơn ở trạng thái này')),
                ),
              for (final b in visible)
                Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(14),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        hotelImageUrl(b['hotels']?['images']),
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                      ),
                    ),
                    title: Text(
                      '${b['hotels']?['name'] ?? 'Khách sạn'}',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Text(
                      '${b['check_in_date']} → ${b['check_out_date']}\n${b['status']} · ${((b['total_cents'] as num?) ?? 0) / 100} ${b['currency']}',
                    ),
                    isThreeLine: true,
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: Text('${b['hotels']?['name'] ?? 'Khách sạn'}'),
                        content: Text(
                          'Mã: ${b['confirmation_code']}\nPhòng: ${b['hotel_rooms']?['title'] ?? ''}\nNgày: ${b['check_in_date']} → ${b['check_out_date']}\nKhách: ${b['guest_name']} · ${b['guest_email']} · ${b['guest_phone']}\nTổng: ${((b['total_cents'] as num?) ?? 0) / 100} ${b['currency']}\nTrạng thái: ${b['status']}\nThanh toán: ${b['payment_status']}',
                        ),
                        actions: [
                          if (b['status'] == 'pending')
                            TextButton(
                              onPressed: () async {
                                await state.service.cancelBooking('${b['id']}');
                                if (!c.mounted) return;
                                Navigator.pop(c);
                                setState(() {});
                              },
                              child: const Text(
                                'Hủy đơn',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          TextButton(
                            onPressed: () => Navigator.pop(c),
                            child: const Text('Đóng'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
