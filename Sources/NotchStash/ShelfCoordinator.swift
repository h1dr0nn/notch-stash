import AppKit
import Combine
import NotchStashCore

/// Ties the shared store to the notch windows and the floating panel.
@MainActor
final class ShelfCoordinator {
    let store = ShelfStore()
    private var notchControllers: [NotchController] = []
    private var notchLayout: [CGRect] = []
    private var screenObserver: Any?
    private lazy var floating = FloatingController(store: store)
    private var mouseMonitors: [Any] = []
    private var pruneTimer: Timer?
    private var cancellable: AnyCancellable?

    var isFloatingVisible: Bool { floating.isVisible }

    func start() {
        floating.onVisibilityChanged = { [weak self] visible in
            self?.notchControllers.forEach { $0.isEnabled = !visible }
        }
        rebuildNotchWindows()
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
        if let global = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved, handler: handler) {
            mouseMonitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved, handler: { event in
            handler(event)
            return event
        }) {
            mouseMonitors.append(local)
        }

        pruneTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { _ = self?.store.pruneMissing() }
        }

        cancellable = store.$items
            .map(\.isEmpty)
            .removeDuplicates()
            .dropFirst()
            .filter { $0 }
            .sink { [weak self] _ in self?.closeAll() }
    }

    func toggle() {
        if floating.isVisible {
            floating.hide()
        } else {
            showFloating()
        }
    }

    func showFloating() {
        floating.show(at: NSEvent.mouseLocation)
    }

    func closeAll() {
        notchControllers.forEach { $0.close() }
        floating.hide()
    }

    private func mouseMoved(to point: CGPoint) {
        notchControllers.forEach { $0.mouseMoved(to: point) }
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
        notchControllers.forEach { $0.isEnabled = !floating.isVisible }
    }
}
