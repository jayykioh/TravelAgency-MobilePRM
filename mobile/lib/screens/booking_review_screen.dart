import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/booking_request.dart';
import '../models/online_payment.dart';
import '../models/room_quote.dart';
import '../providers/hotel_state.dart';
import '../utils/currency.dart';
import '../utils/hotel_format.dart';
import '../widgets/payment_bottom_sheet.dart';
import 'hotel_bookings_screen.dart';
import 'hotel_checkout_screen.dart';
import 'online_payment_screen.dart';

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
  PaymentProvider? payingWith;
  BookingCreationException? error;

  Future<void> _submit(RoomQuote quote, {PaymentProvider? payWith}) async {
    if (busy) return;
    final state = context.read<HotelState>();
    setState(() {
      busy = true;
      payingWith = payWith;
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
      if (payWith != null) {
        // Server creates the booking with the service role (no RLS block)
        // and returns the MoMo/PayPal checkout URL.
        final payment = await state.createOnlinePayment(payload, payWith);
        if (!mounted) return;
        state.completeBooking();
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute<void>(
            builder: (_) => OnlinePaymentScreen(
              payment: payment,
              hotelName: '${widget.hotel['name'] ?? ''}',
              roomTitle: quote.roomTitle,
              quote: quote,
              openCheckoutOnStart: true,
            ),
          ),
          (route) => route.isFirst,
        );
        return;
      }
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
      debugPrint('Booking submission failed: $e');
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
    final guest = widget.guest;
    final price = quote.breakdownWithDiscount(guest.discountCents);
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Xem lại đặt phòng')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            BookingSummaryCard(hotel: widget.hotel, quote: quote, state: state),
            const SizedBox(height: 16),
            ReviewCard(
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
                    price.discountCents > 0
                        ? 'Mã ưu đãi: ${guest.voucherCode.toUpperCase()} (Đã giảm ${formatMoney(price.discountCents, quote.currency)})'
                        : 'Mã ưu đãi: ${guest.voucherCode.toUpperCase()} (chưa áp dụng vào tổng)',
                    style: TextStyle(
                      color: price.discountCents > 0
                          ? const Color(0xFF16A34A)
                          : _muted,
                      fontWeight: price.discountCents > 0
                          ? FontWeight.w600
                          : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            ReviewCard(
              title: 'Chi tiết giá',
              children: [
                for (final night in quote.nights)
                  PriceLine(
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
                PriceLine(
                  label: 'Tiền phòng',
                  value: formatMoney(price.subtotalCents, quote.currency),
                ),
                if (price.discountCents > 0)
                  PriceLine(
                    label:
                        'Giảm giá voucher (${guest.voucherCode.toUpperCase()})',
                    value:
                        '-${formatMoney(price.discountCents, quote.currency)}',
                    color: const Color(0xFF16A34A),
                    strong: true,
                  ),
                PriceLine(
                  label: 'Thuế (10%)',
                  value: formatMoney(price.taxCents, quote.currency),
                ),
                PriceLine(
                  label: 'Phí dịch vụ (5%)',
                  value: formatMoney(price.feeCents, quote.currency),
                ),
                const Divider(),
                PriceLine(
                  label: 'Tổng cộng',
                  value: formatMoney(price.totalCents, quote.currency),
                  strong: true,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (quote.source.isReference)
              const InfoBanner(
                icon: Icons.info_outline,
                text:
                    'Giá tham khảo: chưa có giá cho đúng ngày bạn chọn. Khách sạn sẽ xác nhận giá và phòng trống trước khi đơn được xác nhận.',
              ),
            const InfoBanner(
              icon: Icons.hourglass_top,
              text:
                  'Chờ xác nhận · Chưa thanh toán. Gửi yêu cầu không trừ tiền; sau khi đơn được tạo, bạn có thể thanh toán ngay qua MoMo/PayPal hoặc thanh toán sau trong “Đơn của tôi”.',
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
            if (state.paymentsAvailable)
              InfoBanner(
                icon: Icons.payments_outlined,
                text: paymentTestAmountVnd > 0
                    ? 'Chế độ test: MoMo/PayPal chỉ thu ${formatMoney(paymentTestAmountVnd * 100, 'VND')} cho đơn này (PayPal quy đổi sang USD), không phải tổng ở trên.'
                    : 'Thanh toán ngay qua MoMo hoặc PayPal. Số tiền thu do máy chủ xác định.',
              ),
            const SizedBox(height: 16),
            if (state.paymentsAvailable)
              for (final provider in PaymentProvider.values) ...[
                _PayButton(
                  provider: provider,
                  busy: busy,
                  loading: busy && payingWith == provider,
                  onPressed: () => _submit(quote, payWith: provider),
                ),
                const SizedBox(height: 10),
              ],
            SizedBox(
              height: 54,
              child: state.paymentsAvailable
                  ? OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: _brand),
                      onPressed: busy ? null : () => _submit(quote),
                      child: Text(
                        busy && payingWith == null
                            ? 'Đang gửi yêu cầu…'
                            : 'Chỉ gửi yêu cầu (thanh toán sau)',
                      ),
                    )
                  : FilledButton(
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

class _PayButton extends StatelessWidget {
  const _PayButton({
    required this.provider,
    required this.busy,
    required this.loading,
    required this.onPressed,
  });
  final PaymentProvider provider;
  final bool busy;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = provider == PaymentProvider.momo
        ? const Color(0xFFA50064)
        : const Color(0xFF003087);
    final amount = paymentTestAmountVnd > 0
        ? ' · ${formatMoney(paymentTestAmountVnd * 100, 'VND')}'
        : '';
    return SizedBox(
      height: 54,
      child: FilledButton.icon(
        key: ValueKey('pay-${provider.key}'),
        style: FilledButton.styleFrom(backgroundColor: color),
        onPressed: busy ? null : onPressed,
        icon: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(
                provider == PaymentProvider.momo
                    ? Icons.account_balance_wallet_outlined
                    : Icons.credit_card,
              ),
        label: Text(
          loading
              ? 'Đang tạo thanh toán…'
              : 'Thanh toán ${provider.label}$amount',
        ),
      ),
    );
  }
}

/// Shown only after the backend returned a real booking id.
class BookingResultScreen extends StatefulWidget {
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
  State<BookingResultScreen> createState() => _BookingResultScreenState();
}

class _BookingResultScreenState extends State<BookingResultScreen> {
  late bool isPaid;

  @override
  void initState() {
    super.initState();
    isPaid = widget.booking['payment_status'] == 'paid';
  }

  @override
  Widget build(BuildContext context) {
    final total =
        (widget.booking['total_cents'] as num?)?.toInt() ??
        widget.quote.breakdown.totalCents;
    final currency = '${widget.booking['currency'] ?? widget.quote.currency}';
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(isPaid ? 'Đặt phòng thành công' : 'Đã gửi yêu cầu'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(
            isPaid ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
            size: 72,
            color: isPaid ? const Color(0xFF16A34A) : _brand,
          ),
          const SizedBox(height: 12),
          Text(
            isPaid
                ? 'Đã thanh toán & xác nhận đặt phòng'
                : 'Yêu cầu đặt phòng đã được ghi nhận',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            isPaid
                ? 'Đơn phòng của bạn đã được thanh toán thành công và sẵn sàng đón tiếp!'
                : 'Khách sạn sẽ xác nhận sau. Bạn có thể thanh toán ngay qua MoMo hoặc PayPal.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted),
          ),
          const SizedBox(height: 24),
          ReviewCard(
            title: widget.hotelName,
            children: [
              Text(widget.roomTitle),
              Text(
                '${formatDay(widget.quote.start)} → ${formatDay(widget.quote.end)} · ${widget.quote.nightCount} đêm',
              ),
              const Divider(),
              PriceLine(
                label: 'Mã xác nhận',
                value: '${widget.booking['confirmation_code'] ?? '—'}',
                strong: true,
              ),
              PriceLine(
                label: 'Mã đơn',
                value: '${widget.booking['id']}',
                muted: true,
              ),
              PriceLine(
                label: 'Trạng thái',
                value: isPaid ? 'Đã xác nhận' : 'Chờ xác nhận',
                color: isPaid ? const Color(0xFF16A34A) : null,
                strong: isPaid,
              ),
              PriceLine(
                label: 'Thanh toán',
                value: isPaid ? 'Đã thanh toán' : 'Chưa thanh toán',
                color: isPaid
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFDC2626),
                strong: true,
              ),
              PriceLine(
                label: 'Tổng cộng',
                value: formatMoney(total, currency),
                strong: true,
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (!isPaid) ...[
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFA50064),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.payment_rounded, color: Colors.white),
                label: const Text(
                  'Thanh toán ngay (MoMo / PayPal)',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                onPressed: () async {
                  final paid = await PaymentBottomSheet.show(
                    context,
                    bookingId: '${widget.booking['id']}',
                    confirmationCode:
                        '${widget.booking['confirmation_code'] ?? 'HTL'}',
                    totalAmountUsd: minorUnitsToUsd(total, currency) ?? 0,
                    hotelName: widget.hotelName,
                    roomTitle: widget.roomTitle,
                    currency: currency,
                  );
                  if (paid == true && mounted) {
                    setState(() => isPaid = true);
                  }
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            height: 52,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: _brand,
                side: const BorderSide(color: _brand),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute<void>(builder: (_) => const HistoryScreen()),
              ),
              child: const Text(
                'Xem đơn của tôi',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
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

class ReviewCard extends StatelessWidget {
  const ReviewCard({
    super.key,
    required this.title,
    required this.children,
    this.trailing,
  });
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

class PriceLine extends StatelessWidget {
  const PriceLine({
    super.key,
    required this.label,
    required this.value,
    this.strong = false,
    this.muted = false,
    this.color,
  });
  final String label;
  final String value;
  final bool strong;
  final bool muted;
  final Color? color;

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
              color: color ?? (muted ? _muted : null),
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
              color: color ?? (muted ? _muted : (strong ? _brand : null)),
              fontWeight: strong ? FontWeight.w900 : FontWeight.w600,
              fontSize: strong ? 17 : null,
            ),
          ),
        ),
      ],
    ),
  );
}

class InfoBanner extends StatelessWidget {
  const InfoBanner({super.key, required this.icon, required this.text});
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
