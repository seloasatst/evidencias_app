import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../domain/notification_item.dart';

class NotificationInboxService {
  final _storage = const FlutterSecureStorage();
  static const _storageKey = 'seloasa_notifications_inbox_v1';
  static const int _maxSavedNotifications = 60;

  Future<List<NotificationItem>> getNotifications() async {
    try {
      final raw = await _storage.read(key: _storageKey);
      if (raw == null || raw.isEmpty) return [];

      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final list = decoded
            .map((item) => NotificationItem.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
        // Ordenar más recientes primero
        list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        return list;
      }
    } catch (e) {
      debugPrint('Error leyendo historial de notificaciones: $e');
    }
    return [];
  }

  Future<void> saveNotification(NotificationItem item) async {
    try {
      final currentList = await getNotifications();
      // Eliminar duplicado si ya existe por ID
      currentList.removeWhere((n) => n.id == item.id);
      currentList.insert(0, item);

      // Limitar a máximo 60 notificaciones para no saturar memoria
      if (currentList.length > _maxSavedNotifications) {
        currentList.removeRange(_maxSavedNotifications, currentList.length);
      }

      final encoded = jsonEncode(currentList.map((e) => e.toJson()).toList());
      await _storage.write(key: _storageKey, value: encoded);
    } catch (e) {
      debugPrint('Error guardando notificación en historial: $e');
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      final currentList = await getNotifications();
      final index = currentList.indexWhere((n) => n.id == id);
      if (index != -1) {
        currentList[index] = currentList[index].copyWith(isRead: true);
        final encoded = jsonEncode(currentList.map((e) => e.toJson()).toList());
        await _storage.write(key: _storageKey, value: encoded);
      }
    } catch (e) {
      debugPrint('Error marcando notificación como leída: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final currentList = await getNotifications();
      final updated = currentList.map((n) => n.copyWith(isRead: true)).toList();
      final encoded = jsonEncode(updated.map((e) => e.toJson()).toList());
      await _storage.write(key: _storageKey, value: encoded);
    } catch (e) {
      debugPrint('Error marcando todas las notificaciones como leídas: $e');
    }
  }

  Future<void> deleteNotification(String id) async {
    try {
      final currentList = await getNotifications();
      currentList.removeWhere((n) => n.id == id);
      final encoded = jsonEncode(currentList.map((e) => e.toJson()).toList());
      await _storage.write(key: _storageKey, value: encoded);
    } catch (e) {
      debugPrint('Error eliminando notificación: $e');
    }
  }

  Future<void> clearAll() async {
    try {
      await _storage.delete(key: _storageKey);
    } catch (e) {
      debugPrint('Error limpiando historial de notificaciones: $e');
    }
  }

  Future<int> getUnreadCount() async {
    final list = await getNotifications();
    return list.where((n) => !n.isRead).length;
  }
}
