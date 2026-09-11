import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:seloasa_evidencias/ui/theme/app_colors.dart';
import '../../../core/services/fcm_service.dart';
import '../domain/notification_item.dart';
import 'notification_inbox_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inboxState = ref.watch(notificationInboxProvider);
    final inboxNotifier = ref.read(notificationInboxProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/seloasa_logo.png',
              height: 20,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Text(
              "NOTIFICACIONES",
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == 'mark_all_read') {
                inboxNotifier.markAllAsRead();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Todas las notificaciones marcadas como leídas'),
                    duration: Duration(seconds: 2),
                  ),
                );
              } else if (value == 'clear_all') {
                _confirmClearAll(context, inboxNotifier);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'mark_all_read',
                child: Row(
                  children: [
                    Icon(Icons.done_all_rounded, size: 20, color: AppColors.primaryGreen),
                    SizedBox(width: 10),
                    Text('Marcar todas leídas'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep_rounded, size: 20, color: Colors.redAccent),
                    SizedBox(width: 10),
                    Text('Limpiar historial'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(context, ref, inboxState, isDark),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => inboxNotifier.loadNotifications(),
              color: AppColors.accentOrange,
              child: inboxState.filteredItems.isEmpty
                  ? _buildEmptyState(context, inboxState.selectedFilter, isDark)
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: inboxState.filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = inboxState.filteredItems[index];
                        return Dismissible(
                          key: Key(item.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.shade400,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Icon(Icons.delete_outline, color: Colors.white, size: 24),
                                SizedBox(width: 8),
                                Text(
                                  'Eliminar',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          onDismissed: (_) {
                            inboxNotifier.deleteNotification(item.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Notificación eliminada'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          child: _NotificationCard(
                            item: item,
                            onTap: () {
                              if (!item.isRead) {
                                inboxNotifier.markAsRead(item.id);
                              }
                              // Ejecutar acción Deep Link asociada al payload
                              if (item.data.isNotEmpty) {
                                FcmService.handleLocalPayload(
                                  // Reenviar payload a FcmService para navegar
                                  _encodePayload(item),
                                );
                              }
                            },
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  static String _encodePayload(NotificationItem item) {
    final map = Map<String, dynamic>.from(item.data);
    if (!map.containsKey('type')) map['type'] = item.type;
    return Uri(queryParameters: map.map((k, v) => MapEntry(k, v.toString()))).query;
  }

  Widget _buildFilterBar(
      BuildContext context, WidgetRef ref, NotificationInboxState state, bool isDark) {
    final filters = [
      {'id': 'all', 'label': 'Todas (${state.items.length})'},
      {'id': 'unread', 'label': 'No leídas (${state.unreadCount})'},
      {'id': 'dispersion', 'label': 'Dispersiones'},
      {'id': 'kb_article', 'label': 'Artículos'},
      {'id': 'sos', 'label': 'Alertas / SOS'},
    ];

    return Container(
      height: 48,
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final f = filters[index];
          final isSelected = state.selectedFilter == f['id'];

          return ChoiceChip(
            label: Text(
              f['label']!,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white70 : AppColors.textPrimary),
              ),
            ),
            selected: isSelected,
            selectedColor: AppColors.accentOrange,
            backgroundColor: isDark ? const Color(0xFF242424) : const Color(0xFFF0F0F0),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            side: BorderSide.none,
            showCheckmark: false,
            onSelected: (_) {
              ref.read(notificationInboxProvider.notifier).setFilter(f['id']!);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String filter, bool isDark) {
    String title = "No tienes notificaciones";
    String subtitle = "Te avisaremos cuando haya novedades en tus rutas o dispersiones.";

    if (filter == 'unread') {
      title = "¡Estás al día!";
      subtitle = "No tienes notificaciones pendientes de leer.";
    } else if (filter == 'dispersion') {
      title = "Sin avisos de dispersión";
      subtitle = "Aquí aparecerán tus aprobaciones y recargas de Edenred.";
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_none_rounded,
                size: 64,
                color: isDark ? Colors.white30 : Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: isDark ? Colors.white38 : AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmClearAll(BuildContext context, NotificationInboxNotifier notifier) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '¿Limpiar historial?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Se eliminarán todas las notificaciones guardadas en este dispositivo.',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              notifier.clearAll();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Limpiar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final NotificationItem item;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isUnread = !item.isRead;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isUnread
            ? (isDark ? AppColors.accentOrange.withValues(alpha: 0.12) : const Color(0xFFFFF8F3))
            : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isUnread
              ? AppColors.accentOrange.withValues(alpha: 0.3)
              : (isDark ? Colors.white10 : AppColors.cardBorder),
          width: isUnread ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildIconBadge(item.type),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                if (isUnread) ...[
                                  Container(
                                    width: 8,
                                    height: 8,
                                    margin: const EdgeInsets.only(right: 6),
                                    decoration: const BoxDecoration(
                                      color: AppColors.accentOrange,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                                Expanded(
                                  child: Text(
                                    item.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: isUnread ? FontWeight.w800 : FontWeight.w600,
                                      color: isDark ? Colors.white : AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatTimestamp(item.timestamp),
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: isDark ? Colors.white38 : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          color: isDark ? Colors.white70 : AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                      if (item.data.isNotEmpty && item.data.containsKey('type')) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              'Toca para ver detalle →',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.accentOrange,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconBadge(String type) {
    IconData icon;
    Color color;

    final lower = type.toLowerCase();
    if (lower.contains('dispersion') || lower.contains('edenred')) {
      icon = Icons.credit_card_rounded;
      color = const Color(0xFF2E7D32); // Verde esmeralda
    } else if (lower.contains('kb') || lower.contains('article')) {
      icon = Icons.menu_book_rounded;
      color = const Color(0xFF1976D2); // Azul informativo
    } else if (lower.contains('incident') || lower.contains('warning')) {
      icon = Icons.warning_amber_rounded;
      color = const Color(0xFFF57C00); // Naranja alerta
    } else if (lower.contains('sos') || lower.contains('urgente') || lower.contains('emergency')) {
      icon = Icons.emergency_rounded;
      color = Colors.redAccent.shade700; // Rojo emergencia
    } else if (lower.contains('route') || lower.contains('checklist')) {
      icon = Icons.local_shipping_rounded;
      color = const Color(0xFF7B1FA2); // Morado transporte
    } else {
      icon = Icons.notifications_active_rounded;
      color = AppColors.primaryGreen;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) {
      return 'Ahora';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m';
    } else if (diff.inHours < 24 && dt.day == now.day) {
      return DateFormat('HH:mm').format(dt);
    } else if (diff.inDays < 7) {
      return DateFormat('E HH:mm', 'es').format(dt);
    } else {
      return DateFormat('d MMM', 'es').format(dt);
    }
  }
}
