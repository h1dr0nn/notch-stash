import 'package:flutter_test/flutter_test.dart';
import 'package:notch_stash/src/core/app_version.dart';

void main() {
  group('AppVersion.tryParse', () {
    test('accepts plain, v-prefixed, tag and build versions', () {
      expect(AppVersion.tryParse('0.6.1')?.components, [0, 6, 1]);
      expect(AppVersion.tryParse('v0.6.1')?.components, [0, 6, 1]);
      expect(AppVersion.tryParse('release-v1.2.3')?.components, [1, 2, 3]);
      expect(AppVersion.tryParse('develop-v0.7.0')?.components, [0, 7, 0]);
      expect(AppVersion.tryParse('0.6.0+12')?.components, [0, 6, 0]);
    });

    test('rejects malformed text', () {
      expect(AppVersion.tryParse(''), isNull);
      expect(AppVersion.tryParse('abc'), isNull);
      expect(AppVersion.tryParse('1..2'), isNull);
      expect(AppVersion.tryParse('1.2.x'), isNull);
      expect(AppVersion.tryParse('-1.2'), isNull);
    });
  });

  test('compares component by component, missing parts count as zero', () {
    final v = AppVersion.tryParse;
    expect(v('0.6.1')! > v('0.6.0')!, isTrue);
    expect(v('0.10.0')! > v('0.9.9')!, isTrue);
    expect(v('1.0')! == v('1.0.0')!, isTrue);
    expect(v('1.0').hashCode, v('1.0.0').hashCode);
    expect(v('0.6.0')! < v('0.6.0.1')!, isTrue);
  });

  test('prints dotted form', () {
    expect(AppVersion.tryParse('release-v0.6.0+3').toString(), '0.6.0');
  });
}
