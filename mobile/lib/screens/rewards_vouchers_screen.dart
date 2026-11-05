import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/voucher.dart';
import '../providers/hotel_state.dart';
import '../services/voucher_service.dart';
import '../widgets/spin_wheel_dialog.dart';

/// Full Flutter port of the TripC Rewards & Voucher experience.
class RewardsVouchersScreen extends StatefulWidget {
  const RewardsVouchersScreen({super.key, this.initialTabIndex = 0});

  final int initialTabIndex;

  @override
  State<RewardsVouchersScreen> createState() => _RewardsVouchersScreenState();
}

class _RewardsVouchersScreenState extends State<RewardsVouchersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final VoucherService _voucherService;

  TcentRewardStatus? _status;
  List<VoucherModel> _marketplaceVouchers = [];
  List<UserVoucherModel> _walletVouchers = [];
  bool _isLoading = true;
  String _selectedCategory = 'Tất cả';
  int _voucherSubTabIndex = 0; // 0 = Marketplace, 1 = My Wallet

  final numberFormat = NumberFormat('#,###');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _voucherService = VoucherService(context.read<HotelState>().service.client);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final userId = context.read<HotelState>().currentUser?.id;

    try {
      final status = await _voucherService.getTcentStatus(userId);
      final marketplace = await _voucherService.fetchMarketplaceVouchers();
      final wallet = await _voucherService.fetchUserVouchers(userId);

      if (!mounted) return;
      setState(() {
        _status = status;
        _marketplaceVouchers = marketplace;
        _walletVouchers = wallet;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _openSpinWheel() {
    final userId = context.read<HotelState>().currentUser?.id;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SpinWheelDialog(
        voucherService: _voucherService,
        userId: userId,
        canSpin: _status?.canSpin ?? true,
        onSpinCompleted: (result) {
          _loadData();
        },
      ),
    );
  }

  Future<void> _handleRedeemVoucher(VoucherModel voucher) async {
    final userId = context.read<HotelState>().currentUser?.id;
    final currentBalance = _status?.tcentBalance ?? 0;

    if (currentBalance < voucher.tcentPrice) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Số dư Tcent không đủ (${numberFormat.format(voucher.tcentPrice)} TC cần thiết, bạn có ${numberFormat.format(currentBalance)} TC).',
          ),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
      return;
    }

    // Confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Xác nhận đổi voucher', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: voucher.categoryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(voucher.categoryIcon, color: voucher.categoryColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(voucher.code, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      Text(voucher.formattedDiscount, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Giá đổi:', style: TextStyle(color: Color(0xFF64748B))),
                Text(
                  '${numberFormat.format(voucher.tcentPrice)} TC',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFFF5E1F)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Số dư còn lại:', style: TextStyle(color: Color(0xFF64748B))),
                Text(
                  '${numberFormat.format(currentBalance - voucher.tcentPrice)} TC',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5E1F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Đổi ngay', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final newBalance = await _voucherService.redeemVoucher(
        userId: userId,
        voucher: voucher,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã đổi thành công mã ${voucher.code}! Số dư mới: ${numberFormat.format(newBalance)} TC.'),
          backgroundColor: const Color(0xFF059669),
        ),
      );

      // Refresh data & switch to My Wallet tab
      await _loadData();
      setState(() {
        _voucherSubTabIndex = 1;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '').replaceAll('StateError: ', '')),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCFAF8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Tcent Rewards',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            color: Color(0xFF0F172A),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_none_rounded, color: Color(0xFF0F172A), size: 24),
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF5E1F),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Bạn không có thông báo mới.')),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: const Color(0xFFFF5E1F),
              unselectedLabelColor: const Color(0xFF64748B),
              labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'Tcent Rewards'),
                Tab(text: 'Vouchers & Ví'),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF5E1F)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildRewardsTab(),
                _buildVouchersTab(),
              ],
            ),
    );
  }

  // ==========================================
  // TAB 1: TCENTS & REWARDS & DAILY SPINNER
  // ==========================================
  Widget _buildRewardsTab() {
    final status = _status ??
        const TcentRewardStatus(
          tcentBalance: 15000,
          membershipTier: 'PLATINUM',
          tcentPending: 450,
          canSpin: true,
        );

    return RefreshIndicator(
      color: const Color(0xFFFF5E1F),
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          // 1. Balance Hero Card (Orange Gradient matching screenshot)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF7A1A), Color(0xFFFF5E1F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF5E1F).withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.monetization_on_rounded, color: Colors.white, size: 24),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.schedule_rounded, color: Colors.white, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  numberFormat.format(status.tcentBalance),
                  style: const TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    status.tierBadgeText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 2. Lucky Day Spin Banner (Violet/Indigo Gradient matching screenshot)
          GestureDetector(
            onTap: _openSpinWheel,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'SPIN',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Lucky Day',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          status.canSpin
                              ? 'Your free spin is ready'
                              : 'Đã quay hôm nay • Hẹn gặp lại ngày mai!',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      status.canSpin ? 'Spin' : 'Đã quay',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // 3. Active Quests Card (Matching screenshot)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFF1F5F9)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEF3C7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.emoji_events_rounded, color: Color(0xFFD97706), size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Active Quests',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '2 quests available today',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Nhiệm vụ: Đặt phòng đầu tiên (+1000 TC), Hoàn thiện hồ sơ (+500 TC)')),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text(
                    'Claim Rewards',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 4. Daily Streak Card (Matching screenshot)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFF1F5F9)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFEDD5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.local_fire_department_rounded, color: Color(0xFFEA580C), size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Daily Streak',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Keep it up for 7 days!',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.check_rounded, color: Color(0xFF16A34A), size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Claimed',
                        style: TextStyle(
                          color: Color(0xFF16A34A),
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 5. Quick Shortcut to Vouchers
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFFFE0D1)),
            ),
            child: Row(
              children: [
                const Icon(Icons.confirmation_number_outlined, color: Color(0xFFFF5E1F), size: 32),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Chợ Voucher TripC',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: Color(0xFF9A3412),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Dùng điểm Tcent đổi mã giảm giá khách sạn & dịch vụ',
                        style: TextStyle(fontSize: 12, color: Color(0xFFC2410C)),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () => _tabController.animateTo(1),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5E1F),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  child: const Text('Xem ngay', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: VOUCHERS (MARKETPLACE & WALLET)
  // ==========================================
  Widget _buildVouchersTab() {
    return Column(
      children: [
        // Sub-tabs: Marketplace vs My Wallet
        Container(
          margin: const EdgeInsets.fromLTRB(20, 14, 20, 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _voucherSubTabIndex = 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _voucherSubTabIndex == 0 ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: _voucherSubTabIndex == 0
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : [],
                    ),
                    child: Center(
                      child: Text(
                        'Đổi Voucher (${_marketplaceVouchers.length})',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: _voucherSubTabIndex == 0 ? const Color(0xFFFF5E1F) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _voucherSubTabIndex = 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _voucherSubTabIndex == 1 ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: _voucherSubTabIndex == 1
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : [],
                    ),
                    child: Center(
                      child: Text(
                        'Ví của tôi (${_walletVouchers.length})',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: _voucherSubTabIndex == 1 ? const Color(0xFFFF5E1F) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Balance Reminder Banner
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.account_balance_wallet_rounded, color: Color(0xFFFF5E1F), size: 18),
                  SizedBox(width: 8),
                  Text('Số dư Tcent của bạn:', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                ],
              ),
              Text(
                '${numberFormat.format(_status?.tcentBalance ?? 0)} TC',
                style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFFF5E1F), fontSize: 14),
              ),
            ],
          ),
        ),

        // Sub-content
        Expanded(
          child: _voucherSubTabIndex == 0 ? _buildMarketplaceContent() : _buildWalletContent(),
        ),
      ],
    );
  }

  Widget _buildMarketplaceContent() {
    final categories = ['Tất cả', 'Khách sạn', 'Phương tiện', 'Wellness', 'Giải trí'];

    final filtered = _marketplaceVouchers.where((v) {
      if (_selectedCategory == 'Tất cả') return true;
      final lower = v.voucherType.toLowerCase();
      if (_selectedCategory == 'Khách sạn') return lower.contains('hotel');
      if (_selectedCategory == 'Phương tiện') return lower.contains('transport') || lower.contains('flight');
      if (_selectedCategory == 'Wellness') return lower.contains('wellness') || lower.contains('spa');
      if (_selectedCategory == 'Giải trí') return lower.contains('entertainment') || lower.contains('concert');
      return true;
    }).toList();

    return Column(
      children: [
        // Category filters
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: categories.map((cat) {
              final isSel = _selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  selected: isSel,
                  showCheckmark: false,
                  label: Text(cat),
                  labelStyle: TextStyle(
                    color: isSel ? Colors.white : const Color(0xFF64748B),
                    fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 12,
                  ),
                  backgroundColor: Colors.white,
                  selectedColor: const Color(0xFFFF5E1F),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(99),
                    side: BorderSide(color: isSel ? const Color(0xFFFF5E1F) : const Color(0xFFE2E8F0)),
                  ),
                  onSelected: (_) => setState(() => _selectedCategory = cat),
                ),
              );
            }).toList(),
          ),
        ),

        // Marketplace list
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text(
                    'Không có voucher nào trong danh mục này.',
                    style: TextStyle(color: Color(0xFF94A3B8)),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 40),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final voucher = filtered[index];
                    return _buildMarketplaceVoucherCard(voucher);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMarketplaceVoucherCard(VoucherModel voucher) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: voucher.categoryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(voucher.categoryIcon, color: voucher.categoryColor, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      voucher.code,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        voucher.voucherType,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  voucher.description ?? voucher.formattedDiscount,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.monetization_on_rounded, color: Color(0xFFFF5E1F), size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${numberFormat.format(voucher.tcentPrice)} TC',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFFF5E1F),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Còn lại: ${voucher.stockRemaining}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _handleRedeemVoucher(voucher),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5E1F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              elevation: 0,
            ),
            child: const Text('Đổi ngay', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletContent() {
    if (_walletVouchers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.confirmation_number_outlined, color: Color(0xFF94A3B8), size: 36),
              ),
              const SizedBox(height: 16),
              const Text(
                'Ví voucher đang trống',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 6),
              const Text(
                'Bạn chưa đổi voucher nào. Hãy dùng Tcent ở tab "Đổi Voucher" hoặc quay vòng quay may mắn nhé!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: () => setState(() => _voucherSubTabIndex = 0),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5E1F),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: const Text('Khám phá chợ voucher', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
      itemCount: _walletVouchers.length,
      itemBuilder: (context, index) {
        final uv = _walletVouchers[index];
        final voucher = uv.voucher;
        final code = voucher?.code ?? 'VOUCHER';
        final discount = voucher?.formattedDiscount ?? 'Ưu đãi dịch vụ';
        final type = voucher?.voucherType ?? 'Ưu đãi';
        final color = voucher?.categoryColor ?? const Color(0xFFFF5E1F);
        final icon = voucher?.categoryIcon ?? Icons.confirmation_number_rounded;

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFF1F5F9)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(icon, color: color, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              code,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 17,
                                color: Color(0xFF0F172A),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: const Text(
                                'SẴN SÀNG DÙNG',
                                style: TextStyle(
                                  color: Color(0xFF16A34A),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$discount • $type',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Đã nhận: ${DateFormat('dd/MM/yyyy').format(uv.acquiredAt)}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Đã sao chép mã "$code"!'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFFFF5E1F)),
                    label: const Text(
                      'Sao chép mã',
                      style: TextStyle(color: Color(0xFFFF5E1F), fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

