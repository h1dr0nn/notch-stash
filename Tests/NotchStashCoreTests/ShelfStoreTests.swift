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

final class DropStashTests: XCTestCase {
    private var root: URL!
    private var source: URL!

    override func setUpWithError() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("DropStashTests-\(UUID().uuidString)")
        root = base.appendingPathComponent("stash")
        source = base.appendingPathComponent("Screenshot.png")
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        try Data("pixels".utf8).write(to: source)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root.deletingLastPathComponent())
    }

    func testRecognisesTemporaryFolders() {
        XCTAssertTrue(DropStash.isTemporary(source))
        XCTAssertTrue(DropStash.isTemporary(URL(fileURLWithPath: "/private/tmp/a.png")))
        XCTAssertFalse(DropStash.isTemporary(URL(fileURLWithPath: "/Users/someone/Desktop/a.png")))
    }

    func testCopiesTemporaryFileAndKeepsItsName() throws {
        let stash = DropStash(root: root)
        let kept = stash.preserve(source)
        XCTAssertNotEqual(kept, source)
        XCTAssertEqual(kept.lastPathComponent, "Screenshot.png")
        try FileManager.default.removeItem(at: source)
        XCTAssertEqual(try Data(contentsOf: kept), Data("pixels".utf8))
    }

    func testLeavesOtherFilesAsReferences() {
        let stash = DropStash(root: root)
        let desktop = URL(fileURLWithPath: "/Users/someone/Desktop/a.png")
        XCTAssertEqual(stash.preserve(desktop), desktop)
    }

    func testRemovesOnlyOldCopiesNotOnTheShelf() {
        let stash = DropStash(root: root)
        let onShelf = stash.preserve(source)
        let dropped = stash.preserve(source)
        stash.removeUnused(keeping: [onShelf], minimumAge: 3600)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dropped.path), "young copies stay")
        stash.removeUnused(keeping: [onShelf], minimumAge: 3600, now: Date().addingTimeInterval(7200))
        XCTAssertFalse(FileManager.default.fileExists(atPath: dropped.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: onShelf.path))
    }

    @MainActor
    func testStoreKeepsThePreservedCopy() throws {
        let stash = DropStash(root: root)
        let store = ShelfStore(preserve: stash.preserve)
        store.add([source])
        try FileManager.default.removeItem(at: source)
        XCTAssertEqual(store.pruneMissing(), 0)
        XCTAssertEqual(store.items.map(\.name), ["Screenshot.png"])
    }
}
