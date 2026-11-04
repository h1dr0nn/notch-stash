/// Dotted numeric version such as 0.6.1, comparable component by component.
public struct AppVersion: Comparable, Sendable, CustomStringConvertible {
    public let components: [Int]

    /// Accepts "0.6.1", "v0.6.1" and release tags such as "release-v0.6.1".
    public init?(_ text: String) {
        var trimmed = Substring(text)
        if let range = trimmed.range(of: "-v") {
            trimmed = trimmed[range.upperBound...]
        } else if trimmed.hasPrefix("v") {
            trimmed = trimmed.dropFirst()
        }
        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false).map { Int($0) }
        guard !parts.isEmpty, parts.allSatisfy({ $0 != nil }) else { return nil }
        components = parts.compactMap { $0 }
    }

    public var description: String {
        components.map(String.init).joined(separator: ".")
    }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)
        for index in 0..<count {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right { return left < right }
        }
        return false
    }

    public static func == (lhs: AppVersion, rhs: AppVersion) -> Bool {
        !(lhs < rhs) && !(rhs < lhs)
    }
}
