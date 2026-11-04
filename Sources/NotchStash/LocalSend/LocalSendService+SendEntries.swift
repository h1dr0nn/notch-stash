import Foundation
import UniformTypeIdentifiers

extension LocalSendService {
    /// A file to send, with folders flattened into their files and relative paths.
    struct SendEntry {
        let url: URL
        let name: String
        let size: Int64
        let mimeType: String
    }

    static func expand(_ urls: [URL]) -> [SendEntry] {
        var entries: [SendEntry] = []
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey, .contentTypeKey]
        func entry(_ url: URL, name: String) -> SendEntry? {
            guard let values = try? url.resourceValues(forKeys: Set(keys)), values.isRegularFile == true else { return nil }
            let mime = values.contentType?.preferredMIMEType ?? "application/octet-stream"
            return SendEntry(url: url, name: name, size: Int64(values.fileSize ?? 0), mimeType: mime)
        }
        for url in urls {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else { continue }
            if !isDirectory.boolValue {
                if let single = entry(url, name: url.lastPathComponent) { entries.append(single) }
                continue
            }
            let base = url.deletingLastPathComponent().standardizedFileURL.path
            let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])
            while let child = enumerator?.nextObject() as? URL {
                let relative = String(child.standardizedFileURL.path.dropFirst(base.count + 1))
                if let nested = entry(child, name: relative) { entries.append(nested) }
            }
        }
        return entries
    }
}
