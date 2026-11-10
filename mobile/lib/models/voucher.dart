import 'package:flutter/material.dart';

/// Represents a purchasable or promotional voucher in TripC.
class VoucherModel {
  const VoucherModel({
    required this.id,
    required this.code,
    required this.voucherType,
    required this.discountValue,
    this.minSpend = 0.0,
    required this.tcentPrice,
    this.totalUsageLimit,
    this.currentUsageCount = 0,
    this.stockRemaining = 999,
    this.startsAt,
    this.expiresAt,
    this.isActive = true,
    this.isPurchasable = true,
    this.description,
  });

  final String id;
  final String code;
  final String voucherType;
  final double discountValue;
  final double minSpend;
  final int tcentPrice;
  final int? totalUsageLimit;
  final int currentUsageCount;
  final int stockRemaining;
  final DateTime? startsAt;
  final DateTime? expiresAt;
  final bool isActive;
  final bool isPurchasable;
  final String? description;

  factory VoucherModel.fromJson(Map<String, dynamic> json) {
    final totalLimit = (json['total_usage_limit'] as num?)?.toInt();
    final usedCount = (json['current_usage_count'] as num?)?.toInt() ?? 0;
    final stock = json['stock_remaining'] != null
        ? (json['stock_remaining'] as num).toInt()
        : (totalLimit != null ? (totalLimit - usedCount).clamp(0, 999999) : 999);

    return VoucherModel(
      id: '${json['id'] ?? ''}',
      code: '${json['code'] ?? ''}',
      voucherType: '${json['voucher_type'] ?? 'ALL'}',
      discountValue: (json['discount_value'] as num?)?.toDouble() ?? 0.0,
      minSpend: (json['min_spend'] as num?)?.toDouble() ?? 0.0,
      tcentPrice: (json['tcent_price'] as num?)?.toInt() ?? 0,
      totalUsageLimit: totalLimit,
      currentUsageCount: usedCount,
      stockRemaining: stock,
      startsAt: json['starts_at'] != null ? DateTime.tryParse('${json['starts_at']}') : null,
      expiresAt: json['expires_at'] != null ? DateTime.tryParse('${json['expires_at']}') : null,
      isActive: json['is_active'] == null || json['is_active'] == true,
      isPurchasable: json['is_purchasable'] == null || json['is_purchasable'] == true,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'voucher_type': voucherType,
    'discount_value': discountValue,
    'min_spend': minSpend,
    'tcent_price': tcentPrice,
    'total_usage_limit': totalUsageLimit,
    'current_usage_count': currentUsageCount,
    'stock_remaining': stockRemaining,
    'starts_at': startsAt?.toIso8601String(),
    'expires_at': expiresAt?.toIso8601String(),
    'is_active': isActive,
    'is_purchasable': isPurchasable,
    'description': description,
  };

  /// Human-readable discount string.
  String get formattedDiscount {
    if (discountValue <= 0) return 'Ưu đãi dịch vụ';
    if (discountValue < 1.0) {
      return 'Giảm ${(discountValue * 100).round()}%';
    }
    if (discountValue > 100) {
      return 'Giảm \$${discountValue.toStringAsFixed(0)}';
    }
    return 'Giảm \$${discountValue.toStringAsFixed(0)}';
  }

  /// Theme color according to voucher category.
  Color get categoryColor {
    final lower = voucherType.toLowerCase();
    if (lower.contains('hotel')) return const Color(0xFF2563EB); // Blue
    if (lower.contains('flight') || lower.contains('transport')) return const Color(0xFF4F46E5); // Indigo
    if (lower.contains('wellness') || lower.contains('spa')) return const Color(0xFF059669); // Emerald
    if (lower.contains('entertainment') || lower.contains('concert')) return const Color(0xFFE11D48); // Rose
    if (lower.contains('dining') || lower.contains('food')) return const Color(0xFFD97706); // Amber
    return const Color(0xFFFF5E1F); // TripC Brand Primary
  }

  /// Icon corresponding to category.
  IconData get categoryIcon {
    final lower = voucherType.toLowerCase();
    if (lower.contains('hotel')) return Icons.hotel_rounded;
    if (lower.contains('flight')) return Icons.flight_rounded;
    if (lower.contains('transport')) return Icons.directions_car_rounded;
    if (lower.contains('wellness') || lower.contains('spa')) return Icons.spa_rounded;
    if (lower.contains('entertainment') || lower.contains('concert')) return Icons.music_note_rounded;
    if (lower.contains('dining') || lower.contains('food')) return Icons.restaurant_rounded;
    return Icons.confirmation_number_rounded;
  }
}

/// A voucher owned by a user in their wallet.
class UserVoucherModel {
  const UserVoucherModel({
    required this.id,
    required this.userId,
    required this.voucherId,
    required this.status,
    required this.acquiredAt,
    this.usedAt,
    this.voucher,
  });

  final String id;
  final String userId;
  final String voucherId;
  final String status; // 'AVAILABLE' | 'USED' | 'EXPIRED'
  final DateTime acquiredAt;
  final DateTime? usedAt;
  final VoucherModel? voucher;

  bool get isAvailable => status.toUpperCase() == 'AVAILABLE';

  factory UserVoucherModel.fromJson(Map<String, dynamic> json) {
    VoucherModel? nestedVoucher;
    if (json['voucher'] is Map<String, dynamic>) {
      nestedVoucher = VoucherModel.fromJson(json['voucher'] as Map<String, dynamic>);
    } else if (json['vouchers'] is Map<String, dynamic>) {
      nestedVoucher = VoucherModel.fromJson(json['vouchers'] as Map<String, dynamic>);
    }

    return UserVoucherModel(
      id: '${json['id'] ?? ''}',
      userId: '${json['user_id'] ?? ''}',
      voucherId: '${json['voucher_id'] ?? ''}',
      status: '${json['status'] ?? 'AVAILABLE'}'.toUpperCase(),
      acquiredAt: json['acquired_at'] != null
          ? DateTime.tryParse('${json['acquired_at']}') ?? DateTime.now()
          : DateTime.now(),
      usedAt: json['used_at'] != null ? DateTime.tryParse('${json['used_at']}') : null,
      voucher: nestedVoucher,
    );
  }
}

/// Result of playing the daily lucky wheel.
class SpinRewardResult {
  const SpinRewardResult({
    required this.rewardType,
    required this.rewardValue,
    required this.message,
    required this.tcentsWon,
    required this.segmentIndex,
  });

  final String rewardType; // 'TCENT' | 'VOUCHER' | 'NONE'
  final String rewardValue;
  final String message;
  final int tcentsWon;
  final int segmentIndex; // 0..6
}

/// User's current loyalty / Tcent reward status.
class TcentRewardStatus {
  const TcentRewardStatus({
    required this.tcentBalance,
    required this.membershipTier,
    required this.tcentPending,
    required this.canSpin,
    this.lastSpinDate,
  });

  final int tcentBalance;
  final String membershipTier; // 'BRONZE' | 'SILVER' | 'GOLD' | 'PLATINUM'
  final int tcentPending;
  final bool canSpin;
  final DateTime? lastSpinDate;

  double get tierMultiplier {
    switch (membershipTier.toUpperCase()) {
      case 'PLATINUM':
        return 2.0;
      case 'GOLD':
        return 1.5;
      case 'SILVER':
        return 1.2;
      default:
        return 1.0;
    }
  }

  String get tierBadgeText {
    final t = membershipTier.toUpperCase();
    final mult = tierMultiplier.toStringAsFixed(1).replaceAll('.0', '');
    return '$t Member • ${mult}x';
  }
}

/// Result of validating a voucher code at checkout.
class VoucherValidationResult {
  const VoucherValidationResult({
    required this.isValid,
    this.code = '',
    this.discountUsd = 0.0,
    this.discountCents = 0,
    this.currency = 'USD',
    this.message,
    this.errorMessage,
    this.voucher,
  });

  final bool isValid;
  final String code;

  /// Voucher face value actually granted, in USD (vouchers are USD-based).
  final double discountUsd;

  /// [discountUsd] converted to minor units of [currency] (the booking's
  /// currency), already capped at the room total.
  final int discountCents;
  final String currency;
  final String? message;
  final String? errorMessage;
  final VoucherModel? voucher;

  static const none = VoucherValidationResult(isValid: false);
}

