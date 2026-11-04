/// Helpers for turning received file names into safe, collision-free relative paths.
///
/// Paths use "/" as separator; callers join them with the platform separator.
class FileNaming {
  FileNaming._();

  static final _invalidCharacters = RegExp(r'[<>:"|?*\x00-\x1F]');
  static const _reservedNames = {
    'CON', 'PRN', 'AUX', 'NUL', //
    'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9',
    'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9',
  };

  /// Drops empty, "." and ".." components and characters Windows does not allow,
  /// so the result can never escape its base folder.
  static String safeRelativePath(String fileName) {
    final components = fileName
        .replaceAll(r'\', '/')
        .split('/')
        .map(_safeComponent)
        .where((part) => part.isNotEmpty && part != '.' && part != '..')
        .toList();
    return components.isEmpty ? 'file' : components.join('/');
  }

  static String _safeComponent(String component) {
    var cleaned = component.replaceAll(_invalidCharacters, '_');
    // Windows strips trailing dots and spaces, which would merge names.
    cleaned = cleaned.replaceAll(RegExp(r'[. ]+$'), '');
    if (cleaned.isEmpty) return cleaned;
    final stem = cleaned.split('.').first.toUpperCase();
    if (_reservedNames.contains(stem)) cleaned = '_$cleaned';
    return cleaned;
  }

  /// Appends " (n)" before the extension of the last component until [exists]
  /// reports a free name.
  static String uniqueName(String fileName, bool Function(String candidate) exists) {
    final path = safeRelativePath(fileName);
    if (!exists(path)) return path;

    final components = path.split('/');
    final last = components.removeLast();
    final prefix = components.isEmpty ? '' : '${components.join('/')}/';
    final dot = last.lastIndexOf('.');
    final hasExtension = dot > 0 && dot < last.length - 1;
    final stem = hasExtension ? last.substring(0, dot) : last;
    final extension = hasExtension ? last.substring(dot) : '';

    for (var counter = 1;; counter++) {
      final candidate = '$prefix$stem ($counter)$extension';
      if (!exists(candidate)) return candidate;
    }
  }
}
