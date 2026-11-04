import AppKit
import Combine
import NotchStashCore
import OSLog
import UniformTypeIdentifiers

/// Progress of sending files to one peer.
enum LocalSendTransferState: Equatable {
    case waiting
    case sending(Double)
    case done
    case declined
    case busy
    case failed(String)

    var isSending: Bool {
        if case .sending = self { return true }
        return false
    }
}

/// Files another device wants to send; the user accepts or declines.
struct LocalSendIncomingRequest: Identifiable {
    let id = UUID()
    let sender: LocalSendDeviceInfo
    let files: [LocalSendFileInfo]

    var totalSize: Int64 { files.reduce(0) { $0 + $1.size } }

    var headline: String {
        "\(sender.alias) wants to send you \(files.count == 1 ? "a file" : "\(files.count) files")"
    }

    @MainActor var detail: String {
        let folder = (AppSettings.shared.saveFolderPath as NSString).abbreviatingWithTildeInPath
        return "\(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)) · to \(folder)"
    }
}

/// LocalSend v2 on this Mac: discovery, receiving into the shelf, and sending shelf files to nearby devices.
@MainActor
final class LocalSendService: ObservableObject {
    @Published private(set) var peers: [LocalSendPeer] = []
    @Published private(set) var isRunning = false
    @Published private(set) var incoming: LocalSendIncomingRequest?
    @Published private(set) var transfers: [String: LocalSendTransferState] = [:]

    var onIncomingRequest: () -> Void = {}
    let localNetwork = LocalNetworkPermission()

    private let settings = AppSettings.shared
    private let store: ShelfStore
    private let client = LocalSendClient()
    private let server = LocalSendServer()
    private var multicast: MulticastSocket?
    private var incomingDecision: CheckedContinuation<Bool, Never>?
    private var session: ReceiveSession?
    private var sendTasks: [String: Task<Void, Never>] = [:]
    private var cancellables: Set<AnyCancellable> = []
    private let log = Logger(subsystem: "local.notch-stash", category: "localsend")

    /// An accepted incoming transfer.
    private struct ReceiveSession {
        let id: String
        let senderIP: String
        let files: [String: LocalSendFileInfo]
        let tokens: [String: String]
        var reservedPaths: Set<String> = []
        var finished: Set<String> = []
    }

    init(store: ShelfStore) {
        self.store = store
    }

    func start() {
        settings.$nearbySharingEnabled
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] enabled in enabled ? self?.startNetworking() : self?.stopNetworking() }
            .store(in: &cancellables)
        localNetwork.$state
            .removeDuplicates()
            .filter { $0 == .allowed }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.scan() }
            .store(in: &cancellables)
    }

    // MARK: Networking lifecycle

    private func startNetworking() {
        guard !isRunning else { return }
        server.handleRequest = { [weak self] request in
            await self?.handle(request) ?? LocalSendResponse(status: 500)
        }
        server.prepareUpload = { [weak self] head, ip in
            await self?.uploadTarget(head, from: ip) ?? .reject(LocalSendResponse(status: 500))
        }
        server.finishUpload = { [weak self] head, url, success in
            await self?.uploadFinished(head, url: url, success: success) ?? LocalSendResponse(status: 500)
        }
        guard server.start() else {
            log.error("LocalSend server could not start")
            return
        }
        let socket = MulticastSocket { [weak self] data, ip in
            Task { @MainActor in self?.multicastMessage(data, from: ip) }
        }
        if socket.start() {
            multicast = socket
        } else {
            log.error("LocalSend multicast could not start")
        }
        isRunning = true
        localNetwork.check()
        announce()
    }

    private func stopNetworking() {
        multicast?.stop()
        multicast = nil
        server.stop()
        localNetwork.stop()
        peers = []
        isRunning = false
    }

    // MARK: Discovery

    func ownInfo(announce: Bool? = nil) -> LocalSendDeviceInfo {
        LocalSendDeviceInfo(
            alias: settings.deviceName,
            version: "2.1",
            deviceModel: "Mac",
            deviceType: "desktop",
            fingerprint: settings.localSendFingerprint,
            port: Int(server.port),
            protocol: "http",
            download: false,
            announce: announce
        )
    }

    /// Asks every LocalSend device on the network to introduce itself.
    func scan() {
        let staleBefore = Date().addingTimeInterval(-30)
        peers.removeAll { $0.lastSeen < staleBefore }
        announce()
        for delay in [1.0, 3.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.announce() }
        }
    }

    private func announce() {
        guard let data = try? JSONEncoder().encode(ownInfo(announce: true)) else { return }
        multicast?.send(data)
    }

    private func multicastMessage(_ data: Data, from ip: String) {
        guard let info = try? JSONDecoder().decode(LocalSendDeviceInfo.self, from: data),
              info.fingerprint != settings.localSendFingerprint else { return }
        let peer = upsert(info, ip: ip)
        guard info.announce == true else { return }
        let reply = ownInfo()
        Task {
            await client.register(to: peer, info: reply)
        }
        if let data = try? JSONEncoder().encode(ownInfo(announce: false)) {
            multicast?.send(data)
        }
    }

    @discardableResult
    private func upsert(_ info: LocalSendDeviceInfo, ip: String) -> LocalSendPeer {
        let peer = LocalSendPeer(
            fingerprint: info.fingerprint,
            alias: info.alias,
            deviceModel: info.deviceModel,
            deviceType: info.deviceType,
            ip: ip,
            port: info.port ?? 53317,
            scheme: info.protocol ?? "https",
            lastSeen: Date()
        )
        if let index = peers.firstIndex(where: { $0.fingerprint == info.fingerprint }) {
            peers[index] = peer
        } else {
            peers.append(peer)
            peers.sort { $0.alias.localizedCaseInsensitiveCompare($1.alias) == .orderedAscending }
        }
        return peer
    }

    // MARK: Receiving

    private func handle(_ request: LocalSendRequest) async -> LocalSendResponse {
        switch (request.head.method, request.head.path) {
        case ("POST", "/api/localsend/v2/register"):
            if let info = try? JSONDecoder().decode(LocalSendDeviceInfo.self, from: request.body),
               info.fingerprint != settings.localSendFingerprint {
                upsert(info, ip: request.remoteIP)
            }
            return .json(ownInfo())
        case ("GET", "/api/localsend/v2/info"):
            return .json(ownInfo())
        case ("POST", "/api/localsend/v2/prepare-upload"):
            return await prepareIncoming(request)
        case ("POST", "/api/localsend/v2/cancel"):
            if session?.id == request.head.query["sessionId"] { session = nil }
            return LocalSendResponse(status: 200)
        default:
            return LocalSendResponse(status: 404)
        }
    }

    private func prepareIncoming(_ request: LocalSendRequest) async -> LocalSendResponse {
        guard settings.receiveFiles else { return LocalSendResponse(status: 403) }
        guard session == nil, incoming == nil else { return LocalSendResponse(status: 409) }
        guard let body = try? JSONDecoder().decode(LocalSendPrepareUploadRequest.self, from: request.body) else {
            return LocalSendResponse(status: 400)
        }
        guard !body.files.isEmpty else { return LocalSendResponse(status: 204) }
        upsert(body.info, ip: request.remoteIP)

        let files = body.files.values.sorted { $0.fileName < $1.fileName }
        incoming = LocalSendIncomingRequest(sender: body.info, files: files)
        onIncomingRequest()
        let accepted = await withCheckedContinuation { continuation in
            incomingDecision = continuation
            DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in self?.decideIncoming(false) }
        }
        guard accepted else { return LocalSendResponse(status: 403) }

        let tokens = Dictionary(uniqueKeysWithValues: body.files.keys.map { ($0, UUID().uuidString) })
        let newSession = ReceiveSession(id: UUID().uuidString, senderIP: request.remoteIP, files: body.files, tokens: tokens)
        session = newSession
        return .json(LocalSendPrepareUploadResponse(sessionId: newSession.id, files: tokens))
    }

    /// Answers the pending incoming request; called from the prompt window or on timeout.
    func decideIncoming(_ accept: Bool) {
        incoming = nil
        incomingDecision?.resume(returning: accept)
        incomingDecision = nil
    }

    private func uploadTarget(_ head: HTTPRequestHead, from ip: String) -> LocalSendUploadTarget {
        guard var current = session,
              let fileId = head.query["fileId"],
              let file = current.files[fileId],
              head.query["sessionId"] == current.id,
              head.query["token"] == current.tokens[fileId],
              ip == current.senderIP else {
            return .reject(LocalSendResponse(status: 403))
        }
        let folder = URL(fileURLWithPath: settings.saveFolderPath, isDirectory: true)
        let relative = FileNaming.uniqueName(for: FileNaming.safeRelativePath(file.fileName)) { candidate in
            current.reservedPaths.contains(candidate)
                || FileManager.default.fileExists(atPath: folder.appending(path: candidate).path)
        }
        current.reservedPaths.insert(relative)
        session = current
        let destination = folder.appending(path: relative)
        try? FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        return .write(destination)
    }

    private func uploadFinished(_ head: HTTPRequestHead, url: URL, success: Bool) -> LocalSendResponse {
        guard success else {
            try? FileManager.default.removeItem(at: url)
            return LocalSendResponse(status: 500)
        }
        store.add([url])
        if var current = session, let fileId = head.query["fileId"] {
            current.finished.insert(fileId)
            session = current.finished.count == current.files.count ? nil : current
        }
        return LocalSendResponse(status: 200)
    }
}

// MARK: - Sending

extension LocalSendService {
    func send(_ urls: [URL], to peer: LocalSendPeer) {
        sendTasks[peer.id]?.cancel()
        transfers[peer.id] = .waiting
        sendTasks[peer.id] = Task { [weak self] in
            await self?.performSend(urls, to: peer)
        }
    }

    /// Forgets finished transfers before the Send window opens again; running ones keep going.
    func clearTransfers() {
        transfers = transfers.filter { sendTasks[$0.key] != nil && ($0.value == .waiting || $0.value.isSending) }
    }

    func cancelSend(to peer: LocalSendPeer) {
        sendTasks[peer.id]?.cancel()
        sendTasks[peer.id] = nil
        transfers[peer.id] = nil
    }

    private func performSend(_ urls: [URL], to peer: LocalSendPeer) async {
        let entries = Self.expand(urls)
        guard !entries.isEmpty else {
            transfers[peer.id] = .failed("Nothing to send")
            return
        }
        var files: [String: LocalSendFileInfo] = [:]
        var sources: [String: URL] = [:]
        for entry in entries {
            let id = UUID().uuidString
            files[id] = LocalSendFileInfo(id: id, fileName: entry.name, size: entry.size, fileType: entry.mimeType)
            sources[id] = entry.url
        }
        let request = LocalSendPrepareUploadRequest(info: ownInfo(), files: files)
        switch await client.prepareUpload(to: peer, request: request) {
        case let .accepted(response):
            await upload(response, files: files, sources: sources, to: peer)
        case .nothingToSend:
            transfers[peer.id] = .done
        case .declined:
            transfers[peer.id] = .declined
        case .busy:
            transfers[peer.id] = .busy
        case .pinRequired:
            transfers[peer.id] = .failed("This device asks for a PIN, which Notch Stash does not support yet.")
        case let .failed(message):
            transfers[peer.id] = .failed(message)
        }
    }

    private func upload(
        _ response: LocalSendPrepareUploadResponse,
        files: [String: LocalSendFileInfo],
        sources: [String: URL],
        to peer: LocalSendPeer
    ) async {
        let accepted = response.files.keys.filter { sources[$0] != nil }
        let total = max(accepted.reduce(Int64(0)) { $0 + (files[$1]?.size ?? 0) }, 1)
        var completed: Int64 = 0
        transfers[peer.id] = .sending(0)
        do {
            for fileId in accepted {
                guard let source = sources[fileId], let token = response.files[fileId] else { continue }
                try Task.checkCancellation()
                let base = completed
                let ticket = LocalSendUploadTicket(sessionId: response.sessionId, fileId: fileId, token: token)
                try await client.upload(source, to: peer, ticket: ticket) { [weak self] sent in
                    Task { @MainActor in
                        guard case .sending = self?.transfers[peer.id] else { return }
                        self?.transfers[peer.id] = .sending(Double(base + sent) / Double(total))
                    }
                }
                completed += files[fileId]?.size ?? 0
            }
            transfers[peer.id] = .done
        } catch is CancellationError {
            await client.cancel(peer, sessionId: response.sessionId)
        } catch {
            await client.cancel(peer, sessionId: response.sessionId)
            transfers[peer.id] = .failed(error.localizedDescription)
        }
    }

    /// A file to send, with folders flattened into their files and relative paths.
    private struct SendEntry {
        let url: URL
        let name: String
        let size: Int64
        let mimeType: String
    }

    private static func expand(_ urls: [URL]) -> [SendEntry] {
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
