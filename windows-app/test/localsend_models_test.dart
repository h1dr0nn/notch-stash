import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:notch_stash/src/localsend/client.dart';
import 'package:notch_stash/src/localsend/models.dart';

void main() {
  group('DeviceInfo', () {
    test('parses an announcement from the protocol spec', () {
      final info = DeviceInfo.fromJson(jsonDecode('''
        {"alias": "Nice Orange", "version": "2.0", "deviceModel": "Samsung", "deviceType": "mobile",
         "fingerprint": "random string", "port": 53317, "protocol": "https", "download": true, "announce": true}
      '''));
      expect(info, isNotNull);
      expect(info!.alias, 'Nice Orange');
      expect(info.deviceType, 'mobile');
      expect(info.port, 53317);
      expect(info.protocol, 'https');
      expect(info.announce, isTrue);
    });

    test('tolerates nulls and missing optional fields', () {
      final info = DeviceInfo.fromJson({'alias': 'A', 'fingerprint': 'f', 'deviceModel': null});
      expect(info!.deviceModel, isNull);
      expect(info.port, isNull);
      expect(info.version, '1.0');
    });

    test('rejects objects without alias or fingerprint', () {
      expect(DeviceInfo.fromJson({'alias': 'A'}), isNull);
      expect(DeviceInfo.fromJson('text'), isNull);
      expect(DeviceInfo.fromJson(null), isNull);
    });

    test('our own info encodes the fields LocalSend expects', () {
      const own = DeviceInfo(
        alias: 'DESKTOP-1',
        fingerprint: 'abc',
        deviceModel: 'Windows',
        deviceType: 'desktop',
        port: 53317,
        protocol: 'http',
        download: false,
      );
      final json = own.copyWith(announce: true).toJson();
      expect(json, {
        'alias': 'DESKTOP-1',
        'version': '2.1',
        'deviceModel': 'Windows',
        'deviceType': 'desktop',
        'fingerprint': 'abc',
        'port': 53317,
        'protocol': 'http',
        'download': false,
        'announce': true,
      });
      expect(DeviceInfo.fromJson(jsonDecode(jsonEncode(json))), own.copyWith(announce: true));
      expect(own.toJson().containsKey('announce'), isFalse);
    });
  });

  group('PrepareUploadRequest', () {
    test('round-trips through JSON', () {
      const request = PrepareUploadRequest(
        info: DeviceInfo(alias: 'A', fingerprint: 'f', port: 1, protocol: 'http'),
        files: {
          'id1': FileInfo(id: 'id1', fileName: 'a.png', size: 10, fileType: 'image/png'),
          'id2': FileInfo(id: 'id2', fileName: 'dir/b.txt', size: 0, fileType: 'text/plain', sha256: 'x'),
        },
      );
      final decoded = PrepareUploadRequest.fromJson(jsonDecode(jsonEncode(request.toJson())));
      expect(decoded!.info, request.info);
      expect(decoded.files, request.files);
    });

    test('parses files with metadata and defaults a missing type', () {
      final decoded = PrepareUploadRequest.fromJson({
        'info': {'alias': 'A', 'fingerprint': 'f'},
        'files': {
          'x': {
            'id': 'x',
            'fileName': 'n.bin',
            'size': 5.0,
            'metadata': {'modified': '2021-01-01T12:34:56Z'},
          },
        },
      });
      expect(decoded!.files['x']!.size, 5);
      expect(decoded.files['x']!.fileType, 'application/octet-stream');
    });

    test('rejects malformed bodies', () {
      expect(PrepareUploadRequest.fromJson({'files': {}}), isNull);
      expect(
        PrepareUploadRequest.fromJson({
          'info': {'alias': 'A', 'fingerprint': 'f'},
          'files': {'x': {'id': 'x'}},
        }),
        isNull,
      );
    });
  });

  test('PrepareUploadResponse round-trips and rejects bad tokens', () {
    const response = PrepareUploadResponse(sessionId: 's', files: {'a': 't1', 'b': 't2'});
    final decoded = PrepareUploadResponse.fromJson(jsonDecode(jsonEncode(response.toJson())));
    expect(decoded!.sessionId, 's');
    expect(decoded.files, {'a': 't1', 'b': 't2'});
    expect(PrepareUploadResponse.fromJson({'sessionId': 's', 'files': {'a': 1}}), isNull);
  });

  group('Peer', () {
    test('defaults to HTTPS and the standard port', () {
      final peer = Peer.fromInfo(const DeviceInfo(alias: 'A', fingerprint: 'f'), '10.0.0.2', DateTime(2026));
      expect(peer.scheme, 'https');
      expect(peer.port, 53317);
      expect(peer.endpoint('upload', {'sessionId': 's', 'fileId': 'a b'}).toString(),
          'https://10.0.0.2:53317/api/localsend/v2/upload?sessionId=s&fileId=a+b');
    });

    test('uses HTTP when the peer announces it and shows model and IP', () {
      final peer = Peer.fromInfo(
        const DeviceInfo(alias: 'Mac', fingerprint: 'f', protocol: 'http', port: 5000, deviceModel: 'Mac'),
        '10.0.0.3',
        DateTime(2026),
      );
      expect(peer.endpoint('info').toString(), 'http://10.0.0.3:5000/api/localsend/v2/info');
      expect(peer.subtitle, 'Mac · 10.0.0.3');
    });
  });

  group('prepareResultFor', () {
    test('maps status codes', () {
      expect(prepareResultFor(204, ''), isA<PrepareNothingToSend>());
      expect(prepareResultFor(401, ''), isA<PreparePinRequired>());
      expect(prepareResultFor(403, ''), isA<PrepareDeclined>());
      expect(prepareResultFor(409, ''), isA<PrepareBusy>());
      expect(prepareResultFor(429, ''), isA<PrepareBusy>());
      expect((prepareResultFor(500, '') as PrepareFailed).message, 'Error 500');
    });

    test('decodes an accepted session and flags a broken one', () {
      final result = prepareResultFor(200, '{"sessionId":"s","files":{"a":"t"}}');
      expect((result as PrepareAccepted).response.files, {'a': 't'});
      expect(prepareResultFor(200, 'not json'), isA<PrepareFailed>());
    });
  });
}
