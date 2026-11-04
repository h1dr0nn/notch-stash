import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_controller.dart';
import '../core/shortcut.dart';
import 'common.dart';
import 'theme.dart';

/// Shortcut, startup and nearby sharing preferences.
class SettingsView extends StatelessWidget {
  const SettingsView({super.key, required this.app});

  final AppController app;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([app, app.settings, app.localSend]),
      builder: (context, _) {
        final settings = app.settings;
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PanelHeader(title: 'Settings', onDragStart: app.window.startDragging, onClose: app.hide),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(right: 4),
                  children: [
                    const _SectionTitle('Shortcut'),
                    _Row(
                      title: 'Show Shelf',
                      detail: app.hotkeyFailed
                          ? 'Windows did not accept this shortcut; another app may use it. Pick a different one.'
                          : 'Shows or hides the shelf next to the pointer. Click, then press keys with Ctrl, Alt, Shift or Win.',
                      detailColor: app.hotkeyFailed ? ShelfColors.danger : null,
                      trailing: ShortcutRecorder(
                        shortcut: settings.shortcut,
                        onRecordingChanged: (recording) =>
                            unawaited(recording ? app.pauseHotkey() : app.resumeHotkey()),
                        onRecorded: (shortcut) => unawaited(app.setShortcut(shortcut)),
                      ),
                    ),
                    const _SectionTitle('General'),
                    _Row(
                      title: 'Start with Windows',
                      detail: 'Opens Notch Stash in the notification area when you sign in.',
                      trailing: Switch(
                        value: app.startWithWindows,
                        onChanged: (value) => unawaited(app.setStartWithWindows(value)),
                      ),
                    ),
                    const _SectionTitle('Nearby Sharing'),
                    _Row(
                      title: 'Nearby Sharing',
                      detail: 'Send and receive files with devices running LocalSend on the same network.',
                      trailing: Switch(
                        value: settings.nearbySharingEnabled,
                        onChanged: (value) => unawaited(app.setNearbySharing(value)),
                      ),
                    ),
                    if (settings.nearbySharingEnabled) ...[
                      _Row(
                        title: 'Receive Files',
                        detail: 'Other devices can send files to this PC after you accept them.',
                        trailing: Switch(
                          value: settings.receiveFiles,
                          onChanged: (value) => unawaited(settings.setReceiveFiles(value)),
                        ),
                      ),
                      _Row(
                        title: 'Device Name',
                        detail: 'How this PC appears on other devices.',
                        trailing: SizedBox(
                          width: 170,
                          child: _DeviceNameField(
                            initial: settings.deviceName,
                            onSubmitted: (value) => unawaited(app.setDeviceName(value)),
                          ),
                        ),
                      ),
                      _Row(
                        title: 'Save To',
                        detail: settings.saveFolder,
                        detailMaxLines: 2,
                        trailing: OutlinedButton(
                          onPressed: () => unawaited(_chooseFolder()),
                          child: const Text('Choose…'),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 2, bottom: 8),
                        child: Text(
                          'Received files are saved here and added to the shelf.',
                          style: TextStyle(fontSize: 11, color: ShelfColors.secondaryText),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(height: 16),
              Text(
                'Version ${app.version}',
                style: const TextStyle(fontSize: 11, color: ShelfColors.secondaryText),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _chooseFolder() async {
    final folder = await FilePicker.getDirectoryPath(
      dialogTitle: 'Choose where received files are saved',
      initialDirectory: app.settings.saveFolder,
    );
    if (folder != null && folder.isNotEmpty) await app.settings.setSaveFolder(folder);
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Text(
        title,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ShelfColors.secondaryText),
      ),
    );
  }
}

/// A setting: Title Case name, sentence-case description, control on the right.
class _Row extends StatelessWidget {
  const _Row({
    required this.title,
    required this.detail,
    required this.trailing,
    this.detailColor,
    this.detailMaxLines = 3,
  });

  final String title;
  final String detail;
  final Widget trailing;
  final Color? detailColor;
  final int detailMaxLines;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: ShelfColors.tile, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 2),
                Text(
                  detail,
                  maxLines: detailMaxLines,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: detailColor ?? ShelfColors.secondaryText),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing,
        ],
      ),
    );
  }
}

class _DeviceNameField extends StatefulWidget {
  const _DeviceNameField({required this.initial, required this.onSubmitted});

  final String initial;
  final ValueChanged<String> onSubmitted;

  @override
  State<_DeviceNameField> createState() => _DeviceNameFieldState();
}

class _DeviceNameFieldState extends State<_DeviceNameField> {
  late final TextEditingController _controller = TextEditingController(text: widget.initial);
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) widget.onSubmitted(_controller.text);
    });
  }

  @override
  void didUpdateWidget(_DeviceNameField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus && widget.initial != _controller.text) _controller.text = widget.initial;
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focus,
      maxLength: 64,
      style: const TextStyle(fontSize: 13),
      decoration: const InputDecoration(
        isDense: true,
        counterText: '',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
      onSubmitted: widget.onSubmitted,
    );
  }
}

/// Button that shows the shortcut; click it, then press a key combination to change it.
class ShortcutRecorder extends StatefulWidget {
  const ShortcutRecorder({
    super.key,
    required this.shortcut,
    required this.onRecorded,
    required this.onRecordingChanged,
  });

  final Shortcut shortcut;
  final ValueChanged<Shortcut> onRecorded;
  final ValueChanged<bool> onRecordingChanged;

  @override
  State<ShortcutRecorder> createState() => _ShortcutRecorderState();
}

class _ShortcutRecorderState extends State<ShortcutRecorder> {
  final FocusNode _focus = FocusNode();
  bool _recording = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus && _recording) _setRecording(false);
    });
  }

  @override
  void dispose() {
    if (_recording) widget.onRecordingChanged(false);
    _focus.dispose();
    super.dispose();
  }

  void _setRecording(bool recording) {
    if (_recording == recording) return;
    setState(() => _recording = recording);
    widget.onRecordingChanged(recording);
    if (recording) _focus.requestFocus();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!_recording || event is KeyUpEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _setRecording(false);
      return KeyEventResult.handled;
    }
    final shortcut = Shortcut.fromKeyPress(
      physical: event.physicalKey,
      logical: event.logicalKey,
      pressed: HardwareKeyboard.instance.physicalKeysPressed,
    );
    if (shortcut != null) {
      _setRecording(false);
      widget.onRecorded(shortcut);
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: OutlinedButton(
        onPressed: () => _setRecording(!_recording),
        style: OutlinedButton.styleFrom(
          foregroundColor: _recording ? ShelfColors.accent : ShelfColors.primaryText,
          side: BorderSide(color: _recording ? ShelfColors.accent : ShelfColors.separator),
          minimumSize: const Size(130, 32),
        ),
        child: Text(_recording ? 'Press Keys…' : widget.shortcut.label),
      ),
    );
  }
}
