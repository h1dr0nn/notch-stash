import 'package:flutter_test/flutter_test.dart';
import 'package:notch_stash/src/core/file_naming.dart';

void main() {
  group('safeRelativePath', () {
    test('keeps subfolders', () {
      expect(FileNaming.safeRelativePath('photos/2024/a.jpg'), 'photos/2024/a.jpg');
      expect(FileNaming.safeRelativePath(r'photos\2024\a.jpg'), 'photos/2024/a.jpg');
    });

    test('cannot escape the base folder', () {
      expect(FileNaming.safeRelativePath('../../etc/passwd'), 'etc/passwd');
      expect(FileNaming.safeRelativePath('/abs/./file.txt'), 'abs/file.txt');
      expect(FileNaming.safeRelativePath(r'..\..\Windows\win.ini'), 'Windows/win.ini');
      expect(FileNaming.safeRelativePath('C:/Users/x.txt'), 'C_/Users/x.txt');
    });

    test('falls back to "file" when nothing is left', () {
      expect(FileNaming.safeRelativePath(''), 'file');
      expect(FileNaming.safeRelativePath('../..'), 'file');
      expect(FileNaming.safeRelativePath('...'), 'file');
    });

    test('replaces characters Windows forbids and trailing dots', () {
      expect(FileNaming.safeRelativePath('what?.txt'), 'what_.txt');
      expect(FileNaming.safeRelativePath('a<b>c:d"e|f*.txt'), 'a_b_c_d_e_f_.txt');
      expect(FileNaming.safeRelativePath('name. '), 'name');
    });

    test('escapes reserved device names', () {
      expect(FileNaming.safeRelativePath('CON'), '_CON');
      expect(FileNaming.safeRelativePath('nul.txt'), '_nul.txt');
      expect(FileNaming.safeRelativePath('console.txt'), 'console.txt');
    });
  });

  group('uniqueName', () {
    test('returns the name when it is free', () {
      expect(FileNaming.uniqueName('a.txt', (_) => false), 'a.txt');
    });

    test('numbers before the extension', () {
      final taken = {'a.txt', 'a (1).txt'};
      expect(FileNaming.uniqueName('a.txt', taken.contains), 'a (2).txt');
    });

    test('handles names without an extension and dot files', () {
      expect(FileNaming.uniqueName('README', {'README'}.contains), 'README (1)');
      expect(FileNaming.uniqueName('.env', {'.env'}.contains), '.env (1)');
      expect(FileNaming.uniqueName('archive.tar.gz', {'archive.tar.gz'}.contains), 'archive.tar (1).gz');
    });

    test('keeps the folder of nested names', () {
      expect(FileNaming.uniqueName('dir/a.txt', {'dir/a.txt'}.contains), 'dir/a (1).txt');
    });
  });
}
