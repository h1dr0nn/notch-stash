import AppKit
import Carbon.HIToolbox
import NotchStashCore
import OSLog

/// A regular key combination such as ⌃⌥Space, registered with the system. Needs no privacy permission.
struct KeyCombo: Codable, Equatable {
    var keyCode: UInt32
    var carbonModifiers: UInt32
    var display: String
}

/// Registers one global key combination and calls back when it is pressed.
@MainActor
final class ComboHotKey {
    private let onPress: () -> Void
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let log = Logger(subsystem: "local.notch-stash", category: "hotkey")

    init(onPress: @escaping () -> Void) {
        self.onPress = onPress
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(),
            comboHotKeyCallback,
            1,
            &spec,
            Unmanaged.passUnretained(self).toOpaque(),
            &handler
        )
    }

    func register(_ combo: KeyCombo?) {
        unregister()
        guard let combo else { return }
        let identifier = EventHotKeyID(signature: OSType(0x4E53_5448), id: 1)
        let status = RegisterEventHotKey(combo.keyCode, combo.carbonModifiers, identifier, GetApplicationEventTarget(), 0, &hotKey)
        if status == noErr {
            log.notice("Registered \(combo.display, privacy: .public)")
        } else {
            log.error("Could not register \(combo.display, privacy: .public): \(status)")
        }
    }

    func unregister() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        hotKey = nil
    }

    fileprivate func pressed() {
        onPress()
    }
}

private func comboHotKeyCallback(
    _ call: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let userData else { return OSStatus(eventNotHandledErr) }
    let hotKey = Unmanaged<ComboHotKey>.fromOpaque(userData).takeUnretainedValue()
    MainActor.assumeIsolated { hotKey.pressed() }
    return noErr
}

extension KeyCombo {
    /// Builds a combination from a key-down event; nil when it has no ⌘, ⌥ or ⌃ and is not a function key.
    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        let hasCommandLike = !flags.isDisjoint(with: [.command, .option, .control])
        guard hasCommandLike || ShortcutFormatter.isFunctionKey(keyCode: event.keyCode) else { return nil }
        var modifiers: UInt32 = 0
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        let key = ShortcutFormatter.keyName(keyCode: event.keyCode, characters: event.charactersIgnoringModifiers)
        self.init(
            keyCode: UInt32(event.keyCode),
            carbonModifiers: modifiers,
            display: ShortcutFormatter.display(
                control: flags.contains(.control),
                option: flags.contains(.option),
                shift: flags.contains(.shift),
                command: flags.contains(.command),
                key: key
            )
        )
    }
}
