import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/voucher.dart';
import '../providers/hotel_state.dart';
import '../widgets/hotel_image.dart';
import 'hotel_bookings_screen.dart';
import '../services/voucher_service.dart';
import 'rewards_vouchers_screen.dart';

class _PriceLine extends StatelessWidget {
  const _PriceLine({
    required this.label,
    required this.value,
    this.strong = false,
    this.color,
  });
  final String label;
  final String value;
  final bool strong;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: strong ? FontWeight.w900 : null,
              color: color,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: strong ? FontWeight.w900 : FontWeight.w600,
            fontSize: strong ? 18 : null,
            color: color,
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
  final name = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final specialRequests = TextEditingController();
  final voucher = TextEditingController();
  bool busy = false;
  String? error;

  VoucherValidationResult _voucherResult = VoucherValidationResult.none;
  bool _isValidatingVoucher = false;
  Timer? _voucherDebounce;

  @override
  void initState() {
    super.initState();
    final state = context.read<HotelState>();
    name.text = state.draftGuestName;
    email.text = state.draftGuestEmail.isNotEmpty
        ? state.draftGuestEmail
        : (state.currentUser?.email ?? '');
    phone.text = state.draftGuestPhone;
    specialRequests.text = state.draftSpecialRequests;
    voucher.text = state.draftVoucherCode;

    name.addListener(_syncDraft);
    email.addListener(_syncDraft);
    phone.addListener(_syncDraft);
    specialRequests.addListener(_syncDraft);
    voucher.addListener(_syncDraft);

    if (voucher.text.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkVoucherCode(voucher.text);
      });
    }
  }

  void _onVoucherInputChanged(String val) {
    _voucherDebounce?.cancel();
    _voucherDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        _checkVoucherCode(val);
      }
    });
  }

  Future<void> _checkVoucherCode(String code) async {
    final clean = code.trim().toUpperCase();
    if (clean.isEmpty) {
      if (mounted && _voucherResult.isValid) {
        setState(() {
          _voucherResult = VoucherValidationResult.none;
        });
      }
      return;
    }

    final state = context.read<HotelState>();
    final nightly = (widget.room['_priceCents'] as num?)?.toInt() ?? 10000;
    final subtotalUsd = (nightly * state.nights * state.rooms) / 100.0;
    final voucherService = VoucherService(state.service.client);

    setState(() => _isValidatingVoucher = true);

    try {
      final res = await voucherService.validateVoucher(
        code: clean,
        cartTotalUsd: subtotalUsd,
        userId: state.currentUser?.id,
      );
      if (!mounted) return;
      setState(() {
        _voucherResult = res;
        _isValidatingVoucher = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isValidatingVoucher = false);
    }
  }

  void _syncDraft() {
    if (!mounted) return;
    context.read<HotelState>().saveGuestDraft(
      name: name.text,
      email: email.text,
      phone: phone.text,
      specialRequests: specialRequests.text,
      voucherCode: voucher.text,
    );
  }

  @override
  void dispose() {
    _voucherDebounce?.cancel();
    name.removeListener(_syncDraft);
    email.removeListener(_syncDraft);
    phone.removeListener(_syncDraft);
    specialRequests.removeListener(_syncDraft);
    voucher.removeListener(_syncDraft);
    name.dispose();
    email.dispose();
    phone.dispose();
    specialRequests.dispose();
    voucher.dispose();
    super.dispose();
  }

  Future<void> _pickVoucherFromWallet() async {
    final state = context.read<HotelState>();
    final userId = state.currentUser?.id;
    final voucherService = VoucherService(state.service.client);
    final wallet = await voucherService.fetchUserVouchers(userId);

    if (!mounted) return;

    if (wallet.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Ví voucher của bạn đang trống.'),
          action: SnackBarAction(
            label: 'Đổi ngay',
            textColor: const Color(0xFFFF5E1F),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const RewardsVouchersScreen(initialTabIndex: 1),
                ),
              );
            },
          ),
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              const Text(
                'Chọn voucher từ ví của bạn',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: wallet.length,
                  itemBuilder: (_, i) {
                    final uv = wallet[i];
                    final v = uv.voucher;
                    final code = v?.code ?? 'VOUCHER';
                    final discount = v?.formattedDiscount ?? 'Ưu đãi';
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (v?.categoryColor ?? const Color(0xFFFF5E1F)).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(v?.categoryIcon ?? Icons.confirmation_number_rounded, color: v?.categoryColor ?? const Color(0xFFFF5E1F)),
                      ),
                      title: Text(code, style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(discount, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                      trailing: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            voucher.text = code;
                          });
                          _checkVoucherCode(code);
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF5E1F),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                        child: const Text('Áp dụng', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<HotelState>();
    final nightly = (widget.room['_priceCents'] as num?)?.toInt() ?? 10000;
    final subtotal = nightly * state.nights * state.rooms;
    final discountCents = _voucherResult.isValid ? _voucherResult.discountCents : 0;
    final discountedSubtotal = (subtotal - discountCents).clamp(0, 999999999);
    final tax = (discountedSubtotal * .10).round();
    final fee = (discountedSubtotal * .05).round();
    final grandTotal = discountedSubtotal + tax + fee;
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
                    errorBuilder: (_, __, ___) => Container(
                      height: 230,
                      color: const Color(0xFFF1F5F9),
                      child: const Center(
                        child: Icon(Icons.hotel_rounded, size: 48, color: Color(0xFF94A3B8)),
                      ),
                    ),
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
            if (!state.isAuthenticated) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFFFD5C2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_circle_outlined,
                        color: Color(0xFFFF5E1F), size: 28),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bạn chưa đăng nhập',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: Color(0xFF9A3412),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Đăng nhập để liên kết đơn đặt phòng với tài khoản của bạn.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFFC2410C),
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFFF5E1F),
                        textStyle: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      onPressed: () async {
                        final loggedIn = await state.requireAuth(
                          context,
                          reason:
                              'Đăng nhập để liên kết đơn đặt phòng với tài khoản TripC của bạn.',
                        );
                        if (loggedIn && mounted && email.text.isEmpty) {
                          email.text = state.currentUser?.email ?? '';
                        }
                      },
                      child: const Text('Đăng nhập'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
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
              onChanged: _onVoucherInputChanged,
              decoration: InputDecoration(
                labelText: 'Mã giảm giá (Voucher)',
                prefixIcon: const Icon(Icons.local_offer_outlined),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isValidatingVoucher)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF5E1F)),
                        ),
                      ),
                    IconButton(
                      tooltip: 'Chọn từ ví voucher',
                      icon: const Icon(Icons.confirmation_number_rounded, color: Color(0xFFFF5E1F)),
                      onPressed: _pickVoucherFromWallet,
                    ),
                  ],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
            if (_voucherResult.isValid) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Đã áp dụng mã ${_voucherResult.code}: Giảm \$${_voucherResult.discountUsd.toStringAsFixed(1)}',
                        style: const TextStyle(
                          color: Color(0xFF15803D),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_voucherResult.errorMessage != null && voucher.text.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _voucherResult.errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFFB91C1C),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
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
                  if (_voucherResult.isValid)
                    _PriceLine(
                      label: 'Voucher discount (${_voucherResult.code})',
                      value: '-${_voucherResult.discountUsd.toStringAsFixed(1)} $currency',
                      color: const Color(0xFF16A34A),
                      strong: true,
                    ),
                  _PriceLine(label: 'Tax 10%', value: '${tax / 100} $currency'),
                  _PriceLine(
                    label: 'Service fee 5%',
                    value: '${fee / 100} $currency',
                  ),
                  const Divider(),
                  _PriceLine(
                    label: 'Total',
                    value: '${grandTotal / 100} $currency',
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
      final discountCents = _voucherResult.isValid ? _voucherResult.discountCents : 0;
      final discountedSubtotal = (subtotal - discountCents).clamp(0, 999999999);
      final tax = (discountedSubtotal * .10).round();
      final fees = (discountedSubtotal * .05).round();
      final grandTotal = discountedSubtotal + tax + fees;
      if (!mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Review đặt phòng'),
          content: Text(
            '${state.day(state.start)} → ${state.day(state.end)}\n'
            '${state.guests} khách · ${state.nights} đêm\n'
            '${selected.map((r) => "${r['date']}: ${(r['price_cents'] as num) / 100} ${r['currency']}").join("\n")}\n'
            'Giá phòng: ${subtotal / 100} $currency\n'
            '${_voucherResult.isValid ? "Giảm giá voucher (${_voucherResult.code}): -${_voucherResult.discountUsd.toStringAsFixed(1)} $currency\n" : ""}'
            'Thuế 10%: ${tax / 100} $currency\n'
            'Phí dịch vụ 5%: ${fees / 100} $currency\n'
            'Tổng: ${grandTotal / 100} $currency\n'
            'Chờ xác nhận · Chưa thanh toán',
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
          if (_voucherResult.isValid) ...{
            'voucher_code': _voucherResult.code,
            'discount_cents': _voucherResult.discountCents,
            'discount_usd': _voucherResult.discountUsd,
          } else if (voucher.text.trim().isNotEmpty) ...{
            'voucher_code': voucher.text.trim().toUpperCase(),
          },
        },
      });
      if (!mounted) return;
      state.clearGuestDraft();
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
