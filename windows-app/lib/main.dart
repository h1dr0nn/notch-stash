import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'src/app_controller.dart';
import 'src/core/app_version.dart';
import 'src/platform/single_instance.dart';
import 'src/platform/startup.dart';
import 'src/settings.dart';
import 'src/ui/app_root.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  AppController? controller;
  final instance = await SingleInstance.acquire(onActivate: () => controller?.openSettings());
  if (instance == null) {
    // Another copy is running and was asked to show Settings.
    exit(0);
  }

  final settings = await AppSettings.load(defaultSaveFolder: await _downloadsFolder());
  final info = await PackageInfo.fromPlatform();
  final version = AppVersion.tryParse(info.version)?.toString() ?? info.version;

  final app = AppController(settings: settings, version: version);
  controller = app;
  runApp(NotchStashApp(app: app));
  // Launched at sign-in: stay in the notification area. Launched by the user: show Settings,
  // so they can see the app is running and where to find the shortcut.
  await app.start(showSettings: !args.contains(StartupEntry.startupArgument));
}

Future<String> _downloadsFolder() async {
  try {
    final directory = await getDownloadsDirectory();
    if (directory != null) return directory.path;
  } on Object {
    // Fall back to the conventional location below.
  }
  return AppSettings.downloadsFolder();
}
