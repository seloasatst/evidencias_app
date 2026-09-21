import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/services/screen_security_service.dart';
import '../../../../ui/theme/app_colors.dart';
import '../../../auth/data/token_storage.dart';
import '../../data/models/kb_attachment.dart';

class KbDocumentPreviewDialog extends ConsumerStatefulWidget {
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
  ConsumerState<KbDocumentPreviewDialog> createState() => _KbDocumentPreviewDialogState();
}

class _KbDocumentPreviewDialogState extends ConsumerState<KbDocumentPreviewDialog> {
  // PDF State
  String? _localPdfPath;
  PDFViewController? _pdfViewController;
  int _pdfTotalPages = 0;
  int _pdfCurrentPage = 0;
  bool _isPdfReady = false;

  // Image State
  Uint8List? _localImageBytes;

  // Web State
  WebViewController? _webViewController;
  double _loadingProgress = 0.0;

  // Common State
  bool _isLoading = true;
  bool _isDownloading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    ScreenSecurityService.enableSecure();
    _loadFile();
  }

  @override
  void dispose() {
    ScreenSecurityService.disableSecure();
    super.dispose();
  }

  void _loadFile() {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isPdfReady = false;
      _localImageBytes = null;
    });

    if (widget.attachment.isPdf) {
      _downloadAndPreparePdf();
    } else if (widget.attachment.isImage) {
      _downloadAndPrepareImage();
    } else {
      _initWebView();
    }
  }

  Future<void> _downloadAndPrepareImage() async {
    final url = widget.attachment.previewFullUrl.isNotEmpty
        ? widget.attachment.previewFullUrl
        : widget.attachment.fullUrl.trim();

    if (url.isEmpty) {
      if (mounted) {
        setState(() {
          _errorMessage = 'No se encontró la URL de la imagen.';
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final token = await TokenStorage().getToken();
      final headers = <String, String>{
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        'Accept': 'image/*, */*',
      };

      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (mounted) {
          setState(() {
            _localImageBytes = response.bodyBytes;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Error ${response.statusCode} al obtener la imagen.';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'No se pudo cargar la imagen: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _downloadAndPreparePdf() async {
    final url = widget.attachment.previewFullUrl.isNotEmpty
        ? widget.attachment.previewFullUrl
        : widget.attachment.fullUrl.trim();

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
      final token = await TokenStorage().getToken();
      final headers = <String, String>{
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        'Accept': 'application/pdf, */*',
      };

      final response = await http.get(Uri.parse(url), headers: headers);
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
            _errorMessage = 'Error ${response.statusCode} al obtener el archivo.';
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

    bool isWebViewSupported = false;
    try {
      isWebViewSupported = WebViewPlatform.instance != null;
    } catch (_) {
      isWebViewSupported = false;
    }

    if (!isWebViewSupported) {
      if (mounted) {
        setState(() {
          _errorMessage = 'El visor integrado no está disponible en esta plataforma/dispositivo. Puedes usar el botón DESCARGAR para ver este archivo.';
          _isLoading = false;
        });
      }
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
    final rawUrl = widget.attachment.previewFullUrl.isNotEmpty
        ? widget.attachment.previewFullUrl
        : widget.attachment.fullUrl.trim();
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

  Future<void> _downloadFile() async {
    if (!widget.attachment.isDownloadable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Este documento es de solo lectura y no permite descargas."),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    final rawUrl = widget.attachment.fullUrl.trim();
    if (rawUrl.isEmpty) return;

    setState(() => _isDownloading = true);

    try {
      final uri = Uri.tryParse(rawUrl);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Descargando ${widget.attachment.displayName}..."),
            backgroundColor: AppColors.primaryGreen,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error al iniciar descarga: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
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

    final name = att.displayName.toLowerCase();
    final mime = att.mimeType.toLowerCase();

    if (att.isPdf) {
      fileIcon = Icons.picture_as_pdf_rounded;
      iconColor = Colors.redAccent;
      typeLabel = "Documento PDF";
    } else if (att.isImage) {
      fileIcon = Icons.image_rounded;
      iconColor = Colors.blueAccent;
      typeLabel = "Imagen";
    } else if (name.endsWith('.xls') || name.endsWith('.xlsx') || mime.contains('spreadsheet') || mime.contains('excel')) {
      fileIcon = Icons.table_chart_rounded;
      iconColor = Colors.green;
      typeLabel = "Hoja de cálculo";
    } else if (name.endsWith('.doc') || name.endsWith('.docx') || mime.contains('word')) {
      fileIcon = Icons.description_rounded;
      iconColor = Colors.indigo;
      typeLabel = "Documento Word";
    } else if (name.endsWith('.zip') || name.endsWith('.rar')) {
      fileIcon = Icons.folder_zip_rounded;
      iconColor = Colors.amber.shade800;
      typeLabel = "Archivo Comprimido";
    }

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
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
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                                  color: Colors.amber.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  "SOLO LECTURA",
                                  style: GoogleFonts.poppins(
                                    fontSize: 9,
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
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    color: isDark ? Colors.white70 : AppColors.textSecondary,
                    tooltip: "Recargar",
                    onPressed: _loadFile,
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
                color: isDark ? const Color(0xFF121212) : const Color(0xFFF0F2F5),
                child: _buildBody(isDark, fileIcon, iconColor),
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
                    flex: 1,
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
                  if (att.isDownloadable)
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _isDownloading ? null : _downloadFile,
                        icon: _isDownloading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.download_rounded, size: 16),
                        label: Text(
                          _isDownloading ? "DESCARGANDO..." : "DESCARGAR",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                      ),
                    )
                  else
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.amber.withValues(alpha: 0.15) : const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock_outline_rounded, size: 16, color: Colors.amber.shade800),
                            const SizedBox(width: 6),
                            Text(
                              "SOLO LECTURA",
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.amber.shade800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
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

  Widget _buildBody(bool isDark, IconData fileIcon, Color iconColor) {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: Colors.red.shade300),
              const SizedBox(height: 12),
              Text(
                "No se pudo cargar la vista previa",
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
                  fontSize: 11,
                  color: isDark ? Colors.white70 : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadFile,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text("Reintentar"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(iconColor),
            ),
            const SizedBox(height: 16),
            Text(
              "Preparando vista previa...",
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
      return Stack(
        children: [
          PDFView(
            filePath: _localPdfPath,
            enableSwipe: true,
            swipeHorizontal: false,
            autoSpacing: true,
            pageFling: true,
            pageSnap: true,
            fitPolicy: FitPolicy.BOTH,
            preventLinkNavigation: false,
            backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade200,
            onViewCreated: (PDFViewController controller) {
              _pdfViewController = controller;
            },
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
          ),

          // Floating Clean Pagination Pill at Bottom Center
          if (_isPdfReady && _pdfTotalPages > 0)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: _pdfCurrentPage > 0
                            ? () {
                                final prev = _pdfCurrentPage - 1;
                                _pdfViewController?.setPage(prev);
                              }
                            : null,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.chevron_left_rounded,
                            size: 18,
                            color: _pdfCurrentPage > 0 ? Colors.white : Colors.white30,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "${_pdfCurrentPage + 1} / $_pdfTotalPages",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: _pdfCurrentPage < _pdfTotalPages - 1
                            ? () {
                                final next = _pdfCurrentPage + 1;
                                _pdfViewController?.setPage(next);
                              }
                            : null,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: _pdfCurrentPage < _pdfTotalPages - 1 ? Colors.white : Colors.white30,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    }

    if (widget.attachment.isImage) {
      return _buildImageViewer(widget.attachment, isDark);
    }

    return _buildWebViewer(isDark, fileIcon, iconColor);
  }

  Widget _buildImageViewer(KbAttachment att, bool isDark) {
    if (_localImageBytes != null) {
      return Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.memory(
            _localImageBytes!,
            fit: BoxFit.contain,
            errorBuilder: (_, error, ___) => _buildImagePreviewError(att, isDark),
          ),
        ),
      );
    }

    final imgUrl = att.previewFullUrl.isNotEmpty ? att.previewFullUrl : att.fullUrl;

    return Center(
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Image.network(
          imgUrl,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accentOrange),
            );
          },
          errorBuilder: (_, error, ___) => _buildImagePreviewError(att, isDark),
        ),
      ),
    );
  }

  Widget _buildImagePreviewError(KbAttachment att, bool isDark) {
    return Padding(
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
          if (att.isDownloadable) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _downloadFile,
              icon: const Icon(Icons.download_rounded, size: 16),
              label: const Text("Descargar imagen"),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentOrange,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWebViewer(bool isDark, IconData fileIcon, Color iconColor) {
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