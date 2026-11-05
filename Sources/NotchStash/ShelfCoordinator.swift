import AppKit
import Combine
import NotchStashCore

/// Ties the shared store to the notch windows and the floating panel.
@MainActor
final class ShelfCoordinator {
    private static let stash = DropStash.standard()
    let store = ShelfStore(preserve: ShelfCoordinator.stash.preserve)
    private let settings = AppSettings.shared
    private var settingsCancellables: Set<AnyCancellable> = []
    private var notchControllers: [NotchController] = []
    private var notchLayout: [CGRect] = []
    private var screenObserver: Any?
    private var spaceObserver: Any?
    private lazy var floating = FloatingController(store: store)
    private var mouseMonitors: [Any] = []
    private var dragChangeCountAtMouseDown = NSPasteboard(name: .drag).changeCount
    private var isFileDragActive = false
    /// Tracked from the floating panel's callbacks; `panel.isVisible` stays true while it fades out.
    private var isFloatingShown = false
    private var pruneTimer: Timer?
    private var stashCleanupTimer: Timer?
    private var cancellable: AnyCancellable?

    var isFloatingVisible: Bool { isFloatingShown }

    func start() {
        floating.onVisibilityChanged = { [weak self] visible in
            self?.isFloatingShown = visible
            self?.applySettings()
        }
        rebuildNotchWindows()
        settings.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.applySettings() }
            .store(in: &settingsCancellables)
        spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.activeSpaceChanged() }
        }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.rebuildNotchWindows() }
        }

        let handler: (NSEvent) -> Void = { [weak self] _ in
            MainActor.assumeIsolated { self?.mouseMoved(to: NSEvent.mouseLocation) }
        }
        addMouseMonitor(.mouseMoved, handler)
        addMouseMonitor([.leftMouseDown, .leftMouseDragged, .leftMouseUp]) { [weak self] event in
            MainActor.assumeIsolated { self?.mouseButtonEvent(event.type) }
        }

        pruneTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { _ = self?.store.pruneMissing() }
        }
        cleanUpStash()
        stashCleanupTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.cleanUpStash() }
        }

        cancellable = store.$items
            .map(\.isEmpty)
            .removeDuplicates()
            .dropFirst()
            .filter { $0 }
            .sink { [weak self] _ in self?.closeAll() }
    }

    /// Copies of temporary files stay an hour after leaving the shelf, for apps still reading a dragged copy.
    private func cleanUpStash() {
        let inUse = store.items.map(\.url)
        DispatchQueue.global(qos: .utility).async {
            Self.stash.removeUnused(keeping: inUse, minimumAge: 3600)
        }
    }

    func toggle() {
        guard settings.floatingEnabled else { return }
        if isFloatingShown {
            floating.hide()
        } else {
            showFloating()
        }
    }

    func showFloating() {
        floating.show(at: NSEvent.mouseLocation)
    }

    /// The notch shelf stays on the old Space and no mouse events tell us, so start over on the new one.
    private func activeSpaceChanged() {
        let pointer = NSEvent.mouseLocation
        notchControllers.forEach { $0.spaceChanged(pointer: pointer) }
        mouseMoved(to: pointer)
    }

    /// Shows an incoming-files prompt in the notch shelf of the screen with the pointer (or the first notched
    /// screen). Returns false when there is no notch shelf to use.
    func presentIncoming(_ display: LocalSendIncomingDisplay, decide: @escaping (Bool) -> Void) -> Bool {
        guard settings.notchEnabled, !isFloatingShown else { return false }
        let pointer = NSEvent.mouseLocation
        guard let notch = notchControllers.first(where: { NSMouseInRect(pointer, $0.screen.frame, false) })
            ?? notchControllers.first else { return false }
        notch.showIncoming(display, decide: decide)
        return true
    }

    func dismissIncoming() {
        notchControllers.forEach { $0.dismissIncoming() }
    }

    func closeAll() {
        notchControllers.forEach { $0.close("close all") }
        floating.hide()
    }

    private func mouseMoved(to point: CGPoint) {
        notchControllers.forEach { $0.mouseMoved(to: point) }
    }

    private func addMouseMonitor(_ mask: NSEvent.EventTypeMask, _ handler: @escaping (NSEvent) -> Void) {
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler) {
            mouseMonitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { event in
            handler(event)
            return event
        }) {
            mouseMonitors.append(local)
        }
    }

    /// A file drag from any app shows up as a new drag pasteboard holding file URLs while the button is down.
    private func mouseButtonEvent(_ type: NSEvent.EventType) {
        switch type {
        case .leftMouseDown:
            dragChangeCountAtMouseDown = NSPasteboard(name: .drag).changeCount
            isFileDragActive = false
        case .leftMouseDragged:
            if !isFileDragActive {
                let pasteboard = NSPasteboard(name: .drag)
                guard pasteboard.changeCount != dragChangeCountAtMouseDown,
                      !DropTargetView.fileURLs(on: pasteboard).isEmpty else { return }
                isFileDragActive = true
            }
            let point = NSEvent.mouseLocation
            notchControllers.forEach { $0.fileDragMoved(to: point) }
        case .leftMouseUp:
            guard isFileDragActive else { return }
            isFileDragActive = false
            notchControllers.forEach { $0.fileDragEnded() }
        default:
            break
        }
    }

    private func rebuildNotchWindows() {
        let notched: [(NSScreen, CGRect)] = NSScreen.screens.compactMap { screen in
            let rect = NotchGeometry.notchRect(
                screenFrame: screen.frame,
                safeAreaTop: screen.safeAreaInsets.top,
                leftAuxWidth: screen.auxiliaryTopLeftArea?.width,
                rightAuxWidth: screen.auxiliaryTopRightArea?.width
            )
            return rect.map { (screen, $0) }
        }
        let layout = notched.map(\.1)
        guard layout != notchLayout else { return }
        notchLayout = layout
        notchControllers.forEach { $0.tearDown() }
        notchControllers = notched.map { NotchController(screen: $0.0, notchRect: $0.1, store: store) }
        applySettings()
    }

    private func applySettings() {
        if !settings.floatingEnabled { floating.hide() }
        let notchEnabled = settings.notchEnabled && !isFloatingShown
        notchControllers.forEach {
            $0.isEnabled = notchEnabled
            $0.opensOnHover = settings.openNotchOnHover
        }
    }
}
