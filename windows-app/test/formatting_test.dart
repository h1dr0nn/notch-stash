import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notch_stash/src/core/formatting.dart';
import 'package:notch_stash/src/ui/common.dart';

void main() {
  test('formats byte counts', () {
    expect(formatBytes(0), '0 bytes');
    expect(formatBytes(1), '1 byte');
    expect(formatBytes(999), '999 bytes');
    expect(formatBytes(1500), '1.5 KB');
    expect(formatBytes(2345678), '2.3 MB');
    expect(formatBytes(123456789), '123 MB');
    expect(formatBytes(5 * 1000 * 1000 * 1000), '5.0 GB');
  });

  test('counts files', () {
    expect(fileCount(1), 'a file');
    expect(fileCount(3), '3 files');
  });

  test('middle ellipsis keeps start and end', () {
    expect(middleEllipsis('short.txt', (_) => true), 'short.txt');
    final shortened = middleEllipsis('a-very-long-file-name.pdf', (candidate) => candidate.length <= 12);
    expect(shortened.length, 12);
    expect(shortened, startsWith('a-very'));
    expect(shortened, endsWith('.pdf'));
    expect(shortened, contains('…'));
    expect(middleEllipsis('abc', (_) => false), '…');
  });

  testWidgets('MiddleEllipsisText fits two lines', (tester) async {
    const name = 'Quarterly report final version reviewed by everyone 2026.xlsx';
    await tester.pumpWidget(const MaterialApp(
      home: Center(
        child: SizedBox(
          width: 72,
          child: MiddleEllipsisText(name, style: TextStyle(fontSize: 10)),
        ),
      ),
    ));
    final text = tester.widget<Text>(find.byType(Text));
    expect(text.data, isNot(name));
    expect(text.data, contains('…'));
    expect(text.data, endsWith('.xlsx'));
  });
}
