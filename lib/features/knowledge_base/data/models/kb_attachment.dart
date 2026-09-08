import '../../../../core/config/app_api_config.dart';

class KbAttachment {
  final int id;
  final String fileName;
  final String originalName;
  final String filePath;
  final int fileSize;
  final String mimeType;

  KbAttachment({
    required this.id,
    required this.fileName,
    this.originalName = '',
    required this.filePath,
    required this.fileSize,
    required this.mimeType,
  });

  String get displayName => originalName.isNotEmpty ? originalName : fileName;

  factory KbAttachment.fromJson(Map<String, dynamic> json) {
    final rawPath = (json['download_url'] ??
            json['DOWNLOAD_URL'] ??
            json['url'] ??
            json['URL'] ??
            json['file_path'] ??
            json['FILE_PATH'] ??
            json['path'] ??
            json['PATH'] ??
            json['attachment_url'] ??
            json['ATTACHMENT_URL'] ??
            json['SHAREPOINT_URL'] ??
            json['sharepoint_url'] ??
            json['link'] ??
            json['LINK'] ??
            '')
        .toString();

    final rawOrig = (json['ORIGINAL_NAME'] ?? json['original_name'] ?? '').toString();
    final rawName = (json['FILE_NAME'] ??
            json['file_name'] ??
            json['name'] ??
            json['NAME'] ??
            json['filename'] ??
            json['FILENAME'] ??
            json['title'] ??
            json['TITLE'] ??
            '')
        .toString();

    final id = _parseInt(json['ID'] ?? json['id']);

    return KbAttachment(
      id: id,
      fileName: rawName.isNotEmpty ? rawName : (rawPath.isNotEmpty ? rawPath.split('/').last : 'archivo_$id'),
      originalName: rawOrig,
      filePath: rawPath,
      fileSize: _parseInt(json['FILE_SIZE'] ?? json['file_size'] ?? json['size'] ?? json['SIZE'] ?? 0),
      mimeType: (json['FILE_TYPE'] ?? json['file_type'] ?? json['MIME_TYPE'] ?? json['mime_type'] ?? json['type'] ?? json['TYPE'] ?? json['content_type'] ?? 'application/octet-stream').toString(),
    );
  }

  String get fullUrl {
    final path = filePath.trim();
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    final base = AppApiConfig.evidenciasBaseUrl;
    final uri = Uri.parse(base);
    final portStr = (uri.hasPort && uri.port != 80 && uri.port != 443) ? ':${uri.port}' : (uri.port != 0 && uri.port != 80 && uri.port != 443 ? ':${uri.port}' : '');
    final root = '${uri.scheme}://${uri.host}$portStr';

    if (path.isNotEmpty) {
      if (path.startsWith('/')) {
        return '$root$path';
      }
      return '$root/$path';
    }

    if (id > 0) {
      return '$base/kb/attachments/$id/download';
    }

    return '';
  }

  bool get isImage {
    final name = displayName.toLowerCase();
    final mime = mimeType.toLowerCase();
    final path = filePath.toLowerCase();
    return name.endsWith('.png') ||
        name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.webp') ||
        name.endsWith('.gif') ||
        name.endsWith('.bmp') ||
        path.endsWith('.png') ||
        path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.webp') ||
        path.endsWith('.gif') ||
        mime.contains('image');
  }

  bool get isPdf {
    final name = displayName.toLowerCase();
    final mime = mimeType.toLowerCase();
    final path = filePath.toLowerCase();
    return name.endsWith('.pdf') || path.endsWith('.pdf') || mime.contains('pdf');
  }

  String get formattedSize {
    if (fileSize <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double size = fileSize.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }
}

