import AppKit
import NotchStashCore
import SwiftUI
import UniformTypeIdentifiers

/// Incoming files in the notch shelf: the accept prompt, then the progress of the transfer.
struct IncomingCard: View {
    let display: LocalSendIncomingDisplay
    let notchSize: CGSize
    let decide: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("From \(sender.alias)")
                    .font(.headline)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Color.clear.frame(width: notchSize.width + 16)
                Spacer(minLength: 0)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(height: notchSize.height)
            .padding(.top, 6)
            HStack(spacing: 14) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(files, id: \.id) { IncomingTile(file: $0, isFinished: finishedIds.contains($0.id)) }
                    }
                }
                trailing.frame(width: 104)
            }
            .frame(maxHeight: .infinity)
        }
    }

    private var sender: LocalSendDeviceInfo {
        switch display {
        case let .prompt(request): request.sender
        case let .progress(progress): progress.sender
        }
    }

    private var files: [LocalSendFileInfo] {
        switch display {
        case let .prompt(request): request.files
        case let .progress(progress): progress.files
        }
    }

    private var finishedIds: Set<String> {
        if case let .progress(progress) = display { return progress.finishedIds }
        return []
    }

    private var detail: String {
        switch display {
        case let .prompt(request):
            return request.detail
        case let .progress(progress):
            let received = ByteCountFormatter.string(fromByteCount: progress.receivedBytes, countStyle: .file)
            let total = ByteCountFormatter.string(fromByteCount: progress.totalBytes, countStyle: .file)
            return "\(received) of \(total)"
        }
    }

    @ViewBuilder
    private var trailing: some View {
        switch display {
        case .prompt:
            VStack(spacing: 8) {
                pill("Accept", fill: Color.accentColor, text: .white) { decide(true) }
                    .keyboardShortcut(.defaultAction)
                pill("Decline", fill: Color.white.opacity(0.14), text: .primary) { decide(false) }
                    .keyboardShortcut(.cancelAction)
            }
        case let .progress(progress):
            ReceiveProgressColumn(progress: progress)
        }
    }

    private func pill(_ title: String, fill: Color, text: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.callout.weight(.semibold))
                .foregroundStyle(text)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(Capsule().fill(fill))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Percentage, bar and status of a running transfer; a mark when it ends.
struct ReceiveProgressColumn: View {
    let progress: LocalSendReceiveProgress

    var body: some View {
        VStack(spacing: 6) {
            switch progress.phase {
            case .receiving:
                Text("\(Int(progress.fraction * 100))%")
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
            case .done:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.green)
            case .failed:
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.orange)
            }
            ProgressView(value: progress.fraction)
                .tint(progress.phase == .receiving ? Color.accentColor : progress.phase == .done ? .green : .orange)
            Text(progress.status)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
    }
}

/// One offered file: its type icon and name, styled like a shelf tile; ticked once received.
struct IncomingTile: View {
    let file: LocalSendFileInfo
    var isFinished = false

    var body: some View {
        VStack(spacing: 4) {
            Image(nsImage: NSWorkspace.shared.icon(for: Self.type(of: file.fileName)))
                .resizable()
                .frame(width: 44, height: 44)
            Text((file.fileName as NSString).lastPathComponent)
                .font(.caption2)
                .lineLimit(2)
                .truncationMode(.middle)
                .multilineTextAlignment(.center)
                .frame(width: 72)
        }
        .frame(width: 78, height: 86)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.06)))
        .overlay(alignment: .topTrailing) {
            if isFinished {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.white, .green)
                    .padding(4)
            }
        }
        .help(file.fileName)
    }

    private static func type(of fileName: String) -> UTType {
        UTType(filenameExtension: (fileName as NSString).pathExtension) ?? .data
    }
}
