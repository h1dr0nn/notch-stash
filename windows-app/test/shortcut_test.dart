import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notch_stash/src/core/shortcut.dart';

void main() {
  test('default is Ctrl+Alt+Space', () {
    expect(Shortcut.defaultShortcut.label, 'Ctrl+Alt+Space');
  });

  test('builds from a key press with held modifiers', () {
    final shortcut = Shortcut.fromKeyPress(
      physical: PhysicalKeyboardKey.keyK,
      logical: LogicalKeyboardKey.keyK,
      pressed: {PhysicalKeyboardKey.shiftLeft, PhysicalKeyboardKey.controlRight, PhysicalKeyboardKey.keyK},
    );
    expect(shortcut!.label, 'Ctrl+Shift+K');
  });

  test('needs a modifier and a non-modifier key', () {
    expect(
      Shortcut.fromKeyPress(
        physical: PhysicalKeyboardKey.keyK,
        logical: LogicalKeyboardKey.keyK,
        pressed: {PhysicalKeyboardKey.keyK},
      ),
      isNull,
    );
    expect(
      Shortcut.fromKeyPress(
        physical: PhysicalKeyboardKey.altLeft,
        logical: LogicalKeyboardKey.altLeft,
        pressed: {PhysicalKeyboardKey.altLeft, PhysicalKeyboardKey.controlLeft},
      ),
      isNull,
    );
  });

  test('labels named and function keys', () {
    Shortcut make(PhysicalKeyboardKey physical, LogicalKeyboardKey logical) => Shortcut(
          modifiers: const {ShortcutModifier.meta, ShortcutModifier.alt},
          physicalKey: physical.usbHidUsage,
          logicalKey: logical.keyId,
        );
    expect(make(PhysicalKeyboardKey.f5, LogicalKeyboardKey.f5).label, 'Alt+Win+F5');
    expect(make(PhysicalKeyboardKey.arrowUp, LogicalKeyboardKey.arrowUp).label, 'Alt+Win+Up');
    expect(make(PhysicalKeyboardKey.digit1, LogicalKeyboardKey.digit1).label, 'Alt+Win+1');
  });

  test('round-trips through JSON and rejects bad data', () {
    final shortcut = Shortcut.defaultShortcut;
    final decoded = Shortcut.fromJson(jsonDecode(jsonEncode(shortcut.toJson())));
    expect(decoded, shortcut);
    expect(decoded.hashCode, shortcut.hashCode);
    expect(Shortcut.fromJson({'modifiers': [], 'physicalKey': 1, 'logicalKey': 1}), isNull);
    expect(Shortcut.fromJson({'modifiers': ['hyper'], 'physicalKey': 1, 'logicalKey': 1}), isNull);
    expect(Shortcut.fromJson('Ctrl+Alt+Space'), isNull);
    expect(
      Shortcut.fromJson({
        'modifiers': ['control'],
        'physicalKey': PhysicalKeyboardKey.shiftLeft.usbHidUsage,
        'logicalKey': LogicalKeyboardKey.shiftLeft.keyId,
      }),
      isNull,
    );
  });
}
