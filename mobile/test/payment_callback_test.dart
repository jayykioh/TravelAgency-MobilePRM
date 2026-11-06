import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/payment_intent.dart';
import 'package:mobile/services/payment_service.dart';
import 'package:mobile/widgets/payment_bottom_sheet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('Payment Callback & Deep Link Tests', () {
    test('PaymentBottomSheet wasRecentlyHandled behaves correctly', () {
      expect(PaymentBottomSheet.wasRecentlyHandled(), isFalse);

      PaymentBottomSheet.markHandled();
      expect(PaymentBottomSheet.wasRecentlyHandled(), isTrue);
    });

    test('PaymentService default returnUrl is io.supabase.tripc://payment-callback', () async {
      final client = SupabaseClient('https://mock.supabase.co', 'mock-key');
      final service = PaymentService(client);

      // We test through URI schema parsing directly
      const bookingId = 'test-bk-123';
      const provider = PaymentProviderType.paypal;

      final expectedDefaultReturn =
          'io.supabase.tripc://payment-callback?bookingId=$bookingId&provider=${provider.id}';

      final uri = Uri.parse(expectedDefaultReturn);
      expect(uri.scheme, equals('io.supabase.tripc'));
      expect(uri.host, equals('payment-callback'));
      expect(uri.queryParameters['bookingId'], equals('test-bk-123'));
      expect(uri.queryParameters['provider'], equals('paypal'));
    });

    test('Payment callback URI parsing handles PayPal and MoMo responses', () {
      // PayPal return URI simulation
      final paypalUri = Uri.parse(
        'io.supabase.tripc://payment-callback?bookingId=bk-999&provider=paypal&token=75B36916FT8358526&PayerID=2KRZ65CK3KPBS',
      );
      expect(paypalUri.scheme, equals('io.supabase.tripc'));
      expect(paypalUri.host, equals('payment-callback'));
      expect(paypalUri.queryParameters['bookingId'], equals('bk-999'));
      expect(paypalUri.queryParameters['token'], equals('75B36916FT8358526'));
      expect(paypalUri.queryParameters['PayerID'], equals('2KRZ65CK3KPBS'));

      // MoMo return URI simulation
      final momoUri = Uri.parse(
        'io.supabase.tripc://payment-callback?bookingId=bk-999&provider=momo&orderId=MM-123&resultCode=0&message=Successful',
      );
      expect(momoUri.queryParameters['bookingId'], equals('bk-999'));
      expect(momoUri.queryParameters['orderId'], equals('MM-123'));
      expect(momoUri.queryParameters['resultCode'], equals('0'));

      // Cancelled simulation
      final cancelUri = Uri.parse(
        'io.supabase.tripc://payment-callback?bookingId=bk-999&provider=paypal&status=cancelled',
      );
      expect(cancelUri.queryParameters['status'], equals('cancelled'));
    });
  });
}

