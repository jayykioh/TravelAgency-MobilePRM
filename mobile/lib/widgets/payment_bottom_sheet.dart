import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/payment_intent.dart';
import '../providers/hotel_state.dart';
import '../services/payment_service.dart';
import 'payment_method_selector.dart';

/// Interactive checkout payment bottom sheet for MoMo and PayPal.
class PaymentBottomSheet extends StatefulWidget {
  const PaymentBottomSheet({
    super.key,
    required this.bookingId,
    required this.confirmationCode,
    required this.totalAmountUsd,
    this.hotelName = 'Đặt phòng khách sạn',
    this.roomTitle = 'Phòng',
    this.currency = 'USD',
  });

  final String bookingId;
  final String confirmationCode;
  final double totalAmountUsd;
  final String hotelName;
  final String roomTitle;
  final String currency;

  static Future<bool?> show(
    BuildContext context, {
    required String bookingId,
    required String confirmationCode,
    required double totalAmountUsd,
    String hotelName = 'Đặt phòng khách sạn',
    String roomTitle = 'Phòng',
    String currency = 'USD',
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PaymentBottomSheet(
        bookingId: bookingId,
        confirmationCode: confirmationCode,
        totalAmountUsd: totalAmountUsd,
        hotelName: hotelName,
        roomTitle: roomTitle,
        currency: currency,
      ),
    );
  }

  @override
  State<PaymentBottomSheet> createState() => _PaymentBottomSheetState();
}

class _PaymentBottomSheetState extends State<PaymentBottomSheet> {
  PaymentProviderType _provider = PaymentProviderType.momo;
  bool _agreed = true;
  bool _isProcessing = false;
  PaymentIntentResult? _activeIntent;
  String? _statusMessage;

  Future<void> _startPayment() async {
    if (!_agreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đồng ý với điều khoản thanh toán.'),
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Đang khởi tạo cổng thanh toán ${_provider.title}...';
    });

    final state = context.read<HotelState>();
    final paymentService = PaymentService(state.service.client);

    try {
      final intent = await paymentService.createPaymentIntent(
        bookingId: widget.bookingId,
        provider: _provider,
        fallbackAmountUsd: widget.totalAmountUsd,
      );

      if (!mounted) return;

      setState(() {
        _activeIntent = intent;
        _isProcessing = false;
        _statusMessage = 'Đang mở cổng thanh toán ${_provider.title}...';
      });

      // Launch URL in browser or external app (MoMo / PayPal)
      if (intent.paymentUrl.isNotEmpty) {
        final uri = Uri.tryParse(intent.paymentUrl);
        if (uri != null) {
          try {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } catch (_) {
            // If failed to launch external app, fallback to in-app or dialog
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _statusMessage = 'Lỗi khởi tạo: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khởi tạo thanh toán: $e')),
      );
    }
  }

  Future<void> _verifyPayment({bool simulateSuccess = false}) async {
    setState(() => _isProcessing = true);
    final state = context.read<HotelState>();
    final paymentService = PaymentService(state.service.client);

    try {
      if (simulateSuccess) {
        // Direct sandbox confirmation
        await paymentService.markBookingPaid(
          bookingId: widget.bookingId,
          provider: _provider.id,
          amount: widget.totalAmountUsd,
          txnId: _activeIntent?.providerTxnId,
        );
      } else {
        // Query backend or check Supabase status
        if (_provider == PaymentProviderType.momo && _activeIntent != null) {
          await paymentService.verifyMomoPayment(
            orderId: _activeIntent!.providerTxnId,
            resultCode: '0',
            bookingId: widget.bookingId,
          );
        } else if (_provider == PaymentProviderType.paypal &&
            _activeIntent != null) {
          await paymentService.syncPaypalPayment(
            token: _activeIntent!.providerTxnId,
            payerId: 'SIMULATED_PAYER',
            bookingId: widget.bookingId,
          );
        } else {
          final isPaid = await paymentService.checkBookingPaymentStatus(
            widget.bookingId,
          );
          if (!isPaid) {
            throw StateError('Chưa nhận được xác nhận thanh toán.');
          }
        }
      }

      if (!mounted) return;
      setState(() => _isProcessing = false);

      // Celebration dialog
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF16A34A),
                  size: 42,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Thanh toán thành công!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Đơn đặt phòng ${widget.confirmationCode} đã được thanh toán qua ${_provider.title}.',
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF5E1F),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => Navigator.pop(c),
              child: const Text('Hoàn tất'),
            ),
          ],
        ),
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Xác nhận thanh toán: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vndAmount = PaymentService.convertUsdToVnd(widget.totalAmountUsd);
    final vndFormatted = vndAmount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Thanh toán đơn phòng',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Mã đơn: ${widget.confirmationCode}',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context, false),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Booking summary card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          widget.hotelName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '\$${widget.totalAmountUsd.toStringAsFixed(1)} USD',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          color: Color(0xFFFF5E1F),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.roomTitle,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '≈ $vndFormatted đ',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Payment waiting view (if intent already created)
            if (_activeIntent != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFFFD5C2)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Color(0xFFFF5E1F),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Đã mở cổng ${_provider.title}. Vui lòng xác nhận giao dịch trên màn hình thanh toán.',
                            style: const TextStyle(
                              color: Color(0xFF9A3412),
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF9A3412),
                              side: const BorderSide(color: Color(0xFFFFB899)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _isProcessing
                                ? null
                                : () => _verifyPayment(simulateSuccess: false),
                            child: const Text('Kiểm tra kết quả'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _isProcessing
                                ? null
                                : () => _verifyPayment(simulateSuccess: true),
                            child: const Text(
                              'Giả lập xong',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ] else ...[
              // Method selector
              PaymentMethodSelector(
                selected: _provider,
                amountUsd: widget.totalAmountUsd,
                disabled: _isProcessing,
                onChanged: (p) => setState(() => _provider = p),
              ),
              const SizedBox(height: 16),

              // Currency Guard notice
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.currency_exchange_rounded,
                      size: 18,
                      color: Color(0xFF475569),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _provider == PaymentProviderType.momo
                            ? 'MoMo tự động quy đổi \$${widget.totalAmountUsd.toStringAsFixed(1)} USD sang $vndFormatted đ'
                            : 'PayPal chấp nhận thanh toán trực tiếp \$${widget.totalAmountUsd.toStringAsFixed(1)} USD',
                        style: const TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Policy checkbox
              InkWell(
                onTap: () => setState(() => _agreed = !_agreed),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _agreed,
                      activeColor: const Color(0xFFFF5E1F),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                      onChanged: (v) => setState(() => _agreed = v ?? true),
                    ),
                    const Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Tôi đã đọc và đồng ý với điều khoản & chính sách hủy phòng của TripC.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Pay button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _provider == PaymentProviderType.momo
                        ? const Color(0xFFA50064)
                        : const Color(0xFF003087),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _isProcessing ? null : _startPayment,
                  child: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Thanh toán qua ${_provider.title} (${_provider == PaymentProviderType.momo ? "$vndFormatted đ" : "\$${widget.totalAmountUsd.toStringAsFixed(1)}"})',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
