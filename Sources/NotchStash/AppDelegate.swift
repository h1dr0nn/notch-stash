import AppKit
import Combine

/// Menu bar item, shelf coordinator, shortcut and settings window.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let settings = AppSettings.shared
    private let coordinator = ShelfCoordinator()
    private lazy var hotkey = HotkeyMonitor { [weak self] in self?.coordinator.toggle() }
    private lazy var settingsWindow = SettingsWindowController { [weak self] in self?.hotkey.isActive ?? false }
    private var statusItem: NSStatusItem?
    private var cancellables: Set<AnyCancellable> = []
    private var launchedAtLogin = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        let event = NSAppleEventManager.shared().currentAppleEvent
        launchedAtLogin = event?.paramDescriptor(forKeyword: keyAELaunchedAsLogInItem)?.booleanValue ?? false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        coordinator.start()
        hotkey.start()
        setUpStatusItem()

        settings.$hotkeyModifier
            .sink { [weak self] modifier in self?.hotkey.modifier = modifier }
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
        if settings.floatingEnabled {
            menu.addItem(menuItem(coordinator.isFloatingVisible ? "Hide Shelf" : "Show Shelf", #selector(toggleShelf)))
        }
        if !coordinator.store.isEmpty {
            menu.addItem(menuItem("Clear Shelf", #selector(clearShelf)))
        }
        if settings.floatingEnabled {
            menu.addItem(.separator())
            if hotkey.isActive {
                let symbol = settings.hotkeyModifier.symbol
                let hint = NSMenuItem(title: "Double-tap \(symbol) to show or hide the shelf", action: nil, keyEquivalent: "")
                hint.isEnabled = false
                menu.addItem(hint)
            } else {
                menu.addItem(menuItem("Enable Shortcut…", #selector(openSettings)))
            }
        }
        menu.addItem(.separator())
        menu.addItem(menuItem("Settings…", #selector(openSettings), key: ","))
        menu.addItem(menuItem("Quit Notch Stash", #selector(quit), key: "q"))
    }

    private func menuItem(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func toggleShelf() {
        coordinator.toggle()
    }

    @objc private func clearShelf() {
        coordinator.store.removeAll()
    }

    @objc private func openSettings() {
        settingsWindow.show()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
