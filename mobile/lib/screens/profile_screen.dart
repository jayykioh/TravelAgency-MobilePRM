import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/hotel_state.dart';
import '../services/hotel_service.dart';
import 'auth_screen.dart';
import 'hotel_bookings_screen.dart';

/// Flutter port of the React ProfileHero and SettingsList experience.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<Map<String, dynamic>?>? profile;
  String? _lastUserId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = context.read<HotelState>().currentUser;
    if (_lastUserId != user?.id) {
      _lastUserId = user?.id;
      profile = user != null ? context.read<HotelState>().service.currentProfile() : null;
    }
  }

  void reload() {
    final user = context.read<HotelState>().currentUser;
    setState(() {
      _lastUserId = user?.id;
      profile = user != null ? context.read<HotelState>().service.currentProfile() : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hotelState = context.watch<HotelState>();
    final user = hotelState.currentUser;

    if (_lastUserId != user?.id) {
      _lastUserId = user?.id;
      profile = user != null ? hotelState.service.currentProfile() : null;
    }

    if (user == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFFCFAF8),
        appBar: AppBar(
          title: const Text('Hồ sơ cá nhân', style: TextStyle(fontWeight: FontWeight.w700)),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: _buildGuestView(context),
      );
    }

    final service = hotelState.service;

    return Scaffold(
      backgroundColor: const Color(0xFFFCFAF8),
      appBar: AppBar(
        title: const Text('Hồ sơ cá nhân', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: reload,
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: profile,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF5E1F)),
            );
          }
          if (snapshot.hasError) {
            return _ProfileError(error: snapshot.error, onRetry: reload);
          }
          final data = snapshot.data ?? <String, dynamic>{};
          final isProfileMissing = snapshot.data == null;
          final name = '${data['name'] ?? user.email?.split('@').first ?? 'Traveller'}';
          final tier = '${data['membership_tier'] ?? 'BRONZE'}'.toUpperCase();
          final city = '${data['city'] ?? ''}'.trim();
          final country = '${data['country'] ?? ''}'.trim();
          final location = [city, country].where((s) => s.isNotEmpty).join(', ');
          final phone = '${data['phone_number'] ?? ''}'.trim();
          final bio = '${data['bio'] ?? ''}'.trim();

          return RefreshIndicator(
            color: const Color(0xFFFF5E1F),
            onRefresh: () async => reload(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
              children: [
                // Profile missing warning if user exists in auth but not yet in public.users
                if (isProfileMissing) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, color: Color(0xFFD97706), size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Chưa có thông tin hồ sơ',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF92400E),
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Tài khoản của bạn đã được xác thực qua Supabase. Nhấn Chỉnh sửa bên dưới để cập nhật thông tin cá nhân.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFB45309),
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Hero Profile Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [Color(0xFFFF5E1F), Color(0xFFF59E0B)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 38,
                              backgroundColor: const Color(0xFFFFF7ED),
                              child: Text(
                                name.isEmpty ? 'T' : name[0].toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFFFF5E1F),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${user.email}',
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFEDE6),
                                    borderRadius: BorderRadius.circular(99),
                                    border: Border.all(
                                      color: const Color(0xFFFFD5C2),
                                    ),
                                  ),
                                  child: Text(
                                    tier,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFFFF5E1F),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton.filledTonal(
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFFFF7ED),
                              foregroundColor: const Color(0xFFFF5E1F),
                            ),
                            onPressed: () => _openEditDialog(data, user.email),
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            tooltip: 'Chỉnh sửa hồ sơ',
                          ),
                        ],
                      ),
                      if (bio.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            bio,
                            style: const TextStyle(
                              color: Color(0xFF334155),
                              fontSize: 13,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                      if (location.isNotEmpty || phone.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            if (location.isNotEmpty) ...[
                              const Icon(Icons.location_on_outlined,
                                  size: 16, color: Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  location,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                            if (phone.isNotEmpty) ...[
                              const SizedBox(width: 12),
                              const Icon(Icons.phone_outlined,
                                  size: 16, color: Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Text(
                                phone,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 28),
                const Text(
                  'Hoạt động của tôi',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _activityItem(
                      icon: Icons.calendar_month_rounded,
                      label: 'Đơn đặt phòng',
                      color: const Color(0xFFE0F2FE),
                      iconColor: const Color(0xFF0284C7),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const HistoryScreen(),
                          ),
                        );
                      },
                    ),
                    _activityItem(
                      icon: Icons.favorite_rounded,
                      label: 'Đã lưu',
                      color: const Color(0xFFFCE7F3),
                      iconColor: const Color(0xFFDB2777),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Tính năng Danh sách đã lưu đang được phát triển.',
                            ),
                          ),
                        );
                      },
                    ),
                    _activityItem(
                      icon: Icons.card_giftcard_rounded,
                      label: 'Phần thưởng',
                      color: const Color(0xFFD1FAE5),
                      iconColor: const Color(0xFF059669),
                      onTap: () {
                        final balance = data['tcent_balance'] ?? 0;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Điểm thưởng TCent hiện có: $balance TCent.',
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 28),
                const Text(
                  'Cài đặt ứng dụng',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      for (final item in const [
                        (Icons.settings_outlined, 'Cài đặt tài khoản', 'Quản lý mật khẩu và liên kết'),
                        (Icons.shield_outlined, 'Quyền riêng tư & Bảo mật', 'Chính sách và dữ liệu cá nhân'),
                        (Icons.language_rounded, 'Ngôn ngữ & Khu vực', 'Tiếng Việt (VN) / USD'),
                        (Icons.help_outline_rounded, 'Trợ giúp & Hỗ trợ', 'FAQ và liên hệ hỗ trợ TripC'),
                      ])
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(item.$1, size: 20, color: const Color(0xFF475569)),
                          ),
                          title: Text(
                            item.$2,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          subtitle: Text(
                            item.$3,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                          ),
                          trailing: const Icon(Icons.chevron_right, size: 20, color: Color(0xFF94A3B8)),
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${item.$2}: Đang phát triển trong phiên bản tới.')),
                            );
                          },
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(99),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => _confirmSignOut(service),
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Đăng xuất tài khoản', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGuestView(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
    children: [
      Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFFD5C2), width: 2),
              ),
              child: const Icon(
                Icons.person_outline_rounded,
                size: 44,
                color: Color(0xFFFF5E1F),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Chào mừng bạn đến với TripC',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Đăng nhập để xem lịch sử đặt phòng, quản lý thông tin cá nhân và tích lũy điểm thưởng thành viên.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5E1F),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(99),
                  ),
                  elevation: 2,
                ),
                onPressed: () async {
                  await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AuthScreen(
                        reasonMessage: 'Đăng nhập để quản lý hồ sơ và chuyến đi của bạn.',
                      ),
                    ),
                  );
                  reload();
                },
                icon: const Icon(Icons.login_rounded, size: 20),
                label: const Text(
                  'Đăng nhập / Đăng ký',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 28),
      const Text(
        'Lợi ích thành viên TripC',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: Color(0xFF0F172A),
        ),
      ),
      const SizedBox(height: 14),
      for (final benefit in const [
        (Icons.bookmark_border_rounded, 'Lưu khách sạn yêu thích', 'Dễ dàng so sánh và đặt phòng lại bất kỳ lúc nào.'),
        (Icons.monetization_on_outlined, 'Tích lũy điểm TCent', 'Tích điểm cho mỗi lần đặt phòng để đổi voucher ưu đãi.'),
        (Icons.support_agent_rounded, 'Hỗ trợ cá nhân hóa', 'Tiếp tục cuộc trò chuyện với AI Chatbot theo lịch sử của bạn.'),
      ])
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(benefit.$1, color: const Color(0xFFFF5E1F), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        benefit.$2,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        benefit.$3,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
    ],
  );

  Widget _activityItem({
    required IconData icon,
    required String label,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
  }) =>
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: Ink(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFF1F5F9)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    height: 52,
                    width: 52,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Center(child: Icon(icon, color: iconColor, size: 26)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  Future<void> _confirmSignOut(HotelService service) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi tài khoản TripC?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await service.auth.signOut();
      if (!mounted) return;
      reload();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã đăng xuất thành công.')),
      );
    }
  }

  Future<void> _openEditDialog(Map<String, dynamic> current, String? email) async {
    final updated = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _EditProfileDialog(
        current: current,
        email: email,
        service: context.read<HotelState>().service,
      ),
    );
    if (updated == true && mounted) {
      reload();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cập nhật hồ sơ thành công!')),
      );
    }
  }
}

class _EditProfileDialog extends StatefulWidget {
  const _EditProfileDialog({
    required this.current,
    required this.email,
    required this.service,
  });

  final Map<String, dynamic> current;
  final String? email;
  final HotelService service;

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final TextEditingController name;
  late final TextEditingController bio;
  late final TextEditingController city;
  late final TextEditingController phone;
  bool saving = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: '${widget.current['name'] ?? ''}');
    bio = TextEditingController(text: '${widget.current['bio'] ?? ''}');
    city = TextEditingController(text: '${widget.current['city'] ?? ''}');
    phone = TextEditingController(text: '${widget.current['phone_number'] ?? ''}');
  }

  @override
  void dispose() {
    name.dispose();
    bio.dispose();
    city.dispose();
    phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      saving = true;
      errorMessage = null;
    });

    try {
      await widget.service.updateCurrentProfile({
        'name': name.text.trim(),
        'bio': bio.text.trim(),
        'city': city.text.trim(),
        'phone_number': phone.text.trim(),
      });
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          saving = false;
          errorMessage = 'Không thể lưu hồ sơ: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    title: const Row(
      children: [
        Icon(Icons.edit_note_rounded, color: Color(0xFFFF5E1F)),
        SizedBox(width: 8),
        Text('Chỉnh sửa hồ sơ', style: TextStyle(fontWeight: FontWeight.w800)),
      ],
    ),
    content: SizedBox(
      width: double.maxFinite,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (errorMessage != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFF991B1B),
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Email read-only info
            TextField(
              controller: TextEditingController(text: widget.email ?? ''),
              readOnly: true,
              enabled: false,
              decoration: InputDecoration(
                labelText: 'Email (Cố định theo tài khoản)',
                prefixIcon: const Icon(Icons.email_outlined),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: name,
              enabled: !saving,
              decoration: InputDecoration(
                labelText: 'Họ và tên',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bio,
              enabled: !saving,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Giới thiệu bản thân',
                prefixIcon: const Icon(Icons.description_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: city,
              enabled: !saving,
              decoration: InputDecoration(
                labelText: 'Thành phố cư trú',
                prefixIcon: const Icon(Icons.location_city_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phone,
              enabled: !saving,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Số điện thoại liên hệ',
                prefixIcon: const Icon(Icons.phone_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context, false),
        child: const Text('Hủy'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFFF5E1F),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
        ),
        onPressed: saving ? null : _save,
        child: saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text('Lưu thay đổi', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    ],
  );
}

class _ProfileError extends StatelessWidget {
  const _ProfileError({required this.error, required this.onRetry});
  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFFEF2F2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_off_outlined, size: 40, color: Color(0xFFDC2626)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Không thể tải hồ sơ',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Đã xảy ra lỗi khi đọc thông tin hồ sơ từ cơ sở dữ liệu qua quyền hiện tại:\n$error',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF5E1F),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Thử lại', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    ),
  );
}
