import 'package:flutter/foundation.dart';

/// LocalSend defaults (protocol section 1).
class LocalSendDefaults {
  LocalSendDefaults._();

  static const int port = 53317;
  static const String multicastGroup = '224.0.0.167';
  static const String protocolVersion = '2.1';
  static const String apiBase = '/api/localsend/v2';
}

/// Device info used in announcements, register and prepare-upload requests.
@immutable
class DeviceInfo {
  const DeviceInfo({
    required this.alias,
    required this.fingerprint,
    this.version = LocalSendDefaults.protocolVersion,
    this.deviceModel,
    this.deviceType,
    this.port,
    this.protocol,
    this.download,
    this.announce,
  });

  final String alias;
  final String version;
  final String? deviceModel;
  final String? deviceType;
  final String fingerprint;
  final int? port;
  final String? protocol;
  final bool? download;
  final bool? announce;

  /// Parses a JSON object; returns null when required fields are missing.
  static DeviceInfo? fromJson(Object? json) {
    if (json is! Map) return null;
    final alias = json['alias'];
    final fingerprint = json['fingerprint'];
    if (alias is! String || fingerprint is! String) return null;
    final version = json['version'];
    final port = json['port'];
    return DeviceInfo(
      alias: alias,
      fingerprint: fingerprint,
      version: version is String ? version : '1.0',
      deviceModel: _string(json['deviceModel']),
      deviceType: _string(json['deviceType']),
      port: port is int ? port : (port is num ? port.toInt() : null),
      protocol: _string(json['protocol']),
      download: _bool(json['download']),
      announce: _bool(json['announce']),
    );
  }

  Map<String, Object?> toJson() => {
        'alias': alias,
        'version': version,
        'deviceModel': deviceModel,
        'deviceType': deviceType,
        'fingerprint': fingerprint,
        if (port != null) 'port': port,
        if (protocol != null) 'protocol': protocol,
        if (download != null) 'download': download,
        if (announce != null) 'announce': announce,
      };

  DeviceInfo copyWith({bool? announce}) => DeviceInfo(
        alias: alias,
        fingerprint: fingerprint,
        version: version,
        deviceModel: deviceModel,
        deviceType: deviceType,
        port: port,
        protocol: protocol,
        download: download,
        announce: announce,
      );

  @override
  bool operator ==(Object other) =>
      other is DeviceInfo &&
      other.alias == alias &&
      other.version == version &&
      other.deviceModel == deviceModel &&
      other.deviceType == deviceType &&
      other.fingerprint == fingerprint &&
      other.port == port &&
      other.protocol == protocol &&
      other.download == download &&
      other.announce == announce;

  @override
  int get hashCode => Object.hash(
      alias, version, deviceModel, deviceType, fingerprint, port, protocol, download, announce);
}

/// Metadata describing one file offered in a prepare-upload request.
@immutable
class FileInfo {
  const FileInfo({
    required this.id,
    required this.fileName,
    required this.size,
    required this.fileType,
    this.sha256,
    this.preview,
  });

  final String id;
  final String fileName;
  final int size;
  final String fileType;
  final String? sha256;
  final String? preview;

  static FileInfo? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final fileName = json['fileName'];
    final size = json['size'];
    if (id is! String || fileName is! String || size is! num) return null;
    return FileInfo(
      id: id,
      fileName: fileName,
      size: size.toInt(),
      fileType: _string(json['fileType']) ?? 'application/octet-stream',
      sha256: _string(json['sha256']),
      preview: _string(json['preview']),
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'fileName': fileName,
        'size': size,
        'fileType': fileType,
        if (sha256 != null) 'sha256': sha256,
        if (preview != null) 'preview': preview,
      };

  @override
  bool operator ==(Object other) =>
      other is FileInfo &&
      other.id == id &&
      other.fileName == fileName &&
      other.size == size &&
      other.fileType == fileType &&
      other.sha256 == sha256 &&
      other.preview == preview;

  @override
  int get hashCode => Object.hash(id, fileName, size, fileType, sha256, preview);
}

/// Body of a prepare-upload request.
@immutable
class PrepareUploadRequest {
  const PrepareUploadRequest({required this.info, required this.files});

  final DeviceInfo info;
  final Map<String, FileInfo> files;

  static PrepareUploadRequest? fromJson(Object? json) {
    if (json is! Map) return null;
    final info = DeviceInfo.fromJson(json['info']);
    final rawFiles = json['files'];
    if (info == null || rawFiles is! Map) return null;
    final files = <String, FileInfo>{};
    for (final entry in rawFiles.entries) {
      final file = FileInfo.fromJson(entry.value);
      if (entry.key is! String || file == null) return null;
      files[entry.key as String] = file;
    }
    return PrepareUploadRequest(info: info, files: files);
  }

  Map<String, Object?> toJson() => {
        'info': info.toJson(),
        'files': files.map((key, value) => MapEntry(key, value.toJson())),
      };
}

/// Body of a prepare-upload response.
@immutable
class PrepareUploadResponse {
  const PrepareUploadResponse({required this.sessionId, required this.files});

  final String sessionId;

  /// File id to upload token.
  final Map<String, String> files;

  static PrepareUploadResponse? fromJson(Object? json) {
    if (json is! Map) return null;
    final sessionId = json['sessionId'];
    final rawFiles = json['files'];
    if (sessionId is! String || rawFiles is! Map) return null;
    final files = <String, String>{};
    for (final entry in rawFiles.entries) {
      if (entry.key is! String || entry.value is! String) return null;
      files[entry.key as String] = entry.value as String;
    }
    return PrepareUploadResponse(sessionId: sessionId, files: files);
  }

  Map<String, Object?> toJson() => {'sessionId': sessionId, 'files': files};
}

/// A LocalSend device found on the network.
@immutable
class Peer {
  const Peer({
    required this.fingerprint,
    required this.alias,
    required this.ip,
    required this.port,
    required this.scheme,
    required this.lastSeen,
    this.deviceModel,
    this.deviceType,
  });

  factory Peer.fromInfo(DeviceInfo info, String ip, DateTime seen) => Peer(
        fingerprint: info.fingerprint,
        alias: info.alias,
        deviceModel: info.deviceModel,
        deviceType: info.deviceType,
        ip: ip,
        port: info.port ?? LocalSendDefaults.port,
        scheme: info.protocol == 'http' ? 'http' : 'https',
        lastSeen: seen,
      );

  final String fingerprint;
  final String alias;
  final String? deviceModel;
  final String? deviceType;
  final String ip;
  final int port;
  final String scheme;
  final DateTime lastSeen;

  String get id => fingerprint;

  Uri endpoint(String route, [Map<String, String>? query]) => Uri(
        scheme: scheme,
        host: ip,
        port: port,
        path: '${LocalSendDefaults.apiBase}/$route',
        queryParameters: query,
      );

  /// "MacBook Pro · 192.168.1.20".
  String get subtitle => [if (deviceModel != null && deviceModel!.isNotEmpty) deviceModel!, ip].join(' · ');
}

String? _string(Object? value) => value is String ? value : null;
bool? _bool(Object? value) => value is bool ? value : null;
