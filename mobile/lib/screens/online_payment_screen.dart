import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/booking_request.dart';
import '../models/online_payment.dart';
import '../models/room_quote.dart';
import '../providers/hotel_state.dart';
import '../utils/hotel_format.dart';
import 'booking_review_screen.dart';
import 'hotel_bookings_screen.dart';

const _brand = Color(0xFFFF5E1F);
const _muted = Color(0xFF64748B);
const _success = Color(0xFF16A34A);

typedef UrlOpener = Future<bool> Function(Uri url);

Future<bool> _openExternal(Uri url) =>
    launchUrl(url, mode: LaunchMode.externalApplication);

/// Booking with a MoMo/PayPal session: opens the gateway in the browser, then
/// re-checks the payment with the server whenever the app comes back.
class OnlinePaymentScreen extends StatefulWidget {
  const OnlinePaymentScreen({
    super.key,
    required this.payment,
    required this.hotelName,
    required this.roomTitle,
    required this.quote,
    this.openCheckoutOnStart = false,
    this.openUrl = _openExternal,
  });

  final OnlinePayment payment;
  final String hotelName;
  final String roomTitle;
  final RoomQuote quote;
  final bool openCheckoutOnStart;
  final UrlOpener openUrl;

  @override
  State<OnlinePaymentScreen> createState() => _OnlinePaymentScreenState();
}

class _OnlinePaymentScreenState extends State<OnlinePaymentScreen>
    with WidgetsBindingObserver {
  late OnlinePayment payment = widget.payment;
  bool checking = false;
  bool openedCheckout = false;
  String? message;

  String get providerLabel => payment.provider?.label ?? 'cổng thanh toán';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.openCheckoutOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openCheckout());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && openedCheckout) _refresh();
  }

  Future<void> _openCheckout() async {
    final url = payment.paymentUrl;
    if (payment.isPaid || url == null) return;
    var ok = false;
    try {
      ok = await widget.openUrl(Uri.parse(url));
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      openedCheckout = ok;
      message = ok ? null : 'Không mở được trang thanh toán $providerLabel.';
    });
  }

  Future<void> _refresh() async {
    if (checking) return;
    setState(() {
      checking = true;
      message = null;
    });
    try {
      final next = await context.read<HotelState>().paymentStatus(
        payment.bookingId,
      );
      if (!mounted) return;
      setState(() {
        payment = payment.withUpdate(next);
        if (!payment.isPaid) {
          message =
              'Chưa nhận được thanh toán. Hoàn tất trên $providerLabel rồi kiểm tra lại.';
        }
      });
    } catch (e) {
      if (mounted) setState(() => message = describeBookingError(e).message);
    } finally {
      if (mounted) setState(() => checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final paid = payment.isPaid;
    final booking = payment.booking;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(paid ? 'Đã thanh toán' : 'Thanh toán $providerLabel'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(
            paid ? Icons.check_circle_rounded : Icons.payments_outlined,
            size: 72,
            color: paid ? _success : _brand,
          ),
          const SizedBox(height: 12),
          Text(
            paid ? 'Thanh toán thành công' : 'Đang chờ thanh toán',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            paid
                ? 'Đơn đã được thanh toán qua $providerLabel.'
                : 'Hoàn tất thanh toán trên trang $providerLabel, rồi quay lại app.',
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
                value: '${booking['confirmation_code'] ?? '—'}',
                strong: true,
              ),
              PriceLine(label: 'Mã đơn', value: payment.bookingId, muted: true),
              PriceLine(
                label: 'Thanh toán',
                value: paid ? 'Đã thanh toán' : 'Chưa thanh toán',
              ),
              PriceLine(
                label: payment.testMode ? 'Số tiền (test)' : 'Số tiền',
                value: formatMoney(
                  (payment.amount * 100).round(),
                  payment.currency,
                ),
                strong: true,
              ),
            ],
          ),
          if (payment.testMode) ...[
            const SizedBox(height: 12),
            const InfoBanner(
              icon: Icons.science_outlined,
              text:
                  'Chế độ test: chỉ thu số tiền test, không phải tổng giá phòng. PayPal quy đổi sang USD.',
            ),
          ],
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(
              message!,
              key: const ValueKey('payment-message'),
              style: const TextStyle(color: Color(0xFFB91C1C)),
            ),
          ],
          const SizedBox(height: 24),
          if (!paid) ...[
            if (payment.paymentUrl != null) ...[
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: _brand),
                  onPressed: checking ? null : _openCheckout,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Mở trang thanh toán'),
                ),
              ),
              const SizedBox(height: 8),
            ],
            SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                key: const ValueKey('payment-refresh'),
                onPressed: checking ? null : _refresh,
                icon: checking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: const Text('Kiểm tra thanh toán'),
              ),
            ),
          ],
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute<void>(builder: (_) => const HistoryScreen()),
            ),
            child: const Text('Xem đơn của tôi'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            child: const Text('Về trang chủ'),
          ),
        ],
      ),
    );
  }
}
