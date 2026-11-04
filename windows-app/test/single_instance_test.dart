import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:notch_stash/src/platform/single_instance.dart';

void main() {
  test('a second launch activates the first one and is told to exit', () async {
    final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = probe.port;
    await probe.close();

    var activations = 0;
    final first = await SingleInstance.acquire(onActivate: () => activations++, port: port);
    expect(first, isNotNull);
    expect(first!.isPrimary, isTrue);

    final second = await SingleInstance.acquire(onActivate: () {}, port: port);
    expect(second, isNull);
    expect(activations, 1);
    await first.release();
  });

  test('runs without the lock when an unrelated program holds the port', () async {
    final other = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    other.listen((socket) => socket.destroy());
    final instance = await SingleInstance.acquire(onActivate: () {}, port: other.port);
    expect(instance, isNotNull);
    expect(instance!.isPrimary, isFalse);
    await other.close();
  });
}
