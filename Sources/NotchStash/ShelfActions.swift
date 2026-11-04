import AppKit

/// App-level actions the shelf views can trigger, wired up by the app delegate.
@MainActor
final class ShelfActions {
    static let shared = ShelfActions()

    var send: ([URL]) -> Void = { _ in }
}

/// Menu item that runs a closure.
final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(_ title: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        target = self
        if responds(to: NSSelectorFromString("setPreferredImageVisibility:")) {
            setValue(2, forKey: "preferredImageVisibility")
        }
    }

    @available(*, unavailable)
    required init(coder: NSCoder) { fatalError() }

    @objc private func run() {
        handler()
    }
}
