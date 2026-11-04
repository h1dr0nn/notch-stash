import NotchStashCore
import XCTest

final class FileNamingTests: XCTestCase {
    func testSafeRelativePathStripsEscapes() {
        XCTAssertEqual(FileNaming.safeRelativePath("../../etc/passwd"), "etc/passwd")
        XCTAssertEqual(FileNaming.safeRelativePath("/abs/path.txt"), "abs/path.txt")
        XCTAssertEqual(FileNaming.safeRelativePath("album/a.jpg"), "album/a.jpg")
        XCTAssertEqual(FileNaming.safeRelativePath("a\\..\\b\\c.txt"), "a/b/c.txt")
        XCTAssertEqual(FileNaming.safeRelativePath("./x//y.txt"), "x/y.txt")
    }

    func testSafeRelativePathFallback() {
        XCTAssertEqual(FileNaming.safeRelativePath(""), "file")
        XCTAssertEqual(FileNaming.safeRelativePath("../.."), "file")
        XCTAssertEqual(FileNaming.safeRelativePath("/"), "file")
    }

    func testUniqueNameFree() {
        XCTAssertEqual(FileNaming.uniqueName(for: "photo.jpg", exists: { _ in false }), "photo.jpg")
    }

    func testUniqueNameCounts() {
        let taken: Set<String> = ["photo.jpg", "photo (1).jpg"]
        XCTAssertEqual(FileNaming.uniqueName(for: "photo.jpg", exists: taken.contains), "photo (2).jpg")
    }

    func testUniqueNameWithoutExtension() {
        let taken: Set<String> = ["notes"]
        XCTAssertEqual(FileNaming.uniqueName(for: "notes", exists: taken.contains), "notes (1)")
    }

    func testUniqueNameKeepsSubfolder() {
        let taken: Set<String> = ["album/a.jpg"]
        XCTAssertEqual(FileNaming.uniqueName(for: "album/a.jpg", exists: taken.contains), "album/a (1).jpg")
    }

    func testUniqueNameSanitizesFirst() {
        XCTAssertEqual(FileNaming.uniqueName(for: "../x.txt", exists: { _ in false }), "x.txt")
    }
}
