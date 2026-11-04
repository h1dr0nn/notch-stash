/// Addresses to probe over HTTP when multicast discovery is blocked (LocalSend's legacy discovery).
public enum SubnetSweep {
    /// Hosts in the subnet of `address`, without the network, broadcast and own address.
    /// Subnets wider than `widestPrefix` are narrowed to the block around `address` to keep the sweep short.
    public static func hosts(address: String, netmask: String, widestPrefix: Int = 22) -> [String] {
        guard let ip = parse(address), let mask = parse(netmask), shouldSweep(ip) else { return [] }
        let maskPrefix = mask.nonzeroBitCount
        let prefix = max(maskPrefix, widestPrefix)
        guard prefix < 31 else { return [] }
        let blockMask: UInt32 = prefix == 0 ? 0 : ~UInt32(0) << UInt32(32 - prefix)
        let network = ip & blockMask
        let broadcast = network | ~blockMask
        return (network + 1..<broadcast).compactMap { $0 == ip ? nil : format($0) }
    }

    /// Loopback, link-local and carrier-grade NAT (Tailscale and similar VPNs) are not swept.
    static func shouldSweep(_ ip: UInt32) -> Bool {
        let first = ip >> 24
        let second = (ip >> 16) & 0xFF
        if first == 127 || first == 0 { return false }
        if first == 169 && second == 254 { return false }
        if first == 100 && (64...127).contains(second) { return false }
        return true
    }

    static func parse(_ text: String) -> UInt32? {
        let parts = text.split(separator: ".")
        guard parts.count == 4 else { return nil }
        var value: UInt32 = 0
        for part in parts {
            guard let byte = UInt8(part) else { return nil }
            value = value << 8 | UInt32(byte)
        }
        return value
    }

    static func format(_ value: UInt32) -> String {
        "\(value >> 24).\((value >> 16) & 0xFF).\((value >> 8) & 0xFF).\(value & 0xFF)"
    }
}
