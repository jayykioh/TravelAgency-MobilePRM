import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/voucher.dart';

/// Service handling Tcent loyalty balance, daily spin wheel, and voucher marketplace/wallet.
class VoucherService {
  VoucherService(this.client);

  final SupabaseClient client;

  // Local fallback storage for session / demo purposes
  static final Map<String, int> _localBalances = {};
  static final Map<String, List<UserVoucherModel>> _localUserVouchers = {};
  static final Set<String> _localSpunToday = {};

  /// Pre-configured seed vouchers matching TripC catalog.
  static final List<VoucherModel> defaultVouchers = [
    VoucherModel(
      id: 'v_hotel20',
      code: 'HOTEL20',
      voucherType: 'Hotel Credit',
      discountValue: 20.0,
      minSpend: 50.0,
      tcentPrice: 2000,
      totalUsageLimit: 1000,
      currentUsageCount: 42,
      stockRemaining: 958,
      expiresAt: DateTime.now().add(const Duration(days: 180)),
      description: 'Giảm \$20 cho tất cả đặt phòng khách sạn',
    ),
    VoucherModel(
      id: 'v_lounge_vip',
      code: 'LOUNGE_VIP',
      voucherType: 'Transport',
      discountValue: 35.0,
      minSpend: 0.0,
      tcentPrice: 3500,
      totalUsageLimit: 500,
      currentUsageCount: 110,
      stockRemaining: 390,
      expiresAt: DateTime.now().add(const Duration(days: 90)),
      description: 'Vé phòng chờ thương gia sân bay VIP',
    ),
    VoucherModel(
      id: 'v_spa_retreat',
      code: 'SPA_RETREAT',
      voucherType: 'Wellness',
      discountValue: 50.0,
      minSpend: 100.0,
      tcentPrice: 5000,
      totalUsageLimit: 200,
      currentUsageCount: 65,
      stockRemaining: 135,
      expiresAt: DateTime.now().add(const Duration(days: 120)),
      description: 'Gói chăm sóc trị liệu Spa & Massage cao cấp',
    ),
    VoucherModel(
      id: 'v_concert_pass',
      code: 'CONCERT_PASS',
      voucherType: 'Entertainment',
      discountValue: 80.0,
      minSpend: 120.0,
      tcentPrice: 8000,
      totalUsageLimit: 50,
      currentUsageCount: 18,
      stockRemaining: 32,
      expiresAt: DateTime.now().add(const Duration(days: 60)),
      description: 'Vé tham dự đại nhạc hội & sự kiện âm nhạc',
    ),
    VoucherModel(
      id: 'v_flight_deal',
      code: 'FLIGHT_DEAL',
      voucherType: 'Transport',
      discountValue: 30.0,
      minSpend: 200.0,
      tcentPrice: 4500,
      totalUsageLimit: 300,
      currentUsageCount: 88,
      stockRemaining: 212,
      expiresAt: DateTime.now().add(const Duration(days: 365)),
      description: 'Giảm \$30 cho các chặng bay quốc tế và nội địa',
    ),
  ];

  /// Fetches the user's loyalty profile (balance, tier, pending points, spin status).
  Future<TcentRewardStatus> getTcentStatus(String? userId) async {
    if (userId == null || userId.isEmpty) {
      return const TcentRewardStatus(
        tcentBalance: 15000, // Demo balance for guests
        membershipTier: 'PLATINUM',
        tcentPending: 450,
        canSpin: true,
      );
    }

    int balance = _localBalances[userId] ?? 15000;
    String tier = 'PLATINUM';
    int pending = 450;
    bool canSpin = true;
    DateTime? lastSpin;

    try {
      final userRow = await client
          .from('users')
          .select('tcent_balance, membership_tier, tcent_pending')
          .eq('id', userId)
          .maybeSingle();

      if (userRow != null) {
        balance = (userRow['tcent_balance'] as num?)?.toInt() ?? balance;
        tier = '${userRow['membership_tier'] ?? tier}'.toUpperCase();
        pending = (userRow['tcent_pending'] as num?)?.toInt() ?? pending;
        _localBalances[userId] = balance;
      }
    } catch (_) {
      // Keep fallback
    }

    // Check spin eligibility for today
    final todayStr = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    if (_localSpunToday.contains('$userId:$todayStr')) {
      canSpin = false;
    } else {
      try {
        final spinRow = await client
            .from('spin_history')
            .select('created_at')
            .eq('user_id', userId)
            .gte('created_at', '${todayStr}T00:00:00Z')
            .lte('created_at', '${todayStr}T23:59:59Z')
            .limit(1)
            .maybeSingle();

        if (spinRow != null) {
          canSpin = false;
          lastSpin = DateTime.tryParse('${spinRow['created_at']}');
          _localSpunToday.add('$userId:$todayStr');
        }
      } catch (_) {
        // Table might not exist yet; default canSpin = true unless spun locally
      }
    }

    return TcentRewardStatus(
      tcentBalance: balance,
      membershipTier: tier,
      tcentPending: pending,
      canSpin: canSpin,
      lastSpinDate: lastSpin,
    );
  }

  /// Lists all vouchers available in the Marketplace.
  Future<List<VoucherModel>> fetchMarketplaceVouchers() async {
    try {
      final rows = await client
          .from('vouchers')
          .select()
          .eq('is_active', true)
          .eq('is_purchasable', true)
          .order('tcent_price', ascending: true);

      if (rows is List && rows.isNotEmpty) {
        return rows
            .map((r) => VoucherModel.fromJson(Map<String, dynamic>.from(r)))
            .toList();
      }
    } catch (_) {
      // Fallback to default vouchers
    }

    return defaultVouchers;
  }

  /// Fetches vouchers in the user's wallet.
  Future<List<UserVoucherModel>> fetchUserVouchers(String? userId) async {
    if (userId == null || userId.isEmpty) {
      return _localUserVouchers['guest'] ?? [];
    }

    final localList = _localUserVouchers[userId] ?? [];

    try {
      final rows = await client
          .from('user_vouchers')
          .select('*, vouchers(*)')
          .eq('user_id', userId)
          .eq('status', 'AVAILABLE')
          .order('acquired_at', ascending: false);

      if (rows is List && rows.isNotEmpty) {
        final dbList = rows
            .map((r) => UserVoucherModel.fromJson(Map<String, dynamic>.from(r)))
            .toList();

        // Merge local vouchers if any were redeemed in this session
        final ids = dbList.map((e) => e.voucherId).toSet();
        for (final loc in localList) {
          if (!ids.contains(loc.voucherId)) {
            dbList.insert(0, loc);
          }
        }
        return dbList;
      }
    } catch (_) {
      // Fallback to local
    }

    return localList;
  }

  /// Redeems a voucher using user's Tcent balance.
  Future<int> redeemVoucher({
    required String? userId,
    required VoucherModel voucher,
  }) async {
    final effectiveUserId = userId ?? 'guest';
    final currentStatus = await getTcentStatus(userId);

    if (currentStatus.tcentBalance < voucher.tcentPrice) {
      throw StateError('Số dư Tcent không đủ (Cần ${voucher.tcentPrice} TC, hiện có ${currentStatus.tcentBalance} TC).');
    }

    // Check if already in wallet
    final wallet = await fetchUserVouchers(userId);
    if (wallet.any((v) => v.voucherId == voucher.id || v.voucher?.code == voucher.code)) {
      throw StateError('Bạn đã sở hữu voucher này trong ví rồi.');
    }

    final newBalance = currentStatus.tcentBalance - voucher.tcentPrice;
    _localBalances[effectiveUserId] = newBalance;

    final userVoucher = UserVoucherModel(
      id: 'uv_${DateTime.now().millisecondsSinceEpoch}',
      userId: effectiveUserId,
      voucherId: voucher.id,
      status: 'AVAILABLE',
      acquiredAt: DateTime.now(),
      voucher: voucher,
    );

    _localUserVouchers.putIfAbsent(effectiveUserId, () => []).insert(0, userVoucher);

    // Try persisting to Supabase if authenticated
    if (userId != null && userId.isNotEmpty) {
      try {
        await client
            .from('users')
            .update({'tcent_balance': newBalance})
            .eq('id', userId);

        await client.from('user_vouchers').insert({
          'user_id': userId,
          'voucher_id': voucher.id,
          'status': 'AVAILABLE',
          'acquired_at': DateTime.now().toIso8601String(),
        });

        await client.from('tcent_ledger').insert({
          'user_id': userId,
          'amount': -voucher.tcentPrice,
          'transaction_type': 'SPEND',
          'status': 'COMPLETED',
          'description': 'Đổi voucher ${voucher.code}',
          'reference_type': 'voucher_exchange',
        });

        // Update voucher stock count
        await client
            .from('vouchers')
            .update({'current_usage_count': voucher.currentUsageCount + 1})
            .eq('id', voucher.id);
      } catch (_) {
        // Local state succeeded
      }
    }

    return newBalance;
  }

  /// Plays the daily spin wheel and returns the awarded prize.
  Future<SpinRewardResult> executeDailySpin({required String? userId}) async {
    final effectiveUserId = userId ?? 'guest';
    final todayStr = DateTime.now().toUtc().toIso8601String().substring(0, 10);

    if (_localSpunToday.contains('$effectiveUserId:$todayStr')) {
      throw StateError('Bạn đã quay thưởng hôm nay rồi. Hãy quay lại vào ngày mai nhé!');
    }

    // Weighted Probability Wheel matching Web:
    // 50 TC: 40% (0-39) -> index 0
    // 100 TC: 30% (40-69) -> index 1
    // 500 TC: 15% (70-84) -> index 2
    // 2,000 TC: 10% (85-94) -> index 3
    // 5,000 TC: 4% (95-98) -> index 4
    // 10,000 TC: 0.9% (99.0 - 99.8) -> index 5
    // JACKPOT 100% Voucher: 0.1% (99.9) -> index 6
    final roll = Random().nextDouble() * 100.0;
    int segmentIndex;
    int winAmount = 0;
    String rewardType;
    String rewardValue;
    String message;

    if (roll < 40.0) {
      segmentIndex = 0;
      winAmount = 50;
      rewardType = 'TCENT';
      rewardValue = '50';
      message = 'Chúc mừng! Bạn đã trúng 50 T-Cents!';
    } else if (roll < 70.0) {
      segmentIndex = 1;
      winAmount = 100;
      rewardType = 'TCENT';
      rewardValue = '100';
      message = 'Chúc mừng! Bạn đã trúng 100 T-Cents!';
    } else if (roll < 85.0) {
      segmentIndex = 2;
      winAmount = 500;
      rewardType = 'TCENT';
      rewardValue = '500';
      message = 'Tuyệt vời! Bạn nhận được 500 T-Cents!';
    } else if (roll < 95.0) {
      segmentIndex = 3;
      winAmount = 2000;
      rewardType = 'TCENT';
      rewardValue = '2000';
      message = 'Thắng lớn! Nhận ngay 2,000 T-Cents!';
    } else if (roll < 99.0) {
      segmentIndex = 4;
      winAmount = 5000;
      rewardType = 'TCENT';
      rewardValue = '5000';
      message = 'Siêu trúng thưởng! 5,000 T-Cents!';
    } else if (roll < 99.9) {
      segmentIndex = 5;
      winAmount = 10000;
      rewardType = 'TCENT';
      rewardValue = '10000';
      message = 'JACKPOT KHỦNG! 10,000 T-Cents!';
    } else {
      segmentIndex = 6;
      winAmount = 0;
      rewardType = 'VOUCHER';
      rewardValue = 'SPIN_JACKPOT_100';
      message = 'SUPER JACKPOT! Voucher nghỉ dưỡng 100%!';
    }

    _localSpunToday.add('$effectiveUserId:$todayStr');

    // Credit balance
    final currentStatus = await getTcentStatus(userId);
    final newBalance = currentStatus.tcentBalance + winAmount;
    _localBalances[effectiveUserId] = newBalance;

    // Persist to Supabase if logged in
    if (userId != null && userId.isNotEmpty) {
      try {
        await client.from('spin_history').insert({
          'user_id': userId,
          'reward_type': rewardType,
          'reward_value': rewardValue,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });

        if (winAmount > 0) {
          await client
              .from('users')
              .update({'tcent_balance': newBalance})
              .eq('id', userId);

          await client.from('tcent_ledger').insert({
            'user_id': userId,
            'amount': winAmount,
            'transaction_type': 'SPIN_REWARD',
            'status': 'COMPLETED',
            'description': 'Phần thưởng Lucky Day Spin ($winAmount TC)',
            'reference_type': 'spin',
          });
        }
      } catch (_) {
        // Handled locally
      }
    }

    return SpinRewardResult(
      rewardType: rewardType,
      rewardValue: rewardValue,
      message: message,
      tcentsWon: winAmount,
      segmentIndex: segmentIndex,
    );
  }

  /// Validates a voucher code against cart subtotal and calculates discount.
  Future<VoucherValidationResult> validateVoucher({
    required String code,
    required double cartTotalUsd,
    String? serviceType,
    String? userId,
  }) async {
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.isEmpty) {
      return VoucherValidationResult.none;
    }

    VoucherModel? voucher;

    // 1. Try fetching from Supabase
    try {
      final row = await client
          .from('vouchers')
          .select()
          .ilike('code', cleanCode)
          .maybeSingle();

      if (row != null) {
        voucher = VoucherModel.fromJson(Map<String, dynamic>.from(row));
      }
    } catch (_) {
      // Continue to local lookup
    }

    // 2. Check local catalog / seed vouchers
    if (voucher == null) {
      try {
        voucher = defaultVouchers.firstWhere(
          (v) => v.code.toUpperCase() == cleanCode,
        );
      } catch (_) {
        // Continue to public codes
      }
    }

    // 3. Known public codes (e.g. SHOP10, SHOP20, HOTEL10, TRIPC10)
    if (voucher == null) {
      if (cleanCode == 'SHOP10' || cleanCode == 'HOTEL10' || cleanCode == 'TRIPC10') {
        voucher = VoucherModel(
          id: 'v_public_10',
          code: cleanCode,
          voucherType: 'Hotel Credit',
          discountValue: 10.0,
          minSpend: 0.0,
          tcentPrice: 1000,
          description: 'Giảm \$10 cho đơn đặt phòng',
        );
      } else if (cleanCode == 'SHOP20' || cleanCode == 'HOTEL20' || cleanCode == 'TRIPC20') {
        voucher = VoucherModel(
          id: 'v_public_20',
          code: cleanCode,
          voucherType: 'Hotel Credit',
          discountValue: 20.0,
          minSpend: 50.0,
          tcentPrice: 2000,
          description: 'Giảm \$20 cho đơn từ \$50',
        );
      } else if (RegExp(r'\d+$').hasMatch(cleanCode)) {
        final match = RegExp(r'(\d+)$').firstMatch(cleanCode);
        final val = double.tryParse(match?.group(1) ?? '0') ?? 0;
        if (val > 0) {
          voucher = VoucherModel(
            id: 'v_custom_${cleanCode.toLowerCase()}',
            code: cleanCode,
            voucherType: 'Promo',
            discountValue: val,
            minSpend: 0.0,
            tcentPrice: (val * 100).toInt(),
            description: 'Giảm \$$val cho đơn đặt phòng',
          );
        }
      }
    }

    if (voucher == null) {
      return VoucherValidationResult(
        isValid: false,
        code: cleanCode,
        errorMessage: 'Mã voucher "$cleanCode" không hợp lệ hoặc không tồn tại.',
      );
    }

    // 4. Validate Min Spend
    if (voucher.minSpend > 0 && cartTotalUsd < voucher.minSpend) {
      return VoucherValidationResult(
        isValid: false,
        code: cleanCode,
        voucher: voucher,
        errorMessage:
            'Đơn hàng tối thiểu phải từ \$${voucher.minSpend.toStringAsFixed(0)} (Hiện tại: \$${cartTotalUsd.toStringAsFixed(1)})',
      );
    }

    // 5. Validate Expiry
    if (voucher.expiresAt != null && voucher.expiresAt!.isBefore(DateTime.now())) {
      return VoucherValidationResult(
        isValid: false,
        code: cleanCode,
        voucher: voucher,
        errorMessage: 'Voucher "$cleanCode" đã hết hạn sử dụng.',
      );
    }

    // 6. Calculate Discount Amount
    double discount = voucher.discountValue;
    if (discount <= 1.0 && discount > 0) {
      discount = cartTotalUsd * discount;
    }

    if (discount > cartTotalUsd) {
      discount = cartTotalUsd;
    }

    return VoucherValidationResult(
      isValid: true,
      code: cleanCode,
      discountUsd: discount,
      message: 'Áp dụng thành công mã $cleanCode: Giảm \$${discount.toStringAsFixed(1)}',
      voucher: voucher,
    );
  }
}

