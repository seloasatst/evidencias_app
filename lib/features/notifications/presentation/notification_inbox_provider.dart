import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/notification_inbox_service.dart';
import '../domain/notification_item.dart';

class NotificationInboxState {
  final List<NotificationItem> items;
  final bool isLoading;
  final String selectedFilter; // 'all', 'unread', 'dispersion', 'kb_article', 'incident', 'sos'

  const NotificationInboxState({
    this.items = const [],
    this.isLoading = false,
    this.selectedFilter = 'all',
  });

  int get unreadCount => items.where((n) => !n.isRead).length;

  List<NotificationItem> get filteredItems {
    if (selectedFilter == 'unread') {
      return items.where((n) => !n.isRead).toList();
    }
    if (selectedFilter == 'dispersion') {
      return items.where((n) => n.type.contains('dispersion')).toList();
    }
    if (selectedFilter == 'kb_article') {
      return items.where((n) => n.type.contains('kb') || n.type.contains('article')).toList();
    }
    if (selectedFilter == 'sos' || selectedFilter == 'incident') {
      return items.where((n) => n.type.contains('incident') || n.type.contains('sos')).toList();
    }
    return items;
  }

  NotificationInboxState copyWith({
    List<NotificationItem>? items,
    bool? isLoading,
    String? selectedFilter,
  }) {
    return NotificationInboxState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      selectedFilter: selectedFilter ?? this.selectedFilter,
    );
  }
}

class NotificationInboxNotifier extends StateNotifier<NotificationInboxState> {
  final NotificationInboxService _service;

  NotificationInboxNotifier(this._service) : super(const NotificationInboxState()) {
    loadNotifications();
  }

  Future<void> loadNotifications() async {
    state = state.copyWith(isLoading: true);
    final items = await _service.getNotifications();
    state = state.copyWith(items: items, isLoading: false);
  }

  void setFilter(String filter) {
    state = state.copyWith(selectedFilter: filter);
  }

  Future<void> addNotification({
    required String title,
    required String body,
    String type = 'general',
    Map<String, dynamic> data = const {},
  }) async {
    final newItem = NotificationItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      body: body,
      timestamp: DateTime.now(),
      type: type,
      isRead: false,
      data: data,
    );
    await _service.saveNotification(newItem);
    await loadNotifications();
  }

  Future<void> markAsRead(String id) async {
    await _service.markAsRead(id);
    await loadNotifications();
  }

  Future<void> markAllAsRead() async {
    await _service.markAllAsRead();
    await loadNotifications();
  }

  Future<void> deleteNotification(String id) async {
    await _service.deleteNotification(id);
    await loadNotifications();
  }

  Future<void> clearAll() async {
    await _service.clearAll();
    await loadNotifications();
  }
}

final notificationInboxServiceProvider = Provider<NotificationInboxService>((ref) {
  return NotificationInboxService();
});

final notificationInboxProvider =
    StateNotifierProvider<NotificationInboxNotifier, NotificationInboxState>((ref) {
  final service = ref.watch(notificationInboxServiceProvider);
  return NotificationInboxNotifier(service);
});
