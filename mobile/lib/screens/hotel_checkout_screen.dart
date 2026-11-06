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
import 'hotel_bookings_screen.dart';
import 'rewards_vouchers_screen.dart';
import '../widgets/payment_bottom_sheet.dart';

const _brand = Color(0xFFFF5E1F);
const _muted = Color(0xFF64748B);
const _border = Color(0xFFE2E8F0);

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
    if (clean.isEmpty) {
      if (mounted && _voucherResult.isValid) {
        setState(() {
          _voucherResult = VoucherValidationResult.none;
        });
      }
      return;
    }

    final state = context.read<HotelState>();
    final quote = state.selectedQuote;
    final subtotalUsd = quote != null
        ? (quote.breakdown.subtotalCents / 100.0)
        : 100.0;
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
                          color: (v?.categoryColor ?? _brand).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(v?.categoryIcon ?? Icons.confirmation_number_rounded, color: v?.categoryColor ?? _brand),
                      ),
                      title: Text(code, style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(discount, style: const TextStyle(color: _muted, fontSize: 12)),
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
            discountCents: _voucherResult.isValid ? _voucherResult.discountCents : 0,
            discountUsd: _voucherResult.isValid ? _voucherResult.discountUsd : 0.0,
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
                          child: CircularProgressIndicator(strokeWidth: 2, color: _brand),
                        ),
                      ),
                    IconButton(
                      tooltip: 'Chọn từ ví voucher',
                      icon: const Icon(Icons.confirmation_number_rounded, color: _brand),
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

/// Backward compatibility alias for single-page BookingScreen
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
            textColor: _brand,
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
                          color: (v?.categoryColor ?? _brand).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(v?.categoryIcon ?? Icons.confirmation_number_rounded, color: v?.categoryColor ?? _brand),
                      ),
                      title: Text(code, style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(discount, style: const TextStyle(color: _muted, fontSize: 12)),
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
                    errorBuilder: (_, _, _) => Container(
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
              _SignInBanner(
                onSignIn: () async {
                  final loggedIn = await state.requireAuth(
                    context,
                    reason:
                        'Đăng nhập để liên kết đơn đặt phòng với tài khoản TripC của bạn.',
                  );
                  if (loggedIn && mounted && email.text.isEmpty) {
                    email.text = state.currentUser?.email ?? '';
                  }
                },
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
                          child: CircularProgressIndicator(strokeWidth: 2, color: _brand),
                        ),
                      ),
                    IconButton(
                      tooltip: 'Chọn từ ví voucher',
                      icon: const Icon(Icons.confirmation_number_rounded, color: _brand),
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
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _brand,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              onPressed: busy ? null : review,
              child: busy
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Confirm booking',
                      style: TextStyle(fontWeight: FontWeight.w800),
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
        'user_uuid': state.authenticatedUserId.isNotEmpty ? state.authenticatedUserId : null,
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
        'discount_cents': _voucherResult.isValid ? _voucherResult.discountCents : 0,
        'working_pass_discount_cents': 0,
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
      final shouldPayNow = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Đã ghi nhận yêu cầu'),
          content: Text(
            'Mã xác nhận: ${booking['confirmation_code']}\nChờ xác nhận · Chưa thanh toán',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Để sau'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFA50064),
              ),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Thanh toán ngay'),
            ),
          ],
        ),
      );

      if (shouldPayNow == true && mounted) {
        final totalUsd = (grandTotal / 100).toDouble();
        await PaymentBottomSheet.show(
          context,
          bookingId: '${booking['id']}',
          confirmationCode:
              '${booking['confirmation_code'] ?? confirmationCode}',
          totalAmountUsd: totalUsd,
          hotelName: widget.hotel['name']?.toString() ?? 'Khách sạn',
          roomTitle: widget.room['name']?.toString() ?? 'Phòng',
          currency: currency,
        );
      }

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
