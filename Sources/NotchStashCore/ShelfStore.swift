import Combine
import Foundation

/// A file held on the shelf.
public struct ShelfItem: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let url: URL
    public let name: String

    public init(id: UUID = UUID(), url: URL) {
        self.id = id
        self.url = url
        self.name = url.lastPathComponent
    }
}

/// Observable collection of shelf items backed by file URLs.
@MainActor
public final class ShelfStore: ObservableObject {
    @Published public private(set) var items: [ShelfItem] = []

    private let fileExists: (URL) -> Bool

    public init(fileExists: @escaping (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }) {
        self.fileExists = fileExists
    }

    public var isEmpty: Bool {
        items.isEmpty
    }

    @discardableResult
    public func add(_ urls: [URL]) -> [ShelfItem] {
        var seen = Set(items.map { $0.url.path })
        var added: [ShelfItem] = []
        for url in urls where url.isFileURL {
            let standardized = url.standardizedFileURL
            guard !seen.contains(standardized.path), fileExists(standardized) else { continue }
            seen.insert(standardized.path)
            added.append(ShelfItem(url: standardized))
        }
        items.append(contentsOf: added)
        return added
    }

    public func remove(ids: Set<UUID>) {
        items.removeAll { ids.contains($0.id) }
    }

    public func removeAll() {
        items.removeAll()
    }

    @discardableResult
    public func pruneMissing() -> Int {
        let remaining = items.filter { fileExists($0.url) }
        let removed = items.count - remaining.count
        if removed > 0 { items = remaining }
        return removed
    }
}
