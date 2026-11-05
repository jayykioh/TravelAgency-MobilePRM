/// Supported payment gateways matching web unified payment system.
enum PaymentProviderType {
  momo('momo', 'Ví MoMo', 'Thanh toán tức thì qua MoMo (VND)'),
  paypal('paypal', 'PayPal', 'Thanh toán quốc tế Visa/Master (USD)');

  const PaymentProviderType(this.id, this.title, this.subtitle);
  final String id;
  final String title;
  final String subtitle;
}

/// Result returned from POST /api/payments/create.
class PaymentIntentResult {
  const PaymentIntentResult({
    required this.paymentUrl,
    required this.providerTxnId,
    required this.provider,
    this.isMock = false,
    this.metadata,
  });

  final String paymentUrl;
  final String providerTxnId;
  final String provider;
  final bool isMock;
  final Map<String, dynamic>? metadata;

  factory PaymentIntentResult.fromJson(Map<String, dynamic> json, String provider) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    return PaymentIntentResult(
      paymentUrl: '${data['paymentUrl'] ?? data['mockSuccessUrl'] ?? ''}',
      providerTxnId: '${data['providerTxnId'] ?? ''}',
      provider: provider,
      isMock: data['mockSuccessUrl'] != null && data['paymentUrl'] == null,
    );
  }
}

/// Result returned from payment verification/sync.
class PaymentVerificationResult {
  const PaymentVerificationResult({
    required this.isSuccess,
    this.bookingId,
    this.status,
    this.message,
  });

  final bool isSuccess;
  final String? bookingId;
  final String? status;
  final String? message;

  factory PaymentVerificationResult.fromJson(Map<String, dynamic> json) {
    final ok = json['ok'] == true || json['status'] == 'success' || json['status'] == 'already_processed';
    return PaymentVerificationResult(
      isSuccess: ok,
      bookingId: json['bookingId'] as String?,
      status: json['status'] as String?,
      message: json['message'] as String? ?? (ok ? 'Thanh toán thành công' : json['error'] as String?),
    );
  }
}

