import AppKit
import Combine
import OSLog
import ServiceManagement

/// How the floating shelf shortcut is triggered.
enum ShortcutKind: String, CaseIterable, Identifiable {
    case doubleTap, combination

    var id: String { rawValue }

    var title: String {
        switch self {
        case .doubleTap: "Double-Tap a Modifier"
        case .combination: "Key Combination"
        }
    }
}

/// Modifier key whose double tap toggles the floating shelf.
enum HotkeyModifier: String, CaseIterable, Identifiable {
    case control, option, command, shift

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .control: "⌃"
        case .option: "⌥"
        case .command: "⌘"
        case .shift: "⇧"
        }
    }

    var title: String {
        switch self {
        case .control: "Control"
        case .option: "Option"
        case .command: "Command"
        case .shift: "Shift"
        }
    }

    var flag: CGEventFlags {
        switch self {
        case .control: .maskControl
        case .option: .maskAlternate
        case .command: .maskCommand
        case .shift: .maskShift
        }
    }
}

/// User preferences, stored in UserDefaults.
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var notchEnabled: Bool { didSet { save(notchEnabled, Key.notchEnabled) } }
    @Published var openNotchOnHover: Bool { didSet { save(openNotchOnHover, Key.openNotchOnHover) } }
    @Published var floatingEnabled: Bool { didSet { save(floatingEnabled, Key.floatingEnabled) } }
    @Published var shortcutKind: ShortcutKind { didSet { save(shortcutKind.rawValue, Key.shortcutKind) } }
    @Published var hotkeyModifier: HotkeyModifier { didSet { save(hotkeyModifier.rawValue, Key.hotkeyModifier) } }
    @Published var keyCombo: KeyCombo? {
        didSet { defaults.set(keyCombo.flatMap { try? JSONEncoder().encode($0) }, forKey: Key.keyCombo) }
    }
    @Published var showMenuBarIcon: Bool { didSet { save(showMenuBarIcon, Key.showMenuBarIcon) } }
    @Published private(set) var openAtLogin: Bool
    @Published var nearbySharingEnabled: Bool { didSet { save(nearbySharingEnabled, Key.nearbySharingEnabled) } }
    @Published var receiveFiles: Bool { didSet { save(receiveFiles, Key.receiveFiles) } }
    @Published var deviceName: String { didSet { save(deviceName, Key.deviceName) } }
    @Published var saveFolderPath: String { didSet { save(saveFolderPath, Key.saveFolderPath) } }
    /// Random LocalSend identity, kept so other devices recognise this Mac.
    let localSendFingerprint: String

    private enum Key {
        static let notchEnabled = "notchEnabled"
        static let openNotchOnHover = "openNotchOnHover"
        static let floatingEnabled = "floatingEnabled"
        static let hotkeyModifier = "hotkeyModifier"
        static let shortcutKind = "shortcutKind"
        static let keyCombo = "keyCombo"
        static let showMenuBarIcon = "showMenuBarIcon"
        static let nearbySharingEnabled = "nearbySharingEnabled"
        static let receiveFiles = "receiveFiles"
        static let deviceName = "deviceName"
        static let saveFolderPath = "saveFolderPath"
        static let localSendFingerprint = "localSendFingerprint"
    }

    private let defaults = UserDefaults.standard
    private let log = Logger(subsystem: "local.notch-stash", category: "settings")

    private init() {
        defaults.register(defaults: [
            Key.notchEnabled: true,
            Key.openNotchOnHover: true,
            Key.floatingEnabled: true,
            Key.hotkeyModifier: HotkeyModifier.control.rawValue,
            Key.shortcutKind: ShortcutKind.doubleTap.rawValue,
            Key.showMenuBarIcon: true,
            Key.nearbySharingEnabled: true,
            Key.receiveFiles: true,
            Key.saveFolderPath: FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path
                ?? NSHomeDirectory() + "/Downloads"
        ])
        if defaults.string(forKey: Key.localSendFingerprint) == nil {
            defaults.set(UUID().uuidString, forKey: Key.localSendFingerprint)
        }
        notchEnabled = defaults.bool(forKey: Key.notchEnabled)
        openNotchOnHover = defaults.bool(forKey: Key.openNotchOnHover)
        floatingEnabled = defaults.bool(forKey: Key.floatingEnabled)
        hotkeyModifier = HotkeyModifier(rawValue: defaults.string(forKey: Key.hotkeyModifier) ?? "") ?? .control
        shortcutKind = ShortcutKind(rawValue: defaults.string(forKey: Key.shortcutKind) ?? "") ?? .doubleTap
        keyCombo = defaults.data(forKey: Key.keyCombo).flatMap { try? JSONDecoder().decode(KeyCombo.self, from: $0) }
        showMenuBarIcon = defaults.bool(forKey: Key.showMenuBarIcon)
        openAtLogin = SMAppService.mainApp.status == .enabled
        nearbySharingEnabled = defaults.bool(forKey: Key.nearbySharingEnabled)
        receiveFiles = defaults.bool(forKey: Key.receiveFiles)
        deviceName = defaults.string(forKey: Key.deviceName) ?? Host.current().localizedName ?? "Mac"
        saveFolderPath = defaults.string(forKey: Key.saveFolderPath) ?? NSHomeDirectory() + "/Downloads"
        localSendFingerprint = defaults.string(forKey: Key.localSendFingerprint) ?? UUID().uuidString
    }

    /// Human-readable shortcut, nil when a key combination is selected but not recorded yet.
    var shortcutDescription: String? {
        switch shortcutKind {
        case .doubleTap: "double-tap \(hotkeyModifier.symbol)"
        case .combination: keyCombo?.display
        }
    }

    func setOpenAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            log.error("Open at login change failed: \(error.localizedDescription, privacy: .public)")
        }
        openAtLogin = SMAppService.mainApp.status == .enabled
    }

    private func save(_ value: Any, _ key: String) {
        defaults.set(value, forKey: key)
    }
}
