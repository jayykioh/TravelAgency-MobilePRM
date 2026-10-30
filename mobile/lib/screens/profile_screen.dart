import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/hotel_state.dart';
import 'auth_screen.dart';

/// Flutter port of the React ProfileHero and SettingsList experience.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<Map<String, dynamic>?>? profile;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    profile ??= context.read<HotelState>().service.currentProfile();
  }

  void reload() => setState(() {
    profile = context.read<HotelState>().service.currentProfile();
  });

  @override
  Widget build(BuildContext context) {
    final service = context.read<HotelState>().service;
    final user = service.auth.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Hồ sơ')),
        body: Center(
          child: FilledButton.icon(
            onPressed: () async {
              await Navigator.push<void>(
                context,
                MaterialPageRoute(builder: (_) => const AuthScreen()),
              );
              reload();
            },
            icon: const Icon(Icons.login),
            label: const Text('Đăng nhập / Đăng ký'),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Hồ sơ')),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: profile,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ProfileError(error: snapshot.error, onRetry: reload);
          }
          final data = snapshot.data ?? <String, dynamic>{};
          final name =
              '${data['name'] ?? user.email?.split('@').first ?? 'Traveller'}';
          return RefreshIndicator(
            onRefresh: () async => reload(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFFFF5E1F), Color(0xFFF59E0B)],
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 43,
                        backgroundColor: const Color(0xFFFFF7ED),
                        child: Text(
                          name.isEmpty ? 'T' : name[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFFF5E1F),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 27,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            '${user.email}',
                            style: const TextStyle(color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 8),
                          Chip(
                            label: Text(
                              '${data['membership_tier'] ?? 'MEMBER'}',
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: () => _edit(data),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ],
                ),
                if ('${data['bio'] ?? ''}'.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text('${data['bio']}', style: const TextStyle(height: 1.5)),
                ],
                const SizedBox(height: 28),
                const Text(
                  'My Activity',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _activity(
                      Icons.calendar_month,
                      'Bookings',
                      const Color(0xFFE0F2FE),
                    ),
                    _activity(
                      Icons.favorite_outline,
                      'Saved',
                      const Color(0xFFFCE7F3),
                    ),
                    _activity(
                      Icons.card_giftcard,
                      'Rewards',
                      const Color(0xFFD1FAE5),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    children: [
                      for (final item in const [
                        (Icons.settings_outlined, 'Account Settings'),
                        (Icons.shield_outlined, 'Privacy & Security'),
                        (Icons.language, 'Language & Region'),
                        (Icons.help_outline, 'Help & Support'),
                      ])
                        ListTile(
                          leading: Icon(item.$1),
                          title: Text(item.$2),
                          trailing: const Icon(Icons.chevron_right),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () async {
                    await service.auth.signOut();
                    if (mounted) setState(() {});
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Đăng xuất'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _activity(IconData icon, String label, Color color) => Expanded(
    child: Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Column(
        children: [
          Container(
            height: 76,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Center(child: Icon(icon, size: 31)),
          ),
          const SizedBox(height: 7),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ),
  );

  Future<void> _edit(Map<String, dynamic> current) async {
    final name = TextEditingController(text: '${current['name'] ?? ''}');
    final bio = TextEditingController(text: '${current['bio'] ?? ''}');
    final city = TextEditingController(text: '${current['city'] ?? ''}');
    final phone = TextEditingController(
      text: '${current['phone_number'] ?? ''}',
    );
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chỉnh sửa hồ sơ'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Tên'),
              ),
              TextField(
                controller: bio,
                decoration: const InputDecoration(labelText: 'Giới thiệu'),
              ),
              TextField(
                controller: city,
                decoration: const InputDecoration(labelText: 'Thành phố'),
              ),
              TextField(
                controller: phone,
                decoration: const InputDecoration(labelText: 'Số điện thoại'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    if (save != true || !mounted) return;
    try {
      await context.read<HotelState>().service.updateCurrentProfile({
        'name': name.text.trim(),
        'bio': bio.text.trim(),
        'city': city.text.trim(),
        'phone_number': phone.text.trim(),
      });
      reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể cập nhật hồ sơ: $error')),
        );
      }
    }
  }
}

class _ProfileError extends StatelessWidget {
  const _ProfileError({required this.error, required this.onRetry});
  final Object? error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.person_off_outlined, size: 56),
          const SizedBox(height: 12),
          Text(
            'Không đọc được hồ sơ qua quyền hiện tại.\n$error',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    ),
  );
}
