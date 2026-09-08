import 'kb_attachment.dart';
import 'kb_comment.dart';
import 'kb_tag.dart';

class KbRelatedArticle {
  final int id;
  final String title;
  final String slug;

  KbRelatedArticle({
    required this.id,
    required this.title,
    required this.slug,
  });

  factory KbRelatedArticle.fromJson(Map<String, dynamic> json) {
    return KbRelatedArticle(
      id: KbArticle.parseInt(json['ID'] ?? json['id']),
      title: (json['TITLE'] ?? json['title'] ?? '').toString(),
      slug: (json['SLUG'] ?? json['slug'] ?? '').toString(),
    );
  }
}

class KbArticle {
  final int id;
  final int categoryId;
  final String categoryName;
  final String categorySlug;
  final String categoryIcon;
  final String title;
  final String slug;
  final String summary;
  final String? content;
  final bool isPinned;
  final int viewsCount;
  final int helpfulYes;
  final int helpfulNo;
  final String authorName;
  final String createdAt;
  final String updatedAt;
  final List<KbTag> tags;
  final List<KbAttachment> attachments;
  final List<KbRelatedArticle> related;
  final List<KbComment> comments;

  KbArticle({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.categorySlug,
    required this.categoryIcon,
    required this.title,
    required this.slug,
    required this.summary,
    this.content,
    required this.isPinned,
    required this.viewsCount,
    required this.helpfulYes,
    required this.helpfulNo,
    required this.authorName,
    required this.createdAt,
    required this.updatedAt,
    this.tags = const [],
    this.attachments = const [],
    this.related = const [],
    this.comments = const [],
  });

  factory KbArticle.fromJson(Map<String, dynamic> json) {
    List<KbTag> tagsList = [];
    if (json['TAGS'] is List) {
      tagsList = (json['TAGS'] as List)
          .map((e) => KbTag.fromJson(e as Map<String, dynamic>))
          .toList();
    } else if (json['tags'] is List) {
      tagsList = (json['tags'] as List)
          .map((e) => KbTag.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    List<KbAttachment> attachmentsList = [];
    if (json['ATTACHMENTS'] is List) {
      attachmentsList = (json['ATTACHMENTS'] as List)
          .map((e) => KbAttachment.fromJson(e as Map<String, dynamic>))
          .toList();
    } else if (json['attachments'] is List) {
      attachmentsList = (json['attachments'] as List)
          .map((e) => KbAttachment.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    List<KbRelatedArticle> relatedList = [];
    if (json['related'] is List) {
      relatedList = (json['related'] as List)
          .map((e) => KbRelatedArticle.fromJson(e as Map<String, dynamic>))
          .toList();
    } else if (json['RELATED'] is List) {
      relatedList = (json['RELATED'] as List)
          .map((e) => KbRelatedArticle.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    List<KbComment> commentsList = [];
    if (json['comments'] is List) {
      commentsList = (json['comments'] as List)
          .map((e) => KbComment.fromJson(e as Map<String, dynamic>))
          .toList();
    } else if (json['COMMENTS'] is List) {
      commentsList = (json['COMMENTS'] as List)
          .map((e) => KbComment.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return KbArticle(
      id: parseInt(json['ID'] ?? json['id']),
      categoryId: parseInt(json['CATEGORY_ID'] ?? json['category_id']),
      categoryName: (json['CATEGORY_NAME'] ?? json['category_name'] ?? '').toString(),
      categorySlug: (json['CATEGORY_SLUG'] ?? json['category_slug'] ?? '').toString(),
      categoryIcon: (json['CATEGORY_ICON'] ?? json['category_icon'] ?? 'ri-book-line').toString(),
      title: (json['TITLE'] ?? json['title'] ?? '').toString(),
      slug: (json['SLUG'] ?? json['slug'] ?? '').toString(),
      summary: (json['SUMMARY'] ?? json['summary'] ?? '').toString(),
      content: (json['CONTENT'] ?? json['content'])?.toString(),
      isPinned: parseBool(json['IS_PINNED'] ?? json['is_pinned']),
      viewsCount: parseInt(json['VIEWS_COUNT'] ?? json['views_count']),
      helpfulYes: parseInt(json['HELPFUL_YES'] ?? json['helpful_yes']),
      helpfulNo: parseInt(json['HELPFUL_NO'] ?? json['helpful_no']),
      authorName: (json['AUTHOR_NAME'] ?? json['author_name'] ?? 'Seloasa').toString(),
      createdAt: (json['CREATED_AT'] ?? json['created_at'] ?? '').toString(),
      updatedAt: (json['UPDATED_AT'] ?? json['updated_at'] ?? '').toString(),
      tags: tagsList,
      attachments: attachmentsList,
      related: relatedList,
      comments: commentsList,
    );
  }

  KbArticle copyWith({
    int? helpfulYes,
    int? helpfulNo,
    List<KbComment>? comments,
  }) {
    return KbArticle(
      id: id,
      categoryId: categoryId,
      categoryName: categoryName,
      categorySlug: categorySlug,
      categoryIcon: categoryIcon,
      title: title,
      slug: slug,
      summary: summary,
      content: content,
      isPinned: isPinned,
      viewsCount: viewsCount,
      helpfulYes: helpfulYes ?? this.helpfulYes,
      helpfulNo: helpfulNo ?? this.helpfulNo,
      authorName: authorName,
      createdAt: createdAt,
      updatedAt: updatedAt,
      tags: tags,
      attachments: attachments,
      related: related,
      comments: comments ?? this.comments,
    );
  }

  static int parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  static bool parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    final s = value.toString().trim().toLowerCase();
    return s == '1' || s == 'true' || s == 'yes';
  }
}

class KbPagination {
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  KbPagination({
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  factory KbPagination.fromJson(Map<String, dynamic> json) {
    return KbPagination(
      total: KbArticle.parseInt(json['total'] ?? json['TOTAL']),
      page: KbArticle.parseInt(json['page'] ?? json['PAGE'] ?? 1),
      limit: KbArticle.parseInt(json['limit'] ?? json['LIMIT'] ?? 15),
      totalPages: KbArticle.parseInt(json['total_pages'] ?? json['TOTAL_PAGES'] ?? 1),
    );
  }
}
