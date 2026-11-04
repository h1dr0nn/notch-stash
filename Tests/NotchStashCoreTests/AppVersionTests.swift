import NotchStashCore
import XCTest

final class AppVersionTests: XCTestCase {
    func testParsesPlainAndTaggedVersions() {
        XCTAssertEqual(AppVersion("0.6.1")?.components, [0, 6, 1])
        XCTAssertEqual(AppVersion("v1.2")?.components, [1, 2])
        XCTAssertEqual(AppVersion("release-v0.6.1")?.components, [0, 6, 1])
        XCTAssertEqual(AppVersion("develop-v2.0.0")?.description, "2.0.0")
    }

    func testRejectsInvalidText() {
        XCTAssertNil(AppVersion(""))
        XCTAssertNil(AppVersion("1.x"))
        XCTAssertNil(AppVersion("1..2"))
    }

    func testOrdering() throws {
        let older = try XCTUnwrap(AppVersion("0.5.2"))
        let newer = try XCTUnwrap(AppVersion("0.6.0"))
        XCTAssertLessThan(older, newer)
        XCTAssertLessThan(try XCTUnwrap(AppVersion("0.9.9")), try XCTUnwrap(AppVersion("0.10.0")))
        XCTAssertFalse(newer < older)
    }

    func testMissingComponentsCountAsZero() throws {
        XCTAssertEqual(try XCTUnwrap(AppVersion("1.0")), try XCTUnwrap(AppVersion("1.0.0")))
        XCTAssertLessThan(try XCTUnwrap(AppVersion("1.0")), try XCTUnwrap(AppVersion("1.0.1")))
    }
}
