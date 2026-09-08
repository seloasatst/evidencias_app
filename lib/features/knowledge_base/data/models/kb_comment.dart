class KbComment {
  final int id;
  final String userName;
  final String comment;
  final String createdAt;

  KbComment({
    required this.id,
    required this.userName,
    required this.comment,
    required this.createdAt,
  });

  factory KbComment.fromJson(Map<String, dynamic> json) {
    return KbComment(
      id: _parseInt(json['ID'] ?? json['id'] ?? json['comment_id']),
      userName: (json['USER_NAME'] ?? json['user_name'] ?? 'Usuario').toString(),
      comment: (json['COMMENT'] ?? json['comment'] ?? '').toString(),
      createdAt: (json['CREATED_AT'] ?? json['created_at'] ?? '').toString(),
    );
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }
}
