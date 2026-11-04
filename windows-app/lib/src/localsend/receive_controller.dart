import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

import '../core/file_naming.dart';
import 'models.dart';

/// Status and JSON body the HTTP server writes back.
class HttpReply {
  const HttpReply(this.status, [this.body = const []]);

  HttpReply.json(Object? value, {this.status = 200}) : body = utf8.encode(jsonEncode(value));

  final int status;
  final List<int> body;
}

/// Where an upload body goes, decided before the body is read.
sealed class UploadTarget {
  const UploadTarget();
}

class UploadWrite extends UploadTarget {
  const UploadWrite(this.path);
  final String path;
}

class UploadReject extends UploadTarget {
  const UploadReject(this.status);
  final int status;
}

/// Files another device offers; the user accepts or declines.
class IncomingRequest {
  IncomingRequest({required this.id, required this.sender, required this.files});

  final String id;
  final DeviceInfo sender;
  final List<FileInfo> files;

  int get totalSize => files.fold(0, (sum, file) => sum + file.size);
}

class _Session {
  _Session({required this.id, required this.senderIp, required this.files, required this.tokens});

  final String id;
  final String senderIp;
  final Map<String, FileInfo> files;
  final Map<String, String> tokens;
  final Map<String, String> active = {};
  final Set<String> reserved = {};
  final Set<String> finished = {};
  DateTime lastActivity = DateTime.now();
}

/// Receiving side of LocalSend v2: routes requests, owns the single incoming session
/// and decides where uploads are written. Free of sockets so it can be unit tested.
class ReceiveController {
  ReceiveController({
    required this.ownInfo,
    required this.receiveEnabled,
    required this.saveFolder,
    required this.askUser,
    required this.dismissPrompt,
    required this.onPeer,
    required this.onFileReceived,
    this.decisionTimeout = const Duration(seconds: 60),
    this.sessionIdleTimeout = const Duration(minutes: 2),
    bool Function(String path)? exists,
    DateTime Function()? now,
    Random? random,
  })  : _exists = exists ?? _entityExists,
        _now = now ?? DateTime.now,
        _random = random ?? Random.secure();

  final DeviceInfo Function() ownInfo;
  final bool Function() receiveEnabled;
  final String Function() saveFolder;

  /// Shows the accept prompt; completes with the user's answer.
  final Future<bool> Function(IncomingRequest request) askUser;

  /// Called when an unanswered prompt times out.
  final void Function(IncomingRequest request) dismissPrompt;
  final void Function(DeviceInfo info, String ip) onPeer;
  final void Function(String path) onFileReceived;
  final Duration decisionTimeout;
  final Duration sessionIdleTimeout;

  final bool Function(String path) _exists;
  final DateTime Function() _now;
  final Random _random;

  _Session? _session;
  bool _prompting = false;

  static bool _entityExists(String path) =>
      FileSystemEntity.typeSync(path, followLinks: false) != FileSystemEntityType.notFound;

  /// Whether a prompt is open or a transfer is in progress.
  bool get isBusy {
    _expireIdleSession();
    return _prompting || _session != null;
  }

  String? get activeSessionId => _session?.id;

  /// Handles every route except the body of an upload.
  Future<HttpReply> handle(
    String method,
    String path,
    Map<String, String> query,
    List<int> body,
    String remoteIp,
  ) async {
    const base = LocalSendDefaults.apiBase;
    switch ((method, path)) {
      case ('POST', '$base/register'):
        final info = DeviceInfo.fromJson(_decode(body));
        if (info != null && info.fingerprint != ownInfo().fingerprint) onPeer(info, remoteIp);
        return HttpReply.json(ownInfo().toJson());
      case ('GET', '$base/info'):
        return HttpReply.json(ownInfo().toJson());
      case ('POST', '$base/prepare-upload'):
        return _prepareUpload(body, remoteIp);
      case ('POST', '$base/cancel'):
        final session = _session;
        if (session != null && session.id == query['sessionId'] && session.senderIp == remoteIp) {
          _session = null;
        }
        return const HttpReply(200);
      default:
        return const HttpReply(404);
    }
  }

  Future<HttpReply> _prepareUpload(List<int> body, String remoteIp) async {
    if (!receiveEnabled()) return const HttpReply(403);
    if (isBusy) return const HttpReply(409);
    final request = PrepareUploadRequest.fromJson(_decode(body));
    if (request == null) return const HttpReply(400);
    if (request.files.isEmpty) return const HttpReply(204);
    if (request.info.fingerprint != ownInfo().fingerprint) onPeer(request.info, remoteIp);

    final files = request.files.values.toList()..sort((a, b) => a.fileName.compareTo(b.fileName));
    final incoming = IncomingRequest(id: _token(), sender: request.info, files: files);
    _prompting = true;
    bool accepted;
    try {
      accepted = await askUser(incoming).timeout(decisionTimeout, onTimeout: () {
        dismissPrompt(incoming);
        return false;
      });
    } finally {
      _prompting = false;
    }
    if (!accepted) return const HttpReply(403);

    final tokens = {for (final id in request.files.keys) id: _token()};
    final session = _Session(id: _token(), senderIp: remoteIp, files: request.files, tokens: tokens)
      ..lastActivity = _now();
    _session = session;
    return HttpReply.json(PrepareUploadResponse(sessionId: session.id, files: tokens).toJson());
  }

  /// Validates an upload request and reserves a unique path for it.
  UploadTarget uploadTarget(Map<String, String> query, String remoteIp) {
    _expireIdleSession();
    final session = _session;
    final sessionId = query['sessionId'];
    final fileId = query['fileId'];
    final token = query['token'];
    if (sessionId == null || fileId == null || token == null) return const UploadReject(400);
    if (session == null) return const UploadReject(409);
    final file = session.files[fileId];
    if (session.id != sessionId ||
        file == null ||
        session.tokens[fileId] != token ||
        session.senderIp != remoteIp) {
      return const UploadReject(403);
    }
    if (session.active.containsKey(fileId) || session.finished.contains(fileId)) {
      return const UploadReject(409);
    }
    final folder = saveFolder();
    final relative = FileNaming.uniqueName(file.fileName, (candidate) {
      return session.reserved.contains(candidate.toLowerCase()) ||
          _exists(p.joinAll([folder, ...candidate.split('/')]));
    });
    session.reserved.add(relative.toLowerCase());
    session.active[fileId] = relative;
    session.lastActivity = _now();
    return UploadWrite(p.joinAll([folder, ...relative.split('/')]));
  }

  /// Records the end of an upload. On failure the caller deletes the partial file.
  HttpReply uploadFinished(Map<String, String> query, String path, {required bool success}) {
    final session = _session;
    final fileId = query['fileId'];
    if (session == null || fileId == null || session.id != query['sessionId']) {
      return HttpReply(success ? 200 : 500);
    }
    final relative = session.active.remove(fileId);
    session.lastActivity = _now();
    if (!success) {
      if (relative != null) session.reserved.remove(relative.toLowerCase());
      return const HttpReply(500);
    }
    session.finished.add(fileId);
    onFileReceived(path);
    if (session.finished.length >= session.files.length) _session = null;
    return const HttpReply(200);
  }

  /// Forgets a session whose sender went silent, so new transfers are not blocked forever.
  void _expireIdleSession() {
    final session = _session;
    if (session == null || session.active.isNotEmpty) return;
    if (_now().difference(session.lastActivity) > sessionIdleTimeout) _session = null;
  }

  Object? _decode(List<int> body) {
    try {
      return jsonDecode(utf8.decode(body));
    } on FormatException {
      return null;
    }
  }

  String _token() {
    const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(24, (_) => alphabet[_random.nextInt(alphabet.length)]).join();
  }
}
