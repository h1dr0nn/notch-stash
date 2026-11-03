import CoreGraphics
import XCTest
@testable import NotchStashCore

final class NotchGeometryTests: XCTestCase {
    private let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)

    func testNoNotchReturnsNil() {
        XCTAssertNil(NotchGeometry.notchRect(screenFrame: screen, safeAreaTop: 0, leftAuxWidth: 600, rightAuxWidth: 600))
        XCTAssertNil(NotchGeometry.notchRect(screenFrame: screen, safeAreaTop: 32, leftAuxWidth: nil, rightAuxWidth: 600))
        XCTAssertNil(NotchGeometry.notchRect(screenFrame: screen, safeAreaTop: 32, leftAuxWidth: 600, rightAuxWidth: nil))
        XCTAssertNil(NotchGeometry.notchRect(screenFrame: screen, safeAreaTop: 32, leftAuxWidth: 0, rightAuxWidth: 600))
        XCTAssertNil(NotchGeometry.notchRect(screenFrame: screen, safeAreaTop: 32, leftAuxWidth: 600, rightAuxWidth: 0))
    }

    func testNotchMath() {
        let rect = NotchGeometry.notchRect(screenFrame: screen, safeAreaTop: 32, leftAuxWidth: 666, rightAuxWidth: 666)
        XCTAssertEqual(rect, CGRect(x: 666, y: 950, width: 180, height: 32))
    }

    func testNotchMathWithOffsetScreen() {
        let frame = CGRect(x: 1000, y: 200, width: 1000, height: 800)
        let rect = NotchGeometry.notchRect(screenFrame: frame, safeAreaTop: 30, leftAuxWidth: 450, rightAuxWidth: 400)
        XCTAssertEqual(rect, CGRect(x: 1450, y: 970, width: 150, height: 30))
    }

    func testTopCenteredRect() {
        let frame = CGRect(x: 100, y: 50, width: 1000, height: 800)
        let rect = NotchGeometry.topCenteredRect(in: frame, size: CGSize(width: 200, height: 40))
        XCTAssertEqual(rect, CGRect(x: 500, y: 810, width: 200, height: 40))
    }

    private let visible = CGRect(x: 0, y: 0, width: 1000, height: 800)
    private let size = CGSize(width: 200, height: 100)

    func testPanelDefaultsBottomRightOfCursor() {
        let origin = NotchGeometry.panelOrigin(cursor: CGPoint(x: 300, y: 500), panelSize: size, visibleFrame: visible)
        XCTAssertEqual(origin, CGPoint(x: 316, y: 384))
    }

    func testPanelFlipsLeftNearRightEdge() {
        let origin = NotchGeometry.panelOrigin(cursor: CGPoint(x: 900, y: 500), panelSize: size, visibleFrame: visible)
        XCTAssertEqual(origin, CGPoint(x: 684, y: 384))
    }

    func testPanelFlipsUpNearBottomEdge() {
        let origin = NotchGeometry.panelOrigin(cursor: CGPoint(x: 300, y: 50), panelSize: size, visibleFrame: visible)
        XCTAssertEqual(origin, CGPoint(x: 316, y: 66))
    }

    func testPanelFlipsBothAtBottomRightCorner() {
        let origin = NotchGeometry.panelOrigin(cursor: CGPoint(x: 950, y: 30), panelSize: size, visibleFrame: visible)
        XCTAssertEqual(origin, CGPoint(x: 734, y: 46))
    }

    func testPanelClampsInsideVisibleFrame() {
        let origin = NotchGeometry.panelOrigin(cursor: CGPoint(x: 50, y: 790), panelSize: size, visibleFrame: visible)
        XCTAssertEqual(origin, CGPoint(x: 66, y: 674))
        let wide = CGSize(width: 1200, height: 100)
        let clamped = NotchGeometry.panelOrigin(cursor: CGPoint(x: 100, y: 780), panelSize: wide, visibleFrame: visible)
        XCTAssertEqual(clamped.x, 0)
        let tall = CGSize(width: 200, height: 700)
        let top = NotchGeometry.panelOrigin(cursor: CGPoint(x: 500, y: 900), panelSize: tall, visibleFrame: visible)
        XCTAssertEqual(top.y, 100)
    }
}
