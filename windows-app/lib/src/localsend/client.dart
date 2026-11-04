import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'models.dart';

/// Outcome of asking a peer to accept files.
sealed class PrepareResult {
  const PrepareResult();
}

class PrepareAccepted extends PrepareResult {
  const PrepareAccepted(this.response);
  final PrepareUploadResponse response;
}

class PrepareNothingToSend extends PrepareResult {
  const PrepareNothingToSend();
}

class PrepareDeclined extends PrepareResult {
  const PrepareDeclined();
}

class PrepareBusy extends PrepareResult {
  const PrepareBusy();
}

class PreparePinRequired extends PrepareResult {
  const PreparePinRequired();
}

class PrepareFailed extends PrepareResult {
  const PrepareFailed(this.message);
  final String message;
}

/// Maps a prepare-upload HTTP status to its outcome.
PrepareResult prepareResultFor(int status, String body) {
  switch (status) {
    case 200:
      Object? json;
      try {
        json = jsonDecode(body);
      } on FormatException {
        json = null;
      }
      final response = PrepareUploadResponse.fromJson(json);
      return response == null ? const PrepareFailed('Unexpected reply') : PrepareAccepted(response);
    case 204:
      return const PrepareNothingToSend();
    case 401:
      return const PreparePinRequired();
    case 403:
      return const PrepareDeclined();
    case 409:
    case 429:
      return const PrepareBusy();
    default:
      return PrepareFailed('Error $status');
  }
}

/// Lets a running transfer be stopped from the UI.
class TransferCancellation {
  bool _cancelled = false;
  final List<void Function()> _handlers = [];

  bool get isCancelled => _cancelled;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final handler in List.of(_handlers)) {
      handler();
    }
    _handlers.clear();
  }

  void _onCancel(void Function() handler) => _handlers.add(handler);
  void _remove(void Function() handler) => _handlers.remove(handler);
}

/// Thrown when a transfer was cancelled.
class TransferCancelledException implements Exception {
  const TransferCancelledException();
}

/// HTTP client side of LocalSend v2. Peers use self-signed certificates, so any
/// certificate is accepted.
class LocalSendClient {
  LocalSendClient() {
    _http
      ..badCertificateCallback = ((cert, host, port) => true)
      ..connectionTimeout = const Duration(seconds: 5)
      ..idleTimeout = const Duration(seconds: 15);
  }

  final HttpClient _http = HttpClient();

  Future<void> register(Peer peer, DeviceInfo info) async {
    try {
      final request = await _http.postUrl(peer.endpoint('register'));
      _writeJson(request, info.toJson());
      final response = await request.close().timeout(const Duration(seconds: 5));
      await response.drain<void>();
    } on Object {
      // The peer will be found through its own announcement or the next scan.
    }
  }

  Future<PrepareResult> prepareUpload(
    Peer peer,
    PrepareUploadRequest body, {
    TransferCancellation? cancellation,
  }) async {
    HttpClientRequest? request;
    void abort() => request?.abort(const TransferCancelledException());
    cancellation?._onCancel(abort);
    try {
      request = await _http.postUrl(peer.endpoint('prepare-upload'));
      if (cancellation?.isCancelled ?? false) throw const TransferCancelledException();
      _writeJson(request, body.toJson());
      // The receiver waits for its user to accept; LocalSend gives them a minute or more.
      final response = await request.close().timeout(const Duration(seconds: 120));
      final text = await response.transform(utf8.decoder).join();
      return prepareResultFor(response.statusCode, text);
    } on TransferCancelledException {
      rethrow;
    } on TimeoutException {
      return const PrepareFailed('No answer from the device');
    } on Object catch (error) {
      if (cancellation?.isCancelled ?? false) throw const TransferCancelledException();
      return PrepareFailed(_describe(error));
    } finally {
      cancellation?._remove(abort);
    }
  }

  /// Uploads one file; [onProgress] receives the bytes sent so far.
  Future<void> upload(
    Peer peer,
    File file, {
    required String sessionId,
    required String fileId,
    required String token,
    required void Function(int sent) onProgress,
    TransferCancellation? cancellation,
  }) async {
    if (cancellation?.isCancelled ?? false) throw const TransferCancelledException();
    final uri = peer.endpoint('upload', {'sessionId': sessionId, 'fileId': fileId, 'token': token});
    HttpClientRequest? request;
    void abort() => request?.abort(const TransferCancelledException());
    cancellation?._onCancel(abort);
    try {
      final length = await file.length();
      request = await _http.postUrl(uri);
      request.headers.contentType = ContentType.binary;
      request.contentLength = length;
      var sent = 0;
      await request.addStream(file.openRead().map((chunk) {
        sent += chunk.length;
        onProgress(sent);
        return chunk;
      }));
      final response = await request.close();
      await response.drain<void>();
      if (response.statusCode != 200) {
        throw HttpException('Error ${response.statusCode}', uri: uri);
      }
    } on Object {
      if (cancellation?.isCancelled ?? false) throw const TransferCancelledException();
      rethrow;
    } finally {
      cancellation?._remove(abort);
    }
  }

  Future<void> cancel(Peer peer, String sessionId) async {
    try {
      final request = await _http.postUrl(peer.endpoint('cancel', {'sessionId': sessionId}));
      final response = await request.close().timeout(const Duration(seconds: 5));
      await response.drain<void>();
    } on Object {
      // Best effort: the receiver also gives up on idle sessions.
    }
  }

  void close() => _http.close(force: true);

  static void _writeJson(HttpClientRequest request, Object? json) {
    final bytes = utf8.encode(jsonEncode(json));
    request.headers.contentType = ContentType.json;
    request.contentLength = bytes.length;
    request.add(bytes);
  }

  static String _describe(Object error) {
    if (error is SocketException) return 'The device could not be reached';
    if (error is HandshakeException) return 'Secure connection failed';
    if (error is HttpException) return error.message;
    return error.toString();
  }
}
