import AppKit
import Combine
import OSLog
import ServiceManagement

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
    @Published var hotkeyModifier: HotkeyModifier { didSet { save(hotkeyModifier.rawValue, Key.hotkeyModifier) } }
    @Published var showMenuBarIcon: Bool { didSet { save(showMenuBarIcon, Key.showMenuBarIcon) } }
    @Published private(set) var openAtLogin: Bool

    private enum Key {
        static let notchEnabled = "notchEnabled"
        static let openNotchOnHover = "openNotchOnHover"
        static let floatingEnabled = "floatingEnabled"
        static let hotkeyModifier = "hotkeyModifier"
        static let showMenuBarIcon = "showMenuBarIcon"
    }

    private let defaults = UserDefaults.standard
    private let log = Logger(subsystem: "local.notch-stash", category: "settings")

    private init() {
        defaults.register(defaults: [
            Key.notchEnabled: true,
            Key.openNotchOnHover: true,
            Key.floatingEnabled: true,
            Key.hotkeyModifier: HotkeyModifier.control.rawValue,
            Key.showMenuBarIcon: true
        ])
        notchEnabled = defaults.bool(forKey: Key.notchEnabled)
        openNotchOnHover = defaults.bool(forKey: Key.openNotchOnHover)
        floatingEnabled = defaults.bool(forKey: Key.floatingEnabled)
        hotkeyModifier = HotkeyModifier(rawValue: defaults.string(forKey: Key.hotkeyModifier) ?? "") ?? .control
        showMenuBarIcon = defaults.bool(forKey: Key.showMenuBarIcon)
        openAtLogin = SMAppService.mainApp.status == .enabled
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
