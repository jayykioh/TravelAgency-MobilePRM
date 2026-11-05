import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/booking_request.dart';
import '../models/room_quote.dart';
import '../providers/hotel_state.dart';
import '../utils/hotel_format.dart';
import 'hotel_bookings_screen.dart';
import 'hotel_checkout_screen.dart';

const _brand = Color(0xFFFF5E1F);
const _muted = Color(0xFF64748B);
const _border = Color(0xFFE2E8F0);

/// Story 4-2 (summary & price breakdown) and 4-3 (create pending booking).
class BookingReviewScreen extends StatefulWidget {
  const BookingReviewScreen({
    super.key,
    required this.hotel,
    required this.guest,
  });
  final Map<String, dynamic> hotel;
  final GuestDetails guest;

  @override
  State<BookingReviewScreen> createState() => _BookingReviewScreenState();
}

class _BookingReviewScreenState extends State<BookingReviewScreen> {
  bool busy = false;
  BookingCreationException? error;

  Future<void> _submit(RoomQuote quote) async {
    if (busy) return;
    final state = context.read<HotelState>();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (!state.isAuthenticated) {
        final ok = await state.requireAuth(
          context,
          reason:
              'Đăng nhập để gửi yêu cầu đặt phòng dưới tài khoản TripC của bạn.',
        );
        if (!ok) {
          throw const BookingCreationException(
            'Bạn cần đăng nhập để gửi yêu cầu đặt phòng. Thông tin đã nhập vẫn được giữ.',
          );
        }
      }
      if (!state.selectedQuoteIsCurrent) {
        throw const BookingCreationException(
          'Thông tin lưu trú đã thay đổi. Vui lòng quay lại chọn phòng.',
        );
      }
      final code = state.pendingConfirmationCode ??= generateConfirmationCode();
      final payload = buildBookingPayload(
        userId: state.authenticatedUserId,
        hotel: widget.hotel,
        quote: quote,
        guest: widget.guest,
        adults: state.guests,
        children: state.children,
        confirmationCode: code,
      );
      final booking = await state.createBooking(payload);
      if (!mounted) return;
      state.completeBooking();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute<void>(
          builder: (_) => BookingResultScreen(
            booking: booking,
            hotelName: '${widget.hotel['name'] ?? ''}',
            roomTitle: quote.roomTitle,
            quote: quote,
          ),
        ),
        (route) => route.isFirst,
      );
    } catch (e) {
      if (mounted) setState(() => error = describeBookingError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<HotelState>();
    final quote = state.selectedQuote;
    if (quote == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Xem lại đặt phòng')),
        body: const Center(child: Text('Chưa chọn phòng.')),
      );
    }
    final price = quote.breakdown;
    final guest = widget.guest;
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Xem lại đặt phòng')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            BookingSummaryCard(hotel: widget.hotel, quote: quote, state: state),
            const SizedBox(height: 16),
            _Card(
              title: 'Khách lưu trú',
              trailing: TextButton(
                onPressed: busy ? null : () => Navigator.pop(context),
                child: const Text('Sửa'),
              ),
              children: [
                Text(
                  guest.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(guest.email),
                Text(guest.phone),
                if (guest.specialRequests.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Yêu cầu: ${guest.specialRequests}',
                    style: const TextStyle(color: _muted),
                  ),
                ],
                if (guest.voucherCode.isNotEmpty)
                  Text(
                    'Mã ưu đãi: ${guest.voucherCode.toUpperCase()} (chưa áp dụng vào tổng)',
                    style: const TextStyle(color: _muted),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _Card(
              title: 'Chi tiết giá',
              children: [
                for (final night in quote.nights)
                  _PriceLine(
                    label:
                        'Đêm ${formatDay(DateTime.parse(night.date))}'
                        '${quote.roomCount > 1 ? ' × ${quote.roomCount} phòng' : ''}',
                    value: formatMoney(
                      night.priceCents * quote.roomCount,
                      quote.currency,
                    ),
                    muted: true,
                  ),
                const Divider(),
                _PriceLine(
                  label: 'Tiền phòng',
                  value: formatMoney(price.subtotalCents, quote.currency),
                ),
                _PriceLine(
                  label: 'Thuế (10%)',
                  value: formatMoney(price.taxCents, quote.currency),
                ),
                _PriceLine(
                  label: 'Phí dịch vụ (5%)',
                  value: formatMoney(price.feeCents, quote.currency),
                ),
                const Divider(),
                _PriceLine(
                  label: 'Tổng cộng',
                  value: formatMoney(price.totalCents, quote.currency),
                  strong: true,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (quote.source.isReference)
              const _Banner(
                icon: Icons.info_outline,
                text:
                    'Giá tham khảo: chưa có giá cho đúng ngày bạn chọn. Khách sạn sẽ xác nhận giá và phòng trống trước khi đơn được xác nhận.',
              ),
            const _Banner(
              icon: Icons.hourglass_top,
              text:
                  'Chờ xác nhận · Chưa thanh toán. Đây là yêu cầu đặt phòng, không phải xác nhận phòng; app không thu tiền.',
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Container(
                key: const ValueKey('booking-error'),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      error!.message,
                      style: const TextStyle(color: Color(0xFFB91C1C)),
                    ),
                    if (error!.maybeCreated)
                      TextButton(
                        style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const HistoryScreen(),
                          ),
                        ),
                        child: const Text('Mở “Đơn của tôi”'),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: 54,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _brand),
                onPressed: busy ? null : () => _submit(quote),
                child: busy
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text('Đang gửi yêu cầu…'),
                        ],
                      )
                    : Text(
                        state.isAuthenticated
                            ? 'Gửi yêu cầu đặt phòng'
                            : 'Đăng nhập & gửi yêu cầu',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown only after the backend returned a real booking id.
class BookingResultScreen extends StatelessWidget {
  const BookingResultScreen({
    super.key,
    required this.booking,
    required this.hotelName,
    required this.roomTitle,
    required this.quote,
  });
  final Map<String, dynamic> booking;
  final String hotelName;
  final String roomTitle;
  final RoomQuote quote;

  @override
  Widget build(BuildContext context) {
    final total =
        (booking['total_cents'] as num?)?.toInt() ?? quote.breakdown.totalCents;
    final currency = '${booking['currency'] ?? quote.currency}';
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Đã gửi yêu cầu'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.hourglass_top_rounded, size: 72, color: _brand),
          const SizedBox(height: 12),
          const Text(
            'Yêu cầu đặt phòng đã được ghi nhận',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Khách sạn sẽ xác nhận sau. Đơn chưa được thanh toán.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted),
          ),
          const SizedBox(height: 24),
          _Card(
            title: hotelName,
            children: [
              Text(roomTitle),
              Text(
                '${formatDay(quote.start)} → ${formatDay(quote.end)} · ${quote.nightCount} đêm',
              ),
              const Divider(),
              _PriceLine(
                label: 'Mã xác nhận',
                value: '${booking['confirmation_code'] ?? '—'}',
                strong: true,
              ),
              _PriceLine(
                label: 'Mã đơn',
                value: '${booking['id']}',
                muted: true,
              ),
              const _PriceLine(label: 'Trạng thái', value: 'Chờ xác nhận'),
              const _PriceLine(label: 'Thanh toán', value: 'Chưa thanh toán'),
              _PriceLine(
                label: 'Tổng cộng',
                value: formatMoney(total, currency),
                strong: true,
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _brand),
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute<void>(builder: (_) => const HistoryScreen()),
              ),
              child: const Text('Xem đơn của tôi'),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            child: const Text('Về trang chủ'),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.children, this.trailing});
  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    ),
  );
}

class _PriceLine extends StatelessWidget {
  const _PriceLine({
    required this.label,
    required this.value,
    this.strong = false,
    this.muted = false,
  });
  final String label;
  final String value;
  final bool strong;
  final bool muted;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: muted ? _muted : null,
              fontWeight: strong ? FontWeight.w900 : null,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: muted ? _muted : (strong ? _brand : null),
              fontWeight: strong ? FontWeight.w900 : FontWeight.w600,
              fontSize: strong ? 17 : null,
            ),
          ),
        ),
      ],
    ),
  );
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF7ED),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFFFD5C2)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFFC2410C), size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(color: Color(0xFF9A3412))),
        ),
      ],
    ),
  );
}
