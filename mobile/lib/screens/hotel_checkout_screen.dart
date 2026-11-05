import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/booking_request.dart';
import '../models/room_quote.dart';
import '../providers/hotel_state.dart';
import '../utils/hotel_format.dart';
import '../widgets/hotel_image.dart';
import 'booking_review_screen.dart';

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
            TextFormField(
              controller: voucher,
              textCapitalization: TextCapitalization.characters,
              decoration: deco(
                'Mã ưu đãi (không bắt buộc)',
                Icons.local_offer_outlined,
                helper:
                    'Mã được gửi kèm yêu cầu; app chưa trừ giảm giá vào tổng.',
              ),
            ),
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
