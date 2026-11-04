import 'package:flutter_test/flutter_test.dart';
import 'package:notch_stash/src/core/subnet_sweep.dart';

void main() {
  test('covers the /22 block around the address without itself', () {
    final hosts = sweepHosts('10.10.21.40');
    expect(hosts, hasLength(1021));
    expect(hosts.first, '10.10.20.1');
    expect(hosts.last, '10.10.23.254');
    expect(hosts, contains('10.10.20.73'));
    expect(hosts, isNot(contains('10.10.21.40')));
  });

  test('a /24 prefix gives the usual home network', () {
    final hosts = sweepHosts('192.168.1.20', prefix: 24);
    expect(hosts, hasLength(253));
    expect(hosts, isNot(contains('192.168.1.0')));
    expect(hosts, isNot(contains('192.168.1.255')));
  });

  test('skips VPN, link-local, loopback and invalid addresses', () {
    expect(sweepHosts('100.106.50.77'), isEmpty);
    expect(sweepHosts('169.254.3.4'), isEmpty);
    expect(sweepHosts('127.0.0.1'), isEmpty);
    expect(sweepHosts('not an ip'), isEmpty);
    expect(sweepHosts('10.0.0.1', prefix: 8), isEmpty);
  });
}
