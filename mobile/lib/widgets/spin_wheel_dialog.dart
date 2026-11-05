import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/voucher.dart';
import '../services/voucher_service.dart';

class SpinSegment {
  const SpinSegment({
    required this.label,
    required this.color,
    required this.textColor,
  });

  final String label;
  final Color color;
  final Color textColor;
}

class SpinWheelDialog extends StatefulWidget {
  const SpinWheelDialog({
    super.key,
    required this.voucherService,
    required this.userId,
    this.canSpin = true,
    this.onSpinCompleted,
  });

  final VoucherService voucherService;
  final String? userId;
  final bool canSpin;
  final ValueChanged<SpinRewardResult>? onSpinCompleted;

  @override
  State<SpinWheelDialog> createState() => _SpinWheelDialogState();
}

class _SpinWheelDialogState extends State<SpinWheelDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Animation<double>? _animation;

  static const List<SpinSegment> segments = [
    SpinSegment(label: '50 TC', color: Color(0xFFFBBF24), textColor: Colors.black87),
    SpinSegment(label: '100 TC', color: Color(0xFFF59E0B), textColor: Colors.black87),
    SpinSegment(label: '500 TC', color: Color(0xFFEA580C), textColor: Colors.white),
    SpinSegment(label: '2K TC', color: Color(0xFFDB2777), textColor: Colors.white),
    SpinSegment(label: '5K TC', color: Color(0xFF9333EA), textColor: Colors.white),
    SpinSegment(label: '10K TC', color: Color(0xFF7C3AED), textColor: Colors.white),
    SpinSegment(label: 'JACKPOT', color: Color(0xFF2563EB), textColor: Colors.white),
  ];

  bool _isSpinning = false;
  late bool _canSpin;
  double _currentRotation = 0.0;

  @override
  void initState() {
    super.initState();
    _canSpin = widget.canSpin;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSpin() async {
    if (_isSpinning || !_canSpin) return;

    setState(() {
      _isSpinning = true;
    });

    try {
      final result = await widget.voucherService.executeDailySpin(userId: widget.userId);
      final segmentCount = segments.length;
      final segmentAngle = 360.0 / segmentCount;

      // Pointer is located at 270 degrees (Top)
      // Segment i center angle = i * segmentAngle + (segmentAngle / 2)
      // When wheel rotates by R degrees, segment angle rotates by R.
      // Top pointer hits angle: 270 - centerAngle
      final targetIndex = result.segmentIndex;
      final centerAngle = (targetIndex * segmentAngle) + (segmentAngle / 2);
      final rawTarget = 270.0 - centerAngle;

      // Normalize positive turns (at least 6 full 360 rotations)
      final extraSpins = 360.0 * 6;
      final totalTarget = extraSpins + (rawTarget % 360.0);

      final startAngle = _currentRotation % 360.0;
      final endAngle = startAngle + totalTarget;

      _animation = Tween<double>(begin: startAngle, end: endAngle).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      )..addListener(() {
          setState(() {
            _currentRotation = _animation!.value;
          });
        });

      _controller.reset();
      await _controller.forward();

      if (!mounted) return;

      setState(() {
        _isSpinning = false;
        _canSpin = false;
      });

      widget.onSpinCompleted?.call(result);

      // Celebration dialog
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: Row(
            children: const [
              Icon(Icons.stars_rounded, color: Color(0xFFFF5E1F), size: 28),
              SizedBox(width: 8),
              Text('Chúc mừng!', style: TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFFE0D1), width: 2),
                ),
                child: const Icon(Icons.card_giftcard_rounded, color: Color(0xFFFF5E1F), size: 40),
              ),
              const SizedBox(height: 16),
              Text(
                result.message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),
              Text(
                result.rewardType == 'TCENT'
                    ? '+${result.rewardValue} TC đã được cộng vào số dư của bạn.'
                    : 'Voucher đã được thêm vào ví của bạn.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                if (mounted && Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5E1F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Tuyệt vời', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSpinning = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 32,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 32),
                Column(
                  children: const [
                    Text(
                      'Lucky Day Spin',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF4F46E5),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Thử vận may mỗi ngày cùng TripC!',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: _isSpinning ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Wheel Box
            SizedBox(
              width: 270,
              height: 270,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Spinning Wheel
                  Transform.rotate(
                    angle: _currentRotation * (math.pi / 180.0),
                    child: CustomPaint(
                      size: const Size(260, 260),
                      painter: _WheelPainter(segments: segments),
                    ),
                  ),

                  // Center Gift Circle
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF818CF8), width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.card_giftcard_rounded, color: Color(0xFF7C3AED), size: 28),
                  ),

                  // Pointer Arrow at the Top pointing down
                  Positioned(
                    top: -12,
                    child: CustomPaint(
                      size: const Size(26, 26),
                      painter: _PointerPainter(),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Spin button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: _canSpin && !_isSpinning
                      ? const LinearGradient(
                          colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        )
                      : const LinearGradient(
                          colors: [Color(0xFF94A3B8), Color(0xFF64748B)],
                        ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: _canSpin && !_isSpinning
                      ? [
                          BoxShadow(
                            color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : [],
                ),
                child: ElevatedButton(
                  onPressed: (_isSpinning || !_canSpin) ? null : _handleSpin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  child: _isSpinning
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            ),
                            SizedBox(width: 12),
                            Text('Đang quay...', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          ],
                        )
                      : Text(
                          _canSpin ? 'QUAY NGAY' : 'HẸN GẶP LẠI NGÀY MAI',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '1 lượt quay miễn phí mỗi 24 giờ. Điều khoản áp dụng.',
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter({required this.segments});

  final List<SpinSegment> segments;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final sweepAngle = (2 * math.pi) / segments.length;

    final borderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final outerRingPaint = Paint()
      ..color = const Color(0xFF4338CA)
      ..strokeWidth = 5.0
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < segments.length; i++) {
      final startAngle = i * sweepAngle;
      final slicePaint = Paint()
        ..color = segments[i].color
        ..style = PaintingStyle.fill;

      // Draw slice
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        slicePaint,
      );

      // Draw slice separator
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        borderPaint,
      );

      // Draw Text
      final textSpan = TextSpan(
        text: segments[i].label,
        style: TextStyle(
          color: segments[i].textColor,
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.2,
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();

      final midAngle = startAngle + (sweepAngle / 2);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(midAngle);
      canvas.translate(radius * 0.65, 0);
      canvas.rotate(math.pi / 2);
      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2),
      );
      canvas.restore();
    }

    // Draw outer bezel
    canvas.drawCircle(center, radius, outerRingPaint);
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) => false;
}

class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();

    canvas.drawShadow(path, Colors.black, 4, true);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

