import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart' as native;

import 'native_menu.dart';

/// The notification-area icon: left click toggles the shelf, right click opens the menu.
class AppTray {
  AppTray({
    required this.onToggleShelf,
    required this.onSettings,
    required this.onQuit,
    required this.isShelfVisible,
    required this.availableUpdate,
  });

  final VoidCallback onToggleShelf;
  final VoidCallback onSettings;
  final VoidCallback onQuit;
  final bool Function() isShelfVisible;

  /// Version of a newer release, shown as a menu item that opens Settings.
  final String? Function() availableUpdate;

  native.TrayIcon? _icon;
  native.Menu? _menu;

  void install() {
    final icon = native.TrayIcon.create();
    if (icon == null) return;
    icon.icon = native.ImageAsset.fromAsset('assets/tray_icon.png');
    icon.setTooltip('Notch Stash');
    icon.setContextMenuTrigger(native.ContextMenuTrigger.none);
    icon.addListener((event) {
      switch (event) {
        case native.TrayIconClickedEvent():
          onToggleShelf();
        case native.TrayIconRightClickedEvent():
          _openMenu();
        default:
          break;
      }
    });
    icon.setVisible(true);
    _icon = icon;
  }

  /// Rebuilt on every open so the first item says Show Shelf or Hide Shelf.
  void _openMenu() {
    final icon = _icon;
    if (icon == null) return;
    final update = availableUpdate();
    final menu = NativeMenus.build([
      if (update != null) ...[NativeMenuEntry('Update to $update…', onSettings), const NativeMenuEntry.separator()],
      NativeMenuEntry(isShelfVisible() ? 'Hide Shelf' : 'Show Shelf', onToggleShelf),
      const NativeMenuEntry.separator(),
      NativeMenuEntry('Settings…', onSettings),
      const NativeMenuEntry.separator(),
      NativeMenuEntry('Quit Notch Stash', onQuit),
    ]);
    if (menu == null) return;
    icon.setContextMenu(menu);
    _menu?.dispose();
    _menu = menu;
    icon.openContextMenu();
  }

  void dispose() {
    _icon?.setVisible(false);
    _icon?.dispose();
    _icon = null;
    _menu?.dispose();
    _menu = null;
  }
}
