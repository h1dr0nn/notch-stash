import AppKit
import SwiftUI

/// Window content view that accepts dropped files and hosts the SwiftUI shelf as its only subview.
final class DropTargetView: NSView {
    var onTargetChanged: (Bool) -> Void = { _ in }
    var onDrop: ([URL]) -> Void = { _ in }

    init(content: NSView) {
        super.init(frame: content.frame)
        content.frame = bounds
        content.autoresizingMask = [.width, .height]
        addSubview(content)
        registerForDraggedTypes([.fileURL])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        guard !Self.fileURLs(in: sender).isEmpty else { return [] }
        onTargetChanged(true)
        return .copy
    }

    override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        Self.fileURLs(in: sender).isEmpty ? [] : .copy
    }

    override func draggingExited(_ sender: (any NSDraggingInfo)?) {
        onTargetChanged(false)
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        let urls = Self.fileURLs(in: sender)
        onTargetChanged(false)
        guard !urls.isEmpty else { return false }
        onDrop(urls)
        return true
    }

    static func fileURLs(in info: any NSDraggingInfo) -> [URL] {
        fileURLs(on: info.draggingPasteboard)
    }

    static func fileURLs(on pasteboard: NSPasteboard) -> [URL] {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        return pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL] ?? []
    }
}

/// Hosting view for the shelf panels. They never become the key window, so without this the first click
/// would only bring the panel forward and never reach a button.
final class FirstClickHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
