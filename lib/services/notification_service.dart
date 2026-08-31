import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'socket_service.dart';

/// Owns the unread-notification count that drives the badge on the
/// Notifications tab.
///
/// The count is seeded from the API and then kept current by the
/// `notification:new` socket event, so a badge appears the moment someone
/// invites, likes, comments, or follows — without polling.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  /// Fires when a new notification arrives while the app is open, so an open
  /// notifications list can refresh itself.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  bool _listening = false;

  /// Starts listening for pushes and loads the current count.
  Future<void> start() async {
    if (!_listening) {
      _listening = true;
      SocketService().connect();
      SocketService().on('notification:new', _onNotification);
    }
    await refresh();
  }

  void _onNotification(dynamic data) {
    if (data is! Map) return;
    final count = (data['unreadCount'] as num?)?.toInt();
    if (count != null) {
      unreadCount.value = count;
    } else {
      unreadCount.value = unreadCount.value + 1;
    }
    revision.value++;
  }

  /// Re-reads the authoritative unread total from the API.
  Future<void> refresh() async {
    final payload = await ApiService.getNotifications();
    final count = (payload['unreadCount'] as num?)?.toInt();
    if (count != null) unreadCount.value = count;
  }

  /// Optimistically clears the badge after the user reads everything.
  void markAllReadLocally() => unreadCount.value = 0;

  /// Optimistically decrements after a single notification is read.
  void decrement() {
    if (unreadCount.value > 0) unreadCount.value = unreadCount.value - 1;
  }

  void dispose() {
    SocketService().off('notification:new');
    _listening = false;
  }
}
