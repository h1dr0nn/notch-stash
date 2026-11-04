import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:notch_stash/src/core/placement.dart';

void main() {
  const size = Size(380, 190);
  const area = Rect.fromLTWH(0, 0, 1920, 1040);

  test('shows below the pointer, centred on it', () {
    expect(shelfOrigin(cursor: const Offset(800, 300), workArea: area, size: size), const Offset(610, 316));
  });

  test('flips above the pointer near the taskbar', () {
    expect(shelfOrigin(cursor: const Offset(800, 1000), workArea: area, size: size), const Offset(610, 794));
  });

  test('stays inside the work area at the edges', () {
    expect(shelfOrigin(cursor: const Offset(5, 5), workArea: area, size: size), const Offset(0, 21));
    expect(shelfOrigin(cursor: const Offset(1919, 500), workArea: area, size: size), const Offset(1540, 516));
  });

  test('works on a second screen with negative coordinates', () {
    const left = Rect.fromLTWH(-1280, 0, 1280, 984);
    expect(shelfOrigin(cursor: const Offset(-1270, 970), workArea: left, size: size), const Offset(-1280, 764));
  });

  test('centres other windows', () {
    expect(centeredOrigin(workArea: area, size: const Size(480, 600)), const Offset(720, 220));
    expect(centeredOrigin(workArea: const Rect.fromLTWH(0, 0, 400, 400), size: const Size(480, 600)), Offset.zero);
  });

  test('finds the screen under the pointer or the nearest one', () {
    const right = Rect.fromLTWH(1920, 0, 2560, 1400);
    expect(workAreaFor(const Offset(2000, 10), [area, right]), right);
    expect(workAreaFor(const Offset(100, 1060), [area, right]), area);
    expect(workAreaFor(const Offset(10, 10), []), isNull);
  });
}
