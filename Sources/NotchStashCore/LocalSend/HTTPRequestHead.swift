import Foundation

/// Parsed HTTP/1.1 request head.
public struct HTTPRequestHead: Sendable, Equatable {
    public let method: String
    public let path: String
    public let query: [String: String]
    public let headers: [String: String]

    public var contentLength: Int? {
        headers["content-length"].flatMap { Int($0) }
    }

    public var isChunked: Bool {
        headers["transfer-encoding"]?.lowercased().contains("chunked") ?? false
    }

    public init(method: String, path: String, query: [String: String], headers: [String: String]) {
        self.method = method
        self.path = path
        self.query = query
        self.headers = headers
    }

    /// Finds the blank line ending the head; returns nil while the head is incomplete.
    public static func parse(_ data: Data) -> (head: HTTPRequestHead, bodyStart: Int)? {
        let bytes = [UInt8](data)
        guard let end = headEnd(in: bytes) else { return nil }
        let text = String(bytes: bytes[0..<end], encoding: .utf8) ?? ""
        let lines = text.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return nil }
        let parts = requestLine.split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count >= 2 else { return nil }

        let target = String(parts[1])
        let rawPath: String
        let rawQuery: String
        if let mark = target.firstIndex(of: "?") {
            rawPath = String(target[..<mark])
            rawQuery = String(target[target.index(after: mark)...])
        } else {
            rawPath = target
            rawQuery = ""
        }

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            if !key.isEmpty { headers[key] = value }
        }

        let head = HTTPRequestHead(
            method: String(parts[0]).uppercased(),
            path: decode(rawPath),
            query: parseQuery(rawQuery),
            headers: headers
        )
        return (head, end + 4)
    }

    private static func headEnd(in bytes: [UInt8]) -> Int? {
        guard bytes.count >= 4 else { return nil }
        var index = 0
        while index + 3 < bytes.count {
            if bytes[index] == 13, bytes[index + 1] == 10, bytes[index + 2] == 13, bytes[index + 3] == 10 {
                return index
            }
            index += 1
        }
        return nil
    }

    private static func parseQuery(_ raw: String) -> [String: String] {
        var result: [String: String] = [:]
        for pair in raw.split(separator: "&", omittingEmptySubsequences: true) {
            let pieces = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            let key = decode(String(pieces[0]))
            let value = pieces.count > 1 ? decode(String(pieces[1])) : ""
            result[key] = value
        }
        return result
    }

    private static func decode(_ value: String) -> String {
        value.removingPercentEncoding ?? value
    }
}
