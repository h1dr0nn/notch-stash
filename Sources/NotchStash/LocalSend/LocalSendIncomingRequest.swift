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
