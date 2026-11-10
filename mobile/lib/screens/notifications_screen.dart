import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/hotel_state.dart';
import '../providers/notifications_feed.dart';

/// Port of NotificationDrawer: tabs, unread state and mark-as-read actions.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with WidgetsBindingObserver {
  String filter = 'all';
  late final NotificationsFeed feed;
  bool updating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    feed = NotificationsFeed(
      (userId) => context.read<HotelState>().service.watchNotifications(userId),
    )..addListener(_feedChanged);
  }

  void _feedChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = context.watch<HotelState>();
    feed.bindUser(state.currentUser?.id);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && feed.userId != null) {
      unawaited(feed.refresh());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    feed.removeListener(_feedChanged);
    feed.dispose();
    super.dispose();
  }

  Future<void> markRead([String? id]) async {
    final owner = feed.userId;
    if (updating || owner == null) return;
    setState(() => updating = true);
    try {
      final service = context.read<HotelState>().service;
      if (id == null) {
        await service.markAllNotificationsRead();
      } else {
        await service.markNotificationRead(id);
      }
      if (mounted && owner == feed.userId) await feed.refresh();
    } catch (_) {
      if (mounted && owner == feed.userId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chưa đánh dấu được đã đọc. Hãy thử lại.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => updating = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('Thông báo (${feed.unreadCount} chưa đọc)'),
      actions: [
        IconButton(
          tooltip: 'Đánh dấu tất cả đã đọc',
          onPressed: updating || feed.unreadCount == 0
              ? null
              : () => markRead(),
          icon: const Icon(Icons.done_all),
        ),
      ],
    ),
    body: Builder(
      builder: (context) {
        if (feed.userId == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Đăng nhập để xem thông báo của bạn.'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () =>
                      context.read<HotelState>().requireAuth(context),
                  child: const Text('Đăng nhập'),
                ),
              ],
            ),
          );
        }
        if (feed.loading && feed.items.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (feed.error != null && feed.items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Chưa kết nối được thông báo. Kiểm tra mạng rồi thử lại.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: feed.refresh,
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            ),
          );
        }
        final all = feed.items;
        final visible = all
            .where(
              (item) =>
                  filter == 'all' ||
                  (filter == 'unread'
                      ? item['is_read'] != true
                      : item['type'] == filter),
            )
            .toList();
        return Column(
          children: [
            if (feed.error != null)
              MaterialBanner(
                content: const Text(
                  'Kết nối bị gián đoạn. Danh sách có thể chưa cập nhật.',
                ),
                actions: [
                  TextButton(
                    onPressed: feed.refresh,
                    child: const Text('Kết nối lại'),
                  ),
                ],
              ),
            if (feed.loading) const LinearProgressIndicator(),
            SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                children: [
                  for (final value in [
                    'all',
                    'unread',
                    'reward',
                    'booking',
                    'system',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(
                          const {
                            'all': 'Tất cả',
                            'unread': 'Chưa đọc',
                            'reward': 'Phần thưởng',
                            'booking': 'Đặt phòng',
                            'system': 'Hệ thống',
                          }[value]!,
                        ),
                        selected: filter == value,
                        onSelected: (_) => setState(() => filter = value),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: feed.refresh,
                child: visible.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 80),
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.inbox_outlined, size: 56),
                                Text('Chưa có thông báo trong mục này'),
                              ],
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                        itemCount: visible.length,
                        itemBuilder: (context, index) {
                          final item = visible[index];
                          final unread = item['is_read'] != true;
                          final type = '${item['type'] ?? 'system'}';
                          return Card(
                            color: unread
                                ? const Color(0xFFFFF7ED)
                                : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(14),
                              leading: CircleAvatar(
                                backgroundColor: type == 'booking'
                                    ? const Color(0xFFDBEAFE)
                                    : const Color(0xFFFFEDD5),
                                child: Icon(
                                  type == 'booking'
                                      ? Icons.calendar_month
                                      : Icons.notifications_outlined,
                                ),
                              ),
                              title: Text(
                                '${item['title'] ?? 'Thông báo'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Text(
                                '${item['message'] ?? item['content'] ?? ''}\n${item['created_at'] ?? ''}',
                              ),
                              trailing: unread
                                  ? const Icon(
                                      Icons.circle,
                                      size: 10,
                                      color: Color(0xFFFF5E1F),
                                    )
                                  : null,
                              onTap: updating || !unread
                                  ? null
                                  : () => markRead('${item['id']}'),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
