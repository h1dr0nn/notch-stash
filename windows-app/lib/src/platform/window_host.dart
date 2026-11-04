import 'dart:ui';

import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import '../core/placement.dart';

/// What the single app window shows.
enum WindowMode {
  hidden(Size.zero),
  shelf(Size(380, 190)),
  send(Size(420, 460)),
  incoming(Size(360, 340)),
  settings(Size(480, 780));

  const WindowMode(this.size);
  final Size size;
}

/// Drives the native window: frameless, sized and placed for each [WindowMode].
class WindowHost {
  WindowHost({required this.onCloseRequested});

  /// Alt+F4 or the system close command; the app hides instead of quitting.
  final VoidCallback onCloseRequested;

  Window? _window;

  void init() {
    final window = WindowManager.instance.getCurrent();
    if (window == null) return;
    _window = window;
    window
      ..title = 'Notch Stash'
      ..isResizable = false
      ..isMaximizable = false
      ..isMinimizable = false
      ..isFullScreenable = false
      ..hasShadow = true;
    window.setFrameless(true);
    if (Window.isCornerPreferenceSupported()) {
      window.setCornerPreference(WindowCornerPreference.round);
    }
    window.addListener((event) {
      if (event is WindowCloseRequestedEvent) {
        event.request.cancel();
        onCloseRequested();
      }
    });
  }

  bool get isVisible => _window?.isVisible ?? false;

  /// Shows [mode]: the shelf next to the pointer, other modes centred on the pointer's screen.
  void present(WindowMode mode, {bool keepPosition = false}) {
    final window = _window;
    if (window == null || mode == WindowMode.hidden) return;
    final size = mode.size;
    final cursor = DisplayManager.instance.getCursorPosition().toOffset();
    final areas = DisplayManager.instance.getAll().map((display) => display.workArea.toRect()).toList();
    final area = workAreaFor(cursor, areas) ?? Rect.fromLTWH(0, 0, size.width * 3, size.height * 3);

    Offset origin;
    if (keepPosition && window.isVisible) {
      final current = window.bounds.toRect();
      final currentArea = workAreaFor(current.center, areas) ?? area;
      origin = shelfOrigin(cursor: Offset(current.center.dx, current.top - 16), workArea: currentArea, size: size);
    } else if (mode == WindowMode.shelf) {
      origin = shelfOrigin(cursor: cursor, workArea: area, size: size);
    } else {
      origin = centeredOrigin(workArea: area, size: size);
    }

    final onTop = mode != WindowMode.settings;
    window
      ..isVisibleInTaskbar = mode == WindowMode.settings
      ..isAlwaysOnTop = onTop
      ..bounds = Rect.fromLTWH(origin.dx, origin.dy, size.width, size.height).toNative();
    window.show();
    window.focus();
  }

  void hide() => _window?.hide();

  /// Moves the window while the pointer drags its header.
  void startDragging() => _window?.startDragging();
}
