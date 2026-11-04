import Darwin
import Foundation
import NotchStashCore

extension LocalSendService {
    /// Multicast is often blocked on office and guest networks, so every address of the local
    /// subnets is also asked directly over HTTP, the way LocalSend's legacy discovery works.
    func sweep() {
        guard isRunning, !isSweeping else { return }
        let addresses = Self.localSubnets().flatMap { SubnetSweep.hosts(address: $0.address, netmask: $0.netmask) }
        guard !addresses.isEmpty else { return }
        isSweeping = true
        let started = Date()
        let info = ownInfo()
        let client = client
        Task {
            await withTaskGroup(of: (LocalSendDeviceInfo, String, String)?.self) { group in
                var pending = addresses[...]
                func addNext() {
                    guard let ip = pending.popFirst() else { return }
                    group.addTask {
                        guard let (peer, scheme) = await client.probe(ip, info: info) else { return nil }
                        return (peer, ip, scheme)
                    }
                }
                for _ in 0..<96 { addNext() }
                for await found in group {
                    addNext()
                    guard let (peer, ip, scheme) = found, peer.fingerprint != info.fingerprint else { continue }
                    var resolved = peer
                    resolved.port = resolved.port ?? 53317
                    resolved.protocol = scheme
                    upsert(resolved, ip: ip)
                }
            }
            isSweeping = false
            let seconds = Date().timeIntervalSince(started)
            let found = peers.count
            log.notice("Swept \(addresses.count) addresses in \(seconds, format: .fixed(precision: 1)) s, \(found) device(s) known")
        }
    }

    /// IPv4 address and netmask of each active, non-virtual interface.
    private static func localSubnets() -> [(address: String, netmask: String)] {
        var result: [(String, String)] = []
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0, let first = list else { return [] }
        defer { freeifaddrs(list) }
        for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let entry = pointer.pointee
            let name = String(cString: entry.ifa_name)
            let flags = Int32(entry.ifa_flags)
            guard flags & IFF_UP != 0, flags & IFF_LOOPBACK == 0,
                  !["utun", "awdl", "llw", "lo", "gif", "stf", "anpi", "ap"].contains(where: name.hasPrefix),
                  let address = entry.ifa_addr, address.pointee.sa_family == UInt8(AF_INET),
                  let mask = entry.ifa_netmask else { continue }
            result.append((Self.ipv4String(address), Self.ipv4String(mask)))
        }
        return result
    }

    private static func ipv4String(_ address: UnsafeMutablePointer<sockaddr>) -> String {
        address.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { String(cString: inet_ntoa($0.pointee.sin_addr)) }
    }
}
