import Foundation
import NotchStashCore

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

extension LocalSendIncomingRequest: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
}

/// Progress of an accepted incoming transfer, shown to the receiver.
struct LocalSendReceiveProgress: Equatable {
    enum Phase: Equatable {
        case receiving
        case done
        case failed(String)
    }

    let sender: LocalSendDeviceInfo
    let files: [LocalSendFileInfo]
    var receivedBytes: Int64 = 0
    var finishedIds: Set<String> = []
    var phase: Phase = .receiving

    var totalBytes: Int64 { files.reduce(0) { $0 + $1.size } }

    var fraction: Double {
        if phase == .done { return 1 }
        guard totalBytes > 0 else { return 0 }
        return min(Double(receivedBytes) / Double(totalBytes), 1)
    }

    var status: String {
        switch phase {
        case .receiving: "\(finishedIds.count) of \(files.count) \(files.count == 1 ? "file" : "files")"
        case .done: files.count == 1 ? "Received" : "Received \(files.count) files"
        case let .failed(message): message
        }
    }
}

/// What the receiver sees: the accept prompt, then the progress of the accepted transfer.
enum LocalSendIncomingDisplay: Equatable {
    case prompt(LocalSendIncomingRequest)
    case progress(LocalSendReceiveProgress)
}
