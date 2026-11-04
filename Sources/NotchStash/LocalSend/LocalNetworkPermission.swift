import AppKit
import Network
import OSLog

/// Triggers and tracks the macOS Local Network permission.
/// Plain multicast sockets are dropped silently without it, so a Bonjour browse is used to make
/// macOS show its prompt and to learn the answer (a policy-denied DNS error means "not allowed").
@MainActor
final class LocalNetworkPermission: ObservableObject {
    enum State: Equatable {
        case unknown
        case allowed
        case denied
    }

    @Published private(set) var state: State = .unknown

    private var browser: NWBrowser?
    private let log = Logger(subsystem: "local.notch-stash", category: "localsend")
    private static let policyDenied: Int32 = -65570

    static func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocalNetwork") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Starts (or restarts) the check; macOS shows its prompt the first time.
    func check() {
        browser?.cancel()
        let parameters = NWParameters()
        parameters.includePeerToPeer = false
        let browser = NWBrowser(for: .bonjour(type: "_notchstash._tcp", domain: nil), using: parameters)
        browser.stateUpdateHandler = { [weak self] newState in
            Task { @MainActor in self?.update(newState) }
        }
        browser.start(queue: .main)
        self.browser = browser
    }

    func stop() {
        browser?.cancel()
        browser = nil
    }

    private func update(_ browserState: NWBrowser.State) {
        let next: State
        switch browserState {
        case .ready:
            next = .allowed
        case let .waiting(error), let .failed(error):
            if case let .dns(code) = error, code == Self.policyDenied {
                next = .denied
            } else {
                next = state
            }
        default:
            next = state
        }
        if next != state {
            log.notice("Local Network permission: \(String(describing: next), privacy: .public)")
            state = next
        }
    }
}
