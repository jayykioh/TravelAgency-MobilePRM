import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'room_quote.dart';

/// Guest contact values entered on the checkout form.
class GuestDetails {
  const GuestDetails({
    required this.name,
    required this.email,
    required this.phone,
    this.specialRequests = '',
    this.voucherCode = '',
    this.discountCents = 0,
    this.discountUsd = 0.0,
  });

  final String name;
  final String email;
  final String phone;
  final String specialRequests;
  final String voucherCode;
  final int discountCents;
  final double discountUsd;
}

/// Client-side validation for the guest form. The backend stays the
/// authority; these rules only stop obviously invalid submissions.
class GuestValidators {
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _phone = RegExp(r'^\+?[0-9][0-9\s.-]{7,17}$');

  static String? name(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Vui lòng nhập họ tên';
    if (text.length < 2) return 'Họ tên quá ngắn';
    if (text.length > 100) return 'Họ tên tối đa 100 ký tự';
    return null;
  }

  static String? email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Vui lòng nhập email';
    if (!_email.hasMatch(text)) return 'Email không hợp lệ';
    return null;
  }

  static String? phone(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Vui lòng nhập số điện thoại';
    final digits = text.replaceAll(RegExp(r'\D'), '');
    if (!_phone.hasMatch(text) || digits.length < 8 || digits.length > 15) {
      return 'Số điện thoại không hợp lệ';
    }
    return null;
  }

  static String? specialRequests(String? value) =>
      (value?.trim().length ?? 0) > 500 ? 'Tối đa 500 ký tự' : null;
}

/// 8-character code using the same alphabet as the web
/// `generateConfirmationCode` (`Project/lib/hotel/utils.ts`).
String generateConfirmationCode([Random? random]) {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final rng = random ?? Random.secure();
  return List.generate(8, (_) => chars[rng.nextInt(chars.length)]).join();
}

/// Builds the `hotel_bookings` insert for a pending, unpaid booking request.
/// [userId] must be the authenticated session's user id; ownership is never
/// derived from a synthetic guest identifier.
Map<String, dynamic> buildBookingPayload({
  required String userId,
  required Map<String, dynamic> hotel,
  required RoomQuote quote,
  required GuestDetails guest,
  required int adults,
  required int children,
  required String confirmationCode,
}) {
  if (userId.isEmpty) {
    throw ArgumentError('An authenticated user id is required');
  }
  final price = quote.breakdown;
  final requests = guest.specialRequests.trim();
  final voucher = guest.voucherCode.trim().toUpperCase();
  final discountCents = guest.discountCents;
  final discountedSubtotal = max(0, price.subtotalCents - discountCents);
  final taxCents = discountCents > 0 ? (discountedSubtotal * 0.10).round() : price.taxCents;
  final feesCents = discountCents > 0 ? (discountedSubtotal * 0.05).round() : price.feeCents;
  final totalCents = discountCents > 0 ? (discountedSubtotal + taxCents + feesCents) : price.totalCents;
  return {
    'user_uuid': userId,
    'external_user_ref': userId,
    'hotel_id': hotel['id'],
    'room_id': quote.room['id'],
    'partner_id': (quote.source.isReference || quote.partnerId == null || quote.partnerId!.trim().isEmpty)
        ? null
        : quote.partnerId!.trim(),
    'confirmation_code': confirmationCode,
    'check_in_date': isoDay(quote.start),
    'check_out_date': isoDay(quote.end),
    'guest_name': guest.name.trim(),
    'guest_email': guest.email.trim(),
    'guest_phone': guest.phone.trim(),
    'guest_count': {
      'adults': adults,
      'children': children,
      'rooms': quote.roomCount,
    },
    'special_requests': requests.isEmpty ? null : requests,
    'total_cents': totalCents,
    'nightly_rate_cents': quote.averageNightlyCents,
    'tax_cents': taxCents,
    'fees_cents': feesCents,
    'currency': quote.currency,
    'status': 'pending',
    'payment_status': 'pending',
    'booking_source': 'mobile',
    'metadata': {
      'nightly': [for (final night in quote.nights) night.toJson()],
      'room_count': quote.roomCount,
      'subtotal_cents': price.subtotalCents,
      'rate_source': quote.source.key,
      if (voucher.isNotEmpty) 'voucher_code': voucher,
      if (discountCents > 0) ...{
        'voucher_applied': true,
        'discount_cents': discountCents,
        'discount_usd': guest.discountUsd,
      } else if (voucher.isNotEmpty) ...{
        'voucher_applied': false,
      },
    },
  };
}

/// Result returned to the UI after a create request.
class BookingCreationException implements Exception {
  const BookingCreationException(this.message, {this.maybeCreated = false});
  final String message;

  /// True when an earlier attempt may already have been stored (for example a
  /// duplicate confirmation code after a lost response).
  final bool maybeCreated;
  @override
  String toString() => message;
}

/// Maps a create-booking failure to an actionable Vietnamese message without
/// leaking raw backend payloads.
BookingCreationException describeBookingError(Object error) {
  if (error is BookingCreationException) return error;
  if (error is AuthException) {
    return const BookingCreationException(
      'Phiên đăng nhập không hợp lệ hoặc đã hết hạn. Vui lòng đăng nhập lại.',
    );
  }
  if (error is PostgrestException) {
    switch (error.code) {
      case '42501':
        return const BookingCreationException(
          'Backend hiện tại không cho phép phiên này tạo đơn (RLS). Đơn chưa được tạo.',
        );
      case '23503':
        return const BookingCreationException(
          'Tài khoản, khách sạn hoặc phòng chưa liên kết hợp lệ trên backend. Đơn chưa được tạo.',
        );
      case '23505':
        return const BookingCreationException(
          'Yêu cầu này có thể đã được ghi nhận trước đó. Kiểm tra “Đơn của tôi” trước khi gửi lại.',
          maybeCreated: true,
        );
      case '23502':
      case '23514':
      case '22P02':
        return const BookingCreationException(
          'Backend từ chối dữ liệu đặt phòng (thiếu hoặc sai trường bắt buộc). Đơn chưa được tạo.',
        );
      case 'PGRST301':
      case 'PGRST303':
        return const BookingCreationException(
          'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
        );
    }
    return const BookingCreationException(
      'Backend không tạo được đơn. Vui lòng thử lại sau.',
    );
  }
  final text = '$error';
  if (text.contains('SocketException') ||
      text.contains('ClientException') ||
      text.contains('Failed host lookup') ||
      text.contains('Connection') ||
      text.contains('TimeoutException')) {
    return const BookingCreationException(
      'Mất kết nối khi gửi yêu cầu. Kiểm tra “Đơn của tôi” trước khi thử lại để tránh tạo trùng.',
      maybeCreated: true,
    );
  }
  return const BookingCreationException(
    'Không thể gửi yêu cầu đặt phòng. Vui lòng thử lại.',
  );
}
