import AppKit
import SwiftUI

/// Settings tabs shown in the window toolbar.
enum SettingsTab: CaseIterable {
    case general, shortcut, sharing, updates

    var title: String {
        switch self {
        case .general: "General"
        case .shortcut: "Shortcut"
        case .sharing: "Sharing"
        case .updates: "Updates"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .shortcut: "keyboard"
        case .sharing: "antenna.radiowaves.left.and.right"
        case .updates: "arrow.triangle.2.circlepath"
        }
    }
}

/// Preferences form for one tab.
private struct SettingsView: View {
    let tab: SettingsTab
    @ObservedObject var settings: AppSettings
    let isShortcutActive: () -> Bool
    let onRecordingChange: (Bool) -> Void
    @ObservedObject var localNetwork: LocalNetworkPermission
    @ObservedObject var updater: Updater

    var body: some View {
        Form {
            switch tab {
            case .general:
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
                Section("App") {
                    Toggle(isOn: $settings.showMenuBarIcon) {
                        Text("Show Menu Bar Icon")
                        Text("When hidden, open Notch Stash again from Applications to come back here.")
                    }
                    Toggle(isOn: Binding(get: { settings.openAtLogin }, set: { settings.setOpenAtLogin($0) })) {
                        Text("Open at Login")
                    }
                }
            case .shortcut:
                Section("Shortcut") {
                    Picker(selection: $settings.shortcutKind) {
                        ForEach(ShortcutKind.allCases) { kind in
                            Text(kind.title).tag(kind)
                        }
                    } label: {
                        Text("Shortcut Type")
                        Text("Shows or hides the floating shelf.")
                    }
                    if settings.shortcutKind == .doubleTap {
                        Picker(selection: $settings.hotkeyModifier) {
                            ForEach(HotkeyModifier.allCases) { modifier in
                                Text("\(modifier.symbol) \(modifier.title)").tag(modifier)
                            }
                        } label: {
                            Text("Double-Tap")
                            Text("Tap the key twice quickly, without other keys.")
                        }
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
                                    : "Needed for double-tap. Switch on Notch Stash in Input Monitoring.")
                            }
                        }
                    } else {
                        LabeledContent {
                            ShortcutRecorder(combo: $settings.keyCombo, onRecordingChange: onRecordingChange)
                        } label: {
                            Text("Key Combination")
                            Text("Click, then press keys with ⌘, ⌥ or ⌃. Needs no extra permission.")
                        }
                    }
                }
                .disabled(!settings.floatingEnabled)
            case .sharing:
                Section("Nearby Sharing") {
                    Toggle(isOn: $settings.nearbySharingEnabled) {
                        Text("Nearby Sharing")
                        Text("Send and receive files with devices running LocalSend on the same network.")
                    }
                    Group {
                        Toggle(isOn: $settings.receiveFiles) {
                            Text("Receive Files")
                            Text("Other devices can send files to this Mac after you accept them.")
                        }
                        LabeledContent {
                            switch localNetwork.state {
                            case .allowed:
                                Label("Allowed", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                            case .denied:
                                Button("Open Privacy Settings") { LocalNetworkPermission.openPrivacySettings() }
                            case .unknown:
                                Text("Checking…").foregroundStyle(.secondary)
                            }
                        } label: {
                            Text("Local Network")
                            Text(localNetwork.state == .denied
                                ? "Needed to find devices. Switch on Notch Stash in Local Network."
                                : "Needed to find devices on your network.")
                        }
                        TextField("Device Name", text: $settings.deviceName)
                        LabeledContent {
                            HStack(spacing: 8) {
                                Text((settings.saveFolderPath as NSString).abbreviatingWithTildeInPath)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .foregroundStyle(.secondary)
                                Button("Choose…") { chooseSaveFolder() }
                            }
                        } label: {
                            Text("Save To")
                            Text("Received files are saved here and added to the shelf.")
                        }
                    }
                    .disabled(!settings.nearbySharingEnabled)
                }
            case .updates:
                Section("Updates") {
                    Toggle(isOn: $settings.checkForUpdates) {
                        Text("Check for Updates Automatically")
                        Text("Looks for a new version on GitHub once a day.")
                    }
                    LabeledContent {
                        updateControl
                    } label: {
                        Text("Version \(updater.currentVersion)")
                        Text(updateStatus)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }
}

extension SettingsView {
    @ViewBuilder
    fileprivate var updateControl: some View {
        switch updater.state {
        case let .available(release):
            HStack(spacing: 8) {
                Button("Release Notes") { NSWorkspace.shared.open(release.pageURL) }
                Button("Update and Relaunch") { Task { await updater.install(release) } }
                    .keyboardShortcut(.defaultAction)
            }
        case let .downloading(fraction):
            ProgressView(value: fraction).frame(width: 120)
        case .checking, .installing:
            ProgressView().controlSize(.small)
        default:
            Button("Check Now") { Task { await updater.check() } }
        }
    }

    fileprivate var updateStatus: String {
        switch updater.state {
        case .idle: "Not checked yet."
        case .checking: "Checking…"
        case .upToDate: "Notch Stash is up to date."
        case let .available(release): "Version \(release.version) is available."
        case .downloading: "Downloading the update…"
        case .installing: "Installing. Notch Stash will relaunch."
        case let .failed(message): message
        }
    }
}

extension SettingsView {
    fileprivate func chooseSaveFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        panel.directoryURL = URL(fileURLWithPath: settings.saveFolderPath, isDirectory: true)
        if panel.runModal() == .OK, let url = panel.url {
            settings.saveFolderPath = url.path
        }
    }
}

/// Button that records the next key combination pressed while it is active.
private struct ShortcutRecorder: View {
    @Binding var combo: KeyCombo?
    let onRecordingChange: (Bool) -> Void

    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 6) {
            Button(isRecording ? "Press Keys…" : (combo?.display ?? "Record Shortcut")) {
                isRecording ? stop() : start()
            }
            .monospacedDigit()
            if combo != nil, !isRecording {
                Button {
                    combo = nil
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear")
            }
        }
        .onDisappear { stop() }
    }

    private func start() {
        isRecording = true
        onRecordingChange(true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {
                stop()
            } else if let recorded = KeyCombo(event: event) {
                combo = recorded
                stop()
            } else {
                NSSound.beep()
            }
            return nil
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        if isRecording {
            isRecording = false
            onRecordingChange(false)
        }
    }
}

/// Owns the settings window.
@MainActor
final class SettingsWindowController {
    private var window: NSWindow?
    private var closeObserver: Any?
    private let isShortcutActive: () -> Bool
    private let onRecordingChange: (Bool) -> Void
    private let localNetwork: LocalNetworkPermission
    private let updater: Updater

    init(
        isShortcutActive: @escaping () -> Bool,
        onRecordingChange: @escaping (Bool) -> Void,
        localNetwork: LocalNetworkPermission,
        updater: Updater
    ) {
        self.isShortcutActive = isShortcutActive
        self.onRecordingChange = onRecordingChange
        self.localNetwork = localNetwork
        self.updater = updater
    }

    func show() {
        if window == nil {
            let tabs = NSTabViewController()
            tabs.tabStyle = .toolbar
            for tab in SettingsTab.allCases {
                let hosting = NSHostingController(rootView: SettingsView(
                    tab: tab,
                    settings: .shared,
                    isShortcutActive: isShortcutActive,
                    onRecordingChange: onRecordingChange,
                    localNetwork: localNetwork,
                    updater: updater
                ))
                hosting.sizingOptions = .preferredContentSize
                let item = NSTabViewItem(viewController: hosting)
                item.label = tab.title
                item.image = NSImage(systemSymbolName: tab.symbol, accessibilityDescription: tab.title)
                tabs.addTabViewItem(item)
            }
            let window = NSWindow(contentViewController: tabs)
            window.styleMask = [.titled, .closable]
            window.toolbarStyle = .preference
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
            closeObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: window,
                queue: .main
            ) { _ in
                MainActor.assumeIsolated { _ = NSApp.setActivationPolicy(.accessory) }
            }
        }
        localNetwork.check()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}
