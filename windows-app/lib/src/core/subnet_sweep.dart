/// Addresses to probe over HTTP when multicast discovery is blocked (LocalSend's legacy discovery).
///
/// Dart does not expose the netmask, so the block of `2^(32 - prefix)` addresses around [address] is used;
/// /22 covers a normal /24 home network and the wider subnets common on office networks.
List<String> sweepHosts(String address, {int prefix = 22}) {
  final ip = _parse(address);
  if (ip == null || !_shouldSweep(ip) || prefix < 16 || prefix > 30) return const [];
  final mask = (0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF;
  final network = ip & mask;
  final broadcast = network | (~mask & 0xFFFFFFFF);
  return [
    for (var host = network + 1; host < broadcast; host++)
      if (host != ip) _format(host),
  ];
}

/// Loopback, link-local and carrier-grade NAT (Tailscale and similar VPNs) are not swept.
bool _shouldSweep(int ip) {
  final first = ip >> 24;
  final second = (ip >> 16) & 0xFF;
  if (first == 127 || first == 0) return false;
  if (first == 169 && second == 254) return false;
  if (first == 100 && second >= 64 && second <= 127) return false;
  return true;
}

int? _parse(String text) {
  final parts = text.split('.');
  if (parts.length != 4) return null;
  var value = 0;
  for (final part in parts) {
    final byte = int.tryParse(part);
    if (byte == null || byte < 0 || byte > 255) return null;
    value = (value << 8) | byte;
  }
  return value;
}

String _format(int value) => '${value >> 24}.${(value >> 16) & 0xFF}.${(value >> 8) & 0xFF}.${value & 0xFF}';
