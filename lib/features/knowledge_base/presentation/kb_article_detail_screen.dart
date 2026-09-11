import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/services/screen_security_service.dart';
import '../../../ui/theme/app_colors.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/models/kb_article.dart';
import '../data/models/kb_attachment.dart';
import '../data/models/kb_comment.dart';
import 'kb_providers.dart';
import 'widgets/kb_document_preview_dialog.dart';
import 'widgets/kb_html_content.dart';
import 'widgets/kb_icon_helper.dart';

class KbArticleDetailScreen extends ConsumerStatefulWidget {
  final String idOrSlug;

  const KbArticleDetailScreen({super.key, required this.idOrSlug});

  @override
  ConsumerState<KbArticleDetailScreen> createState() => _KbArticleDetailScreenState();
}

class _KbArticleDetailScreenState extends ConsumerState<KbArticleDetailScreen> {
  bool? _submittedFeedback; // true (yes), false (no), null
  bool _isSubmittingFeedback = false;
  final List<KbComment> _localComments = [];
  bool _commentsInitialized = false;
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _headingKeys = {};

  @override
  void initState() {
    super.initState();
    ScreenSecurityService.enableSecure();
  }

  @override
  void dispose() {
    ScreenSecurityService.disableSecure();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final articleAsync = ref.watch(kbArticleDetailProvider(widget.idOrSlug));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "ARTÍCULO DE AYUDA",
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        centerTitle: true,
      ),
      body: articleAsync.when(
        data: (article) {
          if (!_commentsInitialized) {
            _localComments.clear();
            _localComments.addAll(article.comments);
            _commentsInitialized = true;
          }

          final headings = KbHtmlContent.extractHeadings(article.content);
          for (final h in headings) {
            _headingKeys.putIfAbsent(h, () => GlobalKey());
          }

          return SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  // Category & Date Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              KbIconHelper.getIcon(article.categoryIcon),
                              size: 13,
                              color: AppColors.primaryGreen,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              article.categoryName.toUpperCase(),
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.greenAccent : AppColors.primaryGreen,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.visibility_outlined,
                            size: 14,
                            color: isDark ? Colors.white54 : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "${article.viewsCount} vistas",
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: isDark ? Colors.white54 : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Title
                  Text(
                    article.title,
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Author & Date metadata
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.accentOrange.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person_rounded,
                          size: 14,
                          color: AppColors.accentOrange,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                article.authorName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white70 : AppColors.textPrimary,
                                ),
                              ),
                            ),
                            if (article.createdAt.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                child: Text(
                                  "•",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white38 : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              Text(
                                _formatArticleDate(article.createdAt),
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.white38 : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Tags
                  if (article.tags.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: article.tags.map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF252525) : const Color(0xFFEEEEEE),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            "#${tag.name}",
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white60 : AppColors.textSecondary,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  const Divider(height: 28),

                  // Summary Callout Box
                  if (article.summary.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF9F9F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.white10 : AppColors.cardBorder,
                        ),
                      ),
                      child: Text(
                        article.summary,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          fontStyle: FontStyle.italic,
                          color: isDark ? Colors.white70 : AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Content HTML / Body
                  if (article.content != null && article.content!.isNotEmpty)
                    KbHtmlContent(
                      html: article.content!,
                      headingKeys: _headingKeys,
                      onHeadingTap: _scrollToHeading,
                    )
                  else
                    Text(
                      "No hay contenido disponible para esta guía.",
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: isDark ? Colors.white60 : AppColors.textSecondary,
                      ),
                    ),

                  // Attachments
                  if (article.attachments.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildSectionHeader("Archivos Adjuntos"),
                    const SizedBox(height: 10),
                    ...article.attachments.map((att) => _buildAttachmentTile(att, isDark)),
                  ],

                  const Divider(height: 36),

                  // Feedback Section
                  _buildFeedbackSection(article, isDark),

                  // Related Articles
                  if (article.related.isNotEmpty) ...[
                    const Divider(height: 36),
                    _buildSectionHeader("Artículos Relacionados"),
                    const SizedBox(height: 12),
                    ...article.related.map((rel) => _buildRelatedArticleTile(rel, isDark)),
                  ],

                  // Comments Section
                  const Divider(height: 36),
                  _buildCommentsSection(article, isDark),

                  const SizedBox(height: 40),
                ],
              ),
            );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accentOrange),
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
                const SizedBox(height: 12),
                Text(
                  "Error al abrir artículo",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  err.toString().replaceAll('Exception: ', ''),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.refresh(kbArticleDetailProvider(widget.idOrSlug)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Reintentar"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: AppColors.accentOrange,
      ),
    );
  }

  Widget _buildAttachmentTile(KbAttachment att, bool isDark) {
    IconData fileIcon = Icons.insert_drive_file_outlined;
    Color iconColor = AppColors.primaryGreen;
    String badgeText = "DOC";

    final name = att.displayName.toLowerCase();
    final mime = att.mimeType.toLowerCase();

    if (att.isPdf) {
      fileIcon = Icons.picture_as_pdf_outlined;
      iconColor = Colors.redAccent;
      badgeText = "PDF";
    } else if (att.isImage) {
      fileIcon = Icons.image_outlined;
      iconColor = Colors.blueAccent;
      badgeText = "IMG";
    } else if (name.endsWith('.xls') || name.endsWith('.xlsx') || mime.contains('spreadsheet') || mime.contains('excel')) {
      fileIcon = Icons.table_chart_outlined;
      iconColor = Colors.green;
      badgeText = "XLS";
    } else if (name.endsWith('.doc') || name.endsWith('.docx') || mime.contains('word')) {
      fileIcon = Icons.description_outlined;
      iconColor = Colors.indigo;
      badgeText = "DOC";
    } else if (name.endsWith('.zip') || name.endsWith('.rar')) {
      fileIcon = Icons.folder_zip_outlined;
      iconColor = Colors.amber.shade800;
      badgeText = "ZIP";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : AppColors.cardBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => KbDocumentPreviewDialog.show(context, att),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(fileIcon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      att.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: iconColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badgeText,
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: iconColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          att.formattedSize,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: isDark ? Colors.white54 : AppColors.textSecondary,
                          ),
                        ),
                        if (!att.isDownloadable) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              "SOLO LECTURA",
                              style: GoogleFonts.poppins(
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                color: Colors.amber.shade800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: () => KbDocumentPreviewDialog.show(context, att),
                icon: const Icon(Icons.visibility_rounded, size: 16),
                label: Text(
                  "VER",
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.12),
                  foregroundColor: AppColors.primaryGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeedbackSection(KbArticle article, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF9FBFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : AppColors.primaryGreen.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        children: [
          Text(
            "¿Te resultó útil este artículo?",
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (_submittedFeedback != null)
            Text(
              "¡Gracias por tu retroalimentación!",
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryGreen,
              ),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _isSubmittingFeedback ? null : () => _sendFeedback(article.id, true),
                  icon: const Icon(Icons.thumb_up_outlined, size: 16),
                  label: Text("Sí (${article.helpfulYes})"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryGreen,
                    side: BorderSide(color: AppColors.primaryGreen.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _isSubmittingFeedback ? null : () => _sendFeedback(article.id, false),
                  icon: const Icon(Icons.thumb_down_outlined, size: 16),
                  label: Text("No (${article.helpfulNo})"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _sendFeedback(int articleId, bool isHelpful) async {
    final user = ref.read(authStateProvider).user;
    setState(() => _isSubmittingFeedback = true);
    try {
      await ref.read(kbServiceProvider).sendFeedback(
            articleId,
            isHelpful: isHelpful,
            userCode: user?.code,
            userName: user?.name,
          );
      setState(() {
        _submittedFeedback = isHelpful;
        _isSubmittingFeedback = false;
      });
    } catch (e) {
      setState(() => _isSubmittingFeedback = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Widget _buildRelatedArticleTile(dynamic rel, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : AppColors.cardBorder),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        dense: true,
        leading: const Icon(Icons.article_outlined, color: AppColors.primaryGreen, size: 20),
        title: Text(
          rel.title,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12),
        onTap: () {
          context.pushReplacementNamed(
            'kb_article_detail',
            pathParameters: {'idOrSlug': rel.slug.isNotEmpty ? rel.slug : rel.id.toString()},
          );
        },
      ),
    );
  }

  Widget _buildCommentsSection(KbArticle article, bool isDark) {
    final commentController = TextEditingController();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Comentarios (${_localComments.length})"),
        const SizedBox(height: 12),

        // List of comments
        if (_localComments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              "Sé el primero en dejar un comentario o duda sobre esta guía.",
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: isDark ? Colors.white54 : AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          ..._localComments.map((c) => _buildCommentCard(c, isDark)),

        const SizedBox(height: 16),

        // Add Comment Input Box
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.white10 : AppColors.cardBorder),
          ),
          child: Column(
            children: [
              TextField(
                controller: commentController,
                maxLines: 2,
                style: GoogleFonts.poppins(fontSize: 12),
                decoration: InputDecoration(
                  hintText: "Escribe una duda o aporte...",
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : AppColors.textSecondary,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FilledButton.icon(
                    onPressed: () async {
                      final text = commentController.text.trim();
                      if (text.isEmpty) return;
                      final user = ref.read(authStateProvider).user;

                      try {
                        final newComment = await ref.read(kbServiceProvider).postComment(
                              article.id,
                              comment: text,
                              userCode: user?.code ?? '',
                              userName: user?.name,
                            );
                        commentController.clear();
                        setState(() {
                          _localComments.insert(0, newComment);
                        });
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Comentario publicado"),
                              backgroundColor: AppColors.primaryGreen,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Error al comentar: $e"),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.send_rounded, size: 14),
                    label: Text("Publicar", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700)),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accentOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCommentCard(KbComment comment, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? Colors.white10 : AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                comment.userName,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
              Text(
                _formatArticleDate(comment.createdAt),
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: isDark ? Colors.white38 : AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            comment.comment,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: isDark ? Colors.white70 : AppColors.textSecondary,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  String _formatArticleDate(String rawDate) {
    if (rawDate.trim().isEmpty) return '';
    final sanitized = rawDate.replaceAll(RegExp(r'[^\d\-T :.]'), '').trim();
    try {
      final mainPart = sanitized.split('.').first.replaceAll('T', ' ');
      final dateParts = mainPart.split(' ').first.split('-');
      if (dateParts.length == 3) {
        final year = int.tryParse(dateParts[0]);
        final month = int.tryParse(dateParts[1]);
        final day = int.tryParse(dateParts[2]);
        if (year != null && month != null && day != null) {
          const months = [
            'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
            'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
          ];
          final monthName = (month >= 1 && month <= 12) ? months[month - 1] : '$month';
          return '$day $monthName $year';
        }
      }
      final dt = DateTime.tryParse(sanitized);
      if (dt != null) {
        const months = [
          'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
          'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
        ];
        final monthName = months[dt.month - 1];
        return '${dt.day} $monthName ${dt.year}';
      }
    } catch (_) {}
    return sanitized.split(' ').first;
  }

  void _scrollToHeading(String title) {
    final cleanTarget = title.toLowerCase().replaceAll(RegExp(r'^\d+[\.\-\s]+'), '').trim();
    GlobalKey? matchedKey = _headingKeys[title];
    if (matchedKey == null) {
      for (final entry in _headingKeys.entries) {
        final cleanKey = entry.key.toLowerCase().replaceAll(RegExp(r'^\d+[\.\-\s]+'), '').trim();
        if (cleanKey.contains(cleanTarget) || cleanTarget.contains(cleanKey)) {
          matchedKey = entry.value;
          break;
        }
      }
    }
    if (matchedKey?.currentContext != null) {
      Scrollable.ensureVisible(
        matchedKey!.currentContext!,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
        alignment: 0.05,
      );
    }
  }
}