import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/voucher.dart';
import 'package:mobile/providers/hotel_state.dart';
import 'package:mobile/screens/rewards_vouchers_screen.dart';
import 'package:mobile/services/hotel_service.dart';
import 'package:mobile/services/voucher_service.dart';
import 'package:mobile/utils/currency.dart';
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

      final voucherToBuy =
          VoucherService.defaultVouchers.first; // HOTEL20, 2000 TC
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

    test('validateVoucher rejects made-up and hard-coded codes', () async {
      // The fake client throws on every query, so nothing can be looked up.
      for (final code in ['ABC999999', 'SHOP10', 'HOTEL10', 'TRIPC10', 'X5']) {
        final res = await service.validateVoucher(
          code: code,
          subtotalCents: 9000,
          currency: 'USD',
        );
        expect(res.isValid, isFalse, reason: code);
        expect(res.discountCents, 0, reason: code);
      }
    });

    test(
      'validateVoucher accepts a voucher redeemed into the wallet',
      () async {
        final userId = 'wallet_user_${DateTime.now().microsecondsSinceEpoch}';
        final hotel20 = VoucherService.defaultVouchers.firstWhere(
          (v) => v.code == 'HOTEL20',
        );
        await service.redeemVoucher(userId: userId, voucher: hotel20);

        final res = await service.validateVoucher(
          code: 'hotel20',
          subtotalCents: 9000,
          currency: 'USD',
          userId: userId,
        );
        expect(res.isValid, isTrue);
        expect(res.discountCents, 2000);
      },
    );
  });

  group('evaluateVoucher', () {
    const hotel20 = VoucherModel(
      id: 'v1',
      code: 'HOTEL20',
      voucherType: 'Hotel Credit',
      discountValue: 20,
      minSpend: 50,
      tcentPrice: 2000,
    );

    test('USD booking: fixed \$20 off', () {
      final res = evaluateVoucher(
        hotel20,
        subtotalCents: 9000,
        currency: 'USD',
      );
      expect(res.isValid, isTrue);
      expect(res.discountCents, 2000);
      expect(res.discountUsd, 20);
    });

    test('VND booking: \$20 is converted at the web rate', () {
      // 3,000,000 VND room total (~\$117.88).
      final res = evaluateVoucher(
        hotel20,
        subtotalCents: 300000000,
        currency: 'VND',
      );
      expect(res.isValid, isTrue);
      expect(
        res.discountCents,
        (20 * usdToVndRate * 100).round(),
      ); // 509,000 VND
    });

    test('VND min spend is compared in USD', () {
      // 1,000,000 VND (~\$39.29) is below the \$50 minimum.
      final res = evaluateVoucher(
        hotel20,
        subtotalCents: 100000000,
        currency: 'VND',
      );
      expect(res.isValid, isFalse);
      expect(res.errorMessage, contains('tối thiểu'));
    });

    test('discount is capped at the room total', () {
      const big = VoucherModel(
        id: 'v2',
        code: 'BIG',
        voucherType: 'ALL',
        discountValue: 500,
        tcentPrice: 0,
      );
      final res = evaluateVoucher(big, subtotalCents: 9000, currency: 'USD');
      expect(res.discountCents, 9000);
      expect(res.discountUsd, 90);
    });

    test(
      'rejects expired, inactive, used-up, non-hotel and unknown currency',
      () {
        final now = DateTime(2026, 11, 10);
        VoucherModel make({
          bool active = true,
          DateTime? expires,
          int? limit,
          int used = 0,
          String type = 'Hotel Credit',
        }) => VoucherModel(
          id: 'v',
          code: 'V',
          voucherType: type,
          discountValue: 10,
          tcentPrice: 0,
          isActive: active,
          expiresAt: expires,
          totalUsageLimit: limit,
          currentUsageCount: used,
        );
        bool ok(VoucherModel v, [String currency = 'USD']) => evaluateVoucher(
          v,
          subtotalCents: 9000,
          currency: currency,
          now: now,
        ).isValid;

        expect(ok(make()), isTrue);
        expect(ok(make(active: false)), isFalse);
        expect(ok(make(expires: DateTime(2026, 1, 1))), isFalse);
        expect(ok(make(limit: 5, used: 5)), isFalse);
        expect(ok(make(type: 'Wellness')), isFalse);
        expect(ok(make(), 'EUR'), isFalse);
      },
    );
  });

  group('RewardsVouchersScreen Widget', () {
    testWidgets('renders Tcent balance, Lucky Day banner, and Quests', (
      tester,
    ) async {
      final hotelService = HotelService(_FakeClient());
      final hotelState = HotelState(service: hotelService);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<HotelState>.value(value: hotelState),
          ],
          child: const MaterialApp(home: RewardsVouchersScreen()),
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
}
