import Foundation

/// Device info used in announcements, register and prepare-upload requests.
public struct LocalSendDeviceInfo: Codable, Sendable, Equatable {
    public var alias: String
    public var version: String
    public var deviceModel: String?
    public var deviceType: String?
    public var fingerprint: String
    public var port: Int?
    public var `protocol`: String?
    public var download: Bool?
    public var announce: Bool?

    public init(
        alias: String,
        version: String = "2.1",
        deviceModel: String? = nil,
        deviceType: String? = nil,
        fingerprint: String,
        port: Int? = nil,
        protocol: String? = nil,
        download: Bool? = nil,
        announce: Bool? = nil
    ) {
        self.alias = alias
        self.version = version
        self.deviceModel = deviceModel
        self.deviceType = deviceType
        self.fingerprint = fingerprint
        self.port = port
        self.protocol = `protocol`
        self.download = download
        self.announce = announce
    }
}

/// Metadata describing one file offered in a prepare-upload request.
public struct LocalSendFileInfo: Codable, Sendable, Equatable {
    public var id: String
    public var fileName: String
    public var size: Int64
    public var fileType: String
    public var sha256: String?
    public var preview: String?

    public init(
        id: String,
        fileName: String,
        size: Int64,
        fileType: String,
        sha256: String? = nil,
        preview: String? = nil
    ) {
        self.id = id
        self.fileName = fileName
        self.size = size
        self.fileType = fileType
        self.sha256 = sha256
        self.preview = preview
    }
}

/// Body of a prepare-upload request.
public struct LocalSendPrepareUploadRequest: Codable, Sendable, Equatable {
    public var info: LocalSendDeviceInfo
    public var files: [String: LocalSendFileInfo]

    public init(info: LocalSendDeviceInfo, files: [String: LocalSendFileInfo]) {
        self.info = info
        self.files = files
    }
}

/// Body of a prepare-upload response.
public struct LocalSendPrepareUploadResponse: Codable, Sendable, Equatable {
    public var sessionId: String
    public var files: [String: String]

    public init(sessionId: String, files: [String: String]) {
        self.sessionId = sessionId
        self.files = files
    }
}
