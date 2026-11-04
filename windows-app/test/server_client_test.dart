import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:notch_stash/src/localsend/client.dart';
import 'package:notch_stash/src/localsend/models.dart';
import 'package:notch_stash/src/localsend/receive_controller.dart';
import 'package:notch_stash/src/localsend/server.dart';
import 'package:path/path.dart' as p;

/// Runs our HTTP server and client against each other over loopback.
void main() {
  late Directory temp;
  late Directory saveFolder;
  late LocalSendServer server;
  late LocalSendClient client;
  late List<String> received;
  late Future<bool> Function(IncomingRequest) answer;
  late Peer peer;

  const sender = DeviceInfo(alias: 'Sender', fingerprint: 'sender', port: 1, protocol: 'http');

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('notch_stash_test');
    saveFolder = Directory(p.join(temp.path, 'received'))..createSync();
    received = [];
    answer = (_) async => true;
    final controller = ReceiveController(
      ownInfo: () => const DeviceInfo(alias: 'Receiver', fingerprint: 'receiver', protocol: 'http'),
      receiveEnabled: () => true,
      saveFolder: () => saveFolder.path,
      askUser: (request) => answer(request),
      dismissPrompt: (_) {},
      onPeer: (_, _) {},
      onFileReceived: received.add,
    );
    server = LocalSendServer(controller);
    final port = await server.start(preferredPort: 0, address: InternetAddress.loopbackIPv4);
    client = LocalSendClient();
    peer = Peer(
      fingerprint: 'receiver',
      alias: 'Receiver',
      ip: '127.0.0.1',
      port: port,
      scheme: 'http',
      lastSeen: DateTime.now(),
    );
  });

  tearDown(() async {
    client.close();
    await server.stop();
    await temp.delete(recursive: true);
  });

  File source(String name, List<int> bytes) => File(p.join(temp.path, name))..writeAsBytesSync(bytes);

  test('sends files end to end with progress', () async {
    final big = List<int>.generate(300 * 1024, (i) => i % 251);
    final files = {
      'f1': FileInfo(id: 'f1', fileName: 'big.bin', size: big.length, fileType: 'application/octet-stream'),
      'f2': const FileInfo(id: 'f2', fileName: 'notes/readme.txt', size: 5, fileType: 'text/plain'),
    };
    final sources = {'f1': source('big.bin', big), 'f2': source('readme.txt', utf8.encode('hello'))};

    final result = await client.prepareUpload(peer, PrepareUploadRequest(info: sender, files: files));
    final response = (result as PrepareAccepted).response;
    expect(response.files.keys, unorderedEquals(['f1', 'f2']));

    final progress = <int>[];
    for (final id in ['f1', 'f2']) {
      await client.upload(
        peer,
        sources[id]!,
        sessionId: response.sessionId,
        fileId: id,
        token: response.files[id]!,
        onProgress: progress.add,
      );
    }
    expect(File(p.join(saveFolder.path, 'big.bin')).readAsBytesSync(), big);
    expect(File(p.join(saveFolder.path, 'notes', 'readme.txt')).readAsStringSync(), 'hello');
    expect(received, hasLength(2));
    expect(progress.first, greaterThan(0));
    expect(progress.where((sent) => sent == big.length), isNotEmpty);
  });

  test('a declined request reports Declined', () async {
    answer = (_) async => false;
    final result = await client.prepareUpload(
      peer,
      const PrepareUploadRequest(info: sender, files: {
        'f': FileInfo(id: 'f', fileName: 'a.txt', size: 1, fileType: 'text/plain'),
      }),
    );
    expect(result, isA<PrepareDeclined>());
  });

  test('an empty request needs no transfer', () async {
    final result = await client.prepareUpload(peer, const PrepareUploadRequest(info: sender, files: {}));
    expect(result, isA<PrepareNothingToSend>());
  });

  test('a second sender is told the receiver is busy', () async {
    final decision = Completer<bool>();
    answer = (_) => decision.future;
    const request = PrepareUploadRequest(info: sender, files: {
      'f': FileInfo(id: 'f', fileName: 'a.txt', size: 1, fileType: 'text/plain'),
    });
    final first = client.prepareUpload(peer, request);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(await client.prepareUpload(peer, request), isA<PrepareBusy>());
    decision.complete(false);
    expect(await first, isA<PrepareDeclined>());
  });

  test('uploads with a wrong token are rejected and leave no file', () async {
    final result = await client.prepareUpload(
      peer,
      const PrepareUploadRequest(info: sender, files: {
        'f': FileInfo(id: 'f', fileName: 'a.txt', size: 3, fileType: 'text/plain'),
      }),
    );
    final response = (result as PrepareAccepted).response;
    await expectLater(
      client.upload(peer, source('a.txt', [1, 2, 3]),
          sessionId: response.sessionId, fileId: 'f', token: 'wrong', onProgress: (_) {}),
      throwsA(isA<HttpException>()),
    );
    expect(saveFolder.listSync(), isEmpty);
  });

  test('accepts chunked upload bodies', () async {
    final result = await client.prepareUpload(
      peer,
      const PrepareUploadRequest(info: sender, files: {
        'f': FileInfo(id: 'f', fileName: 'chunked.txt', size: 6, fileType: 'text/plain'),
      }),
    );
    final response = (result as PrepareAccepted).response;
    final http = HttpClient();
    final request = await http.postUrl(peer.endpoint('upload', {
      'sessionId': response.sessionId,
      'fileId': 'f',
      'token': response.files['f']!,
    }));
    request.contentLength = -1;
    request.add(utf8.encode('abc'));
    await request.flush();
    request.add(utf8.encode('def'));
    final reply = await request.close();
    expect(reply.statusCode, 200);
    http.close();
    expect(File(p.join(saveFolder.path, 'chunked.txt')).readAsStringSync(), 'abcdef');
  });

  test('register and info answer with the receiver info', () async {
    final http = HttpClient();
    final request = await http.getUrl(peer.endpoint('info'));
    final reply = await request.close();
    final body = jsonDecode(await reply.transform(utf8.decoder).join());
    http.close();
    expect(DeviceInfo.fromJson(body)?.alias, 'Receiver');
    await client.register(peer, sender);
  });

  test('cancelling stops a waiting request', () async {
    final decision = Completer<bool>();
    answer = (_) => decision.future;
    final cancellation = TransferCancellation();
    final pending = client.prepareUpload(
      peer,
      const PrepareUploadRequest(info: sender, files: {
        'f': FileInfo(id: 'f', fileName: 'a.txt', size: 1, fileType: 'text/plain'),
      }),
      cancellation: cancellation,
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));
    cancellation.cancel();
    await expectLater(pending, throwsA(isA<TransferCancelledException>()));
    decision.complete(false);
  });
}
