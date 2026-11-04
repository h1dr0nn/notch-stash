import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/subnet_sweep.dart';
import '../settings.dart';
import 'client.dart';
import 'discovery.dart';
import 'models.dart';
import 'receive_controller.dart';
import 'send_entries.dart';
import 'server.dart';

/// Progress of sending files to one peer.
sealed class TransferState {
  const TransferState();
}

class TransferWaiting extends TransferState {
  const TransferWaiting();
}

class TransferSending extends TransferState {
  const TransferSending(this.fraction);
  final double fraction;
}

class TransferDone extends TransferState {
  const TransferDone();
}

class TransferDeclined extends TransferState {
  const TransferDeclined();
}

class TransferBusy extends TransferState {
  const TransferBusy();
}

class TransferFailed extends TransferState {
  const TransferFailed(this.message);
  final String message;
}

/// LocalSend v2 on this PC: discovery, receiving into the shelf, and sending to nearby devices.
class LocalSendService extends ChangeNotifier {
  LocalSendService({required this.settings, required this.onFilesReceived}) {
    _receiver = ReceiveController(
      ownInfo: ownInfo,
      receiveEnabled: () => settings.receiveFiles,
      saveFolder: () => settings.saveFolder,
      askUser: _askUser,
      dismissPrompt: (request) => _resolveIncoming(request.id, accept: false),
      onPeer: (info, ip) => _upsert(info, ip),
      onFileReceived: (path) => onFilesReceived([path]),
    );
    _server = LocalSendServer(_receiver);
    _discovery = MulticastDiscovery(onMessage: _multicastMessage);
  }

  final AppSettings settings;

  /// Adds received files to the shelf.
  final void Function(List<String> paths) onFilesReceived;

  late final ReceiveController _receiver;
  late final LocalSendServer _server;
  late final MulticastDiscovery _discovery;
  final LocalSendClient _client = LocalSendClient();

  final Map<String, Peer> _peers = {};
  final Map<String, TransferState> _transfers = {};
  final Map<String, TransferCancellation> _running = {};
  IncomingRequest? _incoming;
  Completer<bool>? _decision;
  bool _isRunning = false;
  bool _starting = false;
  Timer? _rescan;

  bool get isRunning => _isRunning;

  List<Peer> get peers {
    final list = _peers.values.toList()..sort((a, b) => a.alias.toLowerCase().compareTo(b.alias.toLowerCase()));
    return list;
  }

  TransferState? transferFor(Peer peer) => _transfers[peer.id];
  IncomingRequest? get incoming => _incoming;

  /// Follows the Nearby Sharing setting.
  Future<void> applySettings() async {
    if (settings.nearbySharingEnabled) {
      await _start();
    } else {
      await _stop();
    }
  }

  DeviceInfo ownInfo({bool? announce}) => DeviceInfo(
    alias: settings.deviceName,
    version: LocalSendDefaults.protocolVersion,
    deviceModel: 'Windows',
    deviceType: 'desktop',
    fingerprint: settings.fingerprint,
    port: _server.port ?? LocalSendDefaults.port,
    protocol: 'http',
    download: false,
    announce: announce,
  );

  Future<void> _start() async {
    if (_isRunning || _starting) return;
    _starting = true;
    try {
      await _server.start();
      await _discovery.start();
      _isRunning = true;
      notifyListeners();
      _announce();
      _probeSavedDevices();
    } on SocketException {
      await _server.stop();
      _discovery.stop();
    } finally {
      _starting = false;
    }
  }

  Future<void> _stop() async {
    if (!_isRunning) return;
    _rescan?.cancel();
    _discovery.stop();
    await _server.stop();
    _peers.clear();
    _isRunning = false;
    notifyListeners();
  }

  /// Stops networking and releases the HTTP client, before the app quits.
  Future<void> shutdown() async {
    await _stop();
    _client.close();
  }

  // Discovery

  /// Asks every LocalSend device on the network to introduce itself.
  Future<void> scan() async {
    if (!_isRunning) return;
    final staleBefore = DateTime.now().subtract(const Duration(seconds: 30));
    _peers.removeWhere((_, peer) => peer.lastSeen.isBefore(staleBefore));
    notifyListeners();
    await _discovery.refreshInterfaces();
    _announce();
    unawaited(_sweep());
    _probeSavedDevices();
    var round = 0;
    _rescan?.cancel();
    _rescan = Timer.periodic(const Duration(seconds: 2), (timer) {
      round++;
      _announce();
      if (round >= 2) timer.cancel();
    });
  }

  void _announce() => _discovery.send(ownInfo(announce: true).toJson());

  /// Asks one address directly and remembers it when a device answers. Returns the device's name.
  Future<String?> addDevice(String address) async {
    final trimmed = address.trim();
    if (trimmed.isEmpty || !_isRunning) return null;
    final peer = await _probe(trimmed);
    if (peer == null) return null;
    await settings.addSavedDeviceAddress(trimmed);
    return peer.alias;
  }

  /// Re-asks every remembered address; devices on other subnets are only reachable this way.
  void _probeSavedDevices() {
    for (final address in settings.savedDeviceAddresses) {
      unawaited(_probe(address));
    }
  }

  Future<Peer?> _probe(String address) async {
    final info = await _client.probe(address, ownInfo());
    if (info == null || info.fingerprint == settings.fingerprint) return null;
    return _upsert(info, address);
  }

  bool _sweeping = false;

  /// Multicast is often blocked on office and guest networks, so every address near this PC's
  /// IPv4 addresses is also asked directly over HTTP, the way LocalSend's legacy discovery works.
  Future<void> _sweep() async {
    if (_sweeping || !_isRunning) return;
    _sweeping = true;
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      final hosts = <String>{
        for (final interface in interfaces)
          for (final address in interface.addresses)
            if (!address.isLoopback) ...sweepHosts(address.address),
      };
      final info = ownInfo();
      final queue = hosts.iterator;
      Future<void> worker() async {
        while (_isRunning && queue.moveNext()) {
          final ip = queue.current;
          final peer = await _client.probe(ip, info);
          if (peer != null && peer.fingerprint != settings.fingerprint) _upsert(peer, ip);
        }
      }

      await Future.wait([for (var i = 0; i < 96; i++) worker()]);
    } on SocketException {
      // No usable network right now; the next scan tries again.
    } finally {
      _sweeping = false;
    }
  }

  void _multicastMessage(Object? json, String ip) {
    final info = DeviceInfo.fromJson(json);
    if (info == null || info.fingerprint == settings.fingerprint) return;
    final peer = _upsert(info, ip);
    if (info.announce != true) return;
    unawaited(_client.register(peer, ownInfo()));
    _discovery.send(ownInfo(announce: false).toJson());
  }

  Peer _upsert(DeviceInfo info, String ip) {
    final peer = Peer.fromInfo(info, ip, DateTime.now());
    _peers[peer.id] = peer;
    notifyListeners();
    return peer;
  }

  // Receiving

  Future<bool> _askUser(IncomingRequest request) {
    final completer = Completer<bool>();
    _decision = completer;
    _incoming = request;
    notifyListeners();
    return completer.future;
  }

  /// Answers the open incoming prompt.
  void decideIncoming({required bool accept}) {
    final request = _incoming;
    if (request != null) _resolveIncoming(request.id, accept: accept);
  }

  void _resolveIncoming(String id, {required bool accept}) {
    if (_incoming?.id != id) return;
    final decision = _decision;
    _incoming = null;
    _decision = null;
    notifyListeners();
    if (decision != null && !decision.isCompleted) decision.complete(accept);
  }

  // Sending

  /// Forgets finished transfers before the Send dialog opens again; running ones keep going.
  void clearFinishedTransfers() {
    _transfers.removeWhere((id, _) => !_running.containsKey(id));
    notifyListeners();
  }

  void cancelSend(Peer peer) {
    _running.remove(peer.id)?.cancel();
    _transfers.remove(peer.id);
    notifyListeners();
  }

  void send(List<String> paths, Peer peer) {
    _running.remove(peer.id)?.cancel();
    final cancellation = TransferCancellation();
    _running[peer.id] = cancellation;
    _setTransfer(peer, const TransferWaiting());
    unawaited(_performSend(paths, peer, cancellation));
  }

  void _setTransfer(Peer peer, TransferState state) {
    _transfers[peer.id] = state;
    notifyListeners();
  }

  Future<void> _performSend(List<String> paths, Peer peer, TransferCancellation cancellation) async {
    try {
      final entries = await Future(() => expandForSending(paths));
      if (entries.isEmpty) {
        _finish(peer, cancellation, const TransferFailed('Nothing to send'));
        return;
      }
      final files = <String, FileInfo>{};
      final sources = <String, SendEntry>{};
      final random = Random.secure();
      for (final entry in entries) {
        final id = List.generate(16, (_) => random.nextInt(16).toRadixString(16)).join();
        files[id] = FileInfo(id: id, fileName: entry.name, size: entry.size, fileType: entry.mimeType);
        sources[id] = entry;
      }
      final result = await _client.prepareUpload(
        peer,
        PrepareUploadRequest(info: ownInfo(), files: files),
        cancellation: cancellation,
      );
      switch (result) {
        case PrepareAccepted(:final response):
          await _upload(peer, response, sources, cancellation);
        case PrepareNothingToSend():
          _finish(peer, cancellation, const TransferDone());
        case PrepareDeclined():
          _finish(peer, cancellation, const TransferDeclined());
        case PrepareBusy():
          _finish(peer, cancellation, const TransferBusy());
        case PreparePinRequired():
          _finish(
            peer,
            cancellation,
            const TransferFailed('This device asks for a PIN, which Notch Stash does not support yet.'),
          );
        case PrepareFailed(:final message):
          _finish(peer, cancellation, TransferFailed(message));
      }
    } on TransferCancelledException {
      // cancelSend already cleared the state.
    } on FileSystemException catch (error) {
      _finish(peer, cancellation, TransferFailed(error.message));
    }
  }

  Future<void> _upload(
    Peer peer,
    PrepareUploadResponse response,
    Map<String, SendEntry> sources,
    TransferCancellation cancellation,
  ) async {
    final accepted = response.files.keys.where(sources.containsKey).toList();
    final total = max(1, accepted.fold<int>(0, (sum, id) => sum + sources[id]!.size));
    var completed = 0;
    _updateIfCurrent(peer, cancellation, const TransferSending(0));
    try {
      for (final fileId in accepted) {
        final entry = sources[fileId]!;
        final base = completed;
        await _client.upload(
          peer,
          File(entry.path),
          sessionId: response.sessionId,
          fileId: fileId,
          token: response.files[fileId]!,
          cancellation: cancellation,
          onProgress: (sent) => _updateIfCurrent(peer, cancellation, TransferSending((base + sent) / total)),
        );
        completed += entry.size;
      }
      _finish(peer, cancellation, const TransferDone());
    } on TransferCancelledException {
      unawaited(_client.cancel(peer, response.sessionId));
    } on Object catch (error) {
      unawaited(_client.cancel(peer, response.sessionId));
      _finish(peer, cancellation, TransferFailed(error is HttpException ? error.message : 'Upload failed'));
    }
  }

  void _updateIfCurrent(Peer peer, TransferCancellation cancellation, TransferState state) {
    if (!identical(_running[peer.id], cancellation)) return;
    final current = _transfers[peer.id];
    if (state is TransferSending && current is TransferSending && state.fraction - current.fraction < 0.005) {
      return;
    }
    _setTransfer(peer, state);
  }

  void _finish(Peer peer, TransferCancellation cancellation, TransferState state) {
    if (!identical(_running[peer.id], cancellation)) return;
    _running.remove(peer.id);
    _setTransfer(peer, state);
  }
}
