/// Builds the display text for a key combination, e.g. "⌃⌥Space".
public enum ShortcutFormatter {
    public static func display(control: Bool, option: Bool, shift: Bool, command: Bool, key: String) -> String {
        var text = ""
        if control { text += "⌃" }
        if option { text += "⌥" }
        if shift { text += "⇧" }
        if command { text += "⌘" }
        return text + key
    }

    /// Name for a virtual key code, falling back to the typed characters for letter and symbol keys.
    public static func keyName(keyCode: UInt16, characters: String?) -> String {
        if let name = namedKeys[keyCode] { return name }
        let trimmed = (characters ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Key \(keyCode)" : trimmed.uppercased()
    }

    /// Whether the key may be used without ⌘, ⌥ or ⌃ (function keys).
    public static func isFunctionKey(keyCode: UInt16) -> Bool {
        functionKeys.contains(keyCode)
    }

    private static let functionKeys: Set<UInt16> = [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111, 105, 107, 113, 106, 64, 79, 80]

    private static let namedKeys: [UInt16: String] = [
        49: "Space", 36: "↩", 48: "⇥", 51: "⌫", 117: "⌦", 53: "⎋",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        115: "↖", 119: "↘", 116: "⇞", 121: "⇟",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
        105: "F13", 107: "F14", 113: "F15", 106: "F16", 64: "F17", 79: "F18", 80: "F19"
    ]
}
