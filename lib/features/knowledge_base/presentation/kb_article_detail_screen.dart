import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../ui/theme/app_colors.dart';
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

          return SingleChildScrollView(
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
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: AppColors.accentOrange.withValues(alpha: 0.2),
                      child: const Icon(
                        Icons.person_rounded,
                        size: 14,
                        color: AppColors.accentOrange,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      article.authorName,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : AppColors.textPrimary,
                      ),
                    ),
                    if (article.createdAt.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        "• ${article.createdAt.split(' ').first}",
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: isDark ? Colors.white38 : AppColors.textSecondary,
                        ),
                      ),
                    ],
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
                  KbHtmlContent(html: article.content!)
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

  Widget _buildFeedbackSection(KbArticle article, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF9FBF9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : AppColors.primaryGreen.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        children: [
          Text(
            "¿Te resultó útil esta información?",
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (_submittedFeedback != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    "¡Gracias por tu retroalimentación!",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _isSubmittingFeedback ? null : () => _handleFeedback(article.id, true),
                  icon: const Icon(Icons.thumb_up_alt_rounded, size: 16, color: Colors.green),
                  label: Text("Sí, útil", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green,
                    side: const BorderSide(color: Colors.green),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(width: 14),
                OutlinedButton.icon(
                  onPressed: _isSubmittingFeedback ? null : () => _handleFeedback(article.id, false),
                  icon: const Icon(Icons.thumb_down_alt_rounded, size: 16, color: Colors.redAccent),
                  label: Text("No", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _handleFeedback(int articleId, bool isHelpful) async {
    // Show optional comment dialog
    final commentController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            isHelpful ? "¿Qué fue lo más útil?" : "¿Cómo podemos mejorar?",
            style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          content: TextField(
            controller: commentController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: "Escribe un comentario opcional...",
              hintStyle: GoogleFonts.poppins(fontSize: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text("Omitir y Enviar"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text("Enviar"),
            ),
          ],
        );
      },
    );

    if (result != true) return;

    setState(() => _isSubmittingFeedback = true);
    try {
      await ref.read(articleActionsProvider).sendFeedback(
        articleId: articleId,
        isHelpful: isHelpful,
        comment: commentController.text.trim().isNotEmpty ? commentController.text.trim() : null,
      );
      setState(() {
        _submittedFeedback = isHelpful;
        _isSubmittingFeedback = false;
      });
    } catch (e) {
      setState(() => _isSubmittingFeedback = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error al registrar feedback: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Widget _buildCommentsSection(KbArticle article, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader("Comentarios y Dudas (${_localComments.length})"),
            TextButton.icon(
              onPressed: () => _showAddCommentDialog(article.id),
              icon: const Icon(Icons.add_comment_outlined, size: 16, color: AppColors.accentOrange),
              label: Text(
                "Preguntar",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentOrange,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (_localComments.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              "No hay comentarios todavía. ¿Tienes alguna pregunta sobre este artículo?",
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: isDark ? Colors.white54 : AppColors.textSecondary,
              ),
            ),
          )
        else
          ..._localComments.map((comment) => _buildCommentCard(comment, isDark)),
      ],
    );
  }

  Widget _buildCommentCard(KbComment comment, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
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
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
              if (comment.createdAt.isNotEmpty)
                Text(
                  comment.createdAt.split(' ').first,
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
              color: isDark ? Colors.white70 : AppColors.textPrimary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddCommentDialog(int articleId) {
    final commentController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Dejar un comentario o pregunta",
                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: commentController,
                maxLines: 4,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: "¿Tienes alguna duda sobre este proceso?",
                  hintStyle: GoogleFonts.poppins(fontSize: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final text = commentController.text.trim();
                    if (text.isEmpty) return;
                    Navigator.pop(bottomSheetContext);

                    try {
                      final newComment = await ref.read(articleActionsProvider).addComment(
                        articleId: articleId,
                        comment: text,
                      );
                      setState(() {
                        _localComments.insert(0, newComment);
                      });
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Comentario publicado correctamente."),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Error al publicar comentario: $e"),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    "PUBLICAR COMENTARIO",
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
