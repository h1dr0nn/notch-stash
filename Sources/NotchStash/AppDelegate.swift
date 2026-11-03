import AppKit
import Combine

/// Menu bar item, shelf coordinator and ⌃⌃ shortcut.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let coordinator = ShelfCoordinator()
    private lazy var hotkey = HotkeyMonitor { [weak self] in self?.coordinator.toggle() }
    private var statusItem: NSStatusItem?
    private var countCancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        coordinator.start()
        hotkey.start()
        if !HotkeyMonitor.hasPermission {
            DispatchQueue.main.async { [weak self] in self?.showPermissionAlert() }
        }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "tray.and.arrow.down", accessibilityDescription: "Notch Stash")
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item
        countCancellable = coordinator.store.$items
            .map(\.count)
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak item] count in
                item?.length = count > 0 ? NSStatusItem.variableLength : NSStatusItem.squareLength
                item?.button?.title = count > 0 ? " \(count)" : ""
                item?.button?.imagePosition = .imageLeading
            }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.addItem(menuItem(coordinator.isFloatingVisible ? "Hide Shelf" : "Show Shelf", #selector(toggleShelf)))
        if !coordinator.store.isEmpty {
            menu.addItem(menuItem("Clear Shelf", #selector(clearShelf)))
        }
        menu.addItem(.separator())
        if hotkey.isActive {
            let hint = NSMenuItem(title: "Double-tap ⌃ to show or hide the shelf", action: nil, keyEquivalent: "")
            hint.isEnabled = false
            menu.addItem(hint)
        } else {
            menu.addItem(menuItem("Enable ⌃⌃ Shortcut…", #selector(openPermissionSettings)))
        }
        menu.addItem(.separator())
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

    @objc private func openPermissionSettings() {
        showPermissionAlert()
    }

    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Turn On Input Monitoring"
        alert.informativeText = "Double-tapping ⌃ needs Input Monitoring. In System Settings, select any old Notch Stash entry "
            + "and remove it with −, add this app with +, then switch it on. The shortcut starts by itself within a few seconds."
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Not Now")
        NSApp.activate()
        if alert.runModal() == .alertFirstButtonReturn {
            HotkeyMonitor.openPrivacySettings()
            NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
