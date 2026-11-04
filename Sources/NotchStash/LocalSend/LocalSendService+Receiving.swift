import Foundation
import NotchStashCore

extension LocalSendService {
    /// Shows progress for an accepted transfer and ends it if the sender goes quiet for two minutes.
    func startReceiving(from sender: LocalSendDeviceInfo, files: [LocalSendFileInfo]) {
        receiving = LocalSendReceiveProgress(sender: sender, files: files)
        lastReceiveActivity = Date()
        receiveWatchdog?.invalidate()
        receiveWatchdog = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
            MainActor.assumeIsolated { [weak self] in
                guard let self, Date().timeIntervalSince(self.lastReceiveActivity) > 120 else { return }
                self.endReceiveSession()
                self.finishReceiving(.failed("The transfer stopped."))
            }
        }
    }

    func received(bytes: Int) {
        guard receiving?.phase == .receiving else { return }
        receiving?.receivedBytes += Int64(bytes)
        lastReceiveActivity = Date()
    }

    /// Shows the final state for a moment, then hides the progress.
    func finishReceiving(_ phase: LocalSendReceiveProgress.Phase) {
        receiveWatchdog?.invalidate()
        receiveWatchdog = nil
        guard var progress = receiving else { return }
        progress.phase = phase
        receiving = progress
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            if self?.receiving == progress { self?.receiving = nil }
        }
    }
}
