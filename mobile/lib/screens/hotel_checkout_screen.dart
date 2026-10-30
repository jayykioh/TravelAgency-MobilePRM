import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/hotel_state.dart';
import '../widgets/hotel_image.dart';
import 'hotel_bookings_screen.dart';

class _PriceLine extends StatelessWidget {
  const _PriceLine({
    required this.label,
    required this.value,
    this.strong = false,
  });
  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontWeight: strong ? FontWeight.w900 : null),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: strong ? FontWeight.w900 : FontWeight.w600,
            fontSize: strong ? 18 : null,
          ),
        ),
      ],
    ),
  );
}

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key, required this.hotel, required this.room});
  final Map<String, dynamic> hotel, room;
  @override
  State<BookingScreen> createState() => _BookingState();
}

class _BookingState extends State<BookingScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      email = TextEditingController(),
      phone = TextEditingController(),
      specialRequests = TextEditingController(),
      voucher = TextEditingController();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    name.dispose();
    email.dispose();
    phone.dispose();
    specialRequests.dispose();
    voucher.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<HotelState>();
    final nightly = (widget.room['_priceCents'] as num?)?.toInt() ?? 10000;
    final subtotal = nightly * state.nights * state.rooms;
    final tax = (subtotal * .10).round();
    final fee = (subtotal * .05).round();
    final currency = '${widget.room['_currency'] ?? 'USD'}';
    return Scaffold(
      appBar: AppBar(title: const Text('Complete your booking')),
      body: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(
                alignment: Alignment.bottomLeft,
                children: [
                  Image.network(
                    hotelImageUrl(widget.hotel['images']),
                    height: 230,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: .78),
                        ],
                      ),
                    ),
                    child: Text(
                      '${widget.hotel['name']}\n${widget.room['title'] ?? 'Room'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Guest Information',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            for (final field in [
              (name, 'Full name', Icons.person_outline),
              (email, 'Email', Icons.email_outlined),
              (phone, 'Phone number', Icons.phone_outlined),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextFormField(
                  controller: field.$1,
                  decoration: InputDecoration(
                    labelText: field.$2,
                    prefixIcon: Icon(field.$3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return 'Vui lòng nhập ${field.$2}';
                    if (field.$1 == email &&
                        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
                      return 'Email không hợp lệ';
                    }
                    if (field.$1 == phone &&
                        !RegExp(r'^\+?[0-9\s-]{8,15}$').hasMatch(text)) {
                      return 'Số điện thoại không hợp lệ';
                    }
                    return null;
                  },
                ),
              ),
            TextFormField(
              controller: specialRequests,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Special requests / Notes',
                prefixIcon: const Icon(Icons.notes),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: voucher,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Voucher code',
                prefixIcon: const Icon(Icons.local_offer_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _PriceLine(
                    label:
                        'Room × ${state.nights} nights × ${state.rooms} rooms',
                    value: '${subtotal / 100} $currency',
                  ),
                  _PriceLine(label: 'Tax 10%', value: '${tax / 100} $currency'),
                  _PriceLine(
                    label: 'Service fee 5%',
                    value: '${fee / 100} $currency',
                  ),
                  const Divider(),
                  _PriceLine(
                    label: 'Total',
                    value: '${(subtotal + tax + fee) / 100} $currency',
                    strong: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Chờ xác nhận · Chưa thanh toán'),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            SizedBox(
              height: 54,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5E1F),
                ),
                onPressed: busy ? null : review,
                child: Text(busy ? 'Đang xử lý…' : 'Confirm booking'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> review() async {
    if (!form.currentState!.validate()) return;
    final state = context.read<HotelState>();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final nightlyPrice =
          (widget.room['_priceCents'] as num?)?.toInt() ?? 10000;
      final currency = '${widget.room['_currency'] ?? 'USD'}';
      final partnerId = widget.room['_partnerId'];
      final selected = List.generate(state.nights, (index) {
        final date = state.start.add(Duration(days: index));
        return <String, dynamic>{
          'date': state.day(date),
          'price_cents': nightlyPrice,
          'currency': currency,
          'partner_id': partnerId,
        };
      });
      final subtotal = nightlyPrice * state.nights * state.rooms;
      final tax = (subtotal * .10).round();
      final fees = (subtotal * .05).round();
      final grandTotal = subtotal + tax + fees;
      if (!mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Review đặt phòng'),
          content: Text(
            '${state.day(state.start)} → ${state.day(state.end)}\n${state.guests} khách · ${state.nights} đêm\n${selected.map((r) => "${r['date']}: ${(r['price_cents'] as num) / 100} ${r['currency']}").join("\n")}\nGiá phòng: ${subtotal / 100}\nThuế 10%: ${tax / 100}\nPhí dịch vụ 5%: ${fees / 100}\nTổng: ${grandTotal / 100} ${selected.first['currency']}\nChờ xác nhận · Chưa thanh toán',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Quay lại'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Gửi yêu cầu'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
      final confirmationCode =
          'HTL-${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase()}';
      final booking = await state.service.createBooking({
        'external_user_ref': state.bookingOwnerRef,
        'hotel_id': widget.hotel['id'],
        'room_id': widget.room['id'],
        'partner_id': partnerId,
        'confirmation_code': confirmationCode,
        'check_in_date': state.day(state.start),
        'check_out_date': state.day(state.end),
        'guest_name': name.text.trim(),
        'guest_email': email.text.trim(),
        'guest_phone': phone.text.trim(),
        'guest_count': {
          'adults': state.guests,
          'children': state.children,
          'rooms': state.rooms,
        },
        'special_requests': specialRequests.text.trim(),
        'total_cents': grandTotal,
        'nightly_rate_cents': (subtotal / state.nights).round(),
        'tax_cents': tax,
        'fees_cents': fees,
        'currency': currency,
        'status': 'pending',
        'payment_status': 'pending',
        'booking_source': 'mobile',
        'metadata': {
          'nightly': selected,
          if (voucher.text.trim().isNotEmpty)
            'voucher_code': voucher.text.trim().toUpperCase(),
        },
      });
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Đã ghi nhận yêu cầu'),
          content: Text(
            'Mã xác nhận: ${booking['confirmation_code']}\nChờ xác nhận · Chưa thanh toán',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(builder: (_) => const HistoryScreen()),
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = 'Không thể đặt phòng: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}
