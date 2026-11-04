import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:notch_stash/src/localsend/send_entries.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory temp;

  setUp(() async => temp = await Directory.systemTemp.createTemp('notch_stash_send'));
  tearDown(() async => temp.delete(recursive: true));

  test('expands folders into files with relative names, skipping hidden ones', () {
    final photo = File(p.join(temp.path, 'photo.png'))..writeAsBytesSync([1, 2, 3]);
    final folder = Directory(p.join(temp.path, 'Project'))..createSync();
    File(p.join(folder.path, 'a.txt')).writeAsStringSync('a');
    Directory(p.join(folder.path, 'sub')).createSync();
    File(p.join(folder.path, 'sub', 'b.json')).writeAsStringSync('{}');
    File(p.join(folder.path, '.hidden')).writeAsStringSync('x');
    Directory(p.join(folder.path, '.git')).createSync();
    File(p.join(folder.path, '.git', 'config')).writeAsStringSync('x');

    final entries = expandForSending([photo.path, folder.path, p.join(temp.path, 'missing.txt')]);
    expect(entries.map((e) => e.name), ['photo.png', 'Project/a.txt', 'Project/sub/b.json']);
    expect(entries.first.size, 3);
    expect(entries.first.mimeType, 'image/png');
    expect(entries[2].mimeType, 'application/json');
  });

  test('unknown types are sent as octet-stream', () {
    final file = File(p.join(temp.path, 'data.unknownext'))..writeAsStringSync('x');
    expect(expandForSending([file.path]).single.mimeType, 'application/octet-stream');
  });
}
