import 'package:flutter_test/flutter_test.dart';
import 'package:notch_stash/src/core/shelf_store.dart';
import 'package:path/path.dart' as p;

void main() {
  late Set<String> existing;
  late int notifications;

  ShelfStore makeStore({bool caseInsensitive = true}) {
    final store = ShelfStore(
      exists: existing.contains,
      pathContext: p.windows,
      caseInsensitive: caseInsensitive,
    );
    store.addListener(() => notifications++);
    return store;
  }

  setUp(() {
    existing = {r'C:\a.txt', r'C:\b.txt', r'C:\Docs\c.pdf'};
    notifications = 0;
  });

  test('adds existing files in order and keeps references', () {
    final store = makeStore();
    final added = store.add([r'C:\a.txt', r'C:\Docs\c.pdf']);
    expect(added.map((item) => item.path), [r'C:\a.txt', r'C:\Docs\c.pdf']);
    expect(store.items.map((item) => item.name), ['a.txt', 'c.pdf']);
    expect(notifications, 1);
  });

  test('drops duplicates, also with different case or spelling on Windows', () {
    final store = makeStore();
    store.add([r'C:\a.txt']);
    final added = store.add([r'C:\A.TXT', r'C:\Docs\..\a.txt', r'C:\a.txt', r'C:\b.txt', r'C:\b.txt']);
    expect(added.map((item) => item.path), [r'C:\b.txt']);
    expect(store.length, 2);
  });

  test('case-sensitive stores keep names that differ in case', () {
    existing.add(r'C:\A.txt');
    final store = makeStore(caseInsensitive: false);
    store.add([r'C:\a.txt', r'C:\A.txt']);
    expect(store.length, 2);
  });

  test('ignores missing and empty paths without notifying', () {
    final store = makeStore();
    expect(store.add([r'C:\missing.txt', '']), isEmpty);
    expect(store.isEmpty, isTrue);
    expect(notifications, 0);
  });

  test('removes by id and clears', () {
    final store = makeStore();
    final added = store.add([r'C:\a.txt', r'C:\b.txt']);
    store.remove([added.first.id]);
    expect(store.items.single.path, r'C:\b.txt');
    store.remove([999]);
    expect(notifications, 2);
    store.removeAll();
    expect(store.isEmpty, isTrue);
    store.removeAll();
    expect(notifications, 3);
  });

  test('ids stay unique after removal', () {
    final store = makeStore();
    final first = store.add([r'C:\a.txt']).single;
    store.remove([first.id]);
    final again = store.add([r'C:\a.txt']).single;
    expect(again.id, isNot(first.id));
  });

  test('prunes items whose file disappeared', () {
    final store = makeStore();
    store.add([r'C:\a.txt', r'C:\b.txt']);
    existing.remove(r'C:\a.txt');
    expect(store.pruneMissing(), 1);
    expect(store.items.single.path, r'C:\b.txt');
    expect(store.pruneMissing(), 0);
  });
}
