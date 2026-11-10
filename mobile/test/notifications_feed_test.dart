import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/providers/notifications_feed.dart';

Map<String, dynamic> row(String id, String user, {bool read = false}) => {
  'id': id,
  'user_id': user,
  'is_read': read,
  'created_at': '2026-11-10T10:00:00Z',
};

Future<void> tick() => Future<void>.delayed(Duration.zero);

void main() {
  test(
    'live insert/update/delete changes the inbox and unread count',
    () async {
      final source = StreamController<NotificationRows>();
      final feed = NotificationsFeed((_) => source.stream);
      feed.bindUser('a');
      await tick();
      source.add([row('1', 'a')]);
      await tick();
      expect(feed.unreadCount, 1);
      source.add([row('1', 'a', read: true), row('2', 'a')]);
      await tick();
      expect(feed.items, hasLength(2));
      expect(feed.unreadCount, 1);
      source.add([]);
      await tick();
      expect(feed.items, isEmpty);
      expect(feed.loading, isFalse);
      feed.dispose();
      await source.close();
    },
  );

  test(
    'account switch clears old rows and cancels previous subscription',
    () async {
      final a = StreamController<NotificationRows>();
      final b = StreamController<NotificationRows>();
      final owners = <String>[];
      final feed = NotificationsFeed((owner) {
        owners.add(owner);
        return owner == 'a' ? a.stream : b.stream;
      });
      feed.bindUser('a');
      await tick();
      a.add([row('1', 'a')]);
      await tick();
      feed.bindUser('b');
      expect(feed.items, isEmpty);
      await tick();
      expect(a.hasListener, isFalse);
      a.add([row('late', 'a')]);
      b.add([row('2', 'b'), row('foreign', 'a')]);
      await tick();
      expect(feed.items.map((item) => item['id']), ['2']);
      feed.bindUser('b');
      expect(owners, ['a', 'b']);
      feed.bindUser(null);
      expect(feed.items, isEmpty);
      await tick();
      expect(b.hasListener, isFalse);
      expect(feed.loading, isFalse);
      feed.dispose();
      await a.close();
      await b.close();
    },
  );

  test('refresh waits for new data and cancels its old stream', () async {
    final streams = <StreamController<NotificationRows>>[];
    final feed = NotificationsFeed((_) {
      final stream = StreamController<NotificationRows>();
      streams.add(stream);
      return stream.stream;
    });
    feed.bindUser('a');
    await tick();
    streams.first.add([]);
    await tick();
    var finished = false;
    final refreshing = feed.refresh().then((_) => finished = true);
    await tick();
    expect(streams.first.hasListener, isFalse);
    expect(finished, isFalse);
    streams.last.add([row('new', 'a')]);
    await refreshing;
    expect(feed.items.single['id'], 'new');
    feed.dispose();
    for (final stream in streams) {
      await stream.close();
    }
  });

  test('connection errors preserve rows and later events recover', () async {
    final source = StreamController<NotificationRows>();
    final feed = NotificationsFeed((_) => source.stream);
    feed.bindUser('a');
    await tick();
    source.add([row('1', 'a')]);
    await tick();
    source.addError(StateError('offline'));
    await tick();
    expect(feed.error, isNotNull);
    expect(feed.items, hasLength(1));
    source.add([row('1', 'a', read: true)]);
    await tick();
    expect(feed.error, isNull);
    expect(feed.unreadCount, 0);
    feed.dispose();
    await source.close();
  });

  test('dispose cancels stream and ignores pending events', () async {
    final source = StreamController<NotificationRows>();
    final feed = NotificationsFeed((_) => source.stream);
    feed.bindUser('a');
    await tick();
    feed.dispose();
    source.add([row('late', 'a')]);
    await tick();
    expect(source.hasListener, isFalse);
    expect(feed.items, isEmpty);
    await source.close();
  });
}
