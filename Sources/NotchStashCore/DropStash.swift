import Foundation

/// Keeps copies of files dropped from temporary folders.
///
/// Screenshot thumbnails, browsers and Photos hand a drag a file they write to a temporary folder and delete
/// soon after, often when the next one is made. The shelf only holds references, so such a file would vanish
/// from it a few seconds later. Those files are copied here instead; everything else stays a reference.
public struct DropStash: Sendable {
    public let root: URL

    public init(root: URL) {
        self.root = root.standardizedFileURL
    }

    /// The per-user stash under Application Support.
    public static func standard(appName: String = "Notch Stash") -> DropStash {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return DropStash(root: support.appendingPathComponent(appName).appendingPathComponent("Dropped Files"))
    }

    /// Whether `url` lives in a folder the system or its app cleans up on its own.
    public static func isTemporary(_ url: URL) -> Bool {
        // Resolving symlinks drops the "/private" of an existing path, so both spellings are checked.
        let path = url.resolvingSymlinksInPath().path
        let folders = ["/var/folders/", "/tmp/", "/var/tmp/"]
        return folders.contains { path.hasPrefix($0) || path.hasPrefix("/private" + $0) }
    }

    /// Returns a lasting URL for `url`: a copy in the stash when it is temporary, otherwise `url` itself.
    /// Falls back to `url` when the copy fails.
    public func preserve(_ url: URL) -> URL {
        guard Self.isTemporary(url), !contains(url) else { return url }
        let folder = root.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let copy = folder.appendingPathComponent(url.lastPathComponent)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: url, to: copy)
            return copy
        } catch {
            try? FileManager.default.removeItem(at: folder)
            return url
        }
    }

    /// Deletes copies that are no longer on the shelf. Copies younger than `minimumAge` stay, so an app a
    /// file was just dragged to can still read it.
    public func removeUnused(keeping inUse: [URL], minimumAge: TimeInterval, now: Date = Date()) {
        let kept = Set(inUse.map { $0.standardizedFileURL.deletingLastPathComponent().path })
        let folders = (try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.creationDateKey]
        )) ?? []
        for folder in folders where !kept.contains(folder.standardizedFileURL.path) {
            let created = (try? folder.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            if now.timeIntervalSince(created) >= minimumAge {
                try? FileManager.default.removeItem(at: folder)
            }
        }
    }

    private func contains(_ url: URL) -> Bool {
        url.standardizedFileURL.path.hasPrefix(root.path + "/")
    }
}
