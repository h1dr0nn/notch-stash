import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_controller.dart';
import '../platform/window_host.dart';
import 'incoming_view.dart';
import 'send_view.dart';
import 'settings_view.dart';
import 'shelf_view.dart';
import 'theme.dart';

/// The single window's content, switched by [AppController.mode].
class NotchStashApp extends StatelessWidget {
  const NotchStashApp({super.key, required this.app});

  final AppController app;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notch Stash',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): app.closeCurrent},
        child: Focus(
          autofocus: true,
          child: Material(
            color: ShelfColors.background,
            child: ListenableBuilder(
              listenable: app,
              builder: (context, _) => switch (app.mode) {
                WindowMode.shelf || WindowMode.hidden => ShelfView(app: app),
                WindowMode.send => SendView(app: app),
                WindowMode.incoming => IncomingView(app: app),
                WindowMode.settings => SettingsView(app: app),
              },
            ),
          ),
        ),
      ),
    );
  }
}
