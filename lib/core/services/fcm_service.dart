import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'notification_service.dart';

/// Manejador global para mensajes en segundo plano (cuando la app está cerrada o en background)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    debugPrint('FCM Background message: ${message.messageId} - ${message.notification?.title}');
  } catch (e) {
    debugPrint('Error en firebaseMessagingBackgroundHandler: $e');
  }
}

class FcmService {
  FcmService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static bool _initialized = false;
  static GlobalKey<NavigatorState>? _navigatorKey;

  /// Inicializa Firebase Cloud Messaging
  static Future<void> init({GlobalKey<NavigatorState>? navigatorKey}) async {
    if (_initialized) return;
    _navigatorKey = navigatorKey;

    try {
      // 1. Solicitar permisos de notificación (Android 13+ / iOS)
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('FCM Permisos: ${settings.authorizationStatus}');

      // 2. Configurar presentación de notificaciones en primer plano para iOS / Android
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 3. Suscribirse automáticamente al Topic de Base de Conocimientos
      await _messaging.subscribeToTopic('kb_articles');
      debugPrint('FCM: Suscrito con éxito al tema "kb_articles"');

      // 4. Obtener y loguear token de dispositivo (opcional para debugging o envíos dirigidos)
      final token = await _messaging.getToken();
      debugPrint('FCM Token de dispositivo: $token');

      // 5. Escuchar mensajes cuando la app está en PRIMER PLANO
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('FCM mensaje recibido en primer plano: ${message.notification?.title}');
        _handleForegroundMessage(message);
      });

      // 6. Escuchar cuando el usuario TOCA una notificación (App estaba en SEGUNDO PLANO)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('FCM Notificación tocada desde segundo plano: ${message.data}');
        _handleNotificationClick(message.data);
      });

      // 7. Verificar si la app fue abierta desde estado TERMINADO mediante un tap en notificación
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('FCM App abierta desde notificación terminada: ${initialMessage.data}');
        Future.delayed(const Duration(milliseconds: 1000), () {
          _handleNotificationClick(initialMessage.data);
        });
      }

      _initialized = true;
    } catch (e) {
      debugPrint('Error inicializando FcmService: $e');
    }
  }

  /// Maneja la recepción de mensaje mientras la app está abierta (foreground)
  static void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] ?? 'Base de Conocimientos';
    final body = notification?.body ?? message.data['body'] ?? 'Nuevo contenido disponible';
    final payload = jsonEncode(message.data);

    NotificationService.showLocalNotification(
      id: message.hashCode,
      title: title,
      body: body,
      channelId: 'kb_channel',
      channelName: 'Base de Conocimientos',
      channelDescription: 'Notificaciones de artículos y procedimientos',
      payload: payload,
    );
  }

  /// Redirecciona al usuario a la pantalla correspondiente al tocar la notificación
  static void _handleNotificationClick(Map<String, dynamic> data) {
    final context = _navigatorKey?.currentContext;
    if (context == null) {
      debugPrint('No navigator context disponible para procesar tap en notificación');
      return;
    }

    final route = data['route']?.toString();
    final articleId = data['article_id']?.toString() ?? data['articleId']?.toString();

    if (route != null && route.isNotEmpty) {
      context.push(route);
    } else if (articleId != null && articleId.isNotEmpty) {
      context.push('/kb/article/$articleId');
    }
  }

  /// Maneja el payload recibido desde NotificationService cuando el usuario toca la notificación local
  static void handleLocalPayload(String? rawPayload) {
    if (rawPayload == null || rawPayload.isEmpty) return;
    try {
      final decoded = jsonDecode(rawPayload);
      if (decoded is Map<String, dynamic>) {
        _handleNotificationClick(decoded);
      }
    } catch (e) {
      debugPrint('Error parseando payload de notificación: $e');
    }
  }
}
