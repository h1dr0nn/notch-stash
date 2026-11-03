import AppKit
import NotchStashCore
import SwiftUI

/// Rounded shelf used on screens without a notch.
private struct FloatingRootView: View {
    @ObservedObject var store: ShelfStore
    let onClose: () -> Void
    let onPreview: (_ urls: [URL], _ index: Int) -> Void

    @State private var dropTargeted = false

    var body: some View {
        ShelfContentView(store: store, onClose: onClose, onPreview: onPreview, movesWindow: true)
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(WindowDragHandle())
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(dropTargeted ? Color.accentColor : Color.primary.opacity(0.12), lineWidth: dropTargeted ? 2 : 1)
            )
            .onDrop(of: [.fileURL], isTargeted: $dropTargeted) { DropLoader.load($0, into: store) }
    }
}

/// Floating shelf that appears next to the cursor.
@MainActor
final class FloatingController {
    private static let size = CGSize(width: 360, height: 170)

    private let panel: ShelfPanel
    var onVisibilityChanged: (Bool) -> Void = { _ in }

    var isVisible: Bool { panel.isVisible }

    init(store: ShelfStore) {
        panel = ShelfPanel(
            contentRect: CGRect(origin: .zero, size: Self.size),
            level: .floating,
            hasShadow: true
        )
        let root = FloatingRootView(
            store: store,
            onClose: { [weak self] in self?.hide() },
            onPreview: { [weak panel] urls, index in panel?.showPreview(urls: urls, index: index) }
        )
        panel.contentView = NSHostingView(rootView: root)
    }

    func show(at cursor: CGPoint) {
        let screen = NSScreen.screens.first { NSMouseInRect(cursor, $0.frame, false) } ?? NSScreen.main
        if let screen {
            let origin = NotchGeometry.panelOrigin(cursor: cursor, panelSize: Self.size, visibleFrame: screen.visibleFrame)
            panel.setFrameOrigin(origin)
        }
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        onVisibilityChanged(true)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            panel.animator().alphaValue = 1
        }
    }

    func hide() {
        guard panel.isVisible else { return }
        onVisibilityChanged(false)
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak panel] in
            MainActor.assumeIsolated {
                guard let panel, panel.alphaValue == 0 else { return }
                panel.orderOut(nil)
            }
        })
    }
}
