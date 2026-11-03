import AppKit
import NotchStashCore
import SwiftUI

/// Header, file tiles and empty-state hint shared by the notch shelf and the floating panel.
struct ShelfContentView: View {
    @ObservedObject var store: ShelfStore
    let onClose: () -> Void
    let onPreview: (_ urls: [URL], _ index: Int) -> Void
    var movesWindow = false
    /// Notch size when the header shares the notch row: title left of the notch, buttons right of it.
    var notchSize: CGSize?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if store.isEmpty {
                placeholder
            } else {
                tiles
            }
        }
    }

    @ViewBuilder
    private var header: some View {
        if let notchSize {
            HStack(spacing: 10) {
                title
                Spacer(minLength: 0)
                Color.clear.frame(width: notchSize.width + 16)
                Spacer(minLength: 0)
                actions(compact: true)
            }
            .frame(height: notchSize.height)
            .padding(.top, 6)
        } else {
            HStack(spacing: 10) {
                title
                Spacer()
                actions(compact: false)
            }
            .background(movesWindow ? WindowDragHandle() : nil)
        }
    }

    private func actions(compact: Bool) -> some View {
        HStack(spacing: compact ? 12 : 10) {
            if !store.isEmpty {
                dragAll(compact: compact)
                Button { store.removeAll() } label: {
                    if compact {
                        Image(systemName: "trash").font(.system(size: 13))
                    } else {
                        Text("Clear All").font(.caption)
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Clear All")
            }
            if !compact {
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close")
            }
        }
    }

    private var title: some View {
        Text("Notch Shelf")
            .font(.headline)
            .allowsHitTesting(false)
    }

    private func dragAll(compact: Bool) -> some View {
        let items = store.items
        return Label("Drag All", systemImage: "square.stack.3d.up.fill")
            .labelStyle(DragAllLabelStyle(compact: compact))
            .font(.caption.weight(.semibold))
            .padding(.horizontal, compact ? 7 : 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.accentColor.opacity(0.85)))
            .foregroundStyle(.white)
            .overlay(
                FileDragSource(
                    urls: items.map(\.url),
                    onClick: {},
                    onDelivered: { store.remove(ids: Set(items.map(\.id))) }
                )
            )
            .help("Drag every file at once")
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            .foregroundStyle(.secondary)
            .overlay(
                Label("Drop files here", systemImage: "tray.and.arrow.down")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var tiles: some View {
        let items = store.items
        let urls = items.map(\.url)
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    FileTile(
                        item: item,
                        onPreview: { onPreview(urls, index) },
                        onRemove: { store.remove(ids: [item.id]) }
                    )
                }
            }
        }
        .frame(maxHeight: .infinity)
    }
}

/// Icon only in the notch row, icon and title elsewhere.
private struct DragAllLabelStyle: LabelStyle {
    let compact: Bool

    func makeBody(configuration: Configuration) -> some View {
        if compact {
            configuration.icon
        } else {
            Label(configuration)
        }
    }
}

/// One file on the shelf: drag it out, click to preview, × to remove.
private struct FileTile: View {
    let item: ShelfItem
    let onPreview: () -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                .resizable()
                .frame(width: 44, height: 44)
            Text(item.name)
                .font(.caption2)
                .lineLimit(2)
                .truncationMode(.middle)
                .multilineTextAlignment(.center)
                .frame(width: 72)
        }
        .frame(width: 78, height: 86)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.06)))
        .overlay(FileDragSource(urls: [item.url], onClick: onPreview, onDelivered: onRemove))
        .overlay(alignment: .topTrailing) {
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(3)
            .help("Remove")
        }
        .help(item.url.path)
    }
}

/// Loads dropped file URLs into the store.
@MainActor
enum DropLoader {
    static func load(_ providers: [NSItemProvider], into store: ShelfStore) -> Bool {
        let fileProviders = providers.filter { $0.canLoadObject(ofClass: URL.self) }
        guard !fileProviders.isEmpty else { return false }
        let batch = DropBatch(count: fileProviders.count, store: store)
        for (index, provider) in fileProviders.enumerated() {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                Task { @MainActor in batch.finish(index, url) }
            }
        }
        return true
    }
}

/// Collects URLs from one drop and adds them to the store in their original order.
@MainActor
private final class DropBatch {
    private var results: [URL?]
    private var pending: Int
    private let store: ShelfStore

    init(count: Int, store: ShelfStore) {
        results = Array(repeating: nil, count: count)
        pending = count
        self.store = store
    }

    func finish(_ index: Int, _ url: URL?) {
        results[index] = url
        pending -= 1
        if pending == 0 { store.add(results.compactMap { $0 }) }
    }
}
