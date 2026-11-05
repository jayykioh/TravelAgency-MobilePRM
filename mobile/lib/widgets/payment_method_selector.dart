import 'package:flutter/material.dart';
import '../models/payment_intent.dart';
import '../services/payment_service.dart';

class PaymentMethodSelector extends StatelessWidget {
  const PaymentMethodSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.amountUsd,
    this.currency = 'USD',
    this.disabled = false,
  });

  final PaymentProviderType? selected;
  final ValueChanged<PaymentProviderType> onChanged;
  final double? amountUsd;
  final String currency;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Phương thức thanh toán',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 12),
        _MethodTile(
          provider: PaymentProviderType.momo,
          title: 'Ví điện tử MoMo',
          subtitle: 'Quét mã QR hoặc mở app MoMo',
          note: amountUsd != null
              ? '≈ ${PaymentService.convertUsdToVnd(amountUsd!).toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} đ'
              : 'Tiền tệ: VND',
          brandColor: const Color(0xFFA50064),
          badgeText: 'MOMO',
          isSelected: selected == PaymentProviderType.momo,
          onTap: disabled ? null : () => onChanged(PaymentProviderType.momo),
        ),
        const SizedBox(height: 10),
        _MethodTile(
          provider: PaymentProviderType.paypal,
          title: 'PayPal',
          subtitle: 'Thanh toán quốc tế (Visa / Master / Amex)',
          note: amountUsd != null
              ? '\$${amountUsd!.toStringAsFixed(2)} USD'
              : 'Tiền tệ: USD',
          brandColor: const Color(0xFF003087),
          badgeText: 'PAYPAL',
          isSelected: selected == PaymentProviderType.paypal,
          onTap: disabled ? null : () => onChanged(PaymentProviderType.paypal),
        ),
      ],
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.provider,
    required this.title,
    required this.subtitle,
    required this.note,
    required this.brandColor,
    required this.badgeText,
    required this.isSelected,
    required this.onTap,
  });

  final PaymentProviderType provider;
  final String title;
  final String subtitle;
  final String note;
  final Color brandColor;
  final String badgeText;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? brandColor.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? brandColor : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: brandColor.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Brand Logo Badge
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: brandColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  badgeText == 'MOMO' ? 'MoMo' : 'PP',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: brandColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          note,
                          style: TextStyle(
                            color: brandColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? brandColor : const Color(0xFFCBD5E1),
                  width: isSelected ? 6 : 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

