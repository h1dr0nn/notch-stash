import Foundation

/// Helpers for turning received file names into safe, collision-free relative paths.
public enum FileNaming {
    /// Drops empty, "." and ".." components so the result can never escape its base folder.
    public static func safeRelativePath(_ fileName: String) -> String {
        let components = fileName
            .replacingOccurrences(of: "\\", with: "/")
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)
            .filter { $0 != "." && $0 != ".." }
        return components.isEmpty ? "file" : components.joined(separator: "/")
    }

    /// Appends " (n)" before the extension of the last component until `exists` reports a free name.
    public static func uniqueName(for fileName: String, exists: (String) -> Bool) -> String {
        let path = safeRelativePath(fileName)
        if !exists(path) { return path }

        var components = path.split(separator: "/").map(String.init)
        let last = components.removeLast()
        let prefix = components.isEmpty ? "" : components.joined(separator: "/") + "/"
        let ext = (last as NSString).pathExtension
        let stem = ext.isEmpty ? last : String((last as NSString).deletingPathExtension)

        var counter = 1
        while true {
            let candidate = ext.isEmpty ? "\(prefix)\(stem) (\(counter))" : "\(prefix)\(stem) (\(counter)).\(ext)"
            if !exists(candidate) { return candidate }
            counter += 1
        }
    }
}
