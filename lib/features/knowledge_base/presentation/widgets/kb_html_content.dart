import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/config/app_api_config.dart';
import '../../../../ui/theme/app_colors.dart';

class KbHtmlContent extends StatelessWidget {
  final String html;
  final Map<String, GlobalKey>? headingKeys;
  final void Function(String heading)? onHeadingTap;

  const KbHtmlContent({
    super.key,
    required this.html,
    this.headingKeys,
    this.onHeadingTap,
  });

  /// Extrae la lista de títulos de encabezados válidos (excluyendo títulos de TOC)
  static List<String> extractHeadings(String? htmlContent) {
    if (htmlContent == null || htmlContent.trim().isEmpty) return [];
    final headings = <String>[];
    final pattern = RegExp(
      r'<(h[1-3])[^>]*>(.*?)<\/\1>',
      dotAll: true,
      caseSensitive: false,
    );
    for (final match in pattern.allMatches(htmlContent)) {
      final inner = match.group(2) ?? '';
      final title = _stripHtml(inner).trim();
      if (title.isNotEmpty && !_isTocTitle(title) && !headings.contains(title)) {
        headings.add(title);
      }
    }
    return headings;
  }

  static bool _isTocTitle(String title) {
    final lower = title.toLowerCase().trim();
    return lower.startsWith('índice') ||
        lower.startsWith('indice') ||
        lower.startsWith('tabla de contenido') ||
        lower.startsWith('temario') ||
        lower == 'toc' ||
        lower == 'contenido';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final blocks = _parseHtmlToBlocks(html);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks.map((block) => _renderBlock(context, block, isDark)).toList(),
    );
  }

  Widget _renderBlock(BuildContext context, _HtmlBlock block, bool isDark) {
    final primaryTextColor = isDark ? Colors.white : AppColors.textPrimary;
    final secondaryTextColor = isDark ? Colors.white70 : AppColors.textSecondary;
    final blockKey = headingKeys?[block.text];

    switch (block.type) {
      case _BlockType.toc:
        return _buildTocBlock(context, block, isDark);

      case _BlockType.h1:
        return Container(
          key: blockKey,
          padding: const EdgeInsets.only(top: 22, bottom: 10),
          child: Text(
            block.text,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.accentOrange,
              height: 1.3,
            ),
          ),
        );

      case _BlockType.h2:
        return Container(
          key: blockKey,
          padding: const EdgeInsets.only(top: 20, bottom: 8),
          child: Container(
            padding: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white12 : AppColors.primaryGreen.withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: Text(
                    block.text,
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.primaryGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

      case _BlockType.h3:
        return Container(
          key: blockKey,
          padding: const EdgeInsets.only(top: 16, bottom: 6),
          child: Text(
            block.text,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
        );

      case _BlockType.h4:
        return Container(
          key: blockKey,
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(
            block.text,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : AppColors.textPrimary,
            ),
          ),
        );

      case _BlockType.paragraph:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildRichText(context, block.text, isDark, primaryTextColor),
        );

      case _BlockType.orderedListItem:
        return Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2, right: 10),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2E3830) : const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "${block.index ?? 1}.",
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
              Expanded(
                child: _buildRichText(context, block.text, isDark, primaryTextColor),
              ),
            ],
          ),
        );

      case _BlockType.unorderedListItem:
        return Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8, right: 10),
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.accentOrange,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: _buildRichText(context, block.text, isDark, primaryTextColor),
              ),
            ],
          ),
        );

      case _BlockType.quote:
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF252525) : const Color(0xFFFFF7ED),
            border: const Border(
              left: BorderSide(color: AppColors.accentOrange, width: 4),
            ),
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, size: 20, color: AppColors.accentOrange),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  block.text,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: secondaryTextColor,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        );

      case _BlockType.image:
        return _buildImageBlock(context, block.text, isDark);

      case _BlockType.video:
        return _buildVideoBlock(context, block.text, isDark);

      case _BlockType.table:
        return _buildTableBlock(context, block.tableData, isDark);

      case _BlockType.code:
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          padding: const EdgeInsets.all(12),
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141414) : const Color(0xFF2B2D42),
            borderRadius: BorderRadius.circular(10),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(
              block.text,
              style: GoogleFonts.firaCode(
                fontSize: 12,
                color: const Color(0xFFE0E0E0),
              ),
            ),
          ),
        );

      case _BlockType.divider:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Divider(
            color: isDark ? Colors.white10 : AppColors.cardBorder,
            height: 1,
          ),
        );
    }
  }

  /// Renderiza un bloque especial para el Índice de Contenido (Table of Contents)
  Widget _buildTocBlock(BuildContext context, _HtmlBlock block, bool isDark) {
    final items = block.listItems ?? [];
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B241E) : const Color(0xFFF2F9F4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF2E4233) : const Color(0xFFC8E6C9),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.format_list_bulleted_rounded,
                  size: 16,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "ÍNDICE DE CONTENIDOS",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryGreen,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              if (items.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accentOrange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "${items.length} temas",
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accentOrange,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isNotEmpty)
            ...items.asMap().entries.map((entry) {
              final idx = entry.key + 1;
              final rawText = entry.value;
              final cleanText = _stripHtml(rawText).trim();

              return InkWell(
                onTap: () {
                  if (onHeadingTap != null) {
                    onHeadingTap!(cleanText);
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 2, right: 10),
                        width: 20,
                        height: 20,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.accentOrange.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          "$idx",
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accentOrange,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          cleanText,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : AppColors.textPrimary,
                            height: 1.35,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 11,
                        color: AppColors.accentOrange,
                      ),
                    ],
                  ),
                ),
              );
            })
          else
            _buildRichText(context, block.text, isDark, isDark ? Colors.white70 : AppColors.textPrimary),
        ],
      ),
    );
  }

  Widget _buildImageBlock(BuildContext context, String src, bool isDark) {
    final cleanSrc = src.trim();
    final bool isBase64 = cleanSrc.startsWith('data:image');
    final fullUrl = isBase64 ? '' : _resolveUrl(cleanSrc);
    Uint8List? memoryBytes;
    if (isBase64) {
      try {
        final commaIndex = cleanSrc.indexOf(',');
        if (commaIndex != -1) {
          memoryBytes = base64Decode(cleanSrc.substring(commaIndex + 1));
        }
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => _openImageFullScreen(context, fullUrl, memoryBytes),
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              if (memoryBytes != null)
                Image.memory(
                  memoryBytes,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (context, error, stackTrace) => _buildImageError(isDark),
                )
              else if (fullUrl.isNotEmpty)
                Image.network(
                  fullUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      height: 180,
                      color: isDark ? const Color(0xFF252525) : Colors.grey.shade200,
                      child: const Center(
                        child: CircularProgressIndicator(color: AppColors.accentOrange),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => _buildImageError(isDark),
                )
              else
                _buildImageError(isDark),
              Container(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageError(bool isDark) {
    return Container(
      height: 140,
      width: double.infinity,
      color: isDark ? const Color(0xFF252525) : Colors.grey.shade200,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.broken_image_rounded, size: 36, color: Colors.grey),
          const SizedBox(height: 6),
          Text(
            "No se pudo cargar la imagen",
            style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoBlock(BuildContext context, String url, bool isDark) {
    return _KbVideoPlayerEmbedWidget(
      rawUrl: url,
      isDark: isDark,
      resolveUrl: _resolveUrl,
    );
  }

  Widget _buildTableBlock(BuildContext context, List<List<String>>? data, bool isDark) {
    if (data == null || data.isEmpty) return const SizedBox.shrink();

    final headerRow = data.first;
    final bodyRows = data.length > 1 ? data.sublist(1) : <List<String>>[];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white12 : AppColors.cardBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(
              isDark ? const Color(0xFF252525) : AppColors.primaryGreen.withValues(alpha: 0.08),
            ),
            dataRowColor: WidgetStateProperty.resolveWith((states) {
              return isDark ? const Color(0xFF1A1A1A) : Colors.white;
            }),
            columnSpacing: 20,
            horizontalMargin: 16,
            columns: headerRow.map((col) {
              return DataColumn(
                label: Text(
                  col,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.primaryGreen,
                  ),
                ),
              );
            }).toList(),
            rows: bodyRows.map((row) {
              return DataRow(
                cells: row.map((cell) {
                  return DataCell(
                    Text(
                      cell,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : AppColors.textPrimary,
                      ),
                    ),
                  );
                }).toList(),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _openImageFullScreen(BuildContext context, String imageUrl, [Uint8List? memoryBytes]) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(12),
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: memoryBytes != null
                      ? Image.memory(
                          memoryBytes,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => _buildZoomError(),
                        )
                      : Image.network(
                          imageUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => _buildZoomError(),
                        ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(dialogCtx),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildZoomError() {
    return Container(
      padding: const EdgeInsets.all(24),
      color: Colors.black87,
      child: const Text(
        "Error al ampliar imagen",
        style: TextStyle(color: Colors.white),
      ),
    );
  }

  String _resolveUrl(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('data:image')) return trimmed;

    // Protocol-relative URLs: //www.youtube.com/... or //youtube.com/...
    if (trimmed.startsWith('//')) {
      return 'https:$trimmed';
    }

    // Direct domain names without scheme: www.youtube.com / youtube.com / youtu.be / vimeo.com
    final lower = trimmed.toLowerCase();
    if (lower.startsWith('www.') ||
        lower.startsWith('youtube.com/') ||
        lower.startsWith('youtu.be/') ||
        lower.startsWith('vimeo.com/') ||
        lower.startsWith('player.vimeo.com/')) {
      return 'https://$trimmed';
    }

    // External http:// or https:// URLs
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      // Fix double domain prefixing e.g. http://server.com//www.youtube.com/embed/...
      final doubleDomainMatch = RegExp(
        r'https?:\/\/[^\/]+\/(?:https?:)?\/\/(?:www\.)?(youtube\.com|youtu\.be|vimeo\.com)\/(.*)',
        caseSensitive: false,
      ).firstMatch(trimmed);
      if (doubleDomainMatch != null) {
        final domain = doubleDomainMatch.group(1);
        final rest = doubleDomainMatch.group(2);
        return 'https://$domain/$rest';
      }
      return trimmed;
    }

    final base = AppApiConfig.evidenciasBaseUrl;
    final uri = Uri.parse(base);
    final portStr = (uri.hasPort && uri.port != 80 && uri.port != 443)
        ? ':${uri.port}'
        : (uri.port != 0 && uri.port != 80 && uri.port != 443 ? ':${uri.port}' : '');
    final serverRoot = '${uri.scheme}://${uri.host}$portStr';

    // Normalizar localhost / 127.0.0.1 / 10.0.2.2 al host real del servidor
    final localhostPattern = RegExp(r'^https?:\/\/(?:localhost|127\.0\.0\.1|10\.0\.2\.2)(?::\d+)?\/(.*)$', caseSensitive: false);
    final match = localhostPattern.firstMatch(trimmed);
    if (match != null) {
      final subpath = match.group(1) ?? '';
      return '$serverRoot/$subpath';
    }

    final cleanPath = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    return '$serverRoot$cleanPath';
  }

  Widget _buildRichText(BuildContext context, String text, bool isDark, Color defaultColor) {
    final spans = _parseInlineStyles(text, isDark, defaultColor);
    return RichText(
      text: TextSpan(
        style: GoogleFonts.poppins(
          fontSize: 14,
          height: 1.55,
          color: defaultColor,
        ),
        children: spans,
      ),
    );
  }

  List<TextSpan> _parseInlineStyles(String text, bool isDark, Color defaultColor) {
    final spans = <TextSpan>[];
    final pattern = RegExp(
      r'(<strong>|<b>)(.*?)(<\/strong>|<\/b>)|(<em>|<i>)(.*?)(<\/em>|<\/i>)|(<code>)(.*?)(<\/code>)|(<a\s+[^>]*href="([^"]+)"[^>]*>)(.*?)(<\/a>)',
      dotAll: true,
    );
    int lastIndex = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(text: _stripHtml(text.substring(lastIndex, match.start))));
      }

      if (match.group(2) != null) {
        // Bold
        spans.add(TextSpan(
          text: _stripHtml(match.group(2)!),
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ));
      } else if (match.group(5) != null) {
        // Italic
        spans.add(TextSpan(
          text: _stripHtml(match.group(5)!),
          style: GoogleFonts.poppins(
            fontStyle: FontStyle.italic,
          ),
        ));
      } else if (match.group(8) != null) {
        // Code inline
        spans.add(TextSpan(
          text: _stripHtml(match.group(8)!),
          style: GoogleFonts.firaCode(
            backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
            color: AppColors.accentOrange,
            fontSize: 12,
          ),
        ));
      } else if (match.group(11) != null) {
        // Link
        final href = match.group(10) ?? '';
        final linkText = _stripHtml(match.group(11)!);
        spans.add(TextSpan(
          text: linkText,
          style: GoogleFonts.poppins(
            color: AppColors.accentOrange,
            decoration: TextDecoration.underline,
            fontWeight: FontWeight.w600,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () async {
              if (href.isNotEmpty) {
                // Enlaces ancla internos (#...)
                if (href.startsWith('#')) {
                  if (onHeadingTap != null) {
                    onHeadingTap!(linkText);
                  }
                  return;
                }
                final resolved = _resolveUrl(href);
                final uri = Uri.tryParse(resolved);
                if (uri != null) {
                  try {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } catch (_) {}
                }
              }
            },
        ));
      }

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(text: _stripHtml(text.substring(lastIndex))));
    }

    return spans.isEmpty ? [TextSpan(text: _stripHtml(text))] : spans;
  }

  static String _stripHtml(String text) {
    return text
        .replaceAll(RegExp(r'<style[^>]*>.*?<\/style>', dotAll: true, caseSensitive: false), '')
        .replaceAll(RegExp(r'<script[^>]*>.*?<\/script>', dotAll: true, caseSensitive: false), '')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
  }

  List<_HtmlBlock> _parseHtmlToBlocks(String rawHtml) {
    final blocks = <_HtmlBlock>[];
    if (rawHtml.trim().isEmpty) return blocks;

    // Limpiar estilos y scripts incrustados
    String content = rawHtml
        .replaceAll(RegExp(r'<style[^>]*>.*?<\/style>', dotAll: true, caseSensitive: false), '')
        .replaceAll(RegExp(r'<script[^>]*>.*?<\/script>', dotAll: true, caseSensitive: false), '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');

    // 1. Detectar si existe un bloque TOC explícito en el HTML:
    // Ejemplo: <h3>Índice de Contenidos</h3>\s*<ol>...</ol> o <div class="toc">...</div>
    final explicitTocPattern = RegExp(
      r'(?:<hr\s*\/?>\s*)?(?:<(?:h[1-4]|p|div)[^>]*>\s*(?:<strong>)?\s*(?:[ÍI]ndice|Tabla de contenido|Temario|Contenido)[^<]*(?:<\/strong>)?\s*<\/(?:h[1-4]|p|div)>\s*)<(?:ol|ul)[^>]*>(.*?)<\/(?:ol|ul)>(?:\s*<hr\s*\/?>)?',
      dotAll: true,
      caseSensitive: false,
    );

    bool hasExplicitToc = false;
    final explicitTocMatch = explicitTocPattern.firstMatch(content);
    if (explicitTocMatch != null) {
      hasExplicitToc = true;
      final listInner = explicitTocMatch.group(1) ?? '';
      final items = _extractListItems(listInner);
      if (items.isNotEmpty) {
        blocks.add(_HtmlBlock(
          type: _BlockType.toc,
          text: '',
          listItems: items,
        ));
      }
      // Reemplazar ese bloque en content con un marcador para no volver a parsearlo
      content = content.replaceRange(explicitTocMatch.start, explicitTocMatch.end, '');
    }

    // 2. Si NO hay TOC explícito, verificar si hay 3 o más secciones para generar uno automático
    if (!hasExplicitToc) {
      final autoHeadings = extractHeadings(content);
      if (autoHeadings.length >= 3) {
        blocks.add(_HtmlBlock(
          type: _BlockType.toc,
          text: '',
          listItems: autoHeadings,
        ));
      }
    }

    // 3. Extraer bloques restantes del cuerpo
    final tagPattern = RegExp(
      r'<(table|h1|h2|h3|h4|h5|h6|ol|ul|blockquote|pre|figure|iframe|video|hr|div|p)[^>]*>(.*?)<\/\1>|<img\s+[^>]*src=["\x27]([^"\x27]+)["\x27][^>]*>|<video\s+[^>]*src=["\x27]([^"\x27]+)["\x27][^>]*\/?>|<iframe\s+[^>]*src=["\x27]([^"\x27]+)["\x27][^>]*\/?>|<hr\s*\/?>',
      dotAll: true,
      caseSensitive: false,
    );

    final matches = tagPattern.allMatches(content);

    if (matches.isEmpty) {
      final paragraphs = content.split('\n\n');
      for (final p in paragraphs) {
        final clean = p.trim();
        if (clean.isNotEmpty) {
          final vidUrl = _extractVideoUrlFromHtml(clean);
          if (vidUrl != null) {
            blocks.add(_HtmlBlock(type: _BlockType.video, text: vidUrl));
          } else {
            blocks.add(_HtmlBlock(type: _BlockType.paragraph, text: clean));
          }
        }
      }
      return blocks;
    }

    for (final match in matches) {
      final fullMatch = match.group(0) ?? '';
      final tag = match.group(1)?.toLowerCase();
      final inner = match.group(2) ?? '';
      final imgSrc = match.group(3);
      final videoSrc = match.group(4);
      final iframeSrc = match.groupCount >= 5 ? match.group(5) : null;

      if (fullMatch.startsWith('<hr') || tag == 'hr') {
        blocks.add(_HtmlBlock(type: _BlockType.divider, text: ''));
        continue;
      }

      if (imgSrc != null) {
        blocks.add(_HtmlBlock(type: _BlockType.image, text: imgSrc));
        continue;
      }

      if (videoSrc != null) {
        blocks.add(_HtmlBlock(type: _BlockType.video, text: videoSrc));
        continue;
      }

      if (iframeSrc != null) {
        blocks.add(_HtmlBlock(type: _BlockType.video, text: iframeSrc));
        continue;
      }

      if (tag == null) continue;

      switch (tag) {
        case 'table':
          final tableData = _parseTable(inner);
          if (tableData.isNotEmpty) {
            blocks.add(_HtmlBlock(type: _BlockType.table, text: '', tableData: tableData));
          }
          break;

        case 'img':
          final srcMatch = RegExp(r'src=["\x27]([^"\x27]+)["\x27]', caseSensitive: false).firstMatch(fullMatch);
          if (srcMatch != null) {
            blocks.add(_HtmlBlock(type: _BlockType.image, text: srcMatch.group(1)!));
          }
          break;

        case 'iframe':
        case 'video':
          final vidUrl = _extractVideoUrlFromHtml(fullMatch) ?? _extractVideoUrlFromHtml(inner) ?? inner.trim();
          if (vidUrl.isNotEmpty) {
            blocks.add(_HtmlBlock(type: _BlockType.video, text: vidUrl));
          }
          break;

        case 'figure':
          final vidUrl = _extractVideoUrlFromHtml(inner);
          if (vidUrl != null) {
            blocks.add(_HtmlBlock(type: _BlockType.video, text: vidUrl));
          } else {
            final imgMatch = RegExp(r'<img\s+[^>]*src=["\x27]([^"\x27]+)["\x27][^>]*>', caseSensitive: false).firstMatch(inner);
            if (imgMatch != null) {
              blocks.add(_HtmlBlock(type: _BlockType.image, text: imgMatch.group(1)!));
            } else {
              final cleanText = _stripHtml(inner).trim();
              if (cleanText.isNotEmpty) {
                blocks.add(_HtmlBlock(type: _BlockType.paragraph, text: cleanText));
              }
            }
          }
          break;

        case 'pre':
          blocks.add(_HtmlBlock(type: _BlockType.code, text: _stripHtml(inner.trim())));
          break;

        case 'h1':
          final h1Text = _stripHtml(inner.trim());
          if (!_isTocTitle(h1Text)) {
            blocks.add(_HtmlBlock(type: _BlockType.h1, text: h1Text));
          }
          break;
        case 'h2':
          final h2Text = _stripHtml(inner.trim());
          if (!_isTocTitle(h2Text)) {
            blocks.add(_HtmlBlock(type: _BlockType.h2, text: h2Text));
          }
          break;
        case 'h3':
          final h3Text = _stripHtml(inner.trim());
          if (!_isTocTitle(h3Text)) {
            blocks.add(_HtmlBlock(type: _BlockType.h3, text: h3Text));
          }
          break;
        case 'h4':
        case 'h5':
        case 'h6':
          final h4Text = _stripHtml(inner.trim());
          if (!_isTocTitle(h4Text)) {
            blocks.add(_HtmlBlock(type: _BlockType.h4, text: h4Text));
          }
          break;

        case 'ol':
          final items = _extractListItems(inner);
          for (int i = 0; i < items.length; i++) {
            blocks.add(_HtmlBlock(
              type: _BlockType.orderedListItem,
              text: items[i],
              index: i + 1,
            ));
          }
          break;

        case 'ul':
          final items = _extractListItems(inner);
          for (final item in items) {
            blocks.add(_HtmlBlock(
              type: _BlockType.unorderedListItem,
              text: item,
            ));
          }
          break;

        case 'blockquote':
          blocks.add(_HtmlBlock(type: _BlockType.quote, text: _stripHtml(inner.trim())));
          break;

        case 'div':
        case 'p':
        default:
          final vidUrl = _extractVideoUrlFromHtml(inner);
          if (vidUrl != null) {
            final textWithoutVideoTags = inner
                .replaceAll(RegExp(r'<(?:iframe|video|source|embed|oembed)[^>]*>(?:.*?<\/(?:iframe|video|embed|oembed)>)?', dotAll: true, caseSensitive: false), '')
                .replaceAll(RegExp(r'https?:\/\/[^\s"<>]+\.(?:mp4|webm|mov|m3u8)', caseSensitive: false), '');
            final cleanText = _stripHtml(textWithoutVideoTags).trim();
            if (cleanText.isNotEmpty) {
              blocks.add(_HtmlBlock(type: _BlockType.paragraph, text: cleanText));
            }
            blocks.add(_HtmlBlock(type: _BlockType.video, text: vidUrl));
          } else {
            final embeddedImg = RegExp(r'<img\s+[^>]*src=["\x27]([^"\x27]+)["\x27][^>]*>', caseSensitive: false).firstMatch(inner);
            if (embeddedImg != null) {
              blocks.add(_HtmlBlock(type: _BlockType.image, text: embeddedImg.group(1)!));
            } else {
              if (inner.contains('<ol') || inner.contains('<ul')) {
                final subBlocks = _parseHtmlToBlocks(inner);
                blocks.addAll(subBlocks);
              } else {
                final cleanText = _stripHtml(inner).trim();
                if (cleanText.isNotEmpty) {
                  blocks.add(_HtmlBlock(type: _BlockType.paragraph, text: cleanText));
                }
              }
            }
          }
          break;
      }
    }

    return blocks;
  }

  static String? _extractVideoUrlFromHtml(String snippet) {
    if (snippet.trim().isEmpty) return null;

    final srcMatch = RegExp(
      r'<(?:iframe|video|source|embed|oembed)[^>]*?\s+(?:src|url)=["\x27]?([^"\x27\s>]+)["\x27]?',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(snippet);
    if (srcMatch != null) {
      var url = srcMatch.group(1)?.trim() ?? '';
      if (url.startsWith('//')) {
        url = 'https:$url';
      } else if (url.startsWith('www.')) {
        url = 'https://$url';
      }
      if (url.isNotEmpty) return url;
    }

    final oembedMatch = RegExp(
      r'url=["\x27]([^"\x27]+)["\x27]',
      caseSensitive: false,
    ).firstMatch(snippet);
    if (oembedMatch != null) {
      var url = oembedMatch.group(1)?.trim() ?? '';
      if (url.startsWith('//')) {
        url = 'https:$url';
      } else if (url.startsWith('www.')) {
        url = 'https://$url';
      }
      if (url.isNotEmpty) return url;
    }

    final ytMatch = RegExp(
      r'(?:https?:)?\/\/(?:www\.)?(?:youtube\.com\/(?:watch\?v=|embed\/)|youtu\.be\/)([\w-]+)',
      caseSensitive: false,
    ).firstMatch(snippet);
    if (ytMatch != null) {
      final id = ytMatch.group(1);
      if (id != null && id.isNotEmpty) {
        return 'https://www.youtube.com/embed/$id';
      }
    }

    final vimeoMatch = RegExp(
      r'(?:https?:)?\/\/(?:player\.)?vimeo\.com\/(?:video\/)?(\d+)',
      caseSensitive: false,
    ).firstMatch(snippet);
    if (vimeoMatch != null) {
      final id = vimeoMatch.group(1);
      if (id != null && id.isNotEmpty) {
        return 'https://player.vimeo.com/video/$id';
      }
    }

    final directMediaMatch = RegExp(
      r'https?:\/\/[^\s"<>]+\.(?:mp4|webm|mov|m3u8|ogg)(?:\?[^\s"<>]*)?',
      caseSensitive: false,
    ).firstMatch(snippet);
    if (directMediaMatch != null) {
      return directMediaMatch.group(0);
    }

    return null;
  }

  List<String> _extractListItems(String listHtml) {
    final items = <String>[];
    final liPattern = RegExp(r'<li[^>]*>(.*?)<\/li>', dotAll: true, caseSensitive: false);
    for (final m in liPattern.allMatches(listHtml)) {
      final itemText = m.group(1)?.trim();
      if (itemText != null && itemText.isNotEmpty) {
        items.add(itemText);
      }
    }
    return items;
  }

  List<List<String>> _parseTable(String tableHtml) {
    final rows = <List<String>>[];
    final trPattern = RegExp(r'<tr[^>]*>(.*?)<\/tr>', dotAll: true, caseSensitive: false);
    final cellPattern = RegExp(r'<(th|td)[^>]*>(.*?)<\/\1>', dotAll: true, caseSensitive: false);

    for (final trMatch in trPattern.allMatches(tableHtml)) {
      final trInner = trMatch.group(1) ?? '';
      final row = <String>[];
      for (final cellMatch in cellPattern.allMatches(trInner)) {
        row.add(_stripHtml(cellMatch.group(2) ?? '').trim());
      }
      if (row.isNotEmpty) {
        rows.add(row);
      }
    }

    return rows;
  }
}

enum _BlockType {
  h1,
  h2,
  h3,
  h4,
  paragraph,
  orderedListItem,
  unorderedListItem,
  quote,
  toc,
  image,
  video,
  table,
  code,
  divider
}

class _HtmlBlock {
  final _BlockType type;
  final String text;
  final int? index;
  final List<String>? listItems;
  final List<List<String>>? tableData;

  _HtmlBlock({
    required this.type,
    required this.text,
    this.index,
    this.listItems,
    this.tableData,
  });
}

class _KbVideoPlayerEmbedWidget extends StatefulWidget {
  final String rawUrl;
  final bool isDark;
  final String Function(String) resolveUrl;

  const _KbVideoPlayerEmbedWidget({
    required this.rawUrl,
    required this.isDark,
    required this.resolveUrl,
  });

  @override
  State<_KbVideoPlayerEmbedWidget> createState() => _KbVideoPlayerEmbedWidgetState();
}

class _KbVideoPlayerEmbedWidgetState extends State<_KbVideoPlayerEmbedWidget> {
  WebViewController? _controller;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isWebViewSupported = false;
  String _finalResolvedUrl = '';

  @override
  void initState() {
    super.initState();
    _checkSupportAndInit();
  }

  void _checkSupportAndInit() {
    try {
      _isWebViewSupported = WebViewPlatform.instance != null;
    } catch (_) {
      _isWebViewSupported = false;
    }

    final resolved = widget.resolveUrl(widget.rawUrl);
    _finalResolvedUrl = resolved;

    if (resolved.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
      return;
    }

    if (!_isWebViewSupported) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final embedUrl = _getEmbedUrl(resolved);

      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.black)
        ..setUserAgent(
          "Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36",
        )
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) {
              if (mounted) {
                setState(() => _isLoading = false);
              }
            },
            onWebResourceError: (err) {
              if (mounted && _isLoading) {
                setState(() => _isLoading = false);
              }
            },
          ),
        );

      final uri = Uri.tryParse(embedUrl);
      if (uri != null) {
        controller.loadRequest(
          uri,
          headers: embedUrl.contains('youtube')
              ? const {'Referer': 'https://www.youtube-nocookie.com'}
              : const {},
        );
        _controller = controller;
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasError = true;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  String _getEmbedUrl(String url) {
    final ytMatch = RegExp(
      r'(?:https?:)?\/\/(?:www\.)?(?:youtube\.com\/(?:watch\?v=|embed\/)|youtube-nocookie\.com\/embed\/|youtu\.be\/)([\w-]+)',
      caseSensitive: false,
    ).firstMatch(url);

    if (ytMatch != null) {
      final ytId = ytMatch.group(1);
      final startMatch = RegExp(r'[?&](?:start|t)=(\d+)').firstMatch(url);
      final startParam = startMatch != null ? '&start=${startMatch.group(1)}' : '';
      return 'https://www.youtube-nocookie.com/embed/$ytId?playsinline=1&rel=0&modestbranding=1$startParam';
    }

    if (url.contains('vimeo.com') && !url.contains('player.vimeo.com')) {
      final vimeoMatch = RegExp(r'vimeo\.com\/(\d+)').firstMatch(url);
      if (vimeoMatch != null) {
        return 'https://player.vimeo.com/video/${vimeoMatch.group(1)}';
      }
    }

    return url;
  }

  String _getWatchUrl(String url) {
    final ytMatch = RegExp(
      r'(?:https?:)?\/\/(?:www\.)?(?:youtube\.com\/(?:watch\?v=|embed\/)|youtu\.be\/)([\w-]+)',
      caseSensitive: false,
    ).firstMatch(url);

    if (ytMatch != null) {
      final ytId = ytMatch.group(1);
      final startMatch = RegExp(r'[?&](?:start|t)=(\d+)').firstMatch(url);
      final startParam = startMatch != null ? '&t=${startMatch.group(1)}s' : '';
      return 'https://www.youtube.com/watch?v=$ytId$startParam';
    }

    return url;
  }

  Future<void> _launchExternal() async {
    final rawTarget = _finalResolvedUrl.isNotEmpty ? _finalResolvedUrl : widget.rawUrl;
    final watchTarget = _getWatchUrl(rawTarget);
    final uri = Uri.tryParse(watchTarget);
    if (uri != null) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final displayWatchUrl = _getWatchUrl(_finalResolvedUrl.isNotEmpty ? _finalResolvedUrl : widget.rawUrl);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white12 : AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.play_circle_fill_rounded, color: Colors.red, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Video Explicativo",
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        displayWatchUrl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: isDark ? Colors.white54 : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(0),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                color: Colors.black,
                child: InkWell(
                  onTap: _launchExternal,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_isWebViewSupported && _controller != null && !_hasError)
                        WebViewWidget(controller: _controller!)
                      else ...[
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFF2A2A2A), Color(0xFF111111)],
                            ),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.85),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.red.withValues(alpha: 0.4),
                                        blurRadius: 16,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 38,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  "Toca para reproducir video",
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (_isLoading && _isWebViewSupported)
                        const Center(
                          child: CircularProgressIndicator(color: AppColors.accentOrange),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _launchExternal,
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: Text(
                  "ABRIR EN NAVEGADOR EXTERNO",
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
