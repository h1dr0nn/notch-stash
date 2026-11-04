import AppKit
import CryptoKit
import NotchStashCore
import OSLog

/// Checks GitHub Releases for a newer version and installs it in place.
@MainActor
final class Updater: ObservableObject {
    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(Release)
        case downloading(Double)
        case installing
        case failed(String)
    }

    /// The newest published release and its zip asset.
    struct Release: Equatable {
        let version: String
        let zipURL: URL
        let sha256: String?
        let pageURL: URL
    }

    @Published private(set) var state: State = .idle

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    var availableRelease: Release? {
        if case let .available(release) = state { return release }
        return nil
    }

    private static let latestReleaseURL = URL(string: "https://api.github.com/repos/h1dr0nn/notch-stash/releases/latest")
    private var timer: Timer?
    private let log = Logger(subsystem: "local.notch-stash", category: "update")

    /// Checks shortly after launch and then once a day.
    func startAutomaticChecks() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in self?.checkIfAllowed() }
        timer = Timer.scheduledTimer(withTimeInterval: 24 * 60 * 60, repeats: true) { _ in
            MainActor.assumeIsolated { [weak self] in self?.checkIfAllowed() }
        }
    }

    private func checkIfAllowed() {
        guard AppSettings.shared.checkForUpdates else { return }
        Task { await check() }
    }

    func check() async {
        guard let url = Self.latestReleaseURL else { return }
        if case .downloading = state { return }
        state = .checking
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                state = .failed("GitHub did not answer. Try again later.")
                return
            }
            let latest = try JSONDecoder().decode(GitHubRelease.self, from: data)
            guard let version = AppVersion(latest.tagName),
                  let current = AppVersion(currentVersion),
                  version > current else {
                state = .upToDate
                return
            }
            let zipName = "NotchStash-\(version).zip"
            guard let asset = latest.assets.first(where: { $0.name == zipName }),
                  let zipURL = URL(string: asset.browserDownloadURL),
                  let pageURL = URL(string: latest.htmlURL) else {
                state = .failed("Version \(version) has no Mac download.")
                return
            }
            let sha256 = asset.digest.flatMap { $0.hasPrefix("sha256:") ? String($0.dropFirst(7)) : nil }
            state = .available(Release(version: version.description, zipURL: zipURL, sha256: sha256, pageURL: pageURL))
            log.notice("Update available: \(version.description, privacy: .public)")
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// Downloads, verifies and swaps in the new app, then relaunches it.
    func install(_ release: Release) async {
        state = .downloading(0)
        do {
            let workDirectory = FileManager.default.temporaryDirectory.appending(path: "NotchStashUpdate-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: workDirectory, withIntermediateDirectories: true)
            let zip = workDirectory.appending(path: "update.zip")
            try await download(release.zipURL, to: zip)
            if let expected = release.sha256 {
                let digest = SHA256.hash(data: try Data(contentsOf: zip, options: .mappedIfSafe))
                let actual = digest.map { String(format: "%02x", $0) }.joined()
                guard actual == expected.lowercased() else { throw UpdateError("The download is damaged. Try again.") }
            }
            state = .installing
            let unpacked = workDirectory.appending(path: "unpacked")
            try run("/usr/bin/ditto", ["-x", "-k", zip.path, unpacked.path])
            let newApp = unpacked.appending(path: "Notch Stash.app")
            guard Bundle(url: newApp)?.bundleIdentifier == Bundle.main.bundleIdentifier else {
                throw UpdateError("The download is not Notch Stash.")
            }
            try relaunch(replacing: Bundle.main.bundleURL, with: newApp, cleaning: workDirectory)
        } catch let error as UpdateError {
            state = .failed(error.message)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func download(_ url: URL, to destination: URL) async throws {
        let (bytes, response) = try await URLSession.shared.bytes(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw UpdateError("The download failed.") }
        let expected = max(response.expectedContentLength, 1)
        FileManager.default.createFile(atPath: destination.path, contents: nil)
        let handle = try FileHandle(forWritingTo: destination)
        defer { try? handle.close() }
        var buffer = Data()
        var written: Int64 = 0
        for try await byte in bytes {
            buffer.append(byte)
            if buffer.count >= 256 * 1024 {
                try handle.write(contentsOf: buffer)
                written += Int64(buffer.count)
                buffer.removeAll(keepingCapacity: true)
                state = .downloading(Double(written) / Double(expected))
            }
        }
        try handle.write(contentsOf: buffer)
    }

    /// A detached shell waits for this process to quit, swaps the bundles and opens the new one.
    private func relaunch(replacing current: URL, with newApp: URL, cleaning workDirectory: URL) throws {
        let folder = current.deletingLastPathComponent()
        guard FileManager.default.isWritableFile(atPath: folder.path) else {
            throw UpdateError("Notch Stash cannot write to \(folder.path). Download the update from GitHub instead.")
        }
        let script = """
        while kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do sleep 0.2; done
        rm -rf "$1" && mv "$2" "$1" && open "$1"
        rm -rf "$3"
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script, "sh", current.path, newApp.path, workDirectory.path]
        try process.run()
        NSApp.terminate(nil)
    }

    private func run(_ tool: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw UpdateError("The download could not be unpacked.") }
    }
}

private struct UpdateError: Error {
    let message: String
    init(_ message: String) { self.message = message }
}

/// A downloadable file of a GitHub release.
private struct GitHubAsset: Decodable {
    let name: String
    let browserDownloadURL: String
    let digest: String?

    enum CodingKeys: String, CodingKey {
        case name, digest
        case browserDownloadURL = "browser_download_url"
    }
}

/// The parts of a GitHub release the updater needs.
private struct GitHubRelease: Decodable {
    let tagName: String
    let htmlURL: String
    let assets: [GitHubAsset]

    enum CodingKeys: String, CodingKey {
        case assets
        case tagName = "tag_name"
        case htmlURL = "html_url"
    }
}
