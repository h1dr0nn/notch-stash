import 'dart:io';

import 'package:launch_at_startup/launch_at_startup.dart';

/// "Start with Windows": a per-user Run entry that starts the app hidden in the tray.
///
/// The installer's optional startup task writes the same value, so Settings shows it as on.
class StartupEntry {
  StartupEntry._();

  static const String appName = 'Notch Stash';
  static const String startupArgument = '--startup';

  static void setup() {
    launchAtStartup.setup(
      appName: appName,
      appPath: '"${Platform.resolvedExecutable}"',
      args: const [startupArgument],
    );
  }

  static Future<bool> isEnabled() async {
    try {
      return await launchAtStartup.isEnabled();
    } on Object {
      return false;
    }
  }

  static Future<bool> setEnabled(bool enabled) async {
    try {
      return enabled ? await launchAtStartup.enable() : await launchAtStartup.disable();
    } on Object {
      return false;
    }
  }
}
