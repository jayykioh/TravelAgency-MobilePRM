import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/providers/hotel_state.dart';
import 'package:mobile/providers/notifications_feed.dart';
import 'package:mobile/screens/notifications_screen.dart';
import 'package:mobile/services/hotel_service.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Client extends Fake implements SupabaseClient {}

class _Service extends HotelService {
  _Service() : super(_Client());
  final sources = <String, StreamController<NotificationRows>>{};
  final marked = <String>[];
  bool failUpdate = false;

  @override
  Stream<NotificationRows> watchNotifications(String userId) =>
      sources.putIfAbsent(userId, () => StreamController.broadcast()).stream;

  @override
  Future<void> markNotificationRead(String id) async {
    if (failUpdate) throw StateError('denied');
    marked.add(id);
  }

  @override
  Future<void> markAllNotificationsRead() async => marked.add('all');
}

class _State extends HotelState {
  _State(_Service service) : super(service: service);
  String? id = 'a';
  @override
  User? get currentUser => id == null
      ? null
      : User(
          id: id!,
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: '2026-11-10T00:00:00Z',
        );
  void signOut() {
    id = null;
    notifyListeners();
  }
}

NotificationRows rows({bool read = false}) => [
  {
    'id': '1',
    'user_id': 'a',
    'title': 'Đặt phòng mới',
    'message': 'Đã xác nhận',
    'type': 'booking',
    'is_read': read,
    'created_at': '2026-11-10T10:00:00Z',
  },
];

void main() {
  testWidgets(
    'live data and read action update UI; sign-out removes old inbox',
    (tester) async {
      final service = _Service();
      final state = _State(service);
      await tester.pumpWidget(
        ChangeNotifierProvider<HotelState>.value(
          value: state,
          child: const MaterialApp(home: NotificationsScreen()),
        ),
      );
      await tester.pump();
      service.sources['a']!.add(rows());
      await tester.pump();
      expect(find.text('Đặt phòng mới'), findsOneWidget);
      expect(find.text('Thông báo (1 chưa đọc)'), findsOneWidget);
      await tester.tap(find.text('Đặt phòng mới'));
      await tester.pump();
      expect(service.marked, ['1']);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      expect(service.sources['a']!.hasListener, isTrue);
      service.sources['a']!.add(rows(read: true));
      await tester.pump();
      await tester.pump();
      expect(find.text('Thông báo (0 chưa đọc)'), findsOneWidget);
      state.signOut();
      await tester.pump();
      expect(find.text('Đặt phòng mới'), findsNothing);
      expect(find.text('Đăng nhập để xem thông báo của bạn.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
      for (final source in service.sources.values) {
        await source.close();
      }
    },
  );

  testWidgets('read failure is visible and retains the unread row', (
    tester,
  ) async {
    final service = _Service()..failUpdate = true;
    final state = _State(service);
    await tester.pumpWidget(
      ChangeNotifierProvider<HotelState>.value(
        value: state,
        child: const MaterialApp(home: NotificationsScreen()),
      ),
    );
    await tester.pump();
    service.sources['a']!.add(rows());
    await tester.pump();
    await tester.tap(find.text('Đặt phòng mới'));
    await tester.pump();
    expect(
      find.text('Chưa đánh dấu được đã đọc. Hãy thử lại.'),
      findsOneWidget,
    );
    expect(find.text('Thông báo (1 chưa đọc)'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
    for (final source in service.sources.values) {
      await source.close();
    }
  });
}
