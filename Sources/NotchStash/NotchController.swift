import AppKit
import NotchStashCore
import OSLog
import SwiftUI

/// View state for the notch window.
@MainActor
final class NotchModel: ObservableObject {
    @Published var isOpen = false
    @Published var showsShape = false
    @Published var isDropTargeted = false
    let notchSize: CGSize
    let openedSize: CGSize

    init(notchSize: CGSize, openedSize: CGSize) {
        self.notchSize = notchSize
        self.openedSize = openedSize
    }
}

/// Black shape that grows out of the notch.
private struct NotchRootView: View {
    @ObservedObject var model: NotchModel
    @ObservedObject var store: ShelfStore
    let onClose: () -> Void
    let onPreview: (_ urls: [URL], _ index: Int) -> Void

    var body: some View {
        let open = model.isOpen
        let shape = UnevenRoundedRectangle(bottomLeadingRadius: 24, bottomTrailingRadius: 24)
        ZStack(alignment: .top) {
            ZStack(alignment: .top) {
                shape.fill(Color.black)
                ShelfContentView(store: store, onClose: onClose, onPreview: onPreview, notchSize: model.notchSize)
                    .padding([.horizontal, .bottom], 16)
                    .opacity(open ? 1 : 0)
                    .animation(open ? .easeOut(duration: 0.18).delay(0.1) : .easeIn(duration: 0.08), value: open)
                    .allowsHitTesting(open)
            }
            .frame(width: model.openedSize.width, height: model.openedSize.height)
            .clipShape(shape)
            .shadow(color: .black.opacity(0.45), radius: 12, y: 4)
            .scaleEffect(open ? 1 : 0.001, anchor: .top)
            .opacity(model.showsShape ? 1 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .environment(\.colorScheme, .dark)
    }
}

/// Owns the window that sits on a notched screen: closed over the notch, opened as the shelf.
@MainActor
final class NotchController {
    enum OpenReason { case hover, drag }

    static let animation = Animation.spring(response: 0.38, dampingFraction: 0.78)
    private static let shadowMargin: CGFloat = 24

    let screen: NSScreen
    let notchRect: CGRect
    private let store: ShelfStore
    private let model: NotchModel
    private let panel: ShelfPanel
    private(set) var openReason: OpenReason?
    var opensOnHover = true
    var isEnabled = true {
        didSet { if !isEnabled { close("disabled") } }
    }
    private var openedFrame: CGRect
    private var layoutGeneration = 0
    private let log = Logger(subsystem: "local.notch-stash", category: "notch")

    var isOpen: Bool { openReason != nil }

    init(screen: NSScreen, notchRect: CGRect, store: ShelfStore) {
        self.screen = screen
        self.notchRect = notchRect
        self.store = store
        let openedSize = CGSize(width: 580, height: notchRect.height + 130)
        model = NotchModel(notchSize: notchRect.size, openedSize: openedSize)
        let windowSize = CGSize(width: openedSize.width + Self.shadowMargin * 2, height: openedSize.height + Self.shadowMargin)
        openedFrame = NotchGeometry.topCenteredRect(in: screen.frame, size: windowSize)
        panel = ShelfPanel(
            contentRect: notchRect,
            level: NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 8),
            hasShadow: false
        )
        let root = NotchRootView(
            model: model,
            store: store,
            onClose: { [weak self] in self?.close("button") },
            onPreview: { [weak self] urls, index in self?.panel.showPreview(urls: urls, index: index) }
        )
        let hostingView = NSHostingView(rootView: root)
        hostingView.sizingOptions = []
        let dropView = DropTargetView(content: hostingView)
        dropView.onTargetChanged = { [weak self] targeted in self?.model.isDropTargeted = targeted }
        dropView.onDrop = { [weak self] urls in
            self?.log.notice("dropped \(urls.count) file(s)")
            self?.store.add(urls)
        }
        panel.contentView = dropView
        panel.setFrame(openedFrame, display: false)
    }

    func open(_ reason: OpenReason) {
        log.notice("open \(String(describing: reason), privacy: .public) enabled=\(self.isEnabled) isOpen=\(self.isOpen)")
        guard isEnabled, !isOpen else { return }
        openReason = reason
        layoutGeneration += 1
        panel.contentView?.layoutSubtreeIfNeeded()
        panel.orderFrontRegardless()
        model.showsShape = true
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isOpen else { return }
            self.log.notice("animate open, frame=\(String(describing: self.panel.frame), privacy: .public)")
            withAnimation(Self.animation) { self.model.isOpen = true }
        }
        Self.playHaptic()
    }

    func close(_ why: String) {
        guard isOpen else { return }
        log.notice("close \(why, privacy: .public)")
        Self.playHaptic()
        openReason = nil
        layoutGeneration += 1
        let generation = layoutGeneration
        withAnimation(Self.animation, completionCriteria: .removed) {
            model.isOpen = false
        } completion: { [weak self] in
            guard let self, generation == self.layoutGeneration else { return }
            self.model.showsShape = false
            self.panel.orderOut(nil)
        }
    }

    func tearDown() {
        panel.orderOut(nil)
        panel.close()
    }

    func mouseMoved(to point: CGPoint) {
        if !isOpen {
            if opensOnHover, NSMouseInRect(point, notchRect, false) { open(.hover) }
        } else if !shelfRect.insetBy(dx: -20, dy: -20).contains(point) {
            close("mouse left")
        }
    }

    /// Called while a file drag is in progress anywhere on screen.
    func fileDragMoved(to point: CGPoint) {
        if !isOpen {
            let zone = CGRect(
                x: notchRect.minX - 24,
                y: notchRect.minY - 24,
                width: notchRect.width + 48,
                height: notchRect.height + 24
            )
            if NSMouseInRect(point, zone, false) { open(.drag) }
        } else if openReason == .drag, !shelfRect.insetBy(dx: -20, dy: -20).contains(point) {
            close("drag left")
        }
    }

    /// Called when the mouse button is released after a file drag.
    func fileDragEnded() {
        guard openReason == .drag else { return }
        if shelfRect.insetBy(dx: -20, dy: -20).contains(NSEvent.mouseLocation) {
            openReason = .hover
        } else {
            close("drag ended")
        }
    }

    /// `.levelChange` feels like two steps while the trackpad is held down for a drag, so use a single tap then.
    private static func playHaptic() {
        let pattern: NSHapticFeedbackManager.FeedbackPattern = NSEvent.pressedMouseButtons == 0 ? .levelChange : .alignment
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
    }

    private var shelfRect: CGRect {
        NotchGeometry.topCenteredRect(in: screen.frame, size: model.openedSize)
    }
}
