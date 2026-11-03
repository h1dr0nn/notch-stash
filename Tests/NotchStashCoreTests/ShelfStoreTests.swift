import XCTest
@testable import NotchStashCore

@MainActor
final class ShelfStoreTests: XCTestCase {
    private func makeStore(existing: Set<String> = []) -> ShelfStore {
        ShelfStore(fileExists: { existing.contains($0.path) })
    }

    func testAddAppendsInOrderWithNames() {
        let store = makeStore(existing: ["/tmp/a.txt", "/tmp/b.txt"])
        let added = store.add([URL(fileURLWithPath: "/tmp/a.txt"), URL(fileURLWithPath: "/tmp/b.txt")])
        XCTAssertEqual(added.map(\.name), ["a.txt", "b.txt"])
        XCTAssertEqual(store.items, added)
        XCTAssertFalse(store.isEmpty)
    }

    func testSkipsNonFileURLs() {
        let store = makeStore()
        let added = store.add([URL(string: "https://example.com/a.txt")].compactMap { $0 })
        XCTAssertTrue(added.isEmpty)
        XCTAssertTrue(store.isEmpty)
    }

    func testSkipsMissingFiles() {
        let store = makeStore(existing: ["/tmp/a.txt"])
        let added = store.add([URL(fileURLWithPath: "/tmp/missing.txt"), URL(fileURLWithPath: "/tmp/a.txt")])
        XCTAssertEqual(added.map(\.name), ["a.txt"])
    }

    func testSkipsDuplicatesAgainstExistingAndWithinBatch() {
        let store = makeStore(existing: ["/tmp/a.txt", "/tmp/b.txt"])
        store.add([URL(fileURLWithPath: "/tmp/a.txt")])
        let added = store.add([
            URL(fileURLWithPath: "/tmp/x/../a.txt"),
            URL(fileURLWithPath: "/tmp/b.txt"),
            URL(fileURLWithPath: "/tmp/b.txt")
        ])
        XCTAssertEqual(added.map(\.name), ["b.txt"])
        XCTAssertEqual(store.items.count, 2)
    }

    func testRemoveByIds() {
        let store = makeStore(existing: ["/tmp/a.txt", "/tmp/b.txt"])
        let added = store.add([URL(fileURLWithPath: "/tmp/a.txt"), URL(fileURLWithPath: "/tmp/b.txt")])
        store.remove(ids: [added[0].id])
        XCTAssertEqual(store.items.map(\.name), ["b.txt"])
    }

    func testRemoveAll() {
        let store = makeStore(existing: ["/tmp/a.txt"])
        store.add([URL(fileURLWithPath: "/tmp/a.txt")])
        store.removeAll()
        XCTAssertTrue(store.isEmpty)
    }

    func testPruneMissing() {
        var existing: Set<String> = ["/tmp/a.txt", "/tmp/b.txt"]
        let store = ShelfStore(fileExists: { existing.contains($0.path) })
        store.add([URL(fileURLWithPath: "/tmp/a.txt"), URL(fileURLWithPath: "/tmp/b.txt")])
        existing.remove("/tmp/a.txt")
        XCTAssertEqual(store.pruneMissing(), 1)
        XCTAssertEqual(store.items.map(\.name), ["b.txt"])
        XCTAssertEqual(store.pruneMissing(), 0)
    }

    func testDefaultFileExistsUsesFileSystem() {
        let store = ShelfStore()
        XCTAssertEqual(store.add([URL(fileURLWithPath: "/definitely/not/here.txt")]).count, 0)
        XCTAssertEqual(store.add([URL(fileURLWithPath: "/")]).count, 1)
    }
}
