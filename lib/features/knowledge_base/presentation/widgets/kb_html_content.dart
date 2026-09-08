import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/app_api_config.dart';
import '../../../../ui/theme/app_colors.dart';

class KbHtmlContent extends StatelessWidget {
  final String html;

  const KbHtmlContent({super.key, required this.html});

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

    switch (block.type) {
      case _BlockType.h1:
        return Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 8),
          child: Text(
            block.text,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.accentOrange,
            ),
          ),
        );

      case _BlockType.h2:
        return Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 8),
          child: Text(
            block.text,
            style: GoogleFonts.poppins(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.primaryGreen,
            ),
          ),
        );

      case _BlockType.h3:
        return Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Text(
            block.text,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: primaryTextColor,
            ),
          ),
        );

      case _BlockType.paragraph:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildRichText(context, block.text, isDark, primaryTextColor),
        );

      case _BlockType.listItem:
        return Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 7, right: 10),
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
            borderRadius: BorderRadius.circular(10),
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
                    height: 1.4,
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
    }
  }

  Widget _buildImageBlock(BuildContext context, String src, bool isDark) {
    final fullUrl = _resolveUrl(src);

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
          onTap: () => _openImageFullScreen(context, fullUrl),
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
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
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 140,
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
                },
              ),
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

  Widget _buildVideoBlock(BuildContext context, String url, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white10 : AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.play_circle_fill_rounded, color: Colors.red, size: 24),
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
                      url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final uri = Uri.tryParse(url);
                if (uri != null) {
                  try {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Enlace de video: $url")),
                      );
                    }
                  }
                }
              },
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: Text(
                "VER VIDEO",
                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accentOrange,
                side: const BorderSide(color: AppColors.accentOrange),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
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

  void _openImageFullScreen(BuildContext context, String imageUrl) {
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
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Container(
                      padding: const EdgeInsets.all(24),
                      color: Colors.black87,
                      child: const Text(
                        "Error al ampliar imagen",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
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

  String _resolveUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    final base = AppApiConfig.evidenciasBaseUrl;
    final uri = Uri.parse(base);
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return '${uri.scheme}://${uri.host}:${uri.port}$cleanPath';
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
      r'(<strong>|<b>)(.*?)(<\/strong>|<\/b>)|(<em>|<i>)(.*?)(<\/em>|<\/i>)|(<code>)(.*?)(<\/code>)|(<a\s+href="([^"]+)">)(.*?)(<\/a>)',
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
        spans.add(TextSpan(
          text: _stripHtml(match.group(11)!),
          style: GoogleFonts.poppins(
            color: AppColors.accentOrange,
            decoration: TextDecoration.underline,
            fontWeight: FontWeight.w600,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () async {
              if (href.isNotEmpty) {
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

  String _stripHtml(String text) {
    return text
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
  }

  List<_HtmlBlock> _parseHtmlToBlocks(String html) {
    final blocks = <_HtmlBlock>[];
    if (html.trim().isEmpty) return blocks;

    String content = html.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    // Extract tables, images, iframes/videos, codes, headers, and paragraphs
    final tagPattern = RegExp(
      r'<(table|h1|h2|h3|p|li|blockquote|pre|figure|iframe|video)[^>]*>(.*?)<\/\1>|<img\s+[^>]*src="([^"]+)"[^>]*>|<video\s+[^>]*src="([^"]+)"[^>]*\/?>',
      dotAll: true,
      caseSensitive: false,
    );

    final matches = tagPattern.allMatches(content);

    if (matches.isEmpty) {
      final paragraphs = content.split('\n\n');
      for (final p in paragraphs) {
        final clean = p.trim();
        if (clean.isNotEmpty) {
          blocks.add(_HtmlBlock(type: _BlockType.paragraph, text: clean));
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

      if (imgSrc != null) {
        blocks.add(_HtmlBlock(type: _BlockType.image, text: imgSrc));
        continue;
      }

      if (videoSrc != null) {
        blocks.add(_HtmlBlock(type: _BlockType.video, text: videoSrc));
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
          final srcMatch = RegExp(r'src="([^"]+)"').firstMatch(fullMatch);
          if (srcMatch != null) {
            blocks.add(_HtmlBlock(type: _BlockType.image, text: srcMatch.group(1)!));
          }
          break;

        case 'iframe':
        case 'video':
          final srcMatch = RegExp(r'src="([^"]+)"').firstMatch(fullMatch);
          final src = srcMatch?.group(1) ?? inner;
          if (src.isNotEmpty) {
            blocks.add(_HtmlBlock(type: _BlockType.video, text: src));
          }
          break;

        case 'figure':
          final imgMatch = RegExp(r'<img\s+[^>]*src="([^"]+)"[^>]*>').firstMatch(inner);
          if (imgMatch != null) {
            blocks.add(_HtmlBlock(type: _BlockType.image, text: imgMatch.group(1)!));
          } else {
            blocks.add(_HtmlBlock(type: _BlockType.paragraph, text: inner.trim()));
          }
          break;

        case 'pre':
          blocks.add(_HtmlBlock(type: _BlockType.code, text: _stripHtml(inner.trim())));
          break;

        case 'h1':
          blocks.add(_HtmlBlock(type: _BlockType.h1, text: _stripHtml(inner.trim())));
          break;
        case 'h2':
          blocks.add(_HtmlBlock(type: _BlockType.h2, text: _stripHtml(inner.trim())));
          break;
        case 'h3':
          blocks.add(_HtmlBlock(type: _BlockType.h3, text: _stripHtml(inner.trim())));
          break;
        case 'li':
          blocks.add(_HtmlBlock(type: _BlockType.listItem, text: inner.trim()));
          break;
        case 'blockquote':
          blocks.add(_HtmlBlock(type: _BlockType.quote, text: _stripHtml(inner.trim())));
          break;
        case 'p':
        default:
          // Check if paragraph contains an img
          final embeddedImg = RegExp(r'<img\s+[^>]*src="([^"]+)"[^>]*>').firstMatch(inner);
          if (embeddedImg != null) {
            blocks.add(_HtmlBlock(type: _BlockType.image, text: embeddedImg.group(1)!));
          } else if (inner.trim().isNotEmpty) {
            blocks.add(_HtmlBlock(type: _BlockType.paragraph, text: inner.trim()));
          }
          break;
      }
    }

    return blocks;
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

enum _BlockType { h1, h2, h3, paragraph, listItem, quote, image, video, table, code }

class _HtmlBlock {
  final _BlockType type;
  final String text;
  final List<List<String>>? tableData;

  _HtmlBlock({required this.type, required this.text, this.tableData});
}
