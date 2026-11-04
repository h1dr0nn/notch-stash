import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

/// Explorer integration: open files with their default app and reveal them.
class Shell {
  Shell._();

  static Future<void> open(String path) async {
    await launchUrl(Uri.file(path, windows: Platform.isWindows));
  }

  static Future<void> showInExplorer(String path) async {
    if (Platform.isWindows) {
      await Process.start('explorer.exe', ['/select,', path], mode: ProcessStartMode.detached);
    } else if (Platform.isMacOS) {
      await Process.start('open', ['-R', path], mode: ProcessStartMode.detached);
    }
  }
}
