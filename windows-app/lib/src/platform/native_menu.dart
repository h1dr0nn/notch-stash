import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart' as native;

/// One entry of a native menu; a null [label] is a separator.
class NativeMenuEntry {
  const NativeMenuEntry(this.label, this.onSelected);
  const NativeMenuEntry.separator()
      : label = null,
        onSelected = null;

  final String? label;
  final VoidCallback? onSelected;
}

/// Builds native (Win32) menus and keeps them alive while they can still be clicked.
class NativeMenus {
  native.Menu? _contextMenu;

  /// Creates a menu whose items call their callbacks; returns null when menus are unsupported.
  static native.Menu? build(List<NativeMenuEntry> entries) {
    final menu = native.Menu.create();
    if (menu == null) return null;
    for (final entry in entries) {
      final label = entry.label;
      if (label == null) {
        menu.addSeparator();
        continue;
      }
      final item = native.MenuItem.createWithLabelAndType(label, native.MenuItemType.normal);
      if (item == null) continue;
      final onSelected = entry.onSelected;
      item.addListener((event) {
        if (event is native.MenuItemClickedEvent) onSelected?.call();
      });
      menu.addItem(item);
    }
    return menu;
  }

  /// Opens a context menu at the pointer.
  void popUpAtCursor(List<NativeMenuEntry> entries) {
    final menu = build(entries);
    final position = native.PositioningStrategy.cursorPosition();
    if (menu == null || position == null) return;
    _contextMenu?.dispose();
    _contextMenu = menu;
    menu.open(position, native.Placement.bottomStart);
  }
}
