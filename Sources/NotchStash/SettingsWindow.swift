import AppKit
import SwiftUI

/// Preferences form.
private struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    let isShortcutActive: () -> Bool

    var body: some View {
        Form {
            Section("Shelves") {
                Toggle(isOn: $settings.notchEnabled) {
                    Text("Notch Shelf")
                    Text("Drops down from the notch when you point at it or drag files onto it.")
                }
                Toggle(isOn: $settings.openNotchOnHover) {
                    Text("Open on Hover")
                    Text("When off, the notch shelf opens only when you drag files onto it.")
                }
                .disabled(!settings.notchEnabled)
                Toggle(isOn: $settings.floatingEnabled) {
                    Text("Floating Shelf")
                    Text("Shows a shelf next to the pointer when you use the shortcut.")
                }
            }

            Section("Shortcut") {
                Picker(selection: $settings.hotkeyModifier) {
                    ForEach(HotkeyModifier.allCases) { modifier in
                        Text("\(modifier.symbol) \(modifier.title)").tag(modifier)
                    }
                } label: {
                    Text("Double-Tap")
                    Text("Tap the key twice quickly, without other keys.")
                }
                .disabled(!settings.floatingEnabled)
                TimelineView(.periodic(from: .now, by: 2)) { _ in
                    let active = isShortcutActive()
                    LabeledContent {
                        if active {
                            Label("Allowed", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Button("Open Privacy Settings") { HotkeyMonitor.openPrivacySettings() }
                        }
                    } label: {
                        Text("Input Monitoring")
                        Text(active
                            ? "The shortcut works in every app."
                            : "Needed for the shortcut. Switch on Notch Stash in Input Monitoring.")
                    }
                }
            }

            Section("General") {
                Toggle(isOn: $settings.showMenuBarIcon) {
                    Text("Show Menu Bar Icon")
                    Text("When hidden, open Notch Stash again from Applications to come back here.")
                }
                Toggle(isOn: Binding(get: { settings.openAtLogin }, set: { settings.setOpenAtLogin($0) })) {
                    Text("Open at Login")
                }
            }

            Section {
                LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–")
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Owns the settings window.
@MainActor
final class SettingsWindowController {
    private var window: NSWindow?
    private let isShortcutActive: () -> Bool

    init(isShortcutActive: @escaping () -> Bool) {
        self.isShortcutActive = isShortcutActive
    }

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView(settings: .shared, isShortcutActive: isShortcutActive))
            let window = NSWindow(contentViewController: hosting)
            window.title = "Notch Stash Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}
