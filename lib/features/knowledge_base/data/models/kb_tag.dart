class KbTag {
  final int id;
  final String name;
  final String slug;
  final int usageCount;

  KbTag({
    required this.id,
    required this.name,
    required this.slug,
    this.usageCount = 0,
  });

  factory KbTag.fromJson(Map<String, dynamic> json) {
    return KbTag(
      id: _parseInt(json['ID'] ?? json['id']),
      name: (json['NAME'] ?? json['name'] ?? '').toString(),
      slug: (json['SLUG'] ?? json['slug'] ?? '').toString(),
      usageCount: _parseInt(json['USAGE_COUNT'] ?? json['usage_count'] ?? 0),
    );
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }
}
