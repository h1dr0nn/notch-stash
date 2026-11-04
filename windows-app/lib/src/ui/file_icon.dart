import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;

import 'theme.dart';

const _thumbnailExtensions = {'.png', '.jpg', '.jpeg', '.gif', '.bmp', '.webp', '.ico'};

/// Thumbnail for pictures, a type icon for everything else.
class FileIcon extends StatelessWidget {
  const FileIcon({super.key, required this.path, this.size = 40});

  final String path;
  final double size;

  @override
  Widget build(BuildContext context) {
    final extension = p.extension(path).toLowerCase();
    if (_thumbnailExtensions.contains(extension)) {
      final pixels = (size * MediaQuery.devicePixelRatioOf(context)).round();
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.file(
          File(path),
          width: size,
          height: size,
          fit: BoxFit.cover,
          cacheWidth: pixels,
          filterQuality: FilterQuality.medium,
          errorBuilder: (context, error, stackTrace) => _icon(Icons.image_outlined),
        ),
      );
    }
    if (FileSystemEntity.isDirectorySync(path)) return _icon(Icons.folder, color: const Color(0xFF5AC8FA));
    return _icon(iconForPath(path));
  }

  Widget _icon(IconData data, {Color color = ShelfColors.primaryText}) =>
      SizedBox(width: size, height: size, child: Icon(data, size: size * 0.9, color: color));
}

/// Material icon for a file's type, from its extension.
IconData iconForPath(String path) {
  final extension = p.extension(path).toLowerCase();
  switch (extension) {
    case '.pdf':
      return Icons.picture_as_pdf_outlined;
    case '.zip':
    case '.7z':
    case '.rar':
    case '.tar':
    case '.gz':
      return Icons.folder_zip_outlined;
    case '.exe':
    case '.msi':
    case '.bat':
    case '.cmd':
      return Icons.terminal;
    case '.lnk':
    case '.url':
      return Icons.link;
  }
  final mime = lookupMimeType(path) ?? '';
  if (mime.startsWith('image/')) return Icons.image_outlined;
  if (mime.startsWith('video/')) return Icons.movie_outlined;
  if (mime.startsWith('audio/')) return Icons.audiotrack_outlined;
  if (mime.startsWith('text/') || mime.contains('json') || mime.contains('xml')) {
    return Icons.description_outlined;
  }
  if (mime.contains('spreadsheet') || mime.contains('excel')) return Icons.table_chart_outlined;
  if (mime.contains('presentation') || mime.contains('powerpoint')) return Icons.slideshow_outlined;
  if (mime.contains('word') || mime.contains('document')) return Icons.article_outlined;
  return Icons.insert_drive_file_outlined;
}
