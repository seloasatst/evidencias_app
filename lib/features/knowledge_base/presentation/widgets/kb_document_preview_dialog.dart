import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../ui/theme/app_colors.dart';
import '../../data/models/kb_attachment.dart';

class KbDocumentPreviewDialog extends StatefulWidget {
  final KbAttachment attachment;

  const KbDocumentPreviewDialog({
    super.key,
    required this.attachment,
  });

  static Future<void> show(BuildContext context, KbAttachment attachment) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => KbDocumentPreviewDialog(attachment: attachment),
    );
  }

  @override
  State<KbDocumentPreviewDialog> createState() => _KbDocumentPreviewDialogState();
}

class _KbDocumentPreviewDialogState extends State<KbDocumentPreviewDialog> {
  // PDF State
  String? _localPdfPath;
  int _pdfTotalPages = 0;
  int _pdfCurrentPage = 0;
  bool _isPdfReady = false;

  // Web State
  WebViewController? _webViewController;
  double _loadingProgress = 0.0;

  // Common State
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  void _loadFile() {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (widget.attachment.isPdf) {
      _downloadAndPreparePdf();
    } else if (!widget.attachment.isImage) {
      _initWebView();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _downloadAndPreparePdf() async {
    final url = widget.attachment.fullUrl.trim();
    if (url.isEmpty) {
      if (mounted) {
        setState(() {
          _errorMessage = 'No se encontró la URL del documento.';
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final bytes = response.bodyBytes;
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/kb_doc_${widget.attachment.id}_${DateTime.now().millisecondsSinceEpoch}.pdf');
        await file.writeAsBytes(bytes, flush: true);

        if (mounted) {
          setState(() {
            _localPdfPath = file.path;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Error ${response.statusCode} al descargar el archivo.';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'No se pudo cargar el PDF: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _initWebView() {
    final previewUrl = _getPreviewUrl();
    if (previewUrl.isEmpty) {
      setState(() {
        _errorMessage = 'No se encontró la ruta del archivo adjunto.';
        _isLoading = false;
      });
      return;
    }

    final uri = Uri.tryParse(previewUrl);
    if (uri == null) {
      setState(() {
        _errorMessage = 'URL de documento inválida.';
        _isLoading = false;
      });
      return;
    }

    try {
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (int progress) {
              if (mounted) {
                setState(() {
                  _loadingProgress = progress / 100.0;
                });
              }
            },
            onPageStarted: (String url) {
              if (mounted) {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });
              }
            },
            onPageFinished: (String url) {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
              }
            },
            onWebResourceError: (WebResourceError error) {
              if (error.isForMainFrame ?? true) {
                if (mounted && _isLoading) {
                  setState(() {
                    _isLoading = false;
                  });
                }
              }
            },
          ),
        )
        ..loadRequest(uri);
    } catch (e) {
      setState(() {
        _errorMessage = 'No se pudo inicializar el visor web: $e';
        _isLoading = false;
      });
    }
  }

  String _getPreviewUrl() {
    final rawUrl = widget.attachment.fullUrl.trim();
    if (rawUrl.isEmpty) return '';

    if (rawUrl.contains('sharepoint.com') ||
        rawUrl.contains('office.com') ||
        rawUrl.contains('view.officeapps.live.com')) {
      return rawUrl;
    }

    final lower = rawUrl.toLowerCase();
    final nameLower = widget.attachment.displayName.toLowerCase();

    if (lower.endsWith('.doc') ||
        lower.endsWith('.docx') ||
        lower.endsWith('.xls') ||
        lower.endsWith('.xlsx') ||
        lower.endsWith('.ppt') ||
        lower.endsWith('.pptx') ||
        nameLower.endsWith('.doc') ||
        nameLower.endsWith('.docx') ||
        nameLower.endsWith('.xls') ||
        nameLower.endsWith('.xlsx')) {
      return 'https://view.officeapps.live.com/op/view.aspx?src=${Uri.encodeComponent(rawUrl)}';
    }

    return rawUrl;
  }

  Future<void> _openExternal() async {
    final rawUrl = widget.attachment.fullUrl.trim();
    if (rawUrl.isEmpty) return;
    final uri = Uri.tryParse(rawUrl);
    if (uri != null) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("No se pudo abrir externamente: $e")),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final att = widget.attachment;
    final screenSize = MediaQuery.of(context).size;

    IconData fileIcon = Icons.insert_drive_file_outlined;
    Color iconColor = AppColors.primaryGreen;
    String typeLabel = "Documento";
    String badgeText = "DOC";

    final name = att.displayName.toLowerCase();
    final mime = att.mimeType.toLowerCase();

    if (att.isPdf) {
      fileIcon = Icons.picture_as_pdf_rounded;
      iconColor = Colors.redAccent;
      typeLabel = "Documento PDF";
      badgeText = "PDF";
    } else if (att.isImage) {
      fileIcon = Icons.image_rounded;
      iconColor = Colors.blueAccent;
      typeLabel = "Imagen";
      badgeText = "IMG";
    } else if (name.endsWith('.xls') || name.endsWith('.xlsx') || mime.contains('spreadsheet') || mime.contains('excel')) {
      fileIcon = Icons.table_chart_rounded;
      iconColor = Colors.green;
      typeLabel = "Hoja de cálculo";
      badgeText = "XLS";
    } else if (name.endsWith('.doc') || name.endsWith('.docx') || mime.contains('word')) {
      fileIcon = Icons.description_rounded;
      iconColor = Colors.indigo;
      typeLabel = "Documento Word";
      badgeText = "DOC";
    } else if (name.endsWith('.zip') || name.endsWith('.rar')) {
      fileIcon = Icons.folder_zip_rounded;
      iconColor = Colors.amber.shade800;
      typeLabel = "Archivo Comprimido";
      badgeText = "ZIP";
    }

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: double.infinity,
        height: screenSize.height * 0.88,
        child: Column(
          children: [
            // Top Header Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF242424) : Colors.grey.shade100,
                border: Border(
                  bottom: BorderSide(color: isDark ? Colors.white12 : AppColors.cardBorder),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(fileIcon, color: iconColor, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          att.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              "$typeLabel • ${att.formattedSize}",
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: isDark ? Colors.white54 : AppColors.textSecondary,
                              ),
                            ),
                            if (att.isPdf && _isPdfReady && _pdfTotalPages > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  "Pág. ${_pdfCurrentPage + 1} de $_pdfTotalPages",
                                  style: GoogleFonts.poppins(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    color: isDark ? Colors.white70 : AppColors.textSecondary,
                    tooltip: "Recargar",
                    onPressed: _loadFile,
                  ),
                  IconButton(
                    icon: const Icon(Icons.open_in_new_rounded, size: 20),
                    color: isDark ? Colors.white70 : AppColors.textSecondary,
                    tooltip: "Abrir fuera de la app",
                    onPressed: _openExternal,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22),
                    color: isDark ? Colors.white70 : AppColors.textSecondary,
                    tooltip: "Cerrar",
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Progress bar
            if (_isLoading)
              LinearProgressIndicator(
                value: _loadingProgress > 0 ? _loadingProgress : null,
                minHeight: 3,
                backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentOrange),
              ),

            // Main Preview Area
            Expanded(
              child: Container(
                color: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
                child: _buildBody(isDark, fileIcon, iconColor, badgeText),
              ),
            ),

            // Bottom Actions Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF242424) : Colors.white,
                border: Border(
                  top: BorderSide(color: isDark ? Colors.white12 : AppColors.cardBorder),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? Colors.white70 : AppColors.textPrimary,
                        side: BorderSide(color: isDark ? Colors.white24 : AppColors.cardBorder),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        "CERRAR",
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _openExternal,
                      icon: const Icon(Icons.open_in_browser_rounded, size: 16),
                      label: Text(
                        "ABRIR ENLACE",
                        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(bool isDark, IconData fileIcon, Color iconColor, String badgeText) {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: Colors.red.shade400),
              const SizedBox(height: 12),
              Text(
                "Error al cargar el documento",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadFile,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text("Reintentar"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentOrange,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading && _localPdfPath == null && widget.attachment.isPdf) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.accentOrange),
            const SizedBox(height: 14),
            Text(
              "Cargando documento PDF...",
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (widget.attachment.isPdf && _localPdfPath != null) {
      return PDFView(
        filePath: _localPdfPath,
        enableSwipe: true,
        swipeHorizontal: false,
        autoSpacing: true,
        pageFling: true,
        pageSnap: true,
        fitPolicy: FitPolicy.BOTH,
        preventLinkNavigation: false,
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade200,
        onRender: (pages) {
          if (mounted) {
            setState(() {
              _pdfTotalPages = pages ?? 0;
              _isPdfReady = true;
            });
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _errorMessage = error.toString();
            });
          }
        },
        onPageError: (page, error) {
          if (mounted) {
            setState(() {
              _errorMessage = "Error en página $page: $error";
            });
          }
        },
        onPageChanged: (page, total) {
          if (mounted) {
            setState(() {
              _pdfCurrentPage = page ?? 0;
            });
          }
        },
      );
    }

    if (widget.attachment.isImage) {
      return _buildImageViewer(widget.attachment, isDark);
    }

    return _buildWebViewer(isDark, fileIcon, iconColor, badgeText);
  }

  Widget _buildImageViewer(KbAttachment att, bool isDark) {
    return Center(
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Image.network(
          att.fullUrl,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accentOrange),
            );
          },
          errorBuilder: (_, error, ___) => Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.broken_image_rounded, size: 54, color: Colors.grey),
                const SizedBox(height: 12),
                Text(
                  "No se pudo cargar la imagen directamente.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _openExternal,
                  icon: const Icon(Icons.open_in_browser_rounded, size: 16),
                  label: const Text("Abrir imagen"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentOrange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWebViewer(bool isDark, IconData fileIcon, Color iconColor, String badgeText) {
    if (_webViewController == null) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(iconColor),
        ),
      );
    }

    return Stack(
      children: [
        WebViewWidget(controller: _webViewController!),
        if (_isLoading)
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.black87 : Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: AppColors.accentOrange),
                  const SizedBox(height: 12),
                  Text(
                    "Cargando vista previa...",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
