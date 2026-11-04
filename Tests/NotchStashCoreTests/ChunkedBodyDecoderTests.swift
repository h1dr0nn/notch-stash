import Foundation
import NotchStashCore
import XCTest

final class ChunkedBodyDecoderTests: XCTestCase {
    private let sample = "5\r\nhello\r\n6;foo=bar\r\n world\r\n0\r\nTrailer: x\r\n\r\n"

    func testDecodesWholeBody() throws {
        var decoder = ChunkedBodyDecoder()
        let out = try decoder.feed(Data(sample.utf8))
        XCTAssertEqual((String(bytes: out, encoding: .utf8) ?? ""), "hello world")
        XCTAssertTrue(decoder.isFinished)
    }

    func testByteByByte() throws {
        var decoder = ChunkedBodyDecoder()
        var out = Data()
        for byte in sample.utf8 {
            out.append(try decoder.feed(Data([byte])))
        }
        XCTAssertEqual((String(bytes: out, encoding: .utf8) ?? ""), "hello world")
        XCTAssertTrue(decoder.isFinished)
    }

    func testRandomSplits() throws {
        let bytes = Array(sample.utf8)
        var generator = SystemRandomNumberGenerator()
        for _ in 0..<200 {
            var decoder = ChunkedBodyDecoder()
            var out = Data()
            var index = 0
            while index < bytes.count {
                let size = Int.random(in: 1...7, using: &generator)
                let end = min(bytes.count, index + size)
                out.append(try decoder.feed(Data(bytes[index..<end])))
                index = end
            }
            XCTAssertEqual((String(bytes: out, encoding: .utf8) ?? ""), "hello world")
            XCTAssertTrue(decoder.isFinished)
        }
    }

    func testTerminatorWithoutTrailers() throws {
        var decoder = ChunkedBodyDecoder()
        XCTAssertEqual(try decoder.feed(Data("3\r\nabc\r\n".utf8)), Data("abc".utf8))
        XCTAssertFalse(decoder.isFinished)
        _ = try decoder.feed(Data("0\r\n\r\n".utf8))
        XCTAssertTrue(decoder.isFinished)
    }

    func testUppercaseHexAndBinaryPayload() throws {
        var decoder = ChunkedBodyDecoder()
        let payload = Data((0..<16).map { UInt8($0) })
        var input = Data("A\r\n".utf8)
        input.append(payload.prefix(10))
        input.append(Data("\r\n6\r\n".utf8))
        input.append(payload.suffix(6))
        input.append(Data("\r\n0\r\n\r\n".utf8))
        XCTAssertEqual(try decoder.feed(input), payload)
        XCTAssertTrue(decoder.isFinished)
    }

    func testBadHexThrows() {
        var decoder = ChunkedBodyDecoder()
        XCTAssertThrowsError(try decoder.feed(Data("zz\r\n".utf8))) { error in
            XCTAssertEqual(error as? ChunkedBodyError, .invalidChunkSize)
        }
    }

    func testMissingChunkTerminatorThrows() {
        var decoder = ChunkedBodyDecoder()
        XCTAssertThrowsError(try decoder.feed(Data("2\r\nabXX".utf8)))
    }
}
