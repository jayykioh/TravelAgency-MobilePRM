import 'booking_request.dart';

/// Gateways the web backend already supports (`PaymentService`).
enum PaymentProvider {
  momo('momo', 'MoMo'),
  paypal('paypal', 'PayPal');

  const PaymentProvider(this.key, this.label);
  final String key;
  final String label;
}

/// Fixed VND amount shown before checkout while the server charges a test
/// amount (`--dart-define=PAYMENT_TEST_AMOUNT_VND=10000`). The server's
/// `PAYMENT_TEST_AMOUNT_VND` stays the source of truth for what is charged.
const paymentTestAmountVnd = int.fromEnvironment('PAYMENT_TEST_AMOUNT_VND');

/// Hotel booking + gateway session returned by `/api/mobile/hotel-payments`.
class OnlinePayment {
  const OnlinePayment({
    required this.booking,
    required this.provider,
    required this.paymentUrl,
    required this.amount,
    required this.currency,
    required this.testMode,
  });

  /// Same shape the result screen reads (`id`, `confirmation_code`,
  /// `status`, `payment_status`, `total_cents`, `currency`).
  final Map<String, dynamic> booking;
  final PaymentProvider? provider;

  /// Only present right after creation; status checks do not return it.
  final String? paymentUrl;

  /// Amount charged, in [currency] major units (VND).
  final num amount;
  final String currency;
  final bool testMode;

  String get bookingId => '${booking['id']}';
  bool get isPaid => booking['payment_status'] == 'paid';

  OnlinePayment withUpdate(OnlinePayment next) => OnlinePayment(
    booking: next.booking,
    provider: next.provider ?? provider,
    paymentUrl: next.paymentUrl ?? paymentUrl,
    amount: next.amount,
    currency: next.currency,
    testMode: next.testMode,
  );

  factory OnlinePayment.fromJson(
    Map<String, dynamic> json, {
    bool requireUrl = false,
  }) {
    final payment = json['payment'];
    if (json['id'] == null || '${json['id']}'.isEmpty || payment is! Map) {
      throw const BookingCreationException(
        'Backend không trả về đơn hoặc thông tin thanh toán.',
      );
    }
    final url = payment['payment_url'] as String?;
    final paid = json['payment_status'] == 'paid';
    if (url != null && !url.startsWith('https://')) {
      throw const BookingCreationException('Link thanh toán không hợp lệ.');
    }
    if (requireUrl && url == null && !paid) {
      throw const BookingCreationException(
        'Backend không trả về link thanh toán.',
      );
    }
    final providerKey = payment['provider'];
    return OnlinePayment(
      booking: Map<String, dynamic>.from(json)..remove('payment'),
      provider: PaymentProvider.values
          .where((p) => p.key == providerKey)
          .firstOrNull,
      paymentUrl: url,
      amount: (payment['amount'] as num?) ?? 0,
      currency: '${payment['currency'] ?? 'VND'}',
      testMode: payment['test_mode'] == true,
    );
  }
}

/// Maps a payment API failure to a Vietnamese message.
BookingCreationException describePaymentHttpError(int status, String? error) {
  switch (status) {
    case 401:
      return const BookingCreationException(
        'Phiên đăng nhập không hợp lệ hoặc đã hết hạn. Vui lòng đăng nhập lại.',
      );
    case 404:
      return const BookingCreationException('Không tìm thấy đơn đặt phòng.');
    case 409:
      return const BookingCreationException(
        'Đơn này đã bị hủy hoặc mã xác nhận đã được dùng. Kiểm tra “Đơn của tôi”.',
        maybeCreated: true,
      );
    case 422:
      return const BookingCreationException(
        'Khách sạn hoặc phòng không còn tồn tại. Vui lòng chọn lại phòng.',
      );
    case 501:
      return const BookingCreationException(
        'Máy chủ chưa bật thanh toán cho app (thiếu PAYMENT_TEST_AMOUNT_VND).',
      );
    case 502:
      return BookingCreationException(
        'Cổng thanh toán từ chối giao dịch${error == null ? '' : ': $error'}.',
      );
  }
  return const BookingCreationException(
    'Không tạo được thanh toán. Vui lòng thử lại.',
  );
}
