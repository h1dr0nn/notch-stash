import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'core/shelf_store.dart';
import 'core/shortcut.dart';
import 'localsend/service.dart';
import 'platform/global_hotkey.dart';
import 'platform/native_menu.dart';
import 'platform/shell.dart';
import 'platform/startup.dart';
import 'platform/tray.dart';
import 'platform/window_host.dart';
import 'settings.dart';
import 'updater.dart';

/// Ties the shelf, the window, the tray, the hotkey and nearby sharing together.
class AppController extends ChangeNotifier {
  AppController({required this.settings, required this.version}) {
    store = ShelfStore();
    localSend = LocalSendService(settings: settings, onFilesReceived: store.add);
    window = WindowHost(onCloseRequested: closeCurrent);
    hotkey = GlobalHotkey(onPressed: toggleShelf);
    tray = AppTray(
      onToggleShelf: toggleShelf,
      onSettings: openSettings,
      onQuit: () => unawaited(quit()),
      isShelfVisible: () => _mode == WindowMode.shelf && window.isVisible,
      availableUpdate: () => updater.available?.version.toString(),
    );
    updater = Updater(currentVersion: version, isEnabled: () => settings.checkForUpdates, onInstallerStarted: quit);
  }

  final AppSettings settings;
  final String version;
  late final ShelfStore store;
  late final LocalSendService localSend;
  late final WindowHost window;
  late final GlobalHotkey hotkey;
  late final AppTray tray;
  late final Updater updater;
  final NativeMenus menus = NativeMenus();

  WindowMode _mode = WindowMode.hidden;
  WindowMode _beforeIncoming = WindowMode.hidden;
  List<String> _sendPaths = const [];
  bool _hotkeyFailed = false;
  bool _startWithWindows = false;
  Timer? _pruneTimer;
  String? _lastIncomingId;

  WindowMode get mode => _mode;
  List<String> get sendPaths => _sendPaths;

  /// True when Windows refused the shortcut (another app may own it).
  bool get hotkeyFailed => _hotkeyFailed;
  bool get startWithWindows => _startWithWindows;

  Future<void> start({required bool showSettings}) async {
    window.init();
    tray.install();
    StartupEntry.setup();
    _startWithWindows = await StartupEntry.isEnabled();
    _hotkeyFailed = !await hotkey.register(settings.shortcut);
    localSend.addListener(_onLocalSendChanged);
    await localSend.applySettings();
    _pruneTimer = Timer.periodic(const Duration(seconds: 2), (_) => _prune());
    updater.startAutomaticChecks();
    if (showSettings) openSettings();
    notifyListeners();
  }

  // Window modes

  void _present(WindowMode mode, {bool keepPosition = false}) {
    _mode = mode;
    notifyListeners();
    window.present(mode, keepPosition: keepPosition);
  }

  void showShelf() => _present(WindowMode.shelf);

  void hide() {
    _mode = WindowMode.hidden;
    window.hide();
    notifyListeners();
  }

  void toggleShelf() {
    if (_mode == WindowMode.incoming) return;
    if (_mode == WindowMode.shelf && window.isVisible) {
      hide();
    } else {
      showShelf();
    }
  }

  void openSettings() {
    if (_mode == WindowMode.incoming) return;
    _present(WindowMode.settings);
  }

  void openSend(List<String> paths) {
    if (paths.isEmpty) return;
    _sendPaths = List.unmodifiable(paths);
    localSend.clearFinishedTransfers();
    _present(WindowMode.send, keepPosition: _mode == WindowMode.shelf);
    unawaited(localSend.scan());
  }

  /// × in the header, Escape or Alt+F4: the send dialog goes back to the shelf,
  /// everything else hides.
  void closeCurrent() {
    switch (_mode) {
      case WindowMode.send:
        if (store.isEmpty) {
          hide();
        } else {
          _present(WindowMode.shelf, keepPosition: true);
        }
      case WindowMode.incoming:
        localSend.decideIncoming(accept: false);
      case WindowMode.shelf:
      case WindowMode.settings:
      case WindowMode.hidden:
        hide();
    }
  }

  // Shelf

  void addFiles(Iterable<String> paths) => store.add(paths);

  /// Called when a drag out of the shelf ended. A copy or move delivered the files;
  /// otherwise they stay, unless the target moved them away (checked after a moment).
  void dragEnded(List<int> ids, {required bool delivered}) {
    if (delivered) {
      store.remove(ids);
      _hideIfEmptiedByDrag();
    } else {
      Timer(const Duration(milliseconds: 600), () {
        if (store.pruneMissing() > 0) _hideIfEmptiedByDrag();
      });
    }
  }

  void _hideIfEmptiedByDrag() {
    if (store.isEmpty && _mode == WindowMode.shelf) hide();
  }

  void _prune() => store.pruneMissing();

  void showItemMenu(ShelfItem item) {
    menus.popUpAtCursor([
      NativeMenuEntry('Open', () => unawaited(Shell.open(item.path))),
      NativeMenuEntry('Show in Explorer', () => unawaited(Shell.showInExplorer(item.path))),
      const NativeMenuEntry.separator(),
      NativeMenuEntry('Send to Device…', () => openSend([item.path])),
      const NativeMenuEntry.separator(),
      NativeMenuEntry('Remove', () => store.remove([item.id])),
    ]);
  }

  // Nearby sharing

  void _onLocalSendChanged() {
    final incoming = localSend.incoming;
    if (incoming != null && incoming.id != _lastIncomingId) {
      _lastIncomingId = incoming.id;
      if (_mode != WindowMode.incoming) _beforeIncoming = _mode;
      _present(WindowMode.incoming);
    } else if (incoming == null && _mode == WindowMode.incoming) {
      _lastIncomingId = null;
      _restoreAfterIncoming();
    }
  }

  void acceptIncoming() {
    // Received files land on the shelf, so show it once the prompt closes.
    _beforeIncoming = WindowMode.shelf;
    localSend.decideIncoming(accept: true);
  }

  void declineIncoming() => localSend.decideIncoming(accept: false);

  void _restoreAfterIncoming() {
    final previous = _beforeIncoming;
    _beforeIncoming = WindowMode.hidden;
    if (previous == WindowMode.hidden) {
      hide();
    } else {
      _present(previous);
    }
  }

  // Settings

  Future<bool> setShortcut(Shortcut shortcut) async {
    await settings.setShortcut(shortcut);
    _hotkeyFailed = !await hotkey.register(shortcut);
    notifyListeners();
    return !_hotkeyFailed;
  }

  Future<void> pauseHotkey() => hotkey.pause();

  Future<void> resumeHotkey() async {
    _hotkeyFailed = !await hotkey.resume();
    notifyListeners();
  }

  Future<void> setStartWithWindows(bool enabled) async {
    await StartupEntry.setEnabled(enabled);
    _startWithWindows = await StartupEntry.isEnabled();
    notifyListeners();
  }

  Future<void> setNearbySharing(bool enabled) async {
    await settings.setNearbySharingEnabled(enabled);
    await localSend.applySettings();
  }

  /// Renames this PC for other devices and tells them right away.
  Future<void> setDeviceName(String name) async {
    if (name.trim() == settings.deviceName) return;
    await settings.setDeviceName(name);
    await localSend.scan();
  }

  Future<void> quit() async {
    _pruneTimer?.cancel();
    window.hide();
    tray.dispose();
    await hotkey.dispose();
    await localSend.shutdown();
    exit(0);
  }
}
