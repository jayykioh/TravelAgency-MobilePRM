import 'dart:async';

import 'package:flutter/foundation.dart';

typedef NotificationRows = List<Map<String, dynamic>>;

/// Owns one account's subscription; late events from a previous account are ignored.
class NotificationsFeed extends ChangeNotifier {
  NotificationsFeed(this.watch);

  final Stream<NotificationRows> Function(String userId) watch;
  StreamSubscription<NotificationRows>? _subscription;
  Completer<void>? _firstData;
  int _generation = 0;
  bool _disposed = false;
  String? userId;
  NotificationRows items = [];
  bool loading = false;
  Object? error;

  int get unreadCount => items.where((row) => row['is_read'] != true).length;

  void bindUser(String? id) {
    if (id == userId) return;
    userId = id;
    items = [];
    unawaited(refresh());
  }

  Future<void> refresh() async {
    if (_disposed) return;
    final generation = ++_generation;
    final previous = _subscription;
    _subscription = null;
    _finishFirstData();
    final ready = Completer<void>();
    _firstData = ready;
    final owner = userId;
    loading = owner != null;
    error = null;
    notifyListeners();

    bool active() => !_disposed && generation == _generation;
    void fail(Object failure) {
      if (!active()) return;
      error = failure;
      loading = false;
      _finishFirstData();
      notifyListeners();
    }

    try {
      await previous?.cancel();
      if (!active()) return;
      if (owner == null) {
        _finishFirstData();
        return;
      }
      _subscription = watch(owner).listen(
        (rows) {
          if (!active()) return;
          items =
              rows
                  .where((row) => '${row['user_id']}' == owner)
                  .map((row) => Map<String, dynamic>.from(row))
                  .toList()
                ..sort(
                  (a, b) =>
                      '${b['created_at']}'.compareTo('${a['created_at']}'),
                );
          items = items.take(50).toList();
          loading = false;
          error = null;
          _finishFirstData();
          notifyListeners();
        },
        onError: (Object failure) => fail(failure),
        onDone: () => fail(StateError('Notification stream closed')),
      );
    } catch (failure) {
      fail(failure);
    }
    await ready.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () =>
          fail(TimeoutException('Notification connection timeout')),
    );
  }

  void _finishFirstData() {
    final ready = _firstData;
    _firstData = null;
    if (ready != null && !ready.isCompleted) ready.complete();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _finishFirstData();
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
