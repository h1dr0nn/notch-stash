import XCTest
@testable import NotchStashCore

final class DoubleTapDetectorTests: XCTestCase {
    private func ctrl(_ down: Bool, others: Bool = false, _ time: TimeInterval) -> DoubleTapDetector.Input {
        .modifiers(controlDown: down, othersDown: others, time: time)
    }

    func testDoubleTapTriggersOnSecondRelease() {
        var detector = DoubleTapDetector()
        XCTAssertFalse(detector.handle(ctrl(true, 0.0)))
        XCTAssertFalse(detector.handle(ctrl(false, 0.1)))
        XCTAssertFalse(detector.handle(ctrl(true, 0.2)))
        XCTAssertTrue(detector.handle(ctrl(false, 0.3)))
    }

    func testSlowTapIgnored() {
        var detector = DoubleTapDetector()
        XCTAssertFalse(detector.handle(ctrl(true, 0.0)))
        XCTAssertFalse(detector.handle(ctrl(false, 0.5)))
        XCTAssertFalse(detector.handle(ctrl(true, 0.6)))
        XCTAssertFalse(detector.handle(ctrl(false, 0.7)))
    }

    func testTooLongIntervalIgnored() {
        var detector = DoubleTapDetector()
        XCTAssertFalse(detector.handle(ctrl(true, 0.0)))
        XCTAssertFalse(detector.handle(ctrl(false, 0.1)))
        XCTAssertFalse(detector.handle(ctrl(true, 0.6)))
        XCTAssertFalse(detector.handle(ctrl(false, 0.7)))
    }

    func testControlPlusKeyCancels() {
        var detector = DoubleTapDetector()
        XCTAssertFalse(detector.handle(ctrl(true, 0.0)))
        XCTAssertFalse(detector.handle(.keyDown(time: 0.05)))
        XCTAssertFalse(detector.handle(ctrl(false, 0.1)))
        XCTAssertFalse(detector.handle(ctrl(true, 0.2)))
        XCTAssertFalse(detector.handle(ctrl(false, 0.3)))
    }

    func testKeyBetweenTapsCancels() {
        var detector = DoubleTapDetector()
        XCTAssertFalse(detector.handle(ctrl(true, 0.0)))
        XCTAssertFalse(detector.handle(ctrl(false, 0.1)))
        XCTAssertFalse(detector.handle(.keyDown(time: 0.15)))
        XCTAssertFalse(detector.handle(ctrl(true, 0.2)))
        XCTAssertFalse(detector.handle(ctrl(false, 0.3)))
    }

    func testControlPlusShiftCancels() {
        var detector = DoubleTapDetector()
        XCTAssertFalse(detector.handle(ctrl(true, 0.0)))
        XCTAssertFalse(detector.handle(ctrl(true, others: true, 0.05)))
        XCTAssertFalse(detector.handle(ctrl(true, 0.07)))
        XCTAssertFalse(detector.handle(ctrl(false, 0.1)))
        XCTAssertFalse(detector.handle(ctrl(true, 0.2)))
        XCTAssertFalse(detector.handle(ctrl(false, 0.3)))
    }

    func testControlPressedWhileOtherHeldIsNotClean() {
        var detector = DoubleTapDetector()
        XCTAssertFalse(detector.handle(ctrl(false, others: true, 0.0)))
        XCTAssertFalse(detector.handle(ctrl(true, others: true, 0.05)))
        XCTAssertFalse(detector.handle(ctrl(false, others: true, 0.1)))
        XCTAssertFalse(detector.handle(ctrl(true, 0.2)))
        XCTAssertFalse(detector.handle(ctrl(false, 0.25)))
    }

    func testThirdTapDoesNotTrigger() {
        var detector = DoubleTapDetector()
        _ = detector.handle(ctrl(true, 0.0))
        _ = detector.handle(ctrl(false, 0.1))
        _ = detector.handle(ctrl(true, 0.2))
        XCTAssertTrue(detector.handle(ctrl(false, 0.3)))
        XCTAssertFalse(detector.handle(ctrl(true, 0.4)))
        XCTAssertFalse(detector.handle(ctrl(false, 0.5)))
    }

    func testRepeatedIdenticalStatesAreIgnored() {
        var detector = DoubleTapDetector()
        XCTAssertFalse(detector.handle(ctrl(true, 0.0)))
        XCTAssertFalse(detector.handle(ctrl(true, 0.05)))
        XCTAssertFalse(detector.handle(ctrl(false, 0.1)))
        XCTAssertFalse(detector.handle(ctrl(false, 0.12)))
        XCTAssertFalse(detector.handle(ctrl(true, 0.2)))
        XCTAssertTrue(detector.handle(ctrl(false, 0.3)))
    }

    func testReleaseWithoutPressIsIgnored() {
        var detector = DoubleTapDetector()
        XCTAssertFalse(detector.handle(ctrl(false, 0.0)))
        XCTAssertFalse(detector.handle(ctrl(true, 0.1)))
        XCTAssertFalse(detector.handle(ctrl(false, 0.2)))
    }
}
