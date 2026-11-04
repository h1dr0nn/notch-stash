import Foundation

/// Errors thrown while decoding a chunked transfer-encoded body.
public enum ChunkedBodyError: Error, Sendable, Equatable {
    case invalidChunkSize
    case missingChunkTerminator
}

/// Incremental decoder for Transfer-Encoding: chunked bodies.
public struct ChunkedBodyDecoder: Sendable {
    private enum State: Sendable {
        case sizeLine
        case payload(remaining: Int)
        case payloadCR
        case payloadLF
        case trailers
        case finished
    }

    private var state: State = .sizeLine
    private var line: [UInt8] = []

    public private(set) var isFinished = false

    public init() {}

    /// Feeds raw bytes and returns the decoded payload bytes available so far.
    public mutating func feed(_ data: Data) throws -> Data {
        var output = Data()
        let bytes = [UInt8](data)
        var index = 0
        while index < bytes.count {
            if case .finished = state { break }
            if case .payload(let remaining) = state {
                let take = min(remaining, bytes.count - index)
                output.append(contentsOf: bytes[index..<(index + take)])
                index += take
                state = take == remaining ? .payloadCR : .payload(remaining: remaining - take)
            } else {
                try consume(bytes[index])
                index += 1
            }
        }
        return output
    }

    private mutating func consume(_ byte: UInt8) throws {
        switch state {
        case .payloadCR:
            guard byte == 13 else { throw ChunkedBodyError.missingChunkTerminator }
            state = .payloadLF
        case .payloadLF:
            guard byte == 10 else { throw ChunkedBodyError.missingChunkTerminator }
            state = .sizeLine
        case .sizeLine:
            if byte == 10 { try finishSizeLine() } else { line.append(byte) }
        case .trailers:
            if byte == 10 {
                let isBlank = line.isEmpty || line == [13]
                line.removeAll()
                if isBlank {
                    state = .finished
                    isFinished = true
                }
            } else {
                line.append(byte)
            }
        case .payload, .finished:
            break
        }
    }

    private mutating func finishSizeLine() throws {
        var raw = line
        line.removeAll()
        if raw.last == 13 { raw.removeLast() }
        if let semicolon = raw.firstIndex(of: 59) { raw = Array(raw[..<semicolon]) }
        let text = (String(bytes: raw, encoding: .utf8) ?? "").trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, let size = Int(text, radix: 16), size >= 0 else {
            throw ChunkedBodyError.invalidChunkSize
        }
        state = size == 0 ? .trailers : .payload(remaining: size)
    }
}
