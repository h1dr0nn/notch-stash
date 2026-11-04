import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'models.dart';

/// UDP multicast socket for LocalSend announcements on 224.0.0.167:53317.
class MulticastDiscovery {
  MulticastDiscovery({required this.onMessage});

  /// Called with each decoded JSON object and the sender's IPv4 address.
  final void Function(Object? json, String ip) onMessage;

  final InternetAddress _group = InternetAddress(LocalSendDefaults.multicastGroup);
  RawDatagramSocket? _socket;
  List<NetworkInterface> _interfaces = const [];

  bool get isRunning => _socket != null;

  Future<bool> start() async {
    if (_socket != null) return true;
    try {
      final socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        LocalSendDefaults.port,
        reuseAddress: true,
      );
      socket
        ..broadcastEnabled = true
        ..multicastLoopback = true
        ..multicastHops = 1;
      _interfaces = await _ipv4Interfaces();
      var joined = false;
      for (final interface in _interfaces) {
        try {
          socket.joinMulticast(_group, interface);
          joined = true;
        } on SocketException {
          // Interfaces without multicast support (some VPN adapters) are skipped.
        }
      }
      if (!joined) socket.joinMulticast(_group);
      socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final datagram = socket.receive();
        if (datagram == null) return;
        Object? json;
        try {
          json = jsonDecode(utf8.decode(datagram.data));
        } on FormatException {
          return;
        }
        onMessage(json, datagram.address.address);
      });
      _socket = socket;
      return true;
    } on SocketException {
      return false;
    }
  }

  /// Sends [json] to the multicast group out of every IPv4 interface, so machines
  /// with several adapters (Wi-Fi, Ethernet, virtual switches) reach all networks.
  void send(Map<String, Object?> json) {
    final socket = _socket;
    if (socket == null) return;
    final data = utf8.encode(jsonEncode(json));
    var sent = false;
    for (final interface in _interfaces) {
      for (final address in interface.addresses) {
        try {
          socket.setRawOption(RawSocketOption(
            RawSocketOption.levelIPv4,
            RawSocketOption.IPv4MulticastInterface,
            Uint8List.fromList(address.rawAddress),
          ));
          socket.send(data, _group, LocalSendDefaults.port);
          sent = true;
        } on SocketException {
          // Try the next interface.
        }
      }
    }
    if (!sent) {
      try {
        socket.send(data, _group, LocalSendDefaults.port);
      } on SocketException {
        // Nothing to send on; discovery resumes when the network comes back.
      }
    }
  }

  /// Picks up adapters that appeared since start (for example after joining Wi-Fi).
  Future<void> refreshInterfaces() async {
    final socket = _socket;
    if (socket == null) return;
    final current = await _ipv4Interfaces();
    final known = _interfaces.map((i) => i.name).toSet();
    for (final interface in current.where((i) => !known.contains(i.name))) {
      try {
        socket.joinMulticast(_group, interface);
      } on SocketException {
        // Skipped, as in start().
      }
    }
    _interfaces = current;
  }

  void stop() {
    _socket?.close();
    _socket = null;
    _interfaces = const [];
  }

  static Future<List<NetworkInterface>> _ipv4Interfaces() async {
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      return interfaces.where((i) => i.addresses.any((a) => !a.isLoopback)).toList();
    } on SocketException {
      return const [];
    }
  }
}
