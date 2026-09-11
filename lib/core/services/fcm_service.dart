import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:seloasa_evidencias/features/notifications/data/notification_inbox_service.dart';
import 'package:seloasa_evidencias/features/notifications/domain/notification_item.dart';
import 'notification_service.dart';

/// Manejador global para mensajes en segundo plano (cuando la app está cerrada o en background)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    debugPrint('FCM Background message: ${message.messageId} - ${message.notification?.title}');

    // Guardar en la bandeja de entrada local
    final title = message.notification?.title ?? message.data['title'] ?? 'Aviso Seloasa';
    final body = message.notification?.body ?? message.data['body'] ?? '';
    final type = message.data['type']?.toString() ?? 'general';

    final inboxService = NotificationInboxService();
    await inboxService.saveNotification(
      NotificationItem(
        id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        body: body,
        timestamp: DateTime.now(),
        type: type,
        isRead: false,
        data: message.data,
      ),
    );
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

            // 3. Suscribirse a canales y temas clave de OneRoute / Seloasa
      final topics = [
        'kb_articles',
        'oneroute_general',
        'oneroute_urgent',
        'knowledge_base_updates',
        'dispersion_updates',
        'incident_alerts',
      ];
      for (final topic in topics) {
        try {
          await _messaging.subscribeToTopic(topic);
          debugPrint('FCM: Suscrito con exito al tema "$topic"');
        } catch (e) {
          debugPrint('FCM: Error al suscribirse al tema "$topic": $e');
        }
      }

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
    final type = message.data['type']?.toString().toLowerCase() ?? 'general';

    String defaultTitle = 'Notificación de Seloasa';
    String channelId = 'general_channel';
    String channelName = 'Avisos Generales';
    String channelDescription = 'Notificaciones operativas generales';

    if (type.contains('dispersion')) {
      defaultTitle = 'Dispersión Edenred';
      channelId = 'dispersion_channel';
      channelName = 'Dispersiones Edenred';
      channelDescription = 'Notificaciones de solicitudes y saldos Edenred';
    } else if (type.contains('kb') || type.contains('article')) {
      defaultTitle = 'Base de Conocimientos';
      channelId = 'kb_channel';
      channelName = 'Base de Conocimientos';
      channelDescription = 'Notificaciones de artículos y procedimientos';
    } else if (type.contains('incident')) {
      defaultTitle = 'Reporte de Incidentes';
      channelId = 'incident_channel';
      channelName = 'Incidentes';
      channelDescription = 'Alertas y seguimiento de incidentes en ruta';
    } else if (type.contains('route') || type.contains('checklist')) {
      defaultTitle = 'Rutas y Checklists';
      channelId = 'routes_channel';
      channelName = 'Rutas y Checklists';
      channelDescription = 'Asignación de rutas y recordatorios de inspección';
    }

    final title = notification?.title ?? message.data['title'] ?? defaultTitle;
    final body = notification?.body ?? message.data['body'] ?? 'Nuevo mensaje operativo disponible';
    final payload = jsonEncode(message.data);

    // Guardar en la bandeja local
    NotificationInboxService().saveNotification(
      NotificationItem(
        id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        body: body,
        timestamp: DateTime.now(),
        type: type,
        isRead: false,
        data: message.data,
      ),
    );

    NotificationService.showLocalNotification(
      id: message.hashCode,
      title: title,
      body: body,
      channelId: channelId,
      channelName: channelName,
      channelDescription: channelDescription,
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

    // 1. Si viene una ruta explícita en el payload (ej. "/dispersion-request" o "/settings")
    final explicitRoute = data['route']?.toString().trim();
    if (explicitRoute != null && explicitRoute.isNotEmpty) {
      try {
        context.push(explicitRoute);
        return;
      } catch (e) {
        debugPrint('Error navegando a ruta explícita ($explicitRoute): $e');
      }
    }

    // 2. Parseo inteligente por tipo de entidad y ID
    final type = (data['type']?.toString() ?? '').toLowerCase().trim();
    final id = data['id']?.toString() ??
        data['article_id']?.toString() ??
        data['articleId']?.toString() ??
        data['dispersion_id']?.toString();

    switch (type) {
      case 'dispersion':
      case 'dispersion_request':
      case 'edenred':
        context.push('/dispersion-request');
        break;

      case 'kb_article':
      case 'kb':
      case 'article':
      case 'knowledge_base':
        if (id != null && id.isNotEmpty) {
          context.push('/kb/article/$id');
        } else {
          context.push('/knowledge-base');
        }
        break;

      case 'incident':
      case 'incidents':
      case 'siniestro':
        context.push('/incident-report');
        break;

      case 'checklist':
        context.push('/checklist-detail');
        break;

      case 'checklist_history':
        context.push('/checklist-history');
        break;

      case 'route':
      case 'routes':
      case 'entrega':
      case 'os':
        context.push('/routes');
        break;

      case 'notifications':
      case 'notification':
        context.push('/notifications');
        break;

      default:
        // Si no coincide con ninguno pero viene un id de artículo legado
        if (id != null && id.isNotEmpty && (data.containsKey('article_id') || data.containsKey('articleId'))) {
          context.push('/kb/article/$id');
        } else {
          context.push('/notifications');
        }
        break;
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
