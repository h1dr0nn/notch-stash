import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'models.dart';
import 'receive_controller.dart';

/// Plain HTTP server for the LocalSend v2 API. Upload bodies stream straight to disk.
class LocalSendServer {
  LocalSendServer(this.controller);

  final ReceiveController controller;

  static const _maxJsonBody = 4 * 1024 * 1024;

  HttpServer? _server;

  int? get port => _server?.port;
  bool get isRunning => _server != null;

  /// Binds the LocalSend default port, or any free port when it is taken
  /// (for example by the LocalSend app on the same PC). Returns the port.
  Future<int> start({int preferredPort = LocalSendDefaults.port, Object? address}) async {
    if (_server != null) return _server!.port;
    final host = address ?? InternetAddress.anyIPv4;
    HttpServer server;
    try {
      server = await HttpServer.bind(host, preferredPort);
    } on SocketException {
      server = await HttpServer.bind(host, 0);
    }
    server.autoCompress = false;
    server.idleTimeout = const Duration(seconds: 30);
    _server = server;
    server.listen((request) => unawaited(_handle(request)), onError: (Object _) {});
    return server.port;
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }

  Future<void> _handle(HttpRequest request) async {
    final remoteIp = _ip(request.connectionInfo?.remoteAddress);
    final path = request.uri.path;
    final query = request.uri.queryParameters;
    try {
      if (request.method == 'POST' && path == '${LocalSendDefaults.apiBase}/upload') {
        await _upload(request, query, remoteIp);
        return;
      }
      final body = await _readBody(request);
      if (body == null) {
        await _reply(request, const HttpReply(413));
        return;
      }
      final reply = await controller.handle(request.method, path, query, body, remoteIp);
      await _reply(request, reply);
    } on Object {
      try {
        await _reply(request, const HttpReply(500));
      } on Object {
        // The connection is already gone.
      }
    }
  }

  Future<void> _upload(HttpRequest request, Map<String, String> query, String remoteIp) async {
    final target = controller.uploadTarget(query, remoteIp);
    switch (target) {
      case UploadReject(:final status):
        await request.drain<void>().catchError((Object _) {});
        await _reply(request, HttpReply(status));
      case UploadWrite(:final path):
        final file = File(path);
        var success = false;
        try {
          await file.parent.create(recursive: true);
          final sink = file.openWrite();
          try {
            await request.cast<List<int>>().pipe(sink);
            success = true;
          } finally {
            await sink.close().catchError((Object _) {});
          }
        } on Object {
          success = false;
        }
        if (!success) {
          await file.delete().catchError((Object _) => file);
        }
        final reply = controller.uploadFinished(query, path, success: success);
        await _reply(request, reply);
    }
  }

  Future<List<int>?> _readBody(HttpRequest request) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in request) {
      builder.add(chunk);
      if (builder.length > _maxJsonBody) return null;
    }
    return builder.takeBytes();
  }

  Future<void> _reply(HttpRequest request, HttpReply reply) async {
    final response = request.response
      ..statusCode = reply.status
      ..persistentConnection = false
      ..headers.contentType = ContentType.json
      ..contentLength = reply.body.length;
    if (reply.body.isNotEmpty) response.add(reply.body);
    await response.close();
  }

  static String _ip(InternetAddress? address) {
    if (address == null) return '';
    final text = address.address;
    const mapped = '::ffff:';
    return text.startsWith(mapped) ? text.substring(mapped.length) : text;
  }
}
