import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// A file or folder held on the shelf, by reference.
@immutable
class ShelfItem {
  const ShelfItem({required this.id, required this.path, required this.name});

  final int id;
  final String path;

  /// File or folder name shown on the tile.
  final String name;
}

/// Ordered list of shelf items backed by file paths. Keeps references, never copies.
class ShelfStore extends ChangeNotifier {
  ShelfStore({
    bool Function(String path)? exists,
    p.Context? pathContext,
    bool? caseInsensitive,
  })  : _exists = exists ?? _entityExists,
        _path = pathContext ?? p.context,
        _caseInsensitive = caseInsensitive ?? Platform.isWindows;

  final bool Function(String path) _exists;
  final p.Context _path;
  final bool _caseInsensitive;
  final List<ShelfItem> _items = [];
  int _nextId = 1;

  static bool _entityExists(String path) =>
      FileSystemEntity.typeSync(path, followLinks: false) != FileSystemEntityType.notFound;

  List<ShelfItem> get items => List.unmodifiable(_items);
  bool get isEmpty => _items.isEmpty;
  int get length => _items.length;

  String _key(String path) {
    final normalized = _path.normalize(path);
    return _caseInsensitive ? normalized.toLowerCase() : normalized;
  }

  /// Adds paths that exist and are not on the shelf yet; returns the new items.
  List<ShelfItem> add(Iterable<String> paths) {
    final seen = _items.map((item) => _key(item.path)).toSet();
    final added = <ShelfItem>[];
    for (final raw in paths) {
      if (raw.isEmpty) continue;
      final path = _path.normalize(raw);
      final key = _key(path);
      if (seen.contains(key) || !_exists(path)) continue;
      seen.add(key);
      final base = _path.basename(path);
      added.add(ShelfItem(id: _nextId++, path: path, name: base.isEmpty ? path : base));
    }
    if (added.isNotEmpty) {
      _items.addAll(added);
      notifyListeners();
    }
    return added;
  }

  void remove(Iterable<int> ids) {
    final targets = ids.toSet();
    final before = _items.length;
    _items.removeWhere((item) => targets.contains(item.id));
    if (_items.length != before) notifyListeners();
  }

  void removeAll() {
    if (_items.isEmpty) return;
    _items.clear();
    notifyListeners();
  }

  /// Drops items whose file disappeared; returns how many were removed.
  int pruneMissing() {
    final before = _items.length;
    _items.removeWhere((item) => !_exists(item.path));
    final removed = before - _items.length;
    if (removed > 0) notifyListeners();
    return removed;
  }
}
