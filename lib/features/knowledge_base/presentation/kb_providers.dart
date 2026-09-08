import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/http_client_provider.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/kb_service.dart';
import '../data/models/kb_article.dart';
import '../data/models/kb_category.dart';
import '../data/models/kb_comment.dart';
import '../data/models/kb_tag.dart';

final kbServiceProvider = Provider<KbService>((ref) {
  final client = ref.watch(httpClientProvider);
  return KbService(client: client);
});

final kbCategoriesProvider = FutureProvider<List<KbCategory>>((ref) async {
  final service = ref.watch(kbServiceProvider);
  return await service.getCategories();
});

final kbTagsProvider = FutureProvider<List<KbTag>>((ref) async {
  final service = ref.watch(kbServiceProvider);
  return await service.getTags();
});

class KbFilterState {
  final String search;
  final int? selectedCategoryId;
  final String? selectedTag;
  final String? selectedSort; // null/recent, 'views', 'popular', 'title'
  final int page;

  KbFilterState({
    this.search = '',
    this.selectedCategoryId,
    this.selectedTag,
    this.selectedSort,
    this.page = 1,
  });

  KbFilterState copyWith({
    String? search,
    int? selectedCategoryId,
    bool clearCategory = false,
    String? selectedTag,
    bool clearTag = false,
    String? selectedSort,
    bool clearSort = false,
    int? page,
  }) {
    return KbFilterState(
      search: search ?? this.search,
      selectedCategoryId: clearCategory ? null : (selectedCategoryId ?? this.selectedCategoryId),
      selectedTag: clearTag ? null : (selectedTag ?? this.selectedTag),
      selectedSort: clearSort ? null : (selectedSort ?? this.selectedSort),
      page: page ?? this.page,
    );
  }
}

class KbArticlesState {
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final List<KbArticle> articles;
  final KbPagination? pagination;
  final KbFilterState filter;

  KbArticlesState({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.articles = const [],
    this.pagination,
    required this.filter,
  });

  bool get hasMore =>
      pagination != null && pagination!.page < pagination!.totalPages;

  KbArticlesState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool clearError = false,
    List<KbArticle>? articles,
    KbPagination? pagination,
    KbFilterState? filter,
  }) {
    return KbArticlesState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      articles: articles ?? this.articles,
      pagination: pagination ?? this.pagination,
      filter: filter ?? this.filter,
    );
  }
}

class KbArticlesNotifier extends StateNotifier<KbArticlesState> {
  final KbService _service;

  KbArticlesNotifier(this._service)
      : super(KbArticlesState(filter: KbFilterState())) {
    fetchArticles();
  }

  Future<void> fetchArticles({bool resetPage = true}) async {
    if (resetPage) {
      state = state.copyWith(
        isLoading: true,
        clearError: true,
        filter: state.filter.copyWith(page: 1),
      );
    } else {
      if (state.isLoadingMore || !state.hasMore) return;
      state = state.copyWith(isLoadingMore: true, clearError: true);
    }

    try {
      final response = await _service.getArticles(
        search: state.filter.search,
        categoryId: state.filter.selectedCategoryId,
        tag: state.filter.selectedTag,
        sort: state.filter.selectedSort,
        page: state.filter.page,
      );

      final combined = resetPage
          ? response.articles
          : [...state.articles, ...response.articles];

      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        articles: combined,
        pagination: response.pagination,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  void setSearch(String query) {
    if (state.filter.search == query) return;
    state = state.copyWith(
      filter: state.filter.copyWith(search: query, page: 1),
    );
    fetchArticles(resetPage: true);
  }

  void selectCategory(int? categoryId) {
    if (state.filter.selectedCategoryId == categoryId) {
      // Toggle off if already selected
      state = state.copyWith(
        filter: state.filter.copyWith(clearCategory: true, page: 1),
      );
    } else {
      state = state.copyWith(
        filter: state.filter.copyWith(
          selectedCategoryId: categoryId,
          clearCategory: categoryId == null,
          page: 1,
        ),
      );
    }
    fetchArticles(resetPage: true);
  }

  void selectTag(String? tag) {
    if (state.filter.selectedTag == tag) {
      state = state.copyWith(
        filter: state.filter.copyWith(clearTag: true, page: 1),
      );
    } else {
      state = state.copyWith(
        filter: state.filter.copyWith(
          selectedTag: tag,
          clearTag: tag == null,
          page: 1,
        ),
      );
    }
    fetchArticles(resetPage: true);
  }

  void setSort(String? sort) {
    if (state.filter.selectedSort == sort) return;
    state = state.copyWith(
      filter: state.filter.copyWith(
        selectedSort: sort,
        clearSort: sort == null,
        page: 1,
      ),
    );
    fetchArticles(resetPage: true);
  }

  void loadNextPage() {
    if (!state.hasMore || state.isLoadingMore || state.isLoading) return;
    state = state.copyWith(
      filter: state.filter.copyWith(page: state.filter.page + 1),
    );
    fetchArticles(resetPage: false);
  }
}

final kbArticlesProvider =
    StateNotifierProvider<KbArticlesNotifier, KbArticlesState>((ref) {
  final service = ref.watch(kbServiceProvider);
  return KbArticlesNotifier(service);
});

/// Article Detail Provider
final kbArticleDetailProvider =
    FutureProvider.family<KbArticle, String>((ref, idOrSlug) async {
  final service = ref.watch(kbServiceProvider);
  return await service.getArticleDetail(idOrSlug);
});

/// Article Actions Notifier (Feedback and Comments)
class ArticleActionsController {
  final Ref ref;

  ArticleActionsController(this.ref);

  Future<void> sendFeedback({
    required int articleId,
    required bool isHelpful,
    String? comment,
  }) async {
    final service = ref.read(kbServiceProvider);
    final auth = ref.read(authStateProvider);
    final userCode = auth.user?.username ?? auth.user?.name ?? 'USER';
    final userName = auth.user?.name ?? auth.user?.username ?? 'Operador';

    await service.sendFeedback(
      articleId,
      isHelpful: isHelpful,
      comment: comment,
      userCode: userCode,
      userName: userName,
    );
  }

  Future<KbComment> addComment({
    required int articleId,
    required String comment,
  }) async {
    final service = ref.read(kbServiceProvider);
    final auth = ref.read(authStateProvider);
    final userCode = auth.user?.username ?? auth.user?.name ?? 'USER';
    final userName = auth.user?.name ?? auth.user?.username ?? 'Operador';

    final newComment = await service.postComment(
      articleId,
      comment: comment,
      userCode: userCode,
      userName: userName,
    );

    return newComment;
  }
}

final articleActionsProvider = Provider<ArticleActionsController>((ref) {
  return ArticleActionsController(ref);
});
