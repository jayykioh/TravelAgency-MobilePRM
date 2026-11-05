import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/models/payment_intent.dart';
import 'package:mobile/providers/hotel_state.dart';
import 'package:mobile/services/hotel_service.dart';
import 'package:mobile/services/payment_service.dart';
import 'package:mobile/widgets/payment_bottom_sheet.dart';
import 'package:mobile/widgets/payment_method_selector.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeClient extends Fake implements SupabaseClient {}

void main() {
  group('Payment Models & Currency Conversion', () {
    test('PaymentProviderType enum properties', () {
      expect(PaymentProviderType.momo.id, 'momo');
      expect(PaymentProviderType.momo.title, contains('MoMo'));
      expect(PaymentProviderType.paypal.id, 'paypal');
      expect(PaymentProviderType.paypal.title, 'PayPal');
    });

    test('PaymentIntentResult JSON parsing', () {
      final json = {
        'ok': true,
        'data': {
          'paymentUrl': 'https://test-payment.momo.vn/v2/gateway/pay?orderId=123',
          'providerTxnId': 'MOMO_123',
        },
      };

      final result = PaymentIntentResult.fromJson(json, 'momo');
      expect(result.paymentUrl, contains('test-payment.momo.vn'));
      expect(result.providerTxnId, 'MOMO_123');
      expect(result.provider, 'momo');
      expect(result.isMock, isFalse);
    });

    test('PaymentVerificationResult JSON parsing', () {
      final successJson = {
        'ok': true,
        'status': 'success',
        'bookingId': 'book_999',
      };
      final success = PaymentVerificationResult.fromJson(successJson);
      expect(success.isSuccess, isTrue);
      expect(success.bookingId, 'book_999');

      final failedJson = {
        'ok': false,
        'error': 'Giao dịch bị từ chối bởi người dùng',
      };
      final failed = PaymentVerificationResult.fromJson(failedJson);
      expect(failed.isSuccess, isFalse);
      expect(failed.message, contains('từ chối'));
    });

    test('USD and VND conversion utilities', () {
      expect(PaymentService.convertUsdToVnd(10.0), 254000);
      expect(PaymentService.convertUsdToVnd(92.0), 2336800);
      expect(PaymentService.convertVndToUsd(254000.0), 10.0);
    });
  });

  group('PaymentService API Calls', () {
    test('createPaymentIntent calls /api/payments/create and returns gateway URL', () async {
      final mockHttp = MockClient((request) async {
        expect(request.url.path, '/api/payments/create');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['bookingId'], 'bk_test_1');
        expect(body['provider'], 'momo');

        return http.Response(
          jsonEncode({
            'ok': true,
            'data': {
              'paymentUrl': 'https://test-payment.momo.vn/pay?order=1',
              'providerTxnId': 'MOMO_ORDER_1',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = PaymentService(
        _FakeClient(),
        httpClient: mockHttp,
        baseUrl: 'http://localhost:3000',
      );

      final result = await service.createPaymentIntent(
        bookingId: 'bk_test_1',
        provider: PaymentProviderType.momo,
        fallbackAmountUsd: 50.0,
      );

      expect(result.paymentUrl, 'https://test-payment.momo.vn/pay?order=1');
      expect(result.providerTxnId, 'MOMO_ORDER_1');
      expect(result.isMock, isFalse);
    });

    test('verifyMomoPayment handles verify-redirect endpoint', () async {
      final mockHttp = MockClient((request) async {
        expect(request.url.path, '/api/payments/momo/verify-redirect');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['orderId'], 'momo_ord_1');
        expect(body['resultCode'], '0');

        return http.Response(
          jsonEncode({
            'ok': true,
            'status': 'success',
            'bookingId': 'bk_123',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = PaymentService(
        _FakeClient(),
        httpClient: mockHttp,
        baseUrl: 'http://localhost:3000',
      );

      final result = await service.verifyMomoPayment(
        orderId: 'momo_ord_1',
        resultCode: '0',
      );

      expect(result.isSuccess, isTrue);
      expect(result.status, 'success');
      expect(result.bookingId, 'bk_123');
    });

    test('syncPaypalPayment handles /api/payments/sync endpoint', () async {
      final mockHttp = MockClient((request) async {
        expect(request.url.path, '/api/payments/sync');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['provider'], 'paypal');
        expect(body['token'], 'ORDER_PP_1');
        expect(body['payerId'], 'PAYER_123');

        return http.Response(
          jsonEncode({
            'ok': true,
            'status': 'success',
            'bookingId': 'bk_456',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = PaymentService(
        _FakeClient(),
        httpClient: mockHttp,
        baseUrl: 'http://localhost:3000',
      );

      final result = await service.syncPaypalPayment(
        token: 'ORDER_PP_1',
        payerId: 'PAYER_123',
      );

      expect(result.isSuccess, isTrue);
      expect(result.status, 'success');
      expect(result.bookingId, 'bk_456');
    });
  });

  group('Payment Widgets', () {
    testWidgets('PaymentMethodSelector displays MoMo and PayPal tiles and toggles selection', (tester) async {
      PaymentProviderType selected = PaymentProviderType.momo;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => PaymentMethodSelector(
                selected: selected,
                amountUsd: 92.0,
                onChanged: (p) => setState(() => selected = p),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Phương thức thanh toán'), findsOneWidget);
      expect(find.text('Ví điện tử MoMo'), findsOneWidget);
      expect(find.text('PayPal'), findsOneWidget);
      expect(find.textContaining('2.336.800 đ'), findsOneWidget);
      expect(find.textContaining('\$92.00 USD'), findsOneWidget);

      // Tap PayPal
      await tester.tap(find.text('PayPal'));
      await tester.pumpAndSettle();

      expect(selected, PaymentProviderType.paypal);
    });

    testWidgets('PaymentBottomSheet renders summary, selector, and action buttons', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final hotelService = HotelService(_FakeClient());
      final hotelState = HotelState(service: hotelService);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<HotelState>.value(value: hotelState),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: PaymentBottomSheet(
                bookingId: 'test_book_1',
                confirmationCode: 'HTL-ABC123',
                totalAmountUsd: 92.0,
                hotelName: 'Vinpearl Luxury Nha Trang',
                roomTitle: 'Deluxe Ocean View',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Thanh toán đơn phòng'), findsOneWidget);
      expect(find.text('Mã đơn: HTL-ABC123'), findsOneWidget);
      expect(find.text('Vinpearl Luxury Nha Trang'), findsOneWidget);
      expect(find.text('\$92.0 USD'), findsOneWidget);
      expect(find.text('Ví điện tử MoMo'), findsOneWidget);
      expect(find.text('PayPal'), findsOneWidget);
      expect(find.textContaining('Thanh toán qua Ví MoMo'), findsOneWidget);
    });
  });
}

