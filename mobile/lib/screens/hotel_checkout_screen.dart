import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/booking_request.dart';
import '../models/room_quote.dart';
import '../models/voucher.dart';
import '../providers/hotel_state.dart';
import '../services/voucher_service.dart';
import '../utils/hotel_format.dart';
import '../widgets/hotel_image.dart';
import 'booking_review_screen.dart';
import 'rewards_vouchers_screen.dart';

const _brand = Color(0xFFFF5E1F);
const _muted = Color(0xFF64748B);
const _border = Color(0xFFE2E8F0);

/// Story 4-1: guest details form. Values are mirrored into [HotelState] on
/// every change so they survive back navigation and auth interruptions.
class GuestDetailsScreen extends StatefulWidget {
  const GuestDetailsScreen({super.key, required this.hotel});
  final Map<String, dynamic> hotel;

  @override
  State<GuestDetailsScreen> createState() => _GuestDetailsScreenState();
}

class _GuestDetailsScreenState extends State<GuestDetailsScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final specialRequests = TextEditingController();
  final voucher = TextEditingController();
  AutovalidateMode autovalidate = AutovalidateMode.disabled;

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
    for (final c in _controllers) {
      c.addListener(_syncDraft);
    }
    _prefillFromProfile();

    if (voucher.text.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkVoucherCode(voucher.text);
      });
    }
  }

  List<TextEditingController> get _controllers => [
    name,
    email,
    phone,
    specialRequests,
    voucher,
  ];

  /// Fills empty name/phone from the signed-in user's profile. Best effort:
  /// a missing or forbidden profile simply leaves the fields for the user.
  Future<void> _prefillFromProfile() async {
    if (name.text.isNotEmpty && phone.text.isNotEmpty) return;
    try {
      final profile = await context.read<HotelState>().currentProfile();
      if (!mounted || profile == null) return;
      final profileName = '${profile['name'] ?? ''}'.trim();
      final profilePhone = '${profile['phone_number'] ?? ''}'.trim();
      if (name.text.isEmpty && profileName.isNotEmpty) name.text = profileName;
      if (phone.text.isEmpty && profilePhone.isNotEmpty) {
        phone.text = profilePhone;
      }
    } catch (_) {
      // Profile is optional for prefill.
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
    // Any edit drops the previous result so a stale discount is never sent.
    if (mounted && _voucherResult.code != clean) {
      setState(() => _voucherResult = VoucherValidationResult.none);
    }
    if (clean.isEmpty) return;

    final state = context.read<HotelState>();
    final quote = state.selectedQuoteIsCurrent ? state.selectedQuote : null;
    if (quote == null) return;
    final voucherService = VoucherService(state.service.client);

    setState(() => _isValidatingVoucher = true);

    try {
      final res = await voucherService.validateVoucher(
        code: clean,
        subtotalCents: quote.subtotalCents,
        currency: quote.currency,
        userId: state.currentUser?.id,
      );
      // Ignore a late answer for a code the user has since changed.
      if (!mounted) return;
      if (voucher.text.trim().toUpperCase() != clean) {
        if (voucher.text.trim().isEmpty) {
          setState(() => _isValidatingVoucher = false);
        }
        return;
      }
      setState(() {
        _voucherResult = res;
        _isValidatingVoucher = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isValidatingVoucher = false);
    }
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
            textColor: _brand,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const RewardsVouchersScreen(initialTabIndex: 1),
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
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (v?.categoryColor ?? _brand).withValues(
                            alpha: 0.12,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          v?.categoryIcon ?? Icons.confirmation_number_rounded,
                          color: v?.categoryColor ?? _brand,
                        ),
                      ),
                      title: Text(
                        code,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        discount,
                        style: const TextStyle(color: _muted, fontSize: 12),
                      ),
                      trailing: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            voucher.text = code;
                          });
                          _checkVoucherCode(code);
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _brand,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                        ),
                        child: const Text(
                          'Áp dụng',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
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
    for (final c in _controllers) {
      c.removeListener(_syncDraft);
      c.dispose();
    }
    super.dispose();
  }

  /// Discount to apply, only when the validated result matches the current
  /// code and was computed for this quote's currency.
  int _appliedDiscount(RoomQuote quote) {
    final r = _voucherResult;
    final matches =
        r.isValid &&
        r.code == voucher.text.trim().toUpperCase() &&
        r.currency == quote.currency;
    return matches ? r.discountCents : 0;
  }

  void _continue(RoomQuote quote) {
    FocusScope.of(context).unfocus();
    if (!form.currentState!.validate()) {
      setState(() => autovalidate = AutovalidateMode.onUserInteraction);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => BookingReviewScreen(
          hotel: widget.hotel,
          guest: GuestDetails(
            name: name.text.trim(),
            email: email.text.trim(),
            phone: phone.text.trim(),
            specialRequests: specialRequests.text.trim(),
            voucherCode: voucher.text.trim(),
            discountCents: _appliedDiscount(quote),
            discountUsd: _appliedDiscount(quote) > 0
                ? _voucherResult.discountUsd
                : 0.0,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<HotelState>();
    final quote = state.selectedQuoteIsCurrent ? state.selectedQuote : null;
    if (quote == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Thông tin khách')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.event_busy, size: 56, color: _muted),
                const SizedBox(height: 12),
                const Text(
                  'Ngày, số khách hoặc số phòng đã thay đổi. Vui lòng chọn lại phòng để cập nhật giá.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: _brand),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Chọn lại phòng'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    InputDecoration deco(String label, IconData icon, {String? helper}) =>
        InputDecoration(
          labelText: label,
          helperText: helper,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Thông tin khách')),
      body: Form(
        key: form,
        autovalidateMode: autovalidate,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            BookingSummaryCard(hotel: widget.hotel, quote: quote, state: state),
            const SizedBox(height: 20),
            if (!state.isAuthenticated) ...[
              _SignInBanner(
                onSignIn: () async {
                  final ok = await state.requireAuth(
                    context,
                    reason:
                        'Đăng nhập để gửi yêu cầu đặt phòng dưới tài khoản TripC của bạn.',
                  );
                  if (ok && mounted && email.text.isEmpty) {
                    email.text = state.currentUser?.email ?? '';
                  }
                  if (ok) _prefillFromProfile();
                },
              ),
              const SizedBox(height: 16),
            ],
            const Text(
              'Thông tin liên hệ',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('guest-name'),
              controller: name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              decoration: deco('Họ và tên', Icons.person_outline),
              validator: GuestValidators.name,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('guest-email'),
              controller: email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              decoration: deco(
                'Email',
                Icons.email_outlined,
                helper: 'Khách sạn dùng email này để liên hệ xác nhận',
              ),
              validator: GuestValidators.email,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('guest-phone'),
              controller: phone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.telephoneNumber],
              decoration: deco('Số điện thoại', Icons.phone_outlined),
              validator: GuestValidators.phone,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: specialRequests,
              maxLines: 3,
              maxLength: 500,
              decoration: deco(
                'Yêu cầu đặc biệt (không bắt buộc)',
                Icons.notes,
              ),
              validator: GuestValidators.specialRequests,
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
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _brand,
                          ),
                        ),
                      ),
                    IconButton(
                      tooltip: 'Chọn từ ví voucher',
                      icon: const Icon(
                        Icons.confirmation_number_rounded,
                        color: _brand,
                      ),
                      onPressed: _pickVoucherFromWallet,
                    ),
                  ],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            if (_voucherResult.isValid) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF16A34A),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Đã áp dụng mã ${_voucherResult.code}: Giảm ${formatMoney(_voucherResult.discountCents, quote.currency)}',
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
            ] else if (_voucherResult.errorMessage != null &&
                voucher.text.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: Color(0xFFDC2626),
                      size: 18,
                    ),
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
            const SizedBox(height: 24),
            SizedBox(
              height: 54,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _brand),
                onPressed: () => _continue(quote),
                child: const Text('Tiếp tục xem lại'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignInBanner extends StatelessWidget {
  const _SignInBanner({required this.onSignIn});
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF7ED),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFFFD5C2)),
    ),
    child: Row(
      children: [
        const Icon(Icons.account_circle_outlined, color: _brand, size: 28),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Cần đăng nhập để gửi yêu cầu đặt phòng. Thông tin bạn nhập sẽ được giữ lại.',
            style: TextStyle(fontSize: 13, color: Color(0xFF9A3412)),
          ),
        ),
        TextButton(onPressed: onSignIn, child: const Text('Đăng nhập')),
      ],
    ),
  );
}

/// Hotel/room/stay summary shared by guest form and review screens.
class BookingSummaryCard extends StatelessWidget {
  const BookingSummaryCard({
    super.key,
    required this.hotel,
    required this.quote,
    required this.state,
  });
  final Map<String, dynamic> hotel;
  final RoomQuote quote;
  final HotelState state;

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: _border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Image.network(
          hotelImageUrl(hotel['images']),
          height: 140,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, error, stack) =>
              Container(height: 140, color: const Color(0xFFFFE1D5)),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${hotel['name'] ?? ''}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                hotelAddressText(hotel['address']),
                style: const TextStyle(color: _muted, fontSize: 13),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.bed_outlined, size: 18, color: _brand),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${quote.roomTitle} × ${quote.roomCount}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${formatDay(quote.start)} → ${formatDay(quote.end)} · ${quote.nightCount} đêm',
              ),
              Text(
                '${state.guests} người lớn · ${state.children} trẻ em',
                style: const TextStyle(color: _muted),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
