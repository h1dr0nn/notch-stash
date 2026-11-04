import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'core/shortcut.dart';

/// User preferences, stored with shared_preferences.
class AppSettings extends ChangeNotifier {
  AppSettings._(this._prefs, this._defaultSaveFolder);

  static const _shortcutKey = 'shortcut';
  static const _nearbySharingKey = 'nearbySharingEnabled';
  static const _receiveFilesKey = 'receiveFiles';
  static const _deviceNameKey = 'deviceName';
  static const _saveFolderKey = 'saveFolderPath';
  static const _fingerprintKey = 'localSendFingerprint';
  static const _checkForUpdatesKey = 'checkForUpdates';

  final SharedPreferencesWithCache _prefs;
  final String _defaultSaveFolder;

  /// Loads settings; [defaultSaveFolder] is used until the user picks another folder.
  static Future<AppSettings> load({required String defaultSaveFolder}) async {
    final prefs = await SharedPreferencesWithCache.create(cacheOptions: const SharedPreferencesWithCacheOptions());
    final settings = AppSettings._(prefs, defaultSaveFolder);
    if (prefs.getString(_fingerprintKey) == null) {
      await prefs.setString(_fingerprintKey, newFingerprint());
    }
    return settings;
  }

  /// Random 32-character hex string; LocalSend uses it in HTTP mode to spot itself.
  static String newFingerprint([Random? random]) {
    final source = random ?? Random.secure();
    return List.generate(16, (_) => source.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  /// The user's Downloads folder, falling back to the home folder.
  static String downloadsFolder() {
    final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? Directory.current.path;
    return p.join(home, 'Downloads');
  }

  Shortcut get shortcut {
    final raw = _prefs.getString(_shortcutKey);
    if (raw == null) return Shortcut.defaultShortcut;
    try {
      return Shortcut.fromJson(jsonDecode(raw)) ?? Shortcut.defaultShortcut;
    } on FormatException {
      return Shortcut.defaultShortcut;
    }
  }

  Future<void> setShortcut(Shortcut value) async {
    await _prefs.setString(_shortcutKey, jsonEncode(value.toJson()));
    notifyListeners();
  }

  bool get nearbySharingEnabled => _prefs.getBool(_nearbySharingKey) ?? true;

  Future<void> setNearbySharingEnabled(bool value) async {
    await _prefs.setBool(_nearbySharingKey, value);
    notifyListeners();
  }

  bool get receiveFiles => _prefs.getBool(_receiveFilesKey) ?? true;

  Future<void> setReceiveFiles(bool value) async {
    await _prefs.setBool(_receiveFilesKey, value);
    notifyListeners();
  }

  /// Name shown to other devices; the computer name by default.
  String get deviceName {
    final stored = _prefs.getString(_deviceNameKey)?.trim();
    if (stored != null && stored.isNotEmpty) return stored;
    final host = Platform.localHostname.trim();
    return host.isEmpty ? 'Windows PC' : host;
  }

  Future<void> setDeviceName(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await _prefs.remove(_deviceNameKey);
    } else {
      await _prefs.setString(_deviceNameKey, trimmed);
    }
    notifyListeners();
  }

  String get saveFolder => _prefs.getString(_saveFolderKey) ?? _defaultSaveFolder;

  Future<void> setSaveFolder(String value) async {
    await _prefs.setString(_saveFolderKey, value);
    notifyListeners();
  }

  String get fingerprint => _prefs.getString(_fingerprintKey) ?? '';

  bool get checkForUpdates => _prefs.getBool(_checkForUpdatesKey) ?? true;

  Future<void> setCheckForUpdates(bool value) async {
    await _prefs.setBool(_checkForUpdatesKey, value);
    notifyListeners();
  }
}
