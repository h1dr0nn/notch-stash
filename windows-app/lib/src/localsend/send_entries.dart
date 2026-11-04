import 'dart:io';

import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;

/// A file to send; folders are flattened into their files with "/"-separated relative names.
class SendEntry {
  const SendEntry({required this.path, required this.name, required this.size, required this.mimeType});

  final String path;
  final String name;
  final int size;
  final String mimeType;
}

/// Expands [paths] into the files to send. Hidden files inside folders are skipped.
List<SendEntry> expandForSending(Iterable<String> paths) {
  final entries = <SendEntry>[];
  for (final path in paths) {
    final type = FileSystemEntity.typeSync(path);
    if (type == FileSystemEntityType.file) {
      entries.add(_entry(File(path), p.basename(path)));
    } else if (type == FileSystemEntityType.directory) {
      final root = Directory(path);
      final base = p.dirname(p.normalize(root.absolute.path));
      final children = root.listSync(recursive: true, followLinks: false).whereType<File>().toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      for (final child in children) {
        final relative = p.relative(child.absolute.path, from: base);
        final parts = p.split(relative);
        if (parts.any((part) => part.startsWith('.'))) continue;
        entries.add(_entry(child, parts.join('/')));
      }
    }
  }
  return entries;
}

SendEntry _entry(File file, String name) => SendEntry(
      path: file.path,
      name: name,
      size: file.lengthSync(),
      mimeType: lookupMimeType(file.path) ?? 'application/octet-stream',
    );
