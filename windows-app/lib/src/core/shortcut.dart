import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Modifier keys a global shortcut can combine, in display order.
enum ShortcutModifier {
  control('Ctrl'),
  alt('Alt'),
  shift('Shift'),
  meta('Win');

  const ShortcutModifier(this.label);
  final String label;
}

/// A global key combination such as Ctrl+Alt+Space.
@immutable
class Shortcut {
  const Shortcut({required this.modifiers, required this.physicalKey, required this.logicalKey});

  /// The default: Ctrl+Alt+Space.
  static final Shortcut defaultShortcut = Shortcut(
    modifiers: const {ShortcutModifier.control, ShortcutModifier.alt},
    physicalKey: PhysicalKeyboardKey.space.usbHidUsage,
    logicalKey: LogicalKeyboardKey.space.keyId,
  );

  final Set<ShortcutModifier> modifiers;

  /// USB HID usage of the key, as in [PhysicalKeyboardKey.usbHidUsage].
  final int physicalKey;

  /// Logical key id, as in [LogicalKeyboardKey.keyId]; used for the label.
  final int logicalKey;

  static const _modifierKeys = {
    ShortcutModifier.control: [PhysicalKeyboardKey.controlLeft, PhysicalKeyboardKey.controlRight],
    ShortcutModifier.alt: [PhysicalKeyboardKey.altLeft, PhysicalKeyboardKey.altRight],
    ShortcutModifier.shift: [PhysicalKeyboardKey.shiftLeft, PhysicalKeyboardKey.shiftRight],
    ShortcutModifier.meta: [PhysicalKeyboardKey.metaLeft, PhysicalKeyboardKey.metaRight],
  };

  static bool isModifierKey(PhysicalKeyboardKey key) =>
      _modifierKeys.values.any((keys) => keys.contains(key));

  /// Builds a shortcut from a key press while [pressed] keys are held.
  /// Returns null for a lone modifier or a key without any modifier.
  static Shortcut? fromKeyPress({
    required PhysicalKeyboardKey physical,
    required LogicalKeyboardKey logical,
    required Set<PhysicalKeyboardKey> pressed,
  }) {
    if (isModifierKey(physical)) return null;
    final modifiers = {
      for (final entry in _modifierKeys.entries)
        if (entry.value.any(pressed.contains)) entry.key,
    };
    if (modifiers.isEmpty) return null;
    return Shortcut(modifiers: modifiers, physicalKey: physical.usbHidUsage, logicalKey: logical.keyId);
  }

  PhysicalKeyboardKey get physical => PhysicalKeyboardKey(physicalKey);
  LogicalKeyboardKey get logical => LogicalKeyboardKey(logicalKey);

  List<ShortcutModifier> get orderedModifiers =>
      ShortcutModifier.values.where(modifiers.contains).toList();

  static final _namedKeys = <LogicalKeyboardKey, String>{
    LogicalKeyboardKey.space: 'Space',
    LogicalKeyboardKey.enter: 'Enter',
    LogicalKeyboardKey.tab: 'Tab',
    LogicalKeyboardKey.escape: 'Esc',
    LogicalKeyboardKey.backspace: 'Backspace',
    LogicalKeyboardKey.delete: 'Delete',
    LogicalKeyboardKey.insert: 'Insert',
    LogicalKeyboardKey.home: 'Home',
    LogicalKeyboardKey.end: 'End',
    LogicalKeyboardKey.pageUp: 'Page Up',
    LogicalKeyboardKey.pageDown: 'Page Down',
    LogicalKeyboardKey.arrowUp: 'Up',
    LogicalKeyboardKey.arrowDown: 'Down',
    LogicalKeyboardKey.arrowLeft: 'Left',
    LogicalKeyboardKey.arrowRight: 'Right',
  };

  /// Name of the non-modifier key, e.g. "Space", "A", "F5".
  String get keyLabel {
    final named = _namedKeys[logical];
    if (named != null) return named;
    final label = logical.keyLabel.trim();
    if (label.isNotEmpty) return label.length == 1 ? label.toUpperCase() : label;
    return 'Key ${physicalKey.toRadixString(16)}';
  }

  /// "Ctrl+Alt+Space".
  String get label => [...orderedModifiers.map((m) => m.label), keyLabel].join('+');

  Map<String, Object> toJson() => {
        'modifiers': orderedModifiers.map((m) => m.name).toList(),
        'physicalKey': physicalKey,
        'logicalKey': logicalKey,
      };

  static Shortcut? fromJson(Object? json) {
    if (json is! Map) return null;
    final names = json['modifiers'];
    final physical = json['physicalKey'];
    final logical = json['logicalKey'];
    if (names is! List || physical is! int || logical is! int) return null;
    final modifiers = <ShortcutModifier>{};
    for (final name in names) {
      final match = ShortcutModifier.values.where((m) => m.name == name);
      if (match.isEmpty) return null;
      modifiers.add(match.first);
    }
    if (modifiers.isEmpty || isModifierKey(PhysicalKeyboardKey(physical))) return null;
    return Shortcut(modifiers: modifiers, physicalKey: physical, logicalKey: logical);
  }

  @override
  bool operator ==(Object other) =>
      other is Shortcut &&
      setEquals(other.modifiers, modifiers) &&
      other.physicalKey == physicalKey &&
      other.logicalKey == logicalKey;

  @override
  int get hashCode => Object.hash(Object.hashAllUnordered(modifiers), physicalKey, logicalKey);

  @override
  String toString() => label;
}
