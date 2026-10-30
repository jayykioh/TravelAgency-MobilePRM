import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/hotel_state.dart';

/// Port of NotificationDrawer: tabs, unread state and mark-as-read actions.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String filter = 'all';
  Future<List<Map<String, dynamic>>>? request;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    request ??= context.read<HotelState>().service.notifications();
  }

  void reload() => setState(
    () => request = context.read<HotelState>().service.notifications(),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Notifications'),
      actions: [
        IconButton(
          tooltip: 'Đánh dấu tất cả đã đọc',
          onPressed: () async {
            try {
              await context
                  .read<HotelState>()
                  .service
                  .markAllNotificationsRead();
              reload();
            } catch (error) {
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('$error')));
              }
            }
          },
          icon: const Icon(Icons.done_all),
        ),
      ],
    ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: request,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Không đọc được notifications qua session hiện tại.\n${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: reload, child: const Text('Thử lại')),
                ],
              ),
            ),
          );
        }
        final all = snapshot.data ?? [];
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
                        label: Text(value.toUpperCase()),
                        selected: filter == value,
                        onSelected: (_) => setState(() => filter = value),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: visible.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inbox_outlined, size: 56),
                          Text('No notifications found'),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async => reload(),
                      child: ListView.builder(
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
                              onTap: () async {
                                await context
                                    .read<HotelState>()
                                    .service
                                    .markNotificationRead('${item['id']}');
                                reload();
                              },
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
