/// Human-readable byte count, e.g. "1.4 MB" (decimal units, like Explorer's size column rounding).
String formatBytes(int bytes) {
  if (bytes < 1000) return bytes == 1 ? '1 byte' : '$bytes bytes';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1000;
  var unit = 0;
  while (value >= 1000 && unit < units.length - 1) {
    value /= 1000;
    unit++;
  }
  final digits = value >= 100 ? 0 : 1;
  return '${value.toStringAsFixed(digits)} ${units[unit]}';
}

/// Shortens [text] by replacing its middle with "…" until [fits] accepts it.
///
/// Keeps more of the start than the end so file extensions stay visible.
String middleEllipsis(String text, bool Function(String candidate) fits) {
  if (fits(text)) return text;
  final characters = text.runes.toList();
  var low = 0;
  var high = characters.length - 1;
  var best = '…';
  while (low <= high) {
    final keep = (low + high) ~/ 2;
    final candidate = _shorten(characters, keep);
    if (fits(candidate)) {
      best = candidate;
      low = keep + 1;
    } else {
      high = keep - 1;
    }
  }
  return best;
}

String _shorten(List<int> characters, int keep) {
  final tail = keep ~/ 2;
  final head = keep - tail;
  final start = String.fromCharCodes(characters.sublist(0, head));
  final end = String.fromCharCodes(characters.sublist(characters.length - tail));
  return '$start…$end';
}

/// "a file" or "N files".
String fileCount(int count) => count == 1 ? 'a file' : '$count files';
