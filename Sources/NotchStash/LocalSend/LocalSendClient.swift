import Foundation
import NotchStashCore

/// A LocalSend device found on the network.
struct LocalSendPeer: Identifiable, Equatable, Sendable {
    var id: String { fingerprint }
    let fingerprint: String
    var alias: String
    var deviceModel: String?
    var deviceType: String?
    var ip: String
    var port: Int
    var scheme: String
    var lastSeen: Date

    var baseURL: URL? {
        URL(string: "\(scheme)://\(ip):\(port)/api/localsend/v2")
    }
}

/// Session, file and token that authorise one upload.
struct LocalSendUploadTicket: Sendable {
    let sessionId: String
    let fileId: String
    let token: String
}

/// Outcome of asking a peer to accept files.
enum LocalSendPrepareResult: Sendable {
    case accepted(LocalSendPrepareUploadResponse)
    case nothingToSend
    case declined
    case busy
    case pinRequired
    case failed(String)
}

/// HTTP client side of LocalSend v2. Peers use self-signed certificates, so server trust is accepted as is.
final class LocalSendClient: NSObject, URLSessionDelegate, @unchecked Sendable {
    private lazy var session = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil)
    private lazy var probeSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 1.5
        configuration.httpMaximumConnectionsPerHost = 1
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()

    /// Asks `ip` directly whether it runs Notch Stash or LocalSend (HTTPS first, then HTTP).
    /// Registering also tells that device about this one.
    func probe(_ ip: String, info: LocalSendDeviceInfo) async -> (LocalSendDeviceInfo, scheme: String)? {
        for scheme in ["https", "http"] {
            guard let url = URL(string: "\(scheme)://\(ip):53317/api/localsend/v2/register") else { continue }
            var request = URLRequest(url: url, timeoutInterval: 1.5)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONEncoder().encode(info)
            do {
                let (data, response) = try await probeSession.data(for: request)
                guard (response as? HTTPURLResponse)?.statusCode == 200,
                      let peer = try? JSONDecoder().decode(LocalSendDeviceInfo.self, from: data) else { return nil }
                return (peer, scheme)
            } catch let error as URLError where [.cannotConnectToHost, .timedOut, .cannotFindHost].contains(error.code) {
                return nil
            } catch {
                continue
            }
        }
        return nil
    }

    func register(to peer: LocalSendPeer, info: LocalSendDeviceInfo) async {
        guard let url = peer.baseURL?.appending(path: "register") else { return }
        var request = URLRequest(url: url, timeoutInterval: 5)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(info)
        _ = try? await session.data(for: request)
    }

    func prepareUpload(to peer: LocalSendPeer, request body: LocalSendPrepareUploadRequest) async -> LocalSendPrepareResult {
        guard let url = peer.baseURL?.appending(path: "prepare-upload") else { return .failed("Invalid address") }
        var request = URLRequest(url: url, timeoutInterval: 120)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(body)
        do {
            let (data, response) = try await session.data(for: request)
            switch (response as? HTTPURLResponse)?.statusCode ?? 0 {
            case 200:
                guard let decoded = try? JSONDecoder().decode(LocalSendPrepareUploadResponse.self, from: data) else {
                    return .failed("Unexpected reply")
                }
                return .accepted(decoded)
            case 204: return .nothingToSend
            case 401: return .pinRequired
            case 403: return .declined
            case 409, 429: return .busy
            case let code: return .failed("Error \(code)")
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    func upload(
        _ file: URL,
        to peer: LocalSendPeer,
        ticket: LocalSendUploadTicket,
        progress: @escaping @Sendable (Int64) -> Void
    ) async throws {
        guard var components = peer.baseURL.flatMap({ URLComponents(url: $0.appending(path: "upload"), resolvingAgainstBaseURL: false) })
        else { throw URLError(.badURL) }
        components.queryItems = [
            URLQueryItem(name: "sessionId", value: ticket.sessionId),
            URLQueryItem(name: "fileId", value: ticket.fileId),
            URLQueryItem(name: "token", value: ticket.token)
        ]
        guard let url = components.url else { throw URLError(.badURL) }
        var request = URLRequest(url: url, timeoutInterval: 300)
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        let (_, response) = try await session.upload(for: request, fromFile: file, delegate: UploadProgress(progress))
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw URLError(.badServerResponse) }
    }

    func cancel(_ peer: LocalSendPeer, sessionId: String) async {
        guard var components = peer.baseURL.flatMap({ URLComponents(url: $0.appending(path: "cancel"), resolvingAgainstBaseURL: false) })
        else { return }
        components.queryItems = [URLQueryItem(name: "sessionId", value: sessionId)]
        guard let url = components.url else { return }
        var request = URLRequest(url: url, timeoutInterval: 5)
        request.httpMethod = "POST"
        _ = try? await session.data(for: request)
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge
    ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust else {
            return (.performDefaultHandling, nil)
        }
        return (.useCredential, URLCredential(trust: trust))
    }
}

/// Reports bytes sent for one upload.
private final class UploadProgress: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let onProgress: @Sendable (Int64) -> Void

    init(_ onProgress: @escaping @Sendable (Int64) -> Void) {
        self.onProgress = onProgress
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        onProgress(totalBytesSent)
    }
}
