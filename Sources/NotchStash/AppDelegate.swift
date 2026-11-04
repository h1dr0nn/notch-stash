import AppKit
import Combine

/// Menu bar item, shelf coordinator, shortcut and settings window.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let settings = AppSettings.shared
    private let coordinator = ShelfCoordinator()
    private lazy var hotkey = HotkeyMonitor { [weak self] in
        guard self?.settings.shortcutKind == .doubleTap else { return }
        self?.coordinator.toggle()
    }
    private lazy var comboHotKey = ComboHotKey { [weak self] in self?.coordinator.toggle() }
    private lazy var settingsWindow = SettingsWindowController(
        isShortcutActive: { [weak self] in self?.hotkey.isActive ?? false },
        onRecordingChange: { [weak self] recording in
            self?.isRecordingShortcut = recording
            self?.applyShortcut()
        },
        localNetwork: localSend.localNetwork,
        updater: updater
    )
    private let updater = Updater()
    private var isRecordingShortcut = false
    private lazy var localSend = LocalSendService(store: coordinator.store)
    private lazy var sendWindow = SendWindowController(service: localSend)
    private var incomingWindow: IncomingWindowController?
    private var statusItem: NSStatusItem?
    private var cancellables: Set<AnyCancellable> = []
    private var launchedAtLogin = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        let event = NSAppleEventManager.shared().currentAppleEvent
        launchedAtLogin = event?.paramDescriptor(forKeyword: keyAELaunchedAsLogInItem)?.booleanValue ?? false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        coordinator.start()
        localSend.start()
        updater.startAutomaticChecks()
        incomingWindow = IncomingWindowController(service: localSend)
        ShelfActions.shared.send = { [weak self] urls in self?.sendWindow.show(urls) }
        setUpStatusItem()
        setUpMainMenu()

        settings.$hotkeyModifier
            .sink { [weak self] modifier in self?.hotkey.modifier = modifier }
            .store(in: &cancellables)
        settings.$shortcutKind.combineLatest(settings.$keyCombo)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.applyShortcut() }
            .store(in: &cancellables)
        settings.$showMenuBarIcon
            .sink { [weak self] visible in self?.statusItem?.isVisible = visible }
            .store(in: &cancellables)

        if !launchedAtLogin {
            settingsWindow.show()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        settingsWindow.show()
        return false
    }

    /// Double-tap needs the Input Monitoring listener; a key combination is registered with the system instead.
    private func applyShortcut() {
        switch settings.shortcutKind {
        case .doubleTap:
            comboHotKey.unregister()
            hotkey.start()
        case .combination:
            comboHotKey.register(isRecordingShortcut ? nil : settings.keyCombo)
        }
    }

    private var isShortcutReady: Bool {
        switch settings.shortcutKind {
        case .doubleTap: hotkey.isActive
        case .combination: settings.keyCombo != nil
        }
    }

    /// Shown while the settings window puts the app in the Dock.
    private func setUpMainMenu() {
        let appMenu = NSMenu()
        let about = #selector(NSApplication.orderFrontStandardAboutPanel(_:))
        appMenu.addItem(withTitle: "About Notch Stash", action: about, keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(menuItem("Settings…", #selector(openSettings), key: ","))
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide Notch Stash", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(menuItem("Quit Notch Stash", #selector(quit), key: "q"))
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        let mainMenu = NSMenu()
        for submenu in [appMenu, windowMenu] {
            let item = NSMenuItem()
            item.submenu = submenu
            mainMenu.addItem(item)
        }
        NSApp.mainMenu = mainMenu
    }

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "tray.and.arrow.down", accessibilityDescription: "Notch Stash")
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item
        coordinator.store.$items
            .map(\.count)
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak item] count in
                item?.length = count > 0 ? NSStatusItem.variableLength : NSStatusItem.squareLength
                item?.button?.title = count > 0 ? " \(count)" : ""
                item?.button?.imagePosition = .imageLeading
            }
            .store(in: &cancellables)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        if let release = updater.availableRelease {
            menu.addItem(menuItem("Update to \(release.version)…", #selector(installUpdate)))
            menu.addItem(.separator())
        }
        if settings.floatingEnabled {
            menu.addItem(menuItem(coordinator.isFloatingVisible ? "Hide Shelf" : "Show Shelf", #selector(toggleShelf)))
        }
        if !coordinator.store.isEmpty {
            menu.addItem(menuItem("Clear Shelf", #selector(clearShelf)))
        }
        if settings.floatingEnabled {
            menu.addItem(.separator())
            if isShortcutReady, let shortcut = settings.shortcutDescription {
                let verb = settings.shortcutKind == .doubleTap ? "" : "Press "
                let text = verb.isEmpty ? shortcut.prefix(1).uppercased() + shortcut.dropFirst() : verb + shortcut
                let hint = NSMenuItem(title: "\(text) to show or hide the shelf", action: nil, keyEquivalent: "")
                hint.isEnabled = false
                menu.addItem(hint)
            } else {
                menu.addItem(menuItem("Set Up Shortcut…", #selector(openSettings)))
            }
        }
        menu.addItem(.separator())
        menu.addItem(menuItem("Settings…", #selector(openSettings), key: ","))
        menu.addItem(menuItem("Quit Notch Stash", #selector(quit), key: "q"))
    }

    private func menuItem(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        Self.hideAutomaticImage(item)
        return item
    }

    /// macOS 27 adds symbols to items like Settings…; hide them so every item looks the same.
    /// Set through the runtime so the app still builds with older SDKs.
    private static func hideAutomaticImage(_ item: NSMenuItem) {
        if item.responds(to: NSSelectorFromString("setPreferredImageVisibility:")) {
            item.setValue(2, forKey: "preferredImageVisibility")
        }
    }

    @objc private func toggleShelf() {
        coordinator.toggle()
    }

    @objc private func clearShelf() {
        coordinator.store.removeAll()
    }

    @objc private func installUpdate() {
        guard let release = updater.availableRelease else { return }
        let alert = NSAlert()
        alert.messageText = "Update to Notch Stash \(release.version)?"
        alert.informativeText = "Notch Stash downloads the update from GitHub, replaces this version and relaunches."
        alert.addButton(withTitle: "Update and Relaunch")
        alert.addButton(withTitle: "Release Notes")
        alert.addButton(withTitle: "Later")
        NSApp.activate()
        switch alert.runModal() {
        case .alertFirstButtonReturn: Task { await updater.install(release) }
        case .alertSecondButtonReturn: NSWorkspace.shared.open(release.pageURL)
        default: break
        }
    }

    @objc private func openSettings() {
        settingsWindow.show()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
