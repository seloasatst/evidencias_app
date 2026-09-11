class NotificationItem {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final String type; // 'dispersion', 'kb_article', 'incident', 'route', 'sos', 'general'
  final bool isRead;
  final Map<String, dynamic> data;

  const NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.type = 'general',
    this.isRead = false,
    this.data = const {},
  });

  NotificationItem copyWith({
    String? id,
    String? title,
    String? body,
    DateTime? timestamp,
    String? type,
    bool? isRead,
    Map<String, dynamic>? data,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      data: data ?? this.data,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'timestamp': timestamp.toIso8601String(),
      'type': type,
      'isRead': isRead,
      'data': data,
    };
  }

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title']?.toString() ?? 'Aviso Seloasa',
      body: json['body']?.toString() ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      type: json['type']?.toString() ?? 'general',
      isRead: json['isRead'] as bool? ?? false,
      data: json['data'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['data'] as Map)
          : {},
    );
  }
}
