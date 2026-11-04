import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:notch_stash/src/localsend/models.dart';
import 'package:notch_stash/src/localsend/receive_controller.dart';
import 'package:path/path.dart' as p;

const _own = DeviceInfo(
  alias: 'This PC',
  fingerprint: 'own',
  deviceModel: 'Windows',
  deviceType: 'desktop',
  port: 53317,
  protocol: 'http',
  download: false,
);

const _sender = {'alias': 'Phone', 'fingerprint': 'phone', 'deviceType': 'mobile', 'version': '2.0'};

List<int> _json(Object value) => utf8.encode(jsonEncode(value));

List<int> _prepareBody(Map<String, Object> files) => _json({
      'info': _sender,
      'files': {
        for (final entry in files.entries)
          entry.key: {'id': entry.key, 'fileName': entry.value, 'size': 3, 'fileType': 'text/plain'},
      },
    });

void main() {
  late List<(String, String)> peers;
  late List<String> received;
  late List<IncomingRequest> asked;
  late List<IncomingRequest> dismissed;
  late Set<String> existing;
  late bool receiveEnabled;
  late Future<bool> Function(IncomingRequest) answer;
  late DateTime now;
  final folder = p.join(p.separator == r'\' ? r'C:\' : '/', 'Downloads');

  ReceiveController make({Duration timeout = const Duration(seconds: 60)}) => ReceiveController(
        ownInfo: () => _own,
        receiveEnabled: () => receiveEnabled,
        saveFolder: () => folder,
        askUser: (request) {
          asked.add(request);
          return answer(request);
        },
        dismissPrompt: dismissed.add,
        onPeer: (info, ip) => peers.add((info.alias, ip)),
        onFileReceived: received.add,
        decisionTimeout: timeout,
        exists: existing.contains,
        now: () => now,
      );

  Future<Map<String, Object?>> accept(ReceiveController controller, Map<String, Object> files,
      {String ip = '10.0.0.5'}) async {
    final reply = await controller.handle('POST', '/api/localsend/v2/prepare-upload', {}, _prepareBody(files), ip);
    expect(reply.status, 200);
    return jsonDecode(utf8.decode(reply.body)) as Map<String, Object?>;
  }

  setUp(() {
    peers = [];
    received = [];
    asked = [];
    dismissed = [];
    existing = {};
    receiveEnabled = true;
    answer = (_) async => true;
    now = DateTime(2026, 1, 1, 12);
  });

  test('register records the peer and answers with our info', () async {
    final controller = make();
    final reply = await controller.handle('POST', '/api/localsend/v2/register', {}, _json(_sender), '10.0.0.5');
    expect(reply.status, 200);
    expect(jsonDecode(utf8.decode(reply.body)), _own.toJson());
    expect(peers, [('Phone', '10.0.0.5')]);
  });

  test('register ignores our own fingerprint', () async {
    final controller = make();
    await controller.handle('POST', '/api/localsend/v2/register', {}, _json(_own.toJson()), '10.0.0.9');
    expect(peers, isEmpty);
  });

  test('info answers, unknown routes 404', () async {
    final controller = make();
    expect((await controller.handle('GET', '/api/localsend/v2/info', {}, [], 'x')).status, 200);
    expect((await controller.handle('GET', '/api/localsend/v2/nope', {}, [], 'x')).status, 404);
    expect((await controller.handle('GET', '/api/localsend/v2/register', {}, [], 'x')).status, 404);
  });

  test('prepare-upload: 403 when receiving is off, 400 for bad bodies, 204 for no files', () async {
    final controller = make();
    receiveEnabled = false;
    expect((await controller.handle('POST', '/api/localsend/v2/prepare-upload', {}, _prepareBody({'a': 'a.txt'}), 'ip')).status, 403);
    receiveEnabled = true;
    expect((await controller.handle('POST', '/api/localsend/v2/prepare-upload', {}, utf8.encode('{'), 'ip')).status, 400);
    expect((await controller.handle('POST', '/api/localsend/v2/prepare-upload', {}, _prepareBody({}), 'ip')).status, 204);
    expect(asked, isEmpty);
  });

  test('prepare-upload asks the user with files sorted by name', () async {
    final controller = make();
    final body = await accept(controller, {'b': 'zeta.txt', 'a': 'alpha.txt'});
    expect(asked.single.sender.alias, 'Phone');
    expect(asked.single.files.map((f) => f.fileName), ['alpha.txt', 'zeta.txt']);
    expect(asked.single.totalSize, 6);
    expect((body['files'] as Map).keys, unorderedEquals(['a', 'b']));
    expect(body['sessionId'], isA<String>());
    expect(controller.isBusy, isTrue);
  });

  test('declined requests get 403 and leave no session', () async {
    final controller = make();
    answer = (_) async => false;
    final reply = await controller.handle('POST', '/api/localsend/v2/prepare-upload', {}, _prepareBody({'a': 'a.txt'}), 'ip');
    expect(reply.status, 403);
    expect(controller.isBusy, isFalse);
  });

  test('an unanswered prompt declines after the timeout', () async {
    final controller = make(timeout: const Duration(milliseconds: 20));
    answer = (_) => Completer<bool>().future;
    final reply = await controller.handle('POST', '/api/localsend/v2/prepare-upload', {}, _prepareBody({'a': 'a.txt'}), 'ip');
    expect(reply.status, 403);
    expect(dismissed, hasLength(1));
    expect(controller.isBusy, isFalse);
  });

  test('a second request while prompting or receiving gets 409', () async {
    final controller = make();
    final decision = Completer<bool>();
    answer = (_) => decision.future;
    final first = controller.handle('POST', '/api/localsend/v2/prepare-upload', {}, _prepareBody({'a': 'a.txt'}), 'ip');
    await Future<void>.delayed(Duration.zero);
    final second = await controller.handle('POST', '/api/localsend/v2/prepare-upload', {}, _prepareBody({'b': 'b.txt'}), 'ip2');
    expect(second.status, 409);
    decision.complete(true);
    expect((await first).status, 200);
    final third = await controller.handle('POST', '/api/localsend/v2/prepare-upload', {}, _prepareBody({'b': 'b.txt'}), 'ip2');
    expect(third.status, 409);
  });

  group('upload', () {
    test('validates parameters, session, token and sender IP', () async {
      final controller = make();
      expect(controller.uploadTarget({}, '10.0.0.5'), isA<UploadReject>().having((r) => r.status, 'status', 400));
      expect(
        controller.uploadTarget({'sessionId': 's', 'fileId': 'a', 'token': 't'}, '10.0.0.5'),
        isA<UploadReject>().having((r) => r.status, 'status', 409),
      );
      final body = await accept(controller, {'a': 'a.txt'});
      final session = body['sessionId'] as String;
      final token = (body['files'] as Map)['a'] as String;
      UploadTarget target(Map<String, String> q, [String ip = '10.0.0.5']) => controller.uploadTarget(q, ip);
      expect(target({'sessionId': 'other', 'fileId': 'a', 'token': token}), isA<UploadReject>());
      expect(target({'sessionId': session, 'fileId': 'a', 'token': 'wrong'}), isA<UploadReject>());
      expect(target({'sessionId': session, 'fileId': 'zzz', 'token': token}), isA<UploadReject>());
      expect(target({'sessionId': session, 'fileId': 'a', 'token': token}, '10.0.0.6'),
          isA<UploadReject>().having((r) => r.status, 'status', 403));
      final ok = target({'sessionId': session, 'fileId': 'a', 'token': token});
      expect(ok, isA<UploadWrite>().having((w) => w.path, 'path', p.join(folder, 'a.txt')));
      expect(target({'sessionId': session, 'fileId': 'a', 'token': token}),
          isA<UploadReject>().having((r) => r.status, 'status', 409));
    });

    test('picks unique names, keeps subfolders and finishes the session', () async {
      final controller = make();
      existing.add(p.join(folder, 'a.txt'));
      final body = await accept(controller, {'1': 'a.txt', '2': 'a.txt', '3': 'pics/../../x/b.png'});
      final session = body['sessionId'] as String;
      final tokens = (body['files'] as Map).cast<String, String>();
      final paths = <String>[];
      for (final id in ['1', '2', '3']) {
        final query = {'sessionId': session, 'fileId': id, 'token': tokens[id]!};
        final target = controller.uploadTarget(query, '10.0.0.5') as UploadWrite;
        paths.add(target.path);
        expect(controller.uploadFinished(query, target.path, success: true).status, 200);
      }
      expect(paths, [
        p.join(folder, 'a (1).txt'),
        p.join(folder, 'a (2).txt'),
        p.join(folder, 'pics', 'x', 'b.png'),
      ]);
      expect(received, paths);
      expect(controller.isBusy, isFalse);
    });

    test('a failed upload frees its name and can be retried', () async {
      final controller = make();
      final body = await accept(controller, {'1': 'a.txt'});
      final query = {'sessionId': body['sessionId'] as String, 'fileId': '1', 'token': (body['files'] as Map)['1'] as String};
      final first = controller.uploadTarget(query, '10.0.0.5') as UploadWrite;
      expect(controller.uploadFinished(query, first.path, success: false).status, 500);
      expect(received, isEmpty);
      final retry = controller.uploadTarget(query, '10.0.0.5') as UploadWrite;
      expect(retry.path, first.path);
    });
  });

  test('cancel from the sender ends the session', () async {
    final controller = make();
    final body = await accept(controller, {'1': 'a.txt'});
    final session = body['sessionId'] as String;
    await controller.handle('POST', '/api/localsend/v2/cancel', {'sessionId': 'other'}, [], '10.0.0.5');
    expect(controller.isBusy, isTrue);
    await controller.handle('POST', '/api/localsend/v2/cancel', {'sessionId': session}, [], '10.0.0.6');
    expect(controller.isBusy, isTrue);
    expect((await controller.handle('POST', '/api/localsend/v2/cancel', {'sessionId': session}, [], '10.0.0.5')).status, 200);
    expect(controller.isBusy, isFalse);
  });

  test('an idle session expires so new transfers are not blocked', () async {
    final controller = make();
    await accept(controller, {'1': 'a.txt'});
    expect(controller.isBusy, isTrue);
    now = now.add(const Duration(minutes: 3));
    expect(controller.isBusy, isFalse);
    await accept(controller, {'2': 'b.txt'}, ip: '10.0.0.7');
  });
}
