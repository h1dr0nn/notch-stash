import AppKit
import Combine
import NotchStashCore
import SwiftUI

/// Lists nearby Notch Stash and LocalSend devices and sends the chosen files to one of them.
private struct SendView: View {
    @ObservedObject var service: LocalSendService
    @ObservedObject var localNetwork: LocalNetworkPermission
    let urls: [URL]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(summary)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.middle)
            HStack {
                Text("Nearby Devices")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Refresh") { service.scan() }
                    .controlSize(.small)
            }
            content
            AddByAddress(service: service)
        }
        .padding(16)
        .frame(width: 400, height: 400, alignment: .top)
        .onAppear { service.scan() }
    }

    private var summary: String {
        urls.count == 1 ? "Send \(urls[0].lastPathComponent)" : "Send \(urls.count) files"
    }

    @ViewBuilder
    private var content: some View {
        if !service.isRunning {
            hint("Nearby sharing is off", "Turn on Nearby Sharing in Settings to find devices.")
        } else if localNetwork.state == .denied {
            VStack(spacing: 10) {
                hint(
                    "Local Network access is off",
                    "Notch Stash needs Local Network access to find devices. Switch it on in System Settings."
                )
                Button("Open Privacy Settings") { LocalNetworkPermission.openPrivacySettings() }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if service.peers.isEmpty {
            VStack(spacing: 10) {
                ProgressView().controlSize(.small)
                hint(
                    "Looking for devices…",
                    "Open Notch Stash on the other computer, or LocalSend on a phone, and keep both on the same network."
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(service.peers) { peer in
                        PeerRow(peer: peer, state: service.transfers[peer.id]) {
                            service.send(urls, to: peer)
                        } onCancel: {
                            service.cancelSend(to: peer)
                        }
                    }
                }
            }
        }
    }

    private func hint(_ title: String, _ detail: String) -> some View {
        VStack(spacing: 4) {
            Text(title).font(.callout.weight(.medium))
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Adds a device on another subnet, which discovery cannot reach, by its IP address.
private struct AddByAddress: View {
    @ObservedObject var service: LocalSendService
    @State private var address = ""
    @State private var status: String?
    @State private var isAdding = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                TextField("IP Address", text: $address)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(add)
                Button("Add", action: add)
                    .disabled(address.trimmingCharacters(in: .whitespaces).isEmpty || isAdding)
            }
            Text(status ?? "Not listed? Enter the other device's IP address. It is remembered for next time.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func add() {
        let target = address.trimmingCharacters(in: .whitespaces)
        guard !target.isEmpty, !isAdding else { return }
        isAdding = true
        status = "Looking for a device at \(target)…"
        Task {
            if let name = await service.addDevice(address: target) {
                status = "Added \(name)."
                address = ""
            } else {
                status = "No Notch Stash or LocalSend answered at \(target)."
            }
            isAdding = false
        }
    }
}

/// One device with its send button or transfer status.
private struct PeerRow: View {
    let peer: LocalSendPeer
    let state: LocalSendTransferState?
    let onSend: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .frame(width: 28)
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(peer.alias).font(.body.weight(.medium))
                Text([peer.deviceModel, peer.ip].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            status
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.05)))
    }

    private var icon: String {
        switch peer.deviceType {
        case "mobile": "iphone"
        case "desktop": "laptopcomputer"
        case "web": "globe"
        case "server", "headless": "server.rack"
        default: "display"
        }
    }

    @ViewBuilder
    private var status: some View {
        switch state {
        case .waiting:
            HStack(spacing: 6) {
                Text("Waiting for approval…").font(.caption).foregroundStyle(.secondary)
                cancelButton
            }
        case let .sending(fraction):
            HStack(spacing: 6) {
                ProgressView(value: fraction).frame(width: 90)
                cancelButton
            }
        case .done:
            Label("Sent", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        case .declined:
            retry("Declined")
        case .busy:
            retry("Busy")
        case let .failed(message):
            retry("Failed").help(message)
        case nil:
            Button("Send", action: onSend)
        }
    }

    private var cancelButton: some View {
        Button(action: onCancel) {
            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help("Cancel")
    }

    private func retry(_ label: String) -> some View {
        HStack(spacing: 6) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Button("Retry", action: onSend).controlSize(.small)
        }
    }
}

/// The window version of the incoming prompt and progress, for screens without a notch shelf.
private struct IncomingWindowView: View {
    let display: LocalSendIncomingDisplay
    let decide: (Bool) -> Void

    var body: some View {
        switch display {
        case let .prompt(request):
            IncomingView(request: request, decide: decide)
        case let .progress(progress):
            VStack(alignment: .leading, spacing: 12) {
                Text("Receiving from \(progress.sender.alias)")
                    .font(.headline)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(progress.files, id: \.id) {
                            IncomingTile(file: $0, isFinished: progress.finishedIds.contains($0.id))
                        }
                    }
                }
                ReceiveProgressColumn(progress: progress)
            }
            .padding(20)
            .frame(width: 340)
        }
    }
}

/// Asks whether to accept files offered by another device.
private struct IncomingView: View {
    let request: LocalSendIncomingRequest
    let decide: (Bool) -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 38))
                .foregroundStyle(Color.accentColor)
            Text(request.headline)
                .font(.headline)
                .multilineTextAlignment(.center)
            Text(request.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 3) {
                ForEach(request.files.prefix(5), id: \.id) { file in
                    Text(file.fileName).font(.callout).lineLimit(1).truncationMode(.middle)
                }
                if request.files.count > 5 {
                    Text("and \(request.files.count - 5) more").font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack {
                Button("Decline") { decide(false) }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Accept") { decide(true) }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 340)
    }
}

/// Owns the Send to Device window.
@MainActor
final class SendWindowController {
    private let service: LocalSendService
    private var window: NSWindow?

    init(service: LocalSendService) {
        self.service = service
    }

    func show(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        service.clearTransfers()
        service.localNetwork.check()
        let hosting = NSHostingController(rootView: SendView(service: service, localNetwork: service.localNetwork, urls: urls))
        if let window {
            window.contentViewController = hosting
        } else {
            let window = NSWindow(contentViewController: hosting)
            window.title = "Send to Device"
            window.styleMask = [.titled, .closable]
            window.level = .floating
            window.isReleasedWhenClosed = false
            self.window = window
        }
        window?.center()
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}

/// Shows the accept prompt whenever another device offers files.
@MainActor
final class IncomingWindowController: NSObject, NSWindowDelegate {
    private let service: LocalSendService
    private var window: NSWindow?
    private var cancellable: AnyCancellable?
    private let presentInNotch: (LocalSendIncomingDisplay) -> Bool
    private let dismissInNotch: () -> Void

    /// `presentInNotch` returns false when no notch shelf can show the prompt; the window is used then.
    init(
        service: LocalSendService,
        presentInNotch: @escaping (LocalSendIncomingDisplay) -> Bool,
        dismissInNotch: @escaping () -> Void
    ) {
        self.service = service
        self.presentInNotch = presentInNotch
        self.dismissInNotch = dismissInNotch
        super.init()
        // A short debounce bridges the gap between answering the prompt and the transfer starting.
        cancellable = service.$incoming.combineLatest(service.$receiving)
            .map { incoming, receiving in
                incoming.map(LocalSendIncomingDisplay.prompt) ?? receiving.map(LocalSendIncomingDisplay.progress)
            }
            .removeDuplicates()
            .debounce(for: .milliseconds(150), scheduler: DispatchQueue.main)
            .sink { [weak self] display in
                if let display { self?.show(display) } else { self?.dismiss() }
            }
    }

    private func show(_ display: LocalSendIncomingDisplay) {
        if presentInNotch(display) {
            closeWindow()
            return
        }
        let view = IncomingWindowView(display: display) { [weak self] accept in
            self?.service.decideIncoming(accept)
        }
        let window = window ?? NSWindow(contentViewController: NSHostingController(rootView: view))
        window.contentViewController = NSHostingController(rootView: view)
        window.title = "Incoming Files"
        window.styleMask = [.titled, .closable]
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.delegate = self
        self.window = window
        if !window.isVisible {
            window.center()
            NSApp.activate()
        }
        window.makeKeyAndOrderFront(nil)
    }

    private func dismiss() {
        dismissInNotch()
        closeWindow()
    }

    private func closeWindow() {
        window?.delegate = nil
        window?.close()
        window?.delegate = self
    }

    func windowWillClose(_ notification: Notification) {
        if service.incoming != nil { service.decideIncoming(false) }
    }
}
