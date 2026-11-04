import Foundation
import NotchStashCore
import XCTest

final class HTTPRequestHeadTests: XCTestCase {
    func testParsesRequestLineQueryAndHeaders() throws {
        let raw = "POST /api/localsend/v2/upload?sessionId=a%20b&fileId=1&token=x HTTP/1.1\r\n"
            + "Host: 192.168.1.2:53317\r\nContent-Length:  42 \r\nX-Mixed-Case: Value\r\n\r\n"
        let parsed = try XCTUnwrap(HTTPRequestHead.parse(Data(raw.utf8)))
        XCTAssertEqual(parsed.head.method, "POST")
        XCTAssertEqual(parsed.head.path, "/api/localsend/v2/upload")
        XCTAssertEqual(parsed.head.query, ["sessionId": "a b", "fileId": "1", "token": "x"])
        XCTAssertEqual(parsed.head.headers["x-mixed-case"], "Value")
        XCTAssertEqual(parsed.head.contentLength, 42)
        XCTAssertFalse(parsed.head.isChunked)
        XCTAssertEqual(parsed.bodyStart, raw.utf8.count)
    }

    func testReturnsNilWhenHeadIncomplete() {
        XCTAssertNil(HTTPRequestHead.parse(Data("GET / HTTP/1.1\r\nHost: x\r\n".utf8)))
        XCTAssertNil(HTTPRequestHead.parse(Data()))
    }

    func testBodyStartWithTrailingBody() throws {
        let head = "POST /x HTTP/1.1\r\ncontent-length: 5\r\n\r\n"
        let data = Data((head + "hello").utf8)
        let parsed = try XCTUnwrap(HTTPRequestHead.parse(data))
        XCTAssertEqual(parsed.bodyStart, head.utf8.count)
        XCTAssertEqual((String(bytes: data[parsed.bodyStart...], encoding: .utf8) ?? ""), "hello")
    }

    func testChunkedDetectionAndLowercasedMethod() throws {
        let raw = "post /x HTTP/1.1\r\nTransfer-Encoding: Chunked\r\n\r\n"
        let parsed = try XCTUnwrap(HTTPRequestHead.parse(Data(raw.utf8)))
        XCTAssertEqual(parsed.head.method, "POST")
        XCTAssertTrue(parsed.head.isChunked)
        XCTAssertNil(parsed.head.contentLength)
    }

    func testPlusIsNotSpaceAndPathIsDecoded() throws {
        let raw = "GET /a%20b/c?q=1+2&flag HTTP/1.1\r\n\r\n"
        let parsed = try XCTUnwrap(HTTPRequestHead.parse(Data(raw.utf8)))
        XCTAssertEqual(parsed.head.path, "/a b/c")
        XCTAssertEqual(parsed.head.query["q"], "1+2")
        XCTAssertEqual(parsed.head.query["flag"], "")
    }

    func testParsesSliceWithNonZeroStartIndex() throws {
        let raw = Data("xxGET /p HTTP/1.1\r\n\r\n".utf8)
        let parsed = try XCTUnwrap(HTTPRequestHead.parse(raw[2...]))
        XCTAssertEqual(parsed.head.path, "/p")
    }
}
