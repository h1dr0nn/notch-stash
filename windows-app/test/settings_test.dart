import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:notch_stash/src/settings.dart';

void main() {
  test('fingerprints are 32 hex characters and differ', () {
    final a = AppSettings.newFingerprint();
    final b = AppSettings.newFingerprint();
    expect(a, matches(RegExp(r'^[0-9a-f]{32}$')));
    expect(a, isNot(b));
    expect(AppSettings.newFingerprint(Random(1)), AppSettings.newFingerprint(Random(1)));
  });

  test('downloads folder ends in Downloads', () {
    expect(AppSettings.downloadsFolder(), endsWith('Downloads'));
  });
}
