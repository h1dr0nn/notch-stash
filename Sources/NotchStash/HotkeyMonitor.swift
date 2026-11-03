import AppKit
import NotchStashCore
import OSLog

/// Watches for a double tap of a modifier key through a listen-only event tap (needs Input Monitoring).
@MainActor
final class HotkeyMonitor {
    private let onTrigger: () -> Void
    private var detector = DoubleTapDetector()
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var tapHasPermission = false
    private var watchTimer: Timer?
    var modifier: HotkeyModifier = .control {
        didSet { detector = DoubleTapDetector() }
    }
    private let log = Logger(subsystem: "local.notch-stash", category: "hotkey")

    init(onTrigger: @escaping () -> Void) {
        self.onTrigger = onTrigger
    }

    /// True only when the tap runs with Input Monitoring, i.e. it sees keys typed in other apps.
    var isActive: Bool {
        guard let tap, tapHasPermission else { return false }
        return CGEvent.tapIsEnabled(tap: tap)
    }

    static var hasPermission: Bool { CGPreflightListenEventAccess() }

    func start() {
        guard watchTimer == nil else { return }
        if !Self.hasPermission {
            log.notice("Input Monitoring not granted, requesting")
            CGRequestListenEventAccess()
        }
        refresh()
        watchTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
            MainActor.assumeIsolated { [weak self] in self?.refresh() }
        }
    }

    static func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    /// A tap created without Input Monitoring only sees this app's own keys and stays that way,
    /// so it is rebuilt once the permission shows up. A tap the system disabled is rebuilt too.
    private func refresh() {
        let granted = Self.hasPermission
        if let tap, granted == tapHasPermission, !granted || CGEvent.tapIsEnabled(tap: tap) { return }
        if tap != nil {
            log.notice("Rebuilding event tap (permission: \(granted, privacy: .public))")
            removeTap()
        }
        installTap(granted: granted)
    }

    private func installTap(granted: Bool) {
        let mask = (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue)
        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: hotkeyTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            log.error("Event tap creation failed")
            return
        }
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        tap = port
        source = runLoopSource
        tapHasPermission = granted
        detector = DoubleTapDetector()
        log.notice("Event tap installed (permission: \(granted, privacy: .public))")
    }

    private func removeTap() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        tap = nil
        source = nil
    }

    fileprivate func handle(type: CGEventType, flags: CGEventFlags) {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            guard tapHasPermission else { return }
            log.notice("Event tap disabled by the system (\(type.rawValue, privacy: .public)), re-enabling")
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
        case .keyDown:
            _ = detector.handle(.keyDown(time: ProcessInfo.processInfo.systemUptime))
        case .flagsChanged:
            let modifiers: CGEventFlags = [.maskControl, .maskShift, .maskAlternate, .maskCommand, .maskSecondaryFn]
            let others = modifiers.subtracting(modifier.flag)
            let input = DoubleTapDetector.Input.modifiers(
                targetDown: flags.contains(modifier.flag),
                othersDown: !flags.isDisjoint(with: others),
                time: ProcessInfo.processInfo.systemUptime
            )
            if detector.handle(input) {
                log.notice("Double tap detected")
                onTrigger()
            }
        default:
            break
        }
    }
}

private func hotkeyTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    if let userInfo {
        let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(userInfo).takeUnretainedValue()
        let flags = event.flags
        MainActor.assumeIsolated {
            monitor.handle(type: type, flags: flags)
        }
    }
    return Unmanaged.passUnretained(event)
}
