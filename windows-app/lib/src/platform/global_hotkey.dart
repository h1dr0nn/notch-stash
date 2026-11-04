import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

import '../core/shortcut.dart';

/// Registers the system-wide shortcut that toggles the shelf.
class GlobalHotkey {
  GlobalHotkey({required this.onPressed});

  final VoidCallback onPressed;
  Shortcut? _active;
  bool _paused = false;

  /// Replaces the registered shortcut; returns false when Windows refused it
  /// (usually because another app owns the combination).
  Future<bool> register(Shortcut shortcut) async {
    _active = shortcut;
    if (_paused) return true;
    return _apply();
  }

  Future<bool> _apply() async {
    final shortcut = _active;
    try {
      await hotKeyManager.unregisterAll();
      if (shortcut == null) return true;
      await hotKeyManager.register(
        HotKey(
          identifier: 'toggle-shelf',
          key: shortcut.physical,
          modifiers: shortcut.orderedModifiers.map(_modifier).toList(),
          scope: HotKeyScope.system,
        ),
        keyDownHandler: (_) => onPressed(),
      );
      return true;
    } on Object {
      return false;
    }
  }

  /// Lets the shortcut recorder see the keys without toggling the shelf.
  Future<void> pause() async {
    if (_paused) return;
    _paused = true;
    try {
      await hotKeyManager.unregisterAll();
    } on PlatformException {
      // Nothing was registered.
    }
  }

  Future<bool> resume() async {
    if (!_paused) return true;
    _paused = false;
    return _apply();
  }

  Future<void> dispose() async {
    _active = null;
    try {
      await hotKeyManager.unregisterAll();
    } on PlatformException {
      // Already gone.
    }
  }

  static HotKeyModifier _modifier(ShortcutModifier modifier) => switch (modifier) {
        ShortcutModifier.control => HotKeyModifier.control,
        ShortcutModifier.alt => HotKeyModifier.alt,
        ShortcutModifier.shift => HotKeyModifier.shift,
        ShortcutModifier.meta => HotKeyModifier.meta,
      };
}
