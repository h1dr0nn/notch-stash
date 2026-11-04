import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Keeps one running copy of the app. The first instance listens on a loopback port;
/// a later launch connects, asks it to show Settings and exits.
class SingleInstance {
  SingleInstance._(this._server);

  static const int defaultPort = 53319;
  static const String _request = 'notch-stash:activate';
  static const String _reply = 'notch-stash:ok';

  final ServerSocket? _server;

  /// Returns null when another instance answered (the caller should exit).
  /// Otherwise returns the lock, which calls [onActivate] for each later launch.
  /// When the port is held by an unrelated program the app runs without the lock.
  static Future<SingleInstance?> acquire({
    required void Function() onActivate,
    int port = defaultPort,
  }) async {
    try {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
      server.listen((socket) => _serve(socket, onActivate), onError: (Object _) {});
      return SingleInstance._(server);
    } on SocketException {
      if (await _signalRunningInstance(port)) return null;
      return SingleInstance._(null);
    }
  }

  static void _serve(Socket socket, void Function() onActivate) {
    var buffer = '';
    socket.cast<List<int>>().transform(utf8.decoder).listen(
      (chunk) {
        buffer += chunk;
        if (!buffer.contains('\n')) return;
        if (buffer.trim() == _request) {
          socket.write('$_reply\n');
          onActivate();
        }
        unawaited(socket.flush().whenComplete(socket.destroy));
      },
      onError: (Object _) => socket.destroy(),
      cancelOnError: true,
    );
  }

  static Future<bool> _signalRunningInstance(int port) async {
    Socket? socket;
    try {
      socket = await Socket.connect(InternetAddress.loopbackIPv4, port, timeout: const Duration(seconds: 2));
      socket.write('$_request\n');
      await socket.flush();
      final answer = await socket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 2));
      return answer.trim() == _reply;
    } on Object {
      return false;
    } finally {
      socket?.destroy();
    }
  }

  bool get isPrimary => _server != null;

  Future<void> release() async => _server?.close();
}
