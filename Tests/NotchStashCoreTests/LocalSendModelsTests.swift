import Foundation
import NotchStashCore
import XCTest

final class LocalSendModelsTests: XCTestCase {
    private let requestJSON = """
    {
      "info": {
        "alias": "Nice Orange",
        "version": "2.0",
        "deviceModel": "Samsung",
        "deviceType": "mobile",
        "fingerprint": "random string",
        "port": 53317,
        "protocol": "https",
        "download": true,
        "unknownKey": 42
      },
      "files": {
        "some file id": {
          "id": "some file id",
          "fileName": "my image.png",
          "size": 324242,
          "fileType": "image/jpeg",
          "sha256": "abc",
          "preview": "data",
          "metadata": { "modified": "2021-01-01T12:34:56Z" }
        },
        "another file id": {
          "id": "another file id",
          "fileName": "another image.jpg",
          "size": 1234,
          "fileType": "image/jpeg"
        }
      }
    }
    """

    func testDecodesPrepareUploadRequest() throws {
        let request = try JSONDecoder().decode(LocalSendPrepareUploadRequest.self, from: Data(requestJSON.utf8))
        XCTAssertEqual(request.info.alias, "Nice Orange")
        XCTAssertEqual(request.info.port, 53317)
        XCTAssertEqual(request.info.protocol, "https")
        XCTAssertNil(request.info.announce)
        XCTAssertEqual(request.files.count, 2)
        XCTAssertEqual(request.files["some file id"]?.size, 324242)
        XCTAssertNil(request.files["another file id"]?.sha256)
    }

    func testRequestRoundTrip() throws {
        let request = try JSONDecoder().decode(LocalSendPrepareUploadRequest.self, from: Data(requestJSON.utf8))
        let data = try JSONEncoder().encode(request)
        XCTAssertEqual(try JSONDecoder().decode(LocalSendPrepareUploadRequest.self, from: data), request)
    }

    func testEncodingOmitsNilOptionals() throws {
        let info = LocalSendDeviceInfo(alias: "A", fingerprint: "f")
        let data = try JSONEncoder().encode(info)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(Set(object.keys), ["alias", "version", "fingerprint"])
        XCTAssertEqual(object["version"] as? String, "2.1")
    }

    func testDecodesMinimalDeviceInfo() throws {
        let json = #"{"alias":"X","version":"2.0","fingerprint":"fp"}"#
        let info = try JSONDecoder().decode(LocalSendDeviceInfo.self, from: Data(json.utf8))
        XCTAssertNil(info.deviceModel)
        XCTAssertNil(info.download)
    }

    func testPrepareUploadResponseRoundTrip() throws {
        let json = #"{"sessionId":"mySessionId","files":{"a":"tokenA","b":"tokenB"}}"#
        let response = try JSONDecoder().decode(LocalSendPrepareUploadResponse.self, from: Data(json.utf8))
        XCTAssertEqual(response, LocalSendPrepareUploadResponse(sessionId: "mySessionId", files: ["a": "tokenA", "b": "tokenB"]))
        let data = try JSONEncoder().encode(response)
        XCTAssertEqual(try JSONDecoder().decode(LocalSendPrepareUploadResponse.self, from: data), response)
    }
}
