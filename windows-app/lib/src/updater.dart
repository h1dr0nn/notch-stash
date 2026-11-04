import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'core/app_version.dart';
import 'core/release_info.dart';

/// Where the updater is.
enum UpdateStatus { idle, checking, upToDate, available, downloading, installing, failed }

/// Checks GitHub Releases for a newer version and installs it with the published installer.
class Updater extends ChangeNotifier {
  Updater({required this.currentVersion, required this.isEnabled, required this.onInstallerStarted});

  static final Uri _latestRelease = Uri.parse('https://api.github.com/repos/h1dr0nn/notch-stash/releases/latest');
  static final Uri _latestReleasePage = Uri.parse('https://github.com/h1dr0nn/notch-stash/releases/latest');

  final String currentVersion;

  /// Whether automatic checks are on in Settings.
  final bool Function() isEnabled;

  /// Called once the installer runs; the app quits so the installer can replace it.
  final Future<void> Function() onInstallerStarted;

  UpdateStatus _status = UpdateStatus.idle;
  ReleaseInfo? _release;
  double _progress = 0;
  String _error = '';
  Timer? _timer;

  UpdateStatus get status => _status;
  ReleaseInfo? get available => _status == UpdateStatus.available ? _release : null;
  double get progress => _progress;
  String get error => _error;

  /// Checks shortly after launch and then once a day.
  void startAutomaticChecks() {
    Timer(const Duration(seconds: 10), _checkIfEnabled);
    _timer = Timer.periodic(const Duration(hours: 24), (_) => _checkIfEnabled());
  }

  void _checkIfEnabled() {
    if (isEnabled()) unawaited(check());
  }

  Future<void> check() async {
    if (_status == UpdateStatus.downloading || _status == UpdateStatus.installing) return;
    _set(UpdateStatus.checking);
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(_latestRelease);
      request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      request.headers.set(HttpHeaders.userAgentHeader, 'NotchStash/$currentVersion');
      final response = await request.close();
      ReleaseInfo? release;
      if (response.statusCode == 200) {
        final json = jsonDecode(await response.transform(utf8.decoder).join());
        release = json is Map<String, dynamic> ? ReleaseInfo.fromGitHubJson(json) : null;
      } else {
        // The API allows 60 calls an hour per address; shared office networks run out quickly.
        await response.drain<void>();
        release = await _releaseFromLatestPage(client);
      }
      final current = AppVersion.tryParse(currentVersion);
      if (release == null || current == null || !(release.version > current)) {
        _release = null;
        return _set(UpdateStatus.upToDate);
      }
      _release = release;
      _set(UpdateStatus.available);
    } on Object catch (error) {
      _fail('Could not check for updates: $error');
    } finally {
      client.close();
    }
  }

  Future<ReleaseInfo?> _releaseFromLatestPage(HttpClient client) async {
    final request = await client.headUrl(_latestReleasePage);
    request.followRedirects = false;
    request.headers.set(HttpHeaders.userAgentHeader, 'NotchStash/$currentVersion');
    final response = await request.close();
    await response.drain<void>();
    final location = response.headers.value(HttpHeaders.locationHeader);
    return location == null ? null : ReleaseInfo.fromTagPage(Uri.parse(location));
  }

  /// Downloads the installer, verifies it, starts it silently and quits.
  Future<void> install() async {
    final release = _release;
    if (release == null) return;
    _progress = 0;
    _set(UpdateStatus.downloading);
    final client = HttpClient();
    try {
      final folder = await Directory.systemTemp.createTemp('NotchStashUpdate');
      final installer = File(p.join(folder.path, ReleaseInfo.installerName(release.version)));
      final request = await client.getUrl(release.installerUrl);
      request.headers.set(HttpHeaders.userAgentHeader, 'NotchStash/$currentVersion');
      final response = await request.close();
      if (response.statusCode != 200) {
        await response.drain<void>();
        return _fail('The download failed. Try again later.');
      }
      final total = response.contentLength > 0 ? response.contentLength : 0;
      final sink = installer.openWrite();
      var received = 0;
      final digestSink = _DigestSink();
      final hasher = sha256.startChunkedConversion(digestSink);
      await for (final chunk in response) {
        sink.add(chunk);
        hasher.add(chunk);
        received += chunk.length;
        if (total > 0) {
          _progress = received / total;
          notifyListeners();
        }
      }
      await sink.close();
      hasher.close();
      final expected = release.sha256;
      if (expected != null && digestSink.value?.toString() != expected) {
        return _fail('The download is damaged. Try again.');
      }
      _set(UpdateStatus.installing);
      await Process.start(installer.path, [
        '/VERYSILENT',
        '/SUPPRESSMSGBOXES',
        '/NORESTART',
        '/CLOSEAPPLICATIONS',
      ], mode: ProcessStartMode.detached);
      await onInstallerStarted();
    } on Object catch (error) {
      _fail('Could not install the update: $error');
    } finally {
      client.close();
    }
  }

  void _set(UpdateStatus status) {
    _status = status;
    notifyListeners();
  }

  void _fail(String message) {
    _error = message;
    _set(UpdateStatus.failed);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Receives the final hash from a chunked SHA-256 conversion.
class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
