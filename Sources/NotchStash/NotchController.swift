import AppKit
import NotchStashCore
import SwiftUI

/// View state for the notch window.
@MainActor
final class NotchModel: ObservableObject {
    @Published var isOpen = false
    @Published var showsShape = false
    let notchSize: CGSize
    let openedSize: CGSize
    var onDragTargetChanged: (Bool) -> Void = { _ in }

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

    @State private var dropTargeted = false

    var body: some View {
        let open = model.isOpen
        let shape = UnevenRoundedRectangle(bottomLeadingRadius: 24, bottomTrailingRadius: 24)
        ZStack(alignment: .top) {
            Color.black.opacity(0.02)
                .frame(width: model.notchSize.width, height: model.notchSize.height)
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
        .onDrop(of: [.fileURL], isTargeted: $dropTargeted) { DropLoader.load($0, into: store) }
        .onChange(of: dropTargeted) { _, targeted in model.onDragTargetChanged(targeted) }
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
    private var isDragTargeted = false
    var isEnabled = true {
        didSet { if !isEnabled { close() } }
    }
    private var openedFrame: CGRect
    private var layoutGeneration = 0

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
            onClose: { [weak self] in self?.close() },
            onPreview: { [weak self] urls, index in self?.panel.showPreview(urls: urls, index: index) }
        )
        let hostingView = NSHostingView(rootView: root)
        hostingView.sizingOptions = []
        panel.contentView = hostingView
        model.onDragTargetChanged = { [weak self] targeted in self?.dragTargetChanged(targeted) }
        setFrame(notchRect)
    }

    func open(_ reason: OpenReason) {
        guard isEnabled, !isOpen else { return }
        openReason = reason
        layoutGeneration += 1
        if panel.frame != openedFrame {
            setFrame(openedFrame)
            panel.contentView?.layoutSubtreeIfNeeded()
        }
        model.showsShape = true
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isOpen else { return }
            withAnimation(Self.animation) { self.model.isOpen = true }
        }
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    }

    func close() {
        guard isOpen else { return }
        openReason = nil
        layoutGeneration += 1
        let generation = layoutGeneration
        withAnimation(Self.animation, completionCriteria: .removed) {
            model.isOpen = false
        } completion: { [weak self] in
            guard let self, generation == self.layoutGeneration else { return }
            self.model.showsShape = false
            self.setFrame(self.notchRect)
        }
    }

    func tearDown() {
        panel.orderOut(nil)
        panel.close()
    }

    func mouseMoved(to point: CGPoint) {
        if !isOpen {
            if NSMouseInRect(point, notchRect, false) { open(.hover) }
        } else if !shelfRect.insetBy(dx: -20, dy: -20).contains(point) {
            close()
        }
    }

    private func dragTargetChanged(_ targeted: Bool) {
        isDragTargeted = targeted
        if targeted {
            open(.drag)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self, !self.isDragTargeted, self.openReason == .drag else { return }
            if self.shelfRect.contains(NSEvent.mouseLocation) {
                self.openReason = .hover
            } else {
                self.close()
            }
        }
    }

    private var shelfRect: CGRect {
        NotchGeometry.topCenteredRect(in: screen.frame, size: model.openedSize)
    }

    private func setFrame(_ frame: CGRect) {
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
    }
}
