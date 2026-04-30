import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seloasa_evidencias/ui/theme/app_colors.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  final List<Map<String, dynamic>> _notifications = const [];

  @override
  Widget build(BuildContext context) {
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
            Text("NOTIFICACIONES", 
              style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 1)),
          ],
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: _notifications.isEmpty
                ? _buildEmptyState(context)
                : ListView.builder(
                    padding: const EdgeInsets.all(24),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) => _NotificationCard(data: _notifications[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none_rounded, 
            size: 80, 
            color: isDark ? Colors.white10 : Colors.grey.shade300
          ),
          const SizedBox(height: 16),
          Text(
            "No tienes notificaciones", 
            style: GoogleFonts.poppins(
              fontSize: 16, 
              color: isDark ? Colors.white38 : Colors.grey.shade500, 
              fontWeight: FontWeight.w500
            )
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _NotificationCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final bool isUnread = !(data['isRead'] as bool);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUnread 
            ? (isDark ? AppColors.primaryGreen.withOpacity(0.15) : const Color(0xFFF0F7F1)) 
            : (isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF8F9FA)),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isUnread 
              ? AppColors.primaryGreen.withOpacity(0.2) 
              : (isDark ? Colors.white10 : AppColors.cardBorder)
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildIcon(),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        data['title'], 
                        style: GoogleFonts.poppins(
                          fontSize: 14, 
                          fontWeight: FontWeight.w700, 
                          color: isDark ? Colors.white : AppColors.textPrimary
                        )
                      ),
                    ),
                    Text(
                      data['time'], 
                      style: GoogleFonts.poppins(
                        fontSize: 11, 
                        color: isDark ? Colors.white38 : AppColors.textSecondary
                      )
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  data['body'], 
                  style: GoogleFonts.poppins(
                    fontSize: 12, 
                    color: isDark ? Colors.white70 : AppColors.textSecondary, 
                    height: 1.4
                  )
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIcon() {
    IconData icon;
    Color color;
    
    switch (data['type']) {
      case 'warning':
        icon = Icons.warning_amber_rounded;
        color = Colors.orange;
        break;
      case 'message':
        icon = Icons.chat_bubble_outline_rounded;
        color = Colors.blue;
        break;
      default:
        icon = Icons.info_outline_rounded;
        color = AppColors.primaryGreen;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
      child: Icon(icon, color: color, size: 20),
    );
  }
}
