class KbCategory {
  final int id;
  final int? parentId;
  final String name;
  final String slug;
  final String description;
  final String icon;
  final int orderIndex;
  final int articlesCount;

  KbCategory({
    required this.id,
    this.parentId,
    required this.name,
    required this.slug,
    required this.description,
    required this.icon,
    required this.orderIndex,
    required this.articlesCount,
  });

  factory KbCategory.fromJson(Map<String, dynamic> json) {
    return KbCategory(
      id: _parseInt(json['ID'] ?? json['id']),
      parentId: json['PARENT_ID'] != null || json['parent_id'] != null
          ? _tryParseInt(json['PARENT_ID'] ?? json['parent_id'])
          : null,
      name: (json['NAME'] ?? json['name'] ?? '').toString(),
      slug: (json['SLUG'] ?? json['slug'] ?? '').toString(),
      description: (json['DESCRIPTION'] ?? json['description'] ?? '').toString(),
      icon: (json['ICON'] ?? json['icon'] ?? 'ri-book-line').toString(),
      orderIndex: _parseInt(json['ORDER_INDEX'] ?? json['order_index'] ?? 0),
      articlesCount: _parseInt(json['ARTICLES_COUNT'] ?? json['articles_count'] ?? 0),
    );
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  static int? _tryParseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}
