import Darwin
import Foundation
import OSLog

/// UDP socket joined to the LocalSend multicast group; delivers datagrams with the sender's IPv4 address.
final class MulticastSocket: @unchecked Sendable {
    static let group = "224.0.0.167"
    static let port: UInt16 = 53317

    private let queue = DispatchQueue(label: "local.notch-stash.multicast")
    private var descriptor: Int32 = -1
    private var source: DispatchSourceRead?
    private let onMessage: @Sendable (Data, String) -> Void
    private let log = Logger(subsystem: "local.notch-stash", category: "localsend")

    init(onMessage: @escaping @Sendable (Data, String) -> Void) {
        self.onMessage = onMessage
    }

    deinit {
        stop()
    }

    func start() -> Bool {
        let socketDescriptor = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard socketDescriptor >= 0 else { return false }
        var yes: Int32 = 1
        setsockopt(socketDescriptor, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))
        setsockopt(socketDescriptor, SOL_SOCKET, SO_REUSEPORT, &yes, socklen_t(MemoryLayout<Int32>.size))

        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = Self.port.bigEndian
        address.sin_addr.s_addr = INADDR_ANY
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(socketDescriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bound == 0 else {
            log.error("Multicast bind failed: \(errno)")
            close(socketDescriptor)
            return false
        }

        var membership = ip_mreq()
        membership.imr_multiaddr.s_addr = inet_addr(Self.group)
        membership.imr_interface.s_addr = INADDR_ANY
        guard setsockopt(socketDescriptor, IPPROTO_IP, IP_ADD_MEMBERSHIP, &membership, socklen_t(MemoryLayout<ip_mreq>.size)) == 0 else {
            log.error("Joining multicast group failed: \(errno)")
            close(socketDescriptor)
            return false
        }

        descriptor = socketDescriptor
        let readSource = DispatchSource.makeReadSource(fileDescriptor: socketDescriptor, queue: queue)
        readSource.setEventHandler { [weak self] in self?.readDatagram() }
        readSource.resume()
        source = readSource
        return true
    }

    func stop() {
        source?.cancel()
        source = nil
        if descriptor >= 0 { close(descriptor) }
        descriptor = -1
    }

    func send(_ data: Data) {
        queue.async { [weak self] in
            guard let self, self.descriptor >= 0 else { return }
            var destination = sockaddr_in()
            destination.sin_family = sa_family_t(AF_INET)
            destination.sin_port = Self.port.bigEndian
            destination.sin_addr.s_addr = inet_addr(Self.group)
            _ = data.withUnsafeBytes { bytes in
                withUnsafePointer(to: &destination) {
                    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                        sendto(self.descriptor, bytes.baseAddress, data.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                    }
                }
            }
        }
    }

    private func readDatagram() {
        var buffer = [UInt8](repeating: 0, count: 65_535)
        var sender = sockaddr_in()
        var senderLength = socklen_t(MemoryLayout<sockaddr_in>.size)
        let count = withUnsafeMutablePointer(to: &sender) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                recvfrom(descriptor, &buffer, buffer.count, 0, $0, &senderLength)
            }
        }
        guard count > 0 else { return }
        let address = String(cString: inet_ntoa(sender.sin_addr))
        onMessage(Data(buffer.prefix(count)), address)
    }
}
