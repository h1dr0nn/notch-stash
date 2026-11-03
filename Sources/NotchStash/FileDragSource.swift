import AppKit
import SwiftUI

/// Transparent AppKit view that starts a real file drag (file URLs on the pasteboard) and reports clicks.
final class FileDragSourceView: NSView, NSDraggingSource {
    var urls: [URL] = []
    var onClick: () -> Void = {}
    var onDragEnded: (_ delivered: Bool) -> Void = { _ in }

    private var mouseDownEvent: NSEvent?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }

    override func mouseDown(with event: NSEvent) {
        mouseDownEvent = event
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = mouseDownEvent, !urls.isEmpty else { return }
        let distance = hypot(event.locationInWindow.x - start.locationInWindow.x, event.locationInWindow.y - start.locationInWindow.y)
        guard distance > 3 else { return }
        mouseDownEvent = nil

        let origin = convert(start.locationInWindow, from: nil)
        let items = urls.enumerated().map { offset, url in
            let item = NSDraggingItem(pasteboardWriter: url as NSURL)
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            let shift = CGFloat(min(offset, 4)) * 6
            item.setDraggingFrame(NSRect(x: origin.x - 24 + shift, y: origin.y - 24 - shift, width: 48, height: 48), contents: icon)
            return item
        }
        let session = beginDraggingSession(with: items, event: start, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
        session.draggingFormation = .pile
    }

    override func mouseUp(with event: NSEvent) {
        if mouseDownEvent != nil { onClick() }
        mouseDownEvent = nil
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        context == .outsideApplication ? [.copy, .move] : []
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        let keep = NSEvent.modifierFlags.contains(.option)
        let delivered = operation.contains(.copy) || operation.contains(.move)
        onDragEnded(delivered && !keep)
    }
}

/// SwiftUI wrapper for `FileDragSourceView`.
struct FileDragSource: NSViewRepresentable {
    let urls: [URL]
    let onClick: () -> Void
    let onDelivered: () -> Void

    func makeNSView(context: Context) -> FileDragSourceView {
        FileDragSourceView()
    }

    func updateNSView(_ view: FileDragSourceView, context: Context) {
        view.urls = urls
        view.onClick = onClick
        view.onDragEnded = { delivered in
            if delivered { onDelivered() }
        }
    }
}

/// Background view that moves its window when dragged.
final class WindowDragView: NSView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var mouseDownCanMoveWindow: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}

/// SwiftUI wrapper for `WindowDragView`.
struct WindowDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowDragView { WindowDragView() }
    func updateNSView(_ view: WindowDragView, context: Context) {}
}
