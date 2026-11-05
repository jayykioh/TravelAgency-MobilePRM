import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/voucher.dart';
import 'package:mobile/providers/hotel_state.dart';
import 'package:mobile/screens/rewards_vouchers_screen.dart';
import 'package:mobile/screens/hotel_checkout_screen.dart';
import 'package:mobile/services/hotel_service.dart';
import 'package:mobile/services/voucher_service.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeClient extends Fake implements SupabaseClient {}

void main() {
  group('Voucher & Reward Models', () {
    test('VoucherModel parsing and properties', () {
      final json = {
        'id': 'v_test',
        'code': 'HOTEL20',
        'voucher_type': 'Hotel Credit',
        'discount_value': 20.0,
        'min_spend': 100.0,
        'tcent_price': 2000,
        'total_usage_limit': 500,
        'current_usage_count': 50,
        'is_active': true,
        'is_purchasable': true,
      };

      final voucher = VoucherModel.fromJson(json);

      expect(voucher.id, 'v_test');
      expect(voucher.code, 'HOTEL20');
      expect(voucher.discountValue, 20.0);
      expect(voucher.tcentPrice, 2000);
      expect(voucher.stockRemaining, 450);
      expect(voucher.formattedDiscount, 'Giảm \$20');
      expect(voucher.categoryColor, const Color(0xFF2563EB));
      expect(voucher.categoryIcon, Icons.hotel_rounded);
    });

    test('UserVoucherModel parsing', () {
      final json = {
        'id': 'uv_1',
        'user_id': 'u_123',
        'voucher_id': 'v_test',
        'status': 'AVAILABLE',
        'acquired_at': '2026-11-04T12:00:00Z',
        'voucher': {
          'id': 'v_test',
          'code': 'SPA50',
          'voucher_type': 'Wellness',
          'discount_value': 50.0,
          'min_spend': 100.0,
          'tcent_price': 5000,
        },
      };

      final userVoucher = UserVoucherModel.fromJson(json);

      expect(userVoucher.id, 'uv_1');
      expect(userVoucher.status, 'AVAILABLE');
      expect(userVoucher.isAvailable, isTrue);
      expect(userVoucher.voucher?.code, 'SPA50');
      expect(userVoucher.voucher?.categoryColor, const Color(0xFF059669));
    });

    test('TcentRewardStatus tier multipliers', () {
      const platinum = TcentRewardStatus(
        tcentBalance: 63596489,
        membershipTier: 'PLATINUM',
        tcentPending: 0,
        canSpin: true,
      );
      expect(platinum.tierMultiplier, 2.0);
      expect(platinum.tierBadgeText, 'PLATINUM Member • 2x');

      const gold = TcentRewardStatus(
        tcentBalance: 5000,
        membershipTier: 'GOLD',
        tcentPending: 100,
        canSpin: false,
      );
      expect(gold.tierMultiplier, 1.5);
      expect(gold.tierBadgeText, 'GOLD Member • 1.5x');
    });
  });

  group('VoucherService Logic', () {
    late VoucherService service;

    setUp(() {
      service = VoucherService(_FakeClient());
    });

    test('getTcentStatus returns demo status for guest', () async {
      final status = await service.getTcentStatus(null);
      expect(status.tcentBalance, greaterThanOrEqualTo(10000));
      expect(status.membershipTier, 'PLATINUM');
      expect(status.canSpin, isTrue);
    });

    test('fetchMarketplaceVouchers returns valid vouchers list', () async {
      final vouchers = await service.fetchMarketplaceVouchers();
      expect(vouchers, isNotEmpty);
      expect(vouchers.any((v) => v.code == 'HOTEL20'), isTrue);
    });

    test('executeDailySpin awards rewards and marks as spun today', () async {
      final userId = 'test_user_${DateTime.now().microsecondsSinceEpoch}';
      final spinResult = await service.executeDailySpin(userId: userId);

      expect(spinResult.segmentIndex, inInclusiveRange(0, 6));
      expect(spinResult.rewardType, isIn(['TCENT', 'VOUCHER']));
      expect(spinResult.message, isNotEmpty);

      // Second spin today should throw StateError
      expect(
        () => service.executeDailySpin(userId: userId),
        throwsA(isA<StateError>()),
      );
    });

    test('redeemVoucher deducts balance and adds to user wallet', () async {
      final userId = 'redeem_user_${DateTime.now().microsecondsSinceEpoch}';
      final statusBefore = await service.getTcentStatus(userId);
      final initialBalance = statusBefore.tcentBalance;

      final voucherToBuy = VoucherService.defaultVouchers.first; // HOTEL20, 2000 TC
      final newBalance = await service.redeemVoucher(
        userId: userId,
        voucher: voucherToBuy,
      );

      expect(newBalance, initialBalance - voucherToBuy.tcentPrice);

      final wallet = await service.fetchUserVouchers(userId);
      expect(wallet.any((v) => v.voucher?.code == voucherToBuy.code), isTrue);

      // Re-redeeming should fail because it's already in wallet
      expect(
        () => service.redeemVoucher(userId: userId, voucher: voucherToBuy),
        throwsA(isA<StateError>()),
      );
    });

    test('validateVoucher calculates correct discount for SHOP10 and HOTEL20', () async {
      // SHOP10 on $90 booking
      final resShop10 = await service.validateVoucher(
        code: 'SHOP10',
        cartTotalUsd: 90.0,
      );
      expect(resShop10.isValid, isTrue);
      expect(resShop10.discountUsd, 10.0);
      expect(resShop10.discountCents, 1000);

      // HOTEL20 on $90 booking
      final resHotel20 = await service.validateVoucher(
        code: 'HOTEL20',
        cartTotalUsd: 90.0,
      );
      expect(resHotel20.isValid, isTrue);
      expect(resHotel20.discountUsd, 20.0);
      expect(resHotel20.discountCents, 2000);

      // SPA_RETREAT has min spend $100 -> fails on $40 booking
      final resMinSpendFail = await service.validateVoucher(
        code: 'SPA_RETREAT',
        cartTotalUsd: 40.0,
      );
      expect(resMinSpendFail.isValid, isFalse);
      expect(resMinSpendFail.errorMessage, contains('tối thiểu'));
    });
  });

  group('RewardsVouchersScreen Widget', () {
    testWidgets('renders Tcent balance, Lucky Day banner, and Quests', (tester) async {
      final hotelService = HotelService(_FakeClient());
      final hotelState = HotelState(service: hotelService);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<HotelState>.value(value: hotelState),
          ],
          child: const MaterialApp(
            home: RewardsVouchersScreen(),
          ),
        ),
      );

      // Pump through async loads
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Tcent Rewards'), findsWidgets);
      expect(find.text('Vouchers & Ví'), findsOneWidget);
      expect(find.text('Lucky Day'), findsOneWidget);
      expect(find.text('Active Quests'), findsOneWidget);
      expect(find.text('Daily Streak'), findsOneWidget);
      expect(find.text('Spin'), findsOneWidget);
    });
  });

  group('BookingScreen Voucher Application Widget', () {
    testWidgets('applying SHOP10 voucher updates price breakdown and grand total', (tester) async {
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
            home: BookingScreen(
              hotel: {
                'name': 'Test Hotel',
                'images': ['https://example.com/hotel.jpg'],
              },
              room: {
                'title': 'Standard Room',
                '_priceCents': 9000, // $90.0
                '_currency': 'USD',
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Before voucher: $90 room, 10% tax = $9, 5% fee = $4.5 -> Total $103.5 USD
      expect(find.text('103.5 USD'), findsOneWidget);

      // Enter SHOP10
      final voucherInput = find.widgetWithText(TextFormField, 'Mã giảm giá (Voucher)');
      expect(voucherInput, findsOneWidget);
      await tester.enterText(voucherInput, 'SHOP10');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      // After voucher: $90 - $10 = $80 discounted subtotal
      // Tax 10% = $8, Fee 5% = $4 -> Total $92.0 USD
      expect(find.text('Voucher discount (SHOP10)'), findsOneWidget);
      expect(find.text('-10.0 USD'), findsOneWidget);
      expect(find.text('92.0 USD'), findsOneWidget);
      expect(find.text('Đã áp dụng mã SHOP10: Giảm \$10.0'), findsOneWidget);
    });
  });
}

