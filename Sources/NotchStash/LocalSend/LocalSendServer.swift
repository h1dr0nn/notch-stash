import Foundation
import Network
import NotchStashCore
import OSLog

/// A request that arrived at the LocalSend HTTP server.
struct LocalSendRequest: Sendable {
    let head: HTTPRequestHead
    let body: Data
    let remoteIP: String
}

/// What the server sends back.
struct LocalSendResponse: Sendable {
    var status: Int
    var body: Data = Data()

    static func json<T: Encodable>(_ value: T) -> LocalSendResponse {
        LocalSendResponse(status: 200, body: (try? JSONEncoder().encode(value)) ?? Data())
    }
}

/// How an upload request should be stored, decided before its body is read.
enum LocalSendUploadTarget: Sendable {
    case write(URL)
    case reject(LocalSendResponse)
}

/// Minimal HTTP/1.1 server for the LocalSend v2 API. Bodies of uploads stream straight to disk.
final class LocalSendServer: @unchecked Sendable {
    /// Handles every request except the body of an upload.
    var handleRequest: @Sendable (LocalSendRequest) async -> LocalSendResponse = { _ in LocalSendResponse(status: 404) }
    /// Picks where an upload goes; called once its head has arrived.
    var prepareUpload: @Sendable (HTTPRequestHead, String) async -> LocalSendUploadTarget = { _, _ in
        .reject(LocalSendResponse(status: 403))
    }
    /// Called when an upload finished writing (success) or failed.
    var finishUpload: @Sendable (HTTPRequestHead, URL, Bool) async -> LocalSendResponse = { _, _, _ in LocalSendResponse(status: 500) }

    private(set) var port: UInt16 = 0
    private var listener: NWListener?
    let queue = DispatchQueue(label: "local.notch-stash.server")
    private let log = Logger(subsystem: "local.notch-stash", category: "localsend")

    /// Starts on the LocalSend default port, or any free port when it is taken (e.g. by the LocalSend app).
    func start() -> Bool {
        for candidate in [NWEndpoint.Port(rawValue: 53317), .any].compactMap({ $0 }) {
            guard let listener = try? NWListener(using: .tcp, on: candidate) else { continue }
            let ready = DispatchSemaphore(value: 0)
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready, .failed, .cancelled: ready.signal()
                default: break
                }
            }
            listener.newConnectionHandler = { [weak self] connection in self?.accept(connection) }
            listener.start(queue: queue)
            _ = ready.wait(timeout: .now() + 2)
            if listener.state == .ready, let actual = listener.port?.rawValue {
                self.listener = listener
                port = actual
                log.notice("LocalSend server on port \(actual)")
                return true
            }
            listener.cancel()
        }
        return false
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func accept(_ connection: NWConnection) {
        connection.start(queue: queue)
        let remoteIP: String
        if case let .hostPort(host, _) = connection.endpoint {
            remoteIP = "\(host)".components(separatedBy: "%").first ?? "\(host)"
        } else {
            remoteIP = ""
        }
        ConnectionHandler(connection: connection, remoteIP: remoteIP, server: self).run()
    }

    fileprivate func respond(_ connection: NWConnection, _ response: LocalSendResponse) {
        var head = "HTTP/1.1 \(response.status) \(Self.reason(response.status))\r\n"
        head += "Content-Type: application/json\r\n"
        head += "Content-Length: \(response.body.count)\r\n"
        head += "Connection: close\r\n\r\n"
        var data = Data(head.utf8)
        data.append(response.body)
        connection.send(content: data, completion: .contentProcessed { _ in connection.cancel() })
    }

    private static func reason(_ status: Int) -> String {
        switch status {
        case 200: "OK"
        case 204: "No Content"
        case 400: "Bad Request"
        case 401: "Unauthorized"
        case 403: "Forbidden"
        case 404: "Not Found"
        case 409: "Conflict"
        case 413: "Payload Too Large"
        default: "Error"
        }
    }
}

/// Reads one request from a connection and answers it. All callbacks run on the server's serial queue.
private final class ConnectionHandler: @unchecked Sendable {
    private static let maxJSONBody = 4 * 1024 * 1024
    private static let chunkSize = 1024 * 1024

    private let connection: NWConnection
    private let remoteIP: String
    private let server: LocalSendServer
    private var buffer = Data()
    private var head: HTTPRequestHead?
    private var reader: BodyReader?
    private var body = Data()
    private var upload: (url: URL, handle: FileHandle)?

    init(connection: NWConnection, remoteIP: String, server: LocalSendServer) {
        self.connection = connection
        self.remoteIP = remoteIP
        self.server = server
    }

    func run() {
        receiveHead()
    }

    private func receiveHead() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [self] data, _, isComplete, error in
            if let data { buffer.append(data) }
            // 0x16 starts a TLS handshake: this server only speaks HTTP, so refuse at once and let
            // the client fall back instead of waiting for a request that never comes.
            if buffer.first == 0x16 {
                connection.cancel()
                return
            }
            if let (parsed, bodyStart) = HTTPRequestHead.parse(buffer) {
                let leftover = buffer.subdata(in: bodyStart..<buffer.count)
                buffer = Data()
                head = parsed
                reader = BodyReader(head: parsed)
                if parsed.method == "POST", parsed.path == "/api/localsend/v2/upload" {
                    startUpload(parsed, leftover)
                } else {
                    consumeJSON(leftover, ended: false)
                }
            } else if error != nil || isComplete || buffer.count > 64 * 1024 {
                connection.cancel()
            } else {
                receiveHead()
            }
        }
    }

    private func consumeJSON(_ data: Data, ended: Bool) {
        guard let reader else { return }
        do {
            body.append(try reader.consume(data))
        } catch {
            return server.respond(connection, LocalSendResponse(status: 400))
        }
        if body.count > Self.maxJSONBody {
            server.respond(connection, LocalSendResponse(status: 413))
        } else if reader.isComplete || (ended && !reader.hasLength) {
            respondToJSON()
        } else if ended {
            connection.cancel()
        } else {
            connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [self] data, _, isComplete, error in
                consumeJSON(data ?? Data(), ended: isComplete || error != nil)
            }
        }
    }

    private func respondToJSON() {
        guard let head else { return }
        let request = LocalSendRequest(head: head, body: body, remoteIP: remoteIP)
        Task { [server, connection] in
            let response = await server.handleRequest(request)
            server.respond(connection, response)
        }
    }

    private func startUpload(_ head: HTTPRequestHead, _ initial: Data) {
        Task { [self, server, remoteIP] in
            let target = await server.prepareUpload(head, remoteIP)
            server.queue.async { [self] in
                switch target {
                case let .reject(response):
                    server.respond(connection, response)
                case let .write(url):
                    guard FileManager.default.createFile(atPath: url.path, contents: nil),
                          let handle = try? FileHandle(forWritingTo: url) else {
                        return server.respond(connection, LocalSendResponse(status: 500))
                    }
                    upload = (url, handle)
                    consumeUpload(initial, ended: false)
                }
            }
        }
    }

    private func consumeUpload(_ data: Data, ended: Bool) {
        guard let reader, let upload else { return }
        do {
            let decoded = try reader.consume(data)
            if !decoded.isEmpty { try upload.handle.write(contentsOf: decoded) }
        } catch {
            return finishUpload(false)
        }
        if reader.isComplete {
            finishUpload(true)
        } else if ended {
            finishUpload(!reader.hasLength)
        } else {
            connection.receive(minimumIncompleteLength: 1, maximumLength: Self.chunkSize) { [self] data, _, isComplete, error in
                consumeUpload(data ?? Data(), ended: isComplete || error != nil)
            }
        }
    }

    private func finishUpload(_ success: Bool) {
        guard let head, let upload else { return }
        try? upload.handle.close()
        self.upload = nil
        Task { [server, connection] in
            let response = await server.finishUpload(head, upload.url, success)
            server.respond(connection, response)
        }
    }
}

/// Tracks a body by Content-Length or chunked encoding.
private final class BodyReader: @unchecked Sendable {
    private var remaining: Int?
    private var chunked: ChunkedBodyDecoder?

    init(head: HTTPRequestHead) {
        if head.isChunked {
            chunked = ChunkedBodyDecoder()
        } else {
            remaining = head.contentLength ?? 0
        }
    }

    var hasLength: Bool { remaining != nil || chunked != nil }

    var isComplete: Bool {
        if let chunked { return chunked.isFinished }
        return (remaining ?? 0) <= 0
    }

    func consume(_ data: Data) throws -> Data {
        if var decoder = chunked {
            let decoded = try decoder.feed(data)
            chunked = decoder
            return decoded
        }
        let take = min(data.count, remaining ?? 0)
        remaining = (remaining ?? 0) - take
        return data.prefix(take)
    }
}
